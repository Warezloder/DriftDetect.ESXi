#Requires -Version 7.0

<#
.SYNOPSIS
    Collector for ESXi firewall rules and exceptions.
#>

class FirewallCollector : ESXiCollectorBase {
    FirewallCollector() : base('Firewall') {}

    [ESXiEntity[]] Collect([object]$vmHost) {
        $entities = [System.Collections.ArrayList]::new()
        
        try {
            $exceptions = Get-VMHostFirewallException -VMHost $vmHost -ErrorAction Stop
            
            foreach ($exception in $exceptions) {
                $props = @{
                    Name = $exception.Name
                    Enabled = $exception.Enabled
                    IncomingPorts = @($exception.IncomingPorts)
                    OutgoingPorts = @($exception.OutgoingPorts)
                    Protocols = @($exception.Protocols)
                    ServiceRunning = $exception.ServiceRunning
                }

                $entity = [ESXiEntity]::new('Firewall', $exception.Name, "Firewall/$($exception.Name)", $props)
                $entities.Add($entity) | Out-Null
            }
        } catch {
            Write-Verbose "Failed to get firewall exceptions: $_"
        }

        # Default firewall policy
        try {
            $esxcli = Get-EsxCli -VMHost $vmHost -V2 -ErrorAction SilentlyContinue
            if ($esxcli) {
                $fwInfo = $esxcli.network.firewall.get.Invoke()
                if ($fwInfo) {
                    $props = @{
                        DefaultAction = $this.GetProperty($fwInfo, 'DefaultAction', 'Unknown')
                        Enabled = $this.GetProperty($fwInfo, 'Enabled', $false)
                        Loaded = $this.GetProperty($fwInfo, 'Loaded', $false)
                    }

                    $entity = [ESXiEntity]::new('Firewall', 'DefaultPolicy', "Firewall/DefaultPolicy", $props)
                    $entities.Add($entity) | Out-Null
                }
            }
        } catch {
            Write-Verbose "Failed to get firewall default policy: $_"
        }

        return $entities.ToArray()
    }
}
