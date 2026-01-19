#Requires -Version 7.0

<#
.SYNOPSIS
    Collector for ESXi storage configuration (datastores, HBAs, LUNs, paths).
#>

class StorageCollector : ESXiCollectorBase {
    StorageCollector() : base('Storage') {}

    [ESXiEntity[]] Collect([object]$vmHost) {
        $entities = [System.Collections.ArrayList]::new()
        
        # Datastores
        try {
            $datastores = Get-Datastore -VMHost $vmHost -ErrorAction SilentlyContinue
            foreach ($ds in $datastores) {
                $props = @{
                    Name = $ds.Name
                    Type = $ds.Type
                    FileSystemVersion = $ds.FileSystemVersion
                    CapacityGB = [math]::Round($ds.CapacityGB, 2)
                    FreeSpaceGB = [math]::Round($ds.FreeSpaceGB, 2)
                    PercentFree = [math]::Round(($ds.FreeSpaceGB / $ds.CapacityGB * 100), 2)
                    State = $ds.State.ToString()
                    Accessible = $ds.State -eq 'Available'
                    StorageIOControlEnabled = $this.GetProperty($ds, 'StorageIOControlEnabled', $false)
                }

                $entity = [ESXiEntity]::new('Storage', $ds.Name, "Storage/Datastore/$($ds.Name)", $props)
                $entities.Add($entity) | Out-Null
            }
        } catch {
            Write-Verbose "Failed to get datastores: $_"
        }

        # HBAs (Host Bus Adapters)
        try {
            $hbas = Get-VMHostHba -VMHost $vmHost -ErrorAction SilentlyContinue
            foreach ($hba in $hbas) {
                $props = @{
                    Device = $hba.Device
                    Type = $hba.Type
                    Model = $this.GetProperty($hba, 'Model', 'Unknown')
                    Driver = $this.GetProperty($hba, 'Driver', 'Unknown')
                    Status = $hba.Status.ToString()
                }

                # iSCSI specific properties
                if ($hba.Type -eq 'IScsi') {
                    $props['IScsiName'] = $this.GetProperty($hba, 'IScsiName', '')
                }

                # FibreChannel specific properties
                if ($hba.Type -eq 'FibreChannel') {
                    $props['NodeWorldWideName'] = $this.GetProperty($hba, 'NodeWorldWideName', '')
                    $props['PortWorldWideName'] = $this.GetProperty($hba, 'PortWorldWideName', '')
                }

                $entity = [ESXiEntity]::new('Storage', $hba.Device, "Storage/HBA/$($hba.Device)", $props)
                $entities.Add($entity) | Out-Null
            }
        } catch {
            Write-Verbose "Failed to get HBAs: $_"
        }

        # SCSI LUNs
        try {
            $luns = Get-ScsiLun -VMHost $vmHost -ErrorAction SilentlyContinue | Where-Object {$_.LunType -ne 'cdrom'}
            foreach ($lun in $luns) {
                $props = @{
                    CanonicalName = $lun.CanonicalName
                    CapacityGB = [math]::Round($lun.CapacityGB, 2)
                    MultipathPolicy = $lun.MultipathPolicy.ToString()
                    Vendor = $this.GetProperty($lun, 'Vendor', 'Unknown')
                    Model = $this.GetProperty($lun, 'Model', 'Unknown')
                    LunType = $lun.LunType
                }

                $entity = [ESXiEntity]::new('Storage', $lun.CanonicalName, "Storage/LUN/$($lun.CanonicalName)", $props)
                $entities.Add($entity) | Out-Null
            }
        } catch {
            Write-Verbose "Failed to get LUNs: $_"
        }

        # Storage Paths
        try {
            $luns = Get-ScsiLun -VMHost $vmHost -ErrorAction SilentlyContinue | Where-Object {$_.LunType -ne 'cdrom'}
            foreach ($lun in $luns) {
                try {
                    $paths = Get-ScsiLunPath -ScsiLun $lun -ErrorAction SilentlyContinue
                    if ($paths) {
                        $props = @{
                            LUN = $lun.CanonicalName
                            TotalPaths = $paths.Count
                            ActivePaths = ($paths | Where-Object {$_.State -eq 'Active'}).Count
                            DeadPaths = ($paths | Where-Object {$_.State -eq 'Dead'}).Count
                            PathStates = @($paths | ForEach-Object { "$($_.Name):$($_.State)" })
                        }

                        $entity = [ESXiEntity]::new('Storage', "Paths-$($lun.CanonicalName)", "Storage/Paths/$($lun.CanonicalName)", $props)
                        $entities.Add($entity) | Out-Null
                    }
                } catch {
                    Write-Verbose "Failed to get paths for LUN $($lun.CanonicalName): $_"
                }
            }
        } catch {
            Write-Verbose "Failed to get storage paths: $_"
        }

        return $entities.ToArray()
    }
}
