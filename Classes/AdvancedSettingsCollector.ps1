#Requires -Version 7.0

<#
.SYNOPSIS
    Collector for ESXi advanced settings.
#>

class AdvancedSettingsCollector : ESXiCollectorBase {
    [string[]]$ImportantSettings = @(
        'Config.HostAgent.log.level'
        'Security.PasswordQualityControl'
        'Security.AccountLockFailures'
        'Security.AccountUnlockTime'
        'UserVars.ESXiShellInteractiveTimeOut'
        'UserVars.ESXiShellTimeOut'
        'UserVars.SuppressShellWarning'
        'Net.DVFilterBindIpAddress'
        'Mem.AllocGuestLargePage'
        'Mem.ShareForceSalting'
        'VSAN.*'
        'Vpx.Vpxa.*'
    )

    AdvancedSettingsCollector() : base('AdvancedSetting') {}

    [ESXiEntity[]] Collect([object]$vmHost) {
        $entities = [System.Collections.ArrayList]::new()
        
        try {
            # Get all advanced settings
            $settings = Get-AdvancedSetting -Entity $vmHost -ErrorAction Stop
            
            foreach ($setting in $settings) {
                # Skip if not in important list (unless collecting all)
                $isImportant = $false
                foreach ($pattern in $this.ImportantSettings) {
                    if ($setting.Name -like $pattern) {
                        $isImportant = $true
                        break
                    }
                }

                # Always include or filter based on importance
                if ($isImportant -or $this.ImportantSettings.Count -eq 0) {
                    $props = @{
                        Name = $setting.Name
                        Value = $setting.Value
                        Type = $setting.Type
                        Description = $this.GetProperty($setting, 'Description', '')
                    }

                    $entity = [ESXiEntity]::new('AdvancedSetting', $setting.Name, "AdvancedSetting/$($setting.Name)", $props)
                    $entities.Add($entity) | Out-Null
                }
            }
        } catch {
            Write-Verbose "Failed to get advanced settings: $_"
        }

        return $entities.ToArray()
    }

    # Method to set which settings to collect
    [void] SetImportantSettings([string[]]$settings) {
        $this.ImportantSettings = $settings
    }

    # Method to collect ALL settings (warning: lots of data)
    [void] CollectAllSettings() {
        $this.ImportantSettings = @()
    }
}
