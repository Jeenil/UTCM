function Connect-UTCM {
    <#
    .SYNOPSIS
        Authenticates to Microsoft Graph and stores the access token for subsequent calls.

    .DESCRIPTION
        Supports three modes:
          - Interactive (delegated): Authorization-code flow with PKCE. Opens a browser
            with account picker for sign-in. Requests explicit UTCM scopes so the user
            can consent. Defaults to the well-known Microsoft Graph PowerShell app.
          - Client Credentials (application): client_credentials grant.
            Requires TenantId, ClientId, and ClientSecret.
          - Token: Bring your own access token.

        After connecting, displays account context (user, tenant, scopes, expiry).

    .PARAMETER TenantId
        Azure AD / Entra ID tenant ID (GUID or domain).

    .PARAMETER ClientId
        Application (client) ID. For interactive flow this defaults to the well-known
        Microsoft Graph PowerShell app (14d82eec-204b-4c2f-b7e8-296a70dab67e).

    .PARAMETER ClientSecret
        Client secret for the app registration (application flow only).

    .PARAMETER Scopes
        Space-separated scopes to request. For interactive flow, defaults to the UTCM
        delegated scopes so consent is properly prompted. For client credentials, defaults
        to 'https://graph.microsoft.com/.default'.

    .PARAMETER AccessToken
        Provide an already-acquired access token directly (skips token acquisition).

    .EXAMPLE
        Connect-UTCM -TenantId "contoso.onmicrosoft.com"

    .EXAMPLE
        Connect-UTCM -TenantId "contoso.onmicrosoft.com" -ClientId "00000000-..."

    .EXAMPLE
        Connect-UTCM -TenantId "contoso.onmicrosoft.com" -ClientId "00000000-..." -ClientSecret "s3cret!"

    .EXAMPLE
        Connect-UTCM -AccessToken $myToken
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Interactive')]
        [Parameter(Mandatory, ParameterSetName = 'ClientCredential')]
        [string]$TenantId,

        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(Mandatory, ParameterSetName = 'ClientCredential')]
        [string]$ClientId,

        [Parameter(Mandatory, ParameterSetName = 'ClientCredential')]
        [string]$ClientSecret,

        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'ClientCredential')]
        [string]$Scopes,

        [Parameter(Mandatory, ParameterSetName = 'Token')]
        [string]$AccessToken
    )

    # --- Bring-your-own-token ---
    if ($PSCmdlet.ParameterSetName -eq 'Token') {
        $script:Token         = $AccessToken
        $script:TokenExpiry   = (Get-Date).AddHours(1)
        $script:RefreshToken  = $null  # No refresh capability with BYOT
        $script:TokenEndpoint = $null
        $script:ClientId      = $null
        $script:Context       = Get-UTCMTokenContext -Token $AccessToken
        Write-UTCMContext 'Provided token'
        return
    }

    # Fall back to the well-known Graph PowerShell app ID for interactive flow
    if (-not $ClientId) { $ClientId = $script:GraphPSAppId }

    $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

    if ($PSCmdlet.ParameterSetName -eq 'ClientCredential') {
        # --- Client Credentials ---
        if (-not $Scopes) { $Scopes = 'https://graph.microsoft.com/.default' }

        $body = @{
            client_id     = $ClientId
            scope         = $Scopes
            client_secret = $ClientSecret
            grant_type    = 'client_credentials'
        }
        $response = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded'
        
        $script:Token         = $response.access_token
        $script:TokenExpiry   = (Get-Date).AddSeconds($response.expires_in - 60)
        $script:RefreshToken  = $null  # Client credentials don't get refresh tokens
        $script:TokenEndpoint = $null
        $script:ClientId      = $null
        $script:Context       = Get-UTCMTokenContext -Token $response.access_token
        Write-UTCMContext 'Client credentials'
    }
    else {
        # --- Authorization Code + PKCE (browser-based interactive login) ---
        if (-not $Scopes) { $Scopes = $script:DefaultScopes }

        # 1. Generate PKCE code verifier & challenge
        $codeVerifierBytes = [byte[]]::new(32)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($codeVerifierBytes)
        $codeVerifier  = [Convert]::ToBase64String($codeVerifierBytes) -replace '\+','-' -replace '/','_' -replace '='
        $challengeHash = [System.Security.Cryptography.SHA256]::HashData(
            [System.Text.Encoding]::ASCII.GetBytes($codeVerifier)
        )
        $codeChallenge = [Convert]::ToBase64String($challengeHash) -replace '\+','-' -replace '/','_' -replace '='

        # 2. Pick a random localhost port and set up a temporary HTTP listener
        $port        = Get-Random -Minimum 49152 -Maximum 65535
        $redirectUri = "http://localhost:$port/"
        $listener    = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add($redirectUri)
        $listener.Start()

        # 3. Build and open the authorize URL (prompt=select_account forces account picker)
        $state    = [guid]::NewGuid().ToString('N')
        $authUrl  = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/authorize?" + (
            @(
                "client_id=$ClientId"
                "response_type=code"
                "redirect_uri=$([uri]::EscapeDataString($redirectUri))"
                "response_mode=query"
                "scope=$([uri]::EscapeDataString($Scopes))"
                "state=$state"
                "code_challenge=$codeChallenge"
                "code_challenge_method=S256"
                "prompt=select_account"
            ) -join '&'
        )

        Write-Host "[UTCM] Opening browser for sign-in..." -ForegroundColor Yellow
        Start-Process $authUrl

        # 4. Wait for the redirect (browser posts back)
        try {
            $context  = $listener.GetContext()      # blocks until browser redirects
            $query    = $context.Request.QueryString

            # Return a friendly page to the user
            $html = '<html><body><h3>Authentication complete — you can close this tab.</h3></body></html>'
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
            $context.Response.OutputStream.Close()

            # Validate state
            if ($query['state'] -ne $state) {
                throw "State mismatch — possible CSRF. Aborting."
            }
            if ($query['error']) {
                throw "Authorization error: $($query['error']) — $($query['error_description'])"
            }
            $authCode = $query['code']
        }
        finally {
            $listener.Stop()
            $listener.Close()
        }

        # 5. Exchange auth code + verifier for tokens
        $tokenBody = @{
            client_id     = $ClientId
            scope         = $Scopes
            code          = $authCode
            redirect_uri  = $redirectUri
            grant_type    = 'authorization_code'
            code_verifier = $codeVerifier
        }
        $tokenResponse = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $tokenBody -ContentType 'application/x-www-form-urlencoded'

        $script:Token         = $tokenResponse.access_token
        $script:TokenExpiry   = (Get-Date).AddSeconds($tokenResponse.expires_in - 60)
        $script:RefreshToken  = $tokenResponse.refresh_token  # Store for silent refresh
        $script:TokenEndpoint = $tokenEndpoint
        $script:ClientId      = $ClientId
        $script:Context       = Get-UTCMTokenContext -Token $tokenResponse.access_token
        Write-UTCMContext 'Interactive browser'
    }
}
