#Requires -Version 7.0
<#
.SYNOPSIS
    UTCM MVP Module - Unified Tenant Configuration Management via Microsoft Graph Beta REST API.

.DESCRIPTION
    A lightweight PowerShell module that wraps the Microsoft Graph Beta UTCM APIs
    using native Invoke-RestMethod (no SDK dependency). Covers:
      - Authentication (interactive delegated + client-credentials)
      - Configuration Monitors (CRUD)
      - Configuration Baselines (get, snapshot)
      - Configuration Drifts (list, get)
      - Monitoring Results (list, get)
      - Snapshot Jobs (list, get, delete, download)
#>

# ---------------------------------------------------------------------------
# Module-scoped state
# ---------------------------------------------------------------------------
$script:GraphBaseUrl   = "https://graph.microsoft.com/beta"
$script:GraphV1Url     = "https://graph.microsoft.com/v1.0"
$script:GraphPSAppId   = '14d82eec-204b-4c2f-b7e8-296a70dab67e'   # Well-known Microsoft Graph PowerShell app
$script:Token          = $null
$script:TokenExpiry    = [datetime]::MinValue
$script:RefreshToken   = $null
$script:TokenEndpoint  = $null
$script:ClientId       = $null
$script:Context        = $null

# Default delegated scopes needed for UTCM operations + openid for identity claims
$script:DefaultScopes  = 'openid profile offline_access https://graph.microsoft.com/ConfigurationMonitoring.ReadWrite.All'

# ---------------------------------------------------------------------------
# Dot-source Private (internal) functions, then Public (exported) functions
# ---------------------------------------------------------------------------
$privatePath = Join-Path $PSScriptRoot 'Private'
$publicPath  = Join-Path $PSScriptRoot 'Public'

if (Test-Path $privatePath) {
    Get-ChildItem -Path $privatePath -Filter '*.ps1' -Recurse | ForEach-Object {
        . $_.FullName
    }
}

if (Test-Path $publicPath) {
    Get-ChildItem -Path $publicPath -Filter '*.ps1' -Recurse | ForEach-Object {
        . $_.FullName
    }
}
