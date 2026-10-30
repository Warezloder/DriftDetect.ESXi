<img width="2560" height="1280" alt="esxi-banner-01" src="https://github.com/user-attachments/assets/3f3e3243-9b10-4042-8218-bd615a3c4729" />

# DriftDetect.ESXi v1.0

**Configuration drift detection for standalone ESXi 8.0+ hosts**

## Overview

DriftDetect.ESXi provides comprehensive drift detection for standalone ESXi hosts not managed by vCenter. Built with PowerShell 7 classes and hash-based change tracking, it quickly identifies configuration changes across system, network, storage, services, and security settings.

**Note:** For vCenter-managed environments, use `DriftDetect.VMware` instead.

## Key Features

- **Hash-Based Change Detection** - Fast comparison using SHA256 hashing
- **Comprehensive Coverage** - System, Network, Storage, Services, Advanced Settings, Firewall, Accounts
- **Entity Lifecycle Tracking** - Detects new, modified, and deleted components
- **Configurable Severity Scoring** - Critical, High, Medium, Low classifications
- **Rich HTML Reports** - Interactive tables with filtering and severity highlighting
- **PowerShell 7 Optimized** - Modern syntax, classes, and performance

## Entity Types Collected

| Category | Entities | Details |
|----------|----------|---------|
| **System** | Host Configuration | Hostname, DNS, NTP, Syslog, Timezone, Version, Build |
| **Network** | vSwitches, Port Groups, VMkernel, pNICs | VLANs, MTU, IP addresses, teaming |
| **Storage** | Datastores, HBAs, LUNs, Paths | Multipathing, capacity, accessibility |
| **Services** | SSH, NTP, TSM, DCUI, etc. | Running state, startup policy |
| **Advanced Settings** | Security, Performance, VSAN | Filtered important settings |
| **Firewall** | Rules and Exceptions | Enabled services, ports, protocols |
| **Accounts** | Local Users, Permissions | User accounts and roles |

## Installation

```powershell
# Prerequisites
Install-Module VMware.PowerCLI -MinimumVersion 12.0.0
Install-Module PSWriteHTML -MinimumVersion 0.0.170

# Import module
Import-Module .\DriftDetect.ESXi.psd1
```

## Quick Start

```powershell
# 1. Connect directly to ESXi host (NOT vCenter)
Connect-VIServer -Server esxi-01.domain.local

# 2. Get the host object
$vmhost = Get-VMHost

# 3. Capture baseline snapshot
New-ESXiSnapshot -VMHost $vmhost -OutputPath "baseline.json" `
    -IncludeAdvancedSettings -IncludeFirewall -IncludeAccounts

# 4. Make some changes to the host...
# (Configure DNS, change NTP, modify firewall, etc.)

# 5. Capture current state
$current = New-ESXiSnapshot -VMHost $vmhost `
    -IncludeAdvancedSettings -IncludeFirewall -IncludeAccounts

# 6. Compare and detect drift
$drift = Compare-ESXiSnapshot -BaselinePath baseline.json -CurrentSnapshot $current

# 7. Generate HTML report
Export-ESXiDriftReport -DriftResult $drift -OutputPath "drift-report.html"

# 8. Review results
Start-Process "drift-report.html"
```

## Usage Examples

### Minimal Snapshot (Fast)
```powershell
# System, Network, Storage, Services only
$snapshot = New-ESXiSnapshot -VMHost $vmhost -OutputPath "quick-snapshot.json"
```

### Comprehensive Snapshot
```powershell
# Everything including advanced settings, firewall, and accounts
New-ESXiSnapshot -VMHost $vmhost -OutputPath "full-snapshot.json" `
    -IncludeAdvancedSettings -IncludeFirewall -IncludeAccounts -Verbose
```

### Compare Snapshots
```powershell
# Using file paths
$drift = Compare-ESXiSnapshot -BaselinePath baseline.json -CurrentPath current.json

# Using objects
$baseline = Get-ESXiSnapshot -Path baseline.json
$current = New-ESXiSnapshot -VMHost $vmhost -IncludeAdvancedSettings
$drift = Compare-ESXiSnapshot -BaselineSnapshot $baseline -CurrentSnapshot $current

# Save comparison results
Compare-ESXiSnapshot -BaselinePath baseline.json -CurrentPath current.json `
    -OutputPath "drift-results.json"
```

