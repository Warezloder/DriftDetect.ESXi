@{
    # Module manifest for DriftDetect.ESXi
    
    RootModule        = 'DriftDetect.ESXi.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b2f8e3d1-9a5c-4f2e-8d7b-3e9a1c6f4d8e'
    Author            = 'Warezloder'
    CompanyName       = 'Community'
    Copyright         = '(c) 2025 Warezloder. All rights reserved.'
    
    Description       = @'
DriftDetect.ESXi - Configuration drift detection for standalone ESXi 8.0+ hosts.

Features:
- Class-based collectors for System, Network, Storage, Services, Advanced Settings, Firewall, and Accounts
- Hash-based change detection for efficient comparison
- Configurable severity scoring (Critical, High, Medium, Low)
- Rich HTML reporting with PSWriteHTML
- PowerShell 7+ optimized
- Tracks new, modified, and deleted configuration entities
- Baseline + delta comparison model
- Supports both VMware.PowerCLI and VCF.PowerCLI

Perfect for standalone ESXi hosts not managed by vCenter. For vCenter environments, use DriftDetect.VMware instead.
'@

    PowerShellVersion = '7.0'
    
    # Required modules
    # Note: VMware.PowerCLI or VCF.PowerCLI is required (checked at runtime)
    RequiredModules   = @(
        @{ModuleName = 'PSWriteHTML'; ModuleVersion = '0.0.170'}
    )

    # Functions to export
    FunctionsToExport = @(
        'New-ESXiSnapshot'
        'Compare-ESXiSnapshot'
        'Export-ESXiDriftReport'
        'Get-ESXiSnapshot'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Private data
    PrivateData       = @{
        PSData = @{
            Tags         = @(
                'VMware'
                'ESXi'
                'Configuration'
                'Drift'
                'Detection'
                'Compliance'
                'PowerCLI'
                'VCF'
                'Infrastructure'
                'Automation'
                'Standalone'
            )
            
            LicenseUri   = 'https://github.com/Warezloder/DriftDetect.ESXi/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/Warezloder/DriftDetect.ESXi'
            
            ReleaseNotes = @'
## Version 1.0.0 - Initial Release

### Features
- Complete configuration drift detection for standalone ESXi 8.0+ hosts
- Class-based architecture with PowerShell 7 classes
- Hash-based change detection for fast comparison
- Comprehensive entity coverage:
  * System (hostname, DNS, NTP, syslog, timezone)
  * Network (vSwitches, port groups, VMkernel, physical NICs)
  * Storage (datastores, HBAs, LUNs, multipathing)
  * Services (SSH, NTP, TSM, etc.)
  * Advanced Settings (security, performance, VSAN)
  * Firewall (rules and exceptions)
  * Accounts (local users and permissions)
- Configurable severity rules via JSON
- Rich HTML reports with interactive tables and charts
- Pipeline support for all cmdlets
- Supports both VMware.PowerCLI and VCF.PowerCLI

### Requirements
- PowerShell 7.0+
- VMware PowerCLI 12.0+ or VCF.PowerCLI
- PSWriteHTML 0.0.170+
- ESXi 8.0+ (may work with 7.0+ but not tested)

### Usage
Connect directly to ESXi host (not vCenter):
```powershell
Connect-VIServer -Server esxi-01.domain.local
$vmhost = Get-VMHost
New-ESXiSnapshot -VMHost $vmhost -OutputPath baseline.json -IncludeAdvancedSettings
```
'@
        }
    }

    HelpInfoURI       = 'https://github.com/Warezloder/DriftDetect.ESXi/wiki'
}
