#Requires -Version 7.0

<#
.SYNOPSIS
    Collector for ESXi network configuration (vSwitches, port groups, VMkernel, pNICs).
#>

class NetworkCollector : ESXiCollectorBase {
    NetworkCollector() : base('Network') {}

    [ESXiEntity[]] Collect([object]$vmHost) {
        $entities = [System.Collections.ArrayList]::new()
        
        # Virtual Switches (vSwitch)
        try {
            $vswitches = Get-VirtualSwitch -VMHost $vmHost -Standard -ErrorAction SilentlyContinue
            foreach ($vs in $vswitches) {
                $props = @{
                    Name = $vs.Name
                    Type = 'StandardSwitch'
                    NumPorts = $vs.NumPorts
                    NumPortsAvailable = $vs.NumPortsAvailable
                    Mtu = $vs.Mtu
                    Nic = @($vs.Nic)
                }

                $entity = [ESXiEntity]::new('Network', $vs.Name, "Network/$($vs.Name)", $props)
                $entities.Add($entity) | Out-Null
            }
        } catch {
            Write-Verbose "Failed to get vSwitches: $_"
        }

        # Port Groups
        try {
            $portGroups = Get-VirtualPortGroup -VMHost $vmHost -Standard -ErrorAction SilentlyContinue
            foreach ($pg in $portGroups) {
                $props = @{
                    Name = $pg.Name
                    Type = 'PortGroup'
                    VirtualSwitch = $pg.VirtualSwitch.Name
                    VLanId = $pg.VLanId
                }

                $entity = [ESXiEntity]::new('Network', $pg.Name, "Network/PortGroup/$($pg.Name)", $props)
                $entities.Add($entity) | Out-Null
            }
        } catch {
            Write-Verbose "Failed to get port groups: $_"
        }

        # VMkernel Adapters
        try {
            $vmks = Get-VMHostNetworkAdapter -VMHost $vmHost -VMKernel -ErrorAction SilentlyContinue
            foreach ($vmk in $vmks) {
                $props = @{
                    Name = $vmk.Name
                    Type = 'VMkernel'
                    IP = $vmk.IP
                    SubnetMask = $vmk.SubnetMask
                    Mac = $vmk.Mac
                    Mtu = $vmk.Mtu
                    PortGroup = $this.GetProperty($vmk, 'PortGroupName', 'Unknown')
                    VMotionEnabled = $vmk.VMotionEnabled
                    FaultToleranceLoggingEnabled = $vmk.FaultToleranceLoggingEnabled
                    ManagementTrafficEnabled = $vmk.ManagementTrafficEnabled
                    VsanTrafficEnabled = $this.GetProperty($vmk, 'VsanTrafficEnabled', $false)
                }

                $entity = [ESXiEntity]::new('Network', $vmk.Name, "Network/VMkernel/$($vmk.Name)", $props)
                $entities.Add($entity) | Out-Null
            }
        } catch {
            Write-Verbose "Failed to get VMkernel adapters: $_"
        }

        # Physical NICs
        try {
            $pnics = Get-VMHostNetworkAdapter -VMHost $vmHost -Physical -ErrorAction SilentlyContinue
            foreach ($pnic in $pnics) {
                $props = @{
                    Name = $pnic.Name
                    Type = 'PhysicalNIC'
                    Mac = $pnic.Mac
                    Driver = $this.GetProperty($pnic, 'Driver', 'Unknown')
                    LinkSpeed = $this.GetProperty($pnic, 'BitRatePerSec', 0)
                    FullDuplex = $this.GetProperty($pnic, 'FullDuplex', $false)
                }

                $entity = [ESXiEntity]::new('Network', $pnic.Name, "Network/pNIC/$($pnic.Name)", $props)
                $entities.Add($entity) | Out-Null
            }
        } catch {
            Write-Verbose "Failed to get physical NICs: $_"
        }

        return $entities.ToArray()
    }
}
