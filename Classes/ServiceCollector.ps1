#Requires -Version 7.0

<#
.SYNOPSIS
    Collector for ESXi services (SSH, NTP, syslog, etc.).
#>

class ServiceCollector : ESXiCollectorBase {
    ServiceCollector() : base('Service') {}

    [ESXiEntity[]] Collect([object]$vmHost) {
        $entities = [System.Collections.ArrayList]::new()
        
        try {
            $services = Get-VMHostService -VMHost $vmHost -ErrorAction Stop
            
            foreach ($svc in $services) {
                $props = @{
                    Key = $svc.Key
                    Label = $svc.Label
                    Running = $svc.Running
                    Policy = $svc.Policy
                    Required = $svc.Required
                }

                $entity = [ESXiEntity]::new('Service', $svc.Key, "Service/$($svc.Key)", $props)
                $entities.Add($entity) | Out-Null
            }
        } catch {
            Write-Verbose "Failed to get services: $_"
        }

        return $entities.ToArray()
    }
}