### Generate Reports
```powershell
# Basic report
Export-ESXiDriftReport -DriftResult $drift -OutputPath "report.html"

# Custom title
Export-ESXiDriftReport -DriftResult $drift -OutputPath "report.html" `
    -Title "ESXi-01 Weekly Drift Report"

# From saved drift results
Export-ESXiDriftReport -DriftResultPath "drift-results.json" `
    -OutputPath "report.html"
```

### Inspect Snapshots
```powershell
# Load and inspect
$snapshot = Get-ESXiSnapshot -Path "snapshot.json"

# View metadata
$snapshot.HostName
$snapshot.HostVersion
$snapshot.CapturedAt
$snapshot.Entities.Keys

# Count entities by type
$snapshot.Entities.System.Count
$snapshot.Entities.Network.Count
$snapshot.Entities.Storage.Count

# Find specific entity
$mgmt = $snapshot.GetEntity('Network', 'Network/VMkernel/vmk0')
$mgmt.Properties
```

## Scheduled Monitoring

```powershell
# Save as C:\Scripts\ESXi-DriftMonitor.ps1
param(
    [Parameter(Mandatory)]
    [string]$ESXiHost,
    
    [Parameter(Mandatory)]
    [PSCredential]$Credential
)

Import-Module DriftDetect.ESXi

try {
    # Connect to ESXi host
    Connect-VIServer -Server $ESXiHost -Credential $Credential | Out-Null
    $vmhost = Get-VMHost
    
    # Capture current snapshot
    $date = Get-Date -Format "yyyy-MM-dd_HHmm"
    $current = New-ESXiSnapshot -VMHost $vmhost `
        -OutputPath "C:\Snapshots\$date.json" `
        -IncludeAdvancedSettings -IncludeFirewall
    
    # Compare to baseline
    $baseline = Get-ESXiSnapshot -Path "C:\Snapshots\baseline.json"
    $drift = Compare-ESXiSnapshot -BaselineSnapshot $baseline -CurrentSnapshot $current
    
    # Generate report if changes detected
    if ($drift.TotalChanges -gt 0) {
        Export-ESXiDriftReport -DriftResult $drift `
            -OutputPath "C:\Reports\drift_$date.html"
        
        # Alert on critical changes
        if ($drift.SeveritySummary.Critical -gt 0) {
            Send-MailMessage -To "admin@domain.local" `
                -Subject "CRITICAL: ESXi $ESXiHost Drift Detected" `
                -Body "$($drift.SeveritySummary.Critical) critical changes detected. See attached report." `
                -Attachments "C:\Reports\drift_$date.html" `
                -SmtpServer "smtp.domain.local"
        }
    }
}
finally {
    Disconnect-VIServer -Confirm:$false
}
```

Schedule it:
```powershell
$trigger = New-ScheduledTaskTrigger -Daily -At 6am
$cred = Get-Credential -UserName "root@esxi-01.domain.local"
$action = New-ScheduledTaskAction -Execute "pwsh.exe" `
    -Argument "-File C:\Scripts\ESXi-DriftMonitor.ps1 -ESXiHost esxi-01.domain.local"

Register-ScheduledTask -TaskName "ESXi Drift Monitor" `
    -Trigger $trigger -Action $action
```

## Custom Severity Rules

Edit `Config\SeverityRules.json`:

```json
{
  "Rules": [
    { "EntityType": "System", "Property": "PowerState", "Severity": "Critical" },
    { "EntityType": "Network", "Property": "IP", "Severity": "Critical" },
    { "EntityType": "Storage", "Property": "ActivePaths", "Severity": "Critical" },
    { "EntityType": "Service", "Property": "Running", "Severity": "Medium" },
    { "EntityType": "Firewall", "Property": "Enabled", "Severity": "High" },
    { "EntityType": "*", "Property": "Version", "Severity": "High" }
  ]
}
```

## Advanced Settings Collection

By default, only important advanced settings are collected to reduce snapshot size. Customize in `AdvancedSettingsCollector`:

```powershell
# Collect ALL advanced settings (warning: large snapshots)
$collector = [AdvancedSettingsCollector]::new()
$collector.CollectAllSettings()

