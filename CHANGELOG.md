# Changelog

All notable changes to the UTCM module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-02-18

### Fixed
- **README**: Corrected all code samples to use actual parameter names (`-Resources` instead of `-ResourceTypes`, `-Baseline` hashtable instead of `-SnapshotId`, `-ReferencePath`/`-DifferencePath` instead of `-ReferenceSnapshotId`/`-DifferenceSnapshotId`, correct `Compare-UTCMSnapshot` export parameters)
- **README**: Removed non-existent `-Mode` parameter from `Connect-UTCM` examples
- **README**: Updated resource type count from 181 to 270
- **New-UTCMSnapshot**: Removed client-side `ValidateLength`/`ValidatePattern` constraints on `-DisplayName` — let the API enforce its own rules
- **Enhanced-Features-Demo**: Fixed `OutNull` typo → `Out-Null`
- **Tests/README**: Removed stale reference to moved `TESTING-STATUS.md`

## [0.1.0] - 2026-02-18

### Added
- **Authentication**: `Connect-UTCM` with Auth Code + PKCE (delegated), Client Credentials, and Bring-Your-Own-Token flows
- **Authentication**: `Disconnect-UTCM` to clear session state
- **Authentication**: `Get-UTCMContext` to display current connection info
- **Monitors**: Full CRUD — `New-UTCMMonitor`, `Get-UTCMMonitor`, `Set-UTCMMonitor`, `Remove-UTCMMonitor`
- **Baselines**: `Get-UTCMBaseline` to retrieve baseline configuration for a monitor
- **Drift Detection**: `Get-UTCMDrift` with `-MonitorId` and `-Status` filtering
- **Monitoring Results**: `Get-UTCMMonitoringResult` with `-MonitorId` filtering
- **Snapshots**: `New-UTCMSnapshot`, `Get-UTCMSnapshot`, `Remove-UTCMSnapshot`, `Wait-UTCMSnapshot`
- **Snapshots**: `Save-UTCMSnapshot` to download and save snapshots locally
- **Snapshots**: `Compare-UTCMSnapshot` for offline two-phase comparison with export to CSV, JSON, XML, and HTML
- **Tenant Setup**: `Install-UTCMServicePrincipal`, `Grant-UTCMPermission`, `Grant-UTCMDirectoryRole`
- **Internal**: `Invoke-UTCMGraphRequest` with automatic pagination, retry logic, and 429 throttling with exponential backoff
- **Internal**: Automatic token refresh for delegated flows via `Update-UTCMToken`
- **Formatting**: Custom `.ps1xml` formatting with color-coded table views for monitors, snapshots, drifts, and comparison results
- **Testing**: 111 Pester tests covering all 19 public functions and 5 private helpers

[0.1.1]: https://github.com/JankeSkanke/UTCM/releases/tag/v0.1.1
[0.1.0]: https://github.com/JankeSkanke/UTCM/releases/tag/v0.1.0
