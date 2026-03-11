# UTCM PowerShell Module

[![PowerShell Version](https://img.shields.io/badge/PowerShell-7.0%2B-blue)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

A lightweight PowerShell module for working with **Microsoft Graph Unified Tenant Configuration Management (UTCM)** Beta APIs. Built with native `Invoke-RestMethod` — no SDK dependencies required.

## � Requirements

- **PowerShell 7.0+** (cross-platform support)
- **UTCM Service Principal** — The UTCM first-party service principal must be installed in your tenant before use.  
  Use the built-in helper: `Install-UTCMServicePrincipal -TenantId "yourtenant.onmicrosoft.com"`  
  Or follow the manual steps in the [Microsoft Learn setup guide](https://learn.microsoft.com/en-us/graph/utcm-authentication-setup#set-up-the-utcm-service-principal).
- **Microsoft Graph Permissions**:
  - `TenantConfiguration.Read.All` — minimum for read operations
  - `TenantConfiguration.ReadWrite.All` — for monitor creation and management

## �🚀 Quick Start

### Installation

```powershell
# Install from PowerShell Gallery
Install-Module -Name UTCM -Scope CurrentUser

# Or clone and import manually
git clone https://github.com/JankeSkanke/UTCM.git
Import-Module .\UTCM\UTCM.psd1
```

### Basic Usage

```powershell
# Connect to your tenant
Connect-UTCM -TenantId "yourtenant.onmicrosoft.com"

# Create a configuration snapshot
$snapshot = New-UTCMSnapshot -DisplayName "Baseline 2026" -Resources @(
    "microsoft.entra.application",
    "microsoft.entra.conditionalAccessPolicy"
)

# Wait for snapshot to complete
Wait-UTCMSnapshot -SnapshotId $snapshot.id

# Save snapshot locally
Save-UTCMSnapshot -SnapshotId $snapshot.id -OutputPath ".\baseline"

# Create a monitor to track configuration drift
$baseline = @{
    displayName = "Production Baseline"
    resources   = @(
        @{
            displayName  = "CA Policy - Require MFA"
            resourceType = "microsoft.entra.conditionalAccessPolicy"
            properties   = @{ displayName = "Require MFA for all users" }
        }
    )
}
$monitor = New-UTCMMonitor -DisplayName "Production Monitor" -Baseline $baseline

# Check for configuration drift
Get-UTCMDrift -MonitorId $monitor.id
```

## ✨ Features

### Core Capabilities

- 🔐 **Flexible Authentication** - Delegated (interactive), Client Credentials, or Bring-Your-Own-Token
- 👁️ **Configuration Monitoring** - Track changes across Microsoft 365 tenant configurations
- 📸 **Snapshot Management** - Capture point-in-time configuration states with 270 resource types
- 🔍 **Drift Detection** - Identify configuration changes against established baselines
- 📊 **Comparison Engine** - Deep diff between snapshots with JSON normalization
- 📈 **Monitoring Results** - Historical tracking of configuration changes over time

### Supported Workloads (270 resource types)

- **Microsoft Entra** (40 resource types) — Applications, Conditional Access, Authentication Methods, Cross-Tenant Access, Entitlement Management, Groups, Roles, etc.
- **Microsoft Exchange Online** (73 resource types) — Transport Rules, Anti-Phish/Malware Policies, Connectors, DKIM, Mailbox Settings, OWA Policies, Safe Links/Attachments, etc.
- **Microsoft Teams** (60 resource types) — Meeting/Messaging/Calling Policies, Federation, App Policies, Dial Plans, Emergency Calling, Voice Routing, etc.
- **Microsoft Intune** (68 resource types) — Device Compliance, Device Configuration, App Protection, Autopilot, Windows Update, Endpoint Detection & Response, etc.
- **Microsoft Security & Compliance** (29 resource types) — DLP Policies, Sensitivity Labels, Retention Policies, Audit Configuration, Compliance Cases, etc.

See [Monitor Schema Reference](docs/UTCM-Monitor-Schema-Reference.md) for the full list of resource types per workload.

## 📚 Available Commands

### Authentication
- `Connect-UTCM` - Authenticate to Microsoft Graph
- `Disconnect-UTCM` - Clear authentication token and session
- `Get-UTCMContext` - Display current connection information

### Configuration Monitors
- `Get-UTCMMonitor` - List or get specific monitor(s)
- `New-UTCMMonitor` - Create a new configuration monitor
- `Set-UTCMMonitor` - Update an existing monitor
- `Remove-UTCMMonitor` - Delete a monitor

### Snapshots
- `New-UTCMSnapshot` - Create a new configuration snapshot
- `Get-UTCMSnapshot` - List or get specific snapshot(s)
- `Save-UTCMSnapshot` - Download snapshot to local filesystem
- `Wait-UTCMSnapshot` - Poll until snapshot completes
- `Remove-UTCMSnapshot` - Delete a snapshot
- `Compare-UTCMSnapshot` - Compare two snapshots and generate diff report

### Drift & Results
- `Get-UTCMDrift` - Get configuration drift items
- `Get-UTCMMonitoringResult` - Get historical monitoring results
- `Get-UTCMBaseline` - Get baseline configuration for a monitor

### Tenant Setup
- `Install-UTCMServicePrincipal` - Create UTCM service principal in tenant
- `Grant-UTCMPermission` - Grant required Graph API permissions
- `Grant-UTCMDirectoryRole` - Assign directory roles for UTCM operations

## 📖 Documentation

- **[API Reference](docs/UTCM-API-Reference.md)** - Detailed function documentation and examples
- **[Monitor Schema Reference](docs/UTCM-Monitor-Schema-Reference.md)** - Monitor configuration schema
- **[Example Scripts](examples/)** - End-to-end usage scenarios
- **[Testing Guide](Tests/README.md)** - Pester test suite documentation

## 📝 Examples

### Create and Compare Snapshots

```powershell
# Take baseline snapshot and save locally
$baseline = New-UTCMSnapshot -DisplayName "Baseline" -Resources @(
    "microsoft.entra.conditionalAccessPolicy"
)
Wait-UTCMSnapshot -SnapshotId $baseline.id
Save-UTCMSnapshot -SnapshotId $baseline.id -OutputPath ".\snapshots\baseline"

# Make some changes in your tenant...

# Take comparison snapshot and save locally
$current = New-UTCMSnapshot -DisplayName "Current State" -Resources @(
    "microsoft.entra.conditionalAccessPolicy"
)
Wait-UTCMSnapshot -SnapshotId $current.id
Save-UTCMSnapshot -SnapshotId $current.id -OutputPath ".\snapshots\current"

# Compare saved snapshots and export results
Compare-UTCMSnapshot -ReferencePath ".\snapshots\baseline" `
    -DifferencePath ".\snapshots\current" `
    -OutputFormat HTML `
    -OutputPath ".\comparison.html" `
    -NormalizeJson
```

### Monitor Configuration Drift

```powershell
# Create monitor with a baseline definition
$baselineDef = @{
    displayName = "Production Config Baseline"
    resources   = @(
        @{
            displayName  = "CA Policy - Require MFA"
            resourceType = "microsoft.entra.conditionalAccessPolicy"
            properties   = @{ displayName = "Require MFA for all users" }
        }
    )
}
$monitor = New-UTCMMonitor -DisplayName "Production Config Monitor" -Baseline $baselineDef

# Check drift after monitor runs
$drifts = Get-UTCMDrift -MonitorId $monitor.id -Status drifted

# Review drift details
$drifts | Format-Table DisplayName, ResourceType, Status, LastModifiedDateTime
```

### Automated Compliance Checking

```powershell
# Create snapshot of security policies
$snapshot = New-UTCMSnapshot -DisplayName "Security Baseline" -Resources @(
    "microsoft.entra.conditionalAccessPolicy",
    "microsoft.entra.authenticationMethodPolicy",
    "microsoft.entra.authenticationStrengthPolicy"
)

# Save as compliance baseline
Save-UTCMSnapshot -SnapshotId $snapshot.id -OutputPath ".\compliance\baseline"

# Create a compliance monitor with baseline
$securityBaseline = @{
    displayName = "Security Compliance Baseline"
    resources   = @(
        @{
            displayName  = "MFA Policy"
            resourceType = "microsoft.entra.authenticationMethodPolicy"
            properties   = @{ state = "enabled" }
        }
    )
}
$monitor = New-UTCMMonitor -DisplayName "Security Compliance Monitor" -Baseline $securityBaseline
```

## 🧪 Testing

The module includes a comprehensive Pester test suite:

```powershell
# Run all tests
Invoke-Pester -Path .\Tests -Output Detailed

# Current status: 111/111 tests passing
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/JankeSkanke/UTCM/issues)
- **Discussions**: [GitHub Discussions](https://github.com/JankeSkanke/UTCM/discussions)
- **Documentation**: See `docs/` folder for detailed API references

## ⚠️ Important Notes

- This module works with **Beta APIs** that may change
- Always test in a non-production environment first
- Snapshots and monitors are stored in the tenant (not locally by default)
- Use `Save-UTCMSnapshot` to download snapshot data for offline comparison
- Review required permissions before granting to service principals

---