# Or customize the list
$collector.SetImportantSettings(@(
    'Security.*'
    'UserVars.*'
    'Net.*'
    'Mem.*'
))
```

## Performance Tips

- **Minimal snapshots** - Omit `-IncludeAdvancedSettings` for faster captures
- **Hash comparison** - Only changed entities are deeply compared
- **Direct connection** - Connect directly to ESXi, not through vCenter
- **Scheduled off-hours** - Run monitoring during low-activity periods

## Troubleshooting

### Connection Issues
```powershell
# Test connection
Connect-VIServer -Server esxi-01.domain.local -Verbose

# Check host object
$vmhost = Get-VMHost
$vmhost.ConnectionState
$vmhost.Version  # Should be 8.0 or higher
```

### Permission Issues
```powershell
# Ensure account has read access to:
# - System configuration
# - Network settings
# - Storage configuration
# - Advanced settings (if collecting)
# - Firewall rules (if collecting)
# - Local accounts (if collecting)
```

### Large Snapshots
```powershell
# Reduce snapshot size by excluding optional components
New-ESXiSnapshot -VMHost $vmhost -OutputPath "snapshot.json"
# Don't use -IncludeAdvancedSettings unless needed

# Or filter advanced settings
$collector = [AdvancedSettingsCollector]::new()
$collector.SetImportantSettings(@('Security.*', 'UserVars.*'))
```

### Validate Snapshot
```powershell
$snap = Get-ESXiSnapshot -Path snapshot.json
$snap.Entities.Keys  # Should show collected types
$snap.Entities.System[0].Properties  # Should show system details
```

## Comparison with DriftDetect.VMware

| Feature | DriftDetect.ESXi | DriftDetect.VMware |
|---------|------------------|--------------------|
| Target | Standalone ESXi hosts | vCenter-managed infrastructure |
| Connection | Direct to ESXi | vCenter Server |
| Scope | Single host | Multiple hosts, clusters, VMs |
| Entities | System, Network, Storage, Services, Advanced, Firewall, Accounts | Hosts, Clusters, VMs, Datastores, Networks |
| Use Case | Edge sites, lab environments, standalone hosts | Production datacenters with vCenter |

## Module Structure

```
DriftDetect.ESXi/
├── DriftDetect.ESXi.psd1            # Module manifest
├── DriftDetect.ESXi.psm1            # Root module
├── Classes/                         # Entity and collector classes
│   ├── EntityBase.ps1               # Base entity class
│   ├── CollectorBase.ps1            # Base collector
│   ├── SystemCollector.ps1          # System configuration
│   ├── NetworkCollector.ps1         # Network entities
│   ├── StorageCollector.ps1         # Storage entities
│   ├── ServiceCollector.ps1         # ESXi services
│   ├── AdvancedSettingsCollector.ps1 # Advanced settings
│   ├── FirewallCollector.ps1        # Firewall rules
│   ├── AccountCollector.ps1         # User accounts
│   ├── Snapshot.ps1                 # Snapshot container
│   └── DriftEngine.ps1              # Comparison engine
├── Public/                          # Exported functions
│   ├── New-ESXiSnapshot.ps1
│   ├── Compare-ESXiSnapshot.ps1
│   ├── Export-ESXiDriftReport.ps1
│   └── Get-ESXiSnapshot.ps1
└── Config/                          # Configuration
    └── SeverityRules.json           # Severity scoring rules
```

## Requirements

- **PowerShell:** 7.0 or higher
- **VMware PowerCLI:** 12.0.0 or higher
- **PSWriteHTML:** 0.0.170 or higher
- **ESXi Version:** 8.0+ (may work with 7.0+ but not tested)
- **Connection:** Direct to ESXi host (not through vCenter)
- **Permissions:** Read access to host configuration

## Use Cases

- **Edge Sites** - Monitor standalone ESXi hosts at remote locations
- **Lab Environments** - Track configuration changes in test labs
- **Compliance Auditing** - Ensure hosts maintain required configurations
- **Change Verification** - Validate updates didn't introduce drift
- **Security Hardening** - Monitor security settings and firewall rules
- **Pre/Post Change** - Capture before/after snapshots for change control

## License

MIT License - see LICENSE file

## Contributing

Issues and pull requests welcome at: https://github.com/Warezloder/DriftDetect.ESXi

## Related Projects

- **DriftDetect.VMware** - For vCenter-managed environments

## Author

**Warezloder**  
https://github.com/Warezloder
