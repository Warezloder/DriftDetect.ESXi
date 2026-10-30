# Each branch emits only common entities. Invoke-DDCollector owns failure isolation.
function Invoke-ESXiUnit {
    param([string]$Unit,[object]$VMHost,[object]$Server,[string[]]$Patterns)
    switch ($Unit) {
        'System.Host' {
            $props = Get-ESXiProjection $VMHost @('Name','Version','Build','Model','Manufacturer','ProcessorType','NumCpu','CpuTotalMhz','MemoryTotalGB','HyperthreadingActive')
            $observations = Get-ESXiProjection $VMHost @('PowerState','ConnectionState') @('PowerState','ConnectionState')
            # License keys are deliberately excluded from persisted configuration.
            New-ESXiEntity $Unit System Host $VMHost.Name $props $observations
        }
        'System.Network' {
            $net = Get-VMHostNetwork -VMHost $VMHost -Server $Server -ErrorAction Stop
            if ($null -eq $net) { throw 'Host network configuration unavailable.' }
            New-ESXiEntity $Unit System Network 'Host network' @{
                HostName=[string]$net.HostName;DomainName=[string]$net.DomainName
                DnsServers=@($net.DnsAddress | ForEach-Object { ConvertTo-ESXiAddress $_ })
                SearchDomains=@($net.SearchDomain | ForEach-Object { [string]$_ })
                DefaultGateway=(ConvertTo-ESXiAddress (Get-ESXiField $net VMKernelGateway))
                IPv6DefaultGateway=(ConvertTo-ESXiAddress (Get-ESXiField $net VMKernelV6Gateway))
            }
        }
        'System.Ntp' {
            $servers = @(Get-VMHostNtpServer -VMHost $VMHost -Server $Server -ErrorAction Stop | ForEach-Object { [string]$_ })
            New-ESXiEntity $Unit System Ntp 'NTP' @{NtpServers=$servers}
        }
        'System.Syslog' {
            $servers = @(Get-VMHostSysLogServer -VMHost $VMHost -Server $Server -ErrorAction Stop | ForEach-Object {
                Get-ESXiProjection $_ @('Host','Port','Protocol') @('Protocol')
            })
            New-ESXiEntity $Unit System Syslog 'Syslog' @{SyslogServers=$servers}
        }
        'System.TimeZone' {
            $reference = Get-ESXiField (Get-ESXiField $VMHost.ExtensionData ConfigManager) DateTimeSystem
            if ($null -eq $reference) { throw 'DateTimeSystem reference unavailable.' }
            $view = Get-View -Id $reference -Server $Server -Property DateTimeInfo -ErrorAction Stop
            $zone = Get-ESXiField (Get-ESXiField $view DateTimeInfo) TimeZone
            $key = [string](Get-ESXiField $zone Key)
            if ([string]::IsNullOrWhiteSpace($key)) { throw 'Host timezone unavailable.' }
            New-ESXiEntity $Unit System TimeZone 'Time zone' @{TimeZone=$key;Name=(Get-ESXiField $zone Name)}
        }
        'Network.Switches' {
            foreach ($item in @(Get-VirtualSwitch -VMHost $VMHost -Server $Server -Standard -ErrorAction Stop)) {
                $id = Get-ESXiStableId $item @('Key','Id','Name')
                $props = Get-ESXiProjection $item @('Name','NumPorts','Mtu')
                $props.Type = 'StandardSwitch'
                $props.Nic = @($item.Nic | ForEach-Object { [string]$_ })
                New-ESXiEntity $Unit Network "Switch/$id" $item.Name $props (Get-ESXiProjection $item @('NumPortsAvailable'))
            }
        }
        'Network.PortGroups' {
            foreach ($item in @(Get-VirtualPortGroup -VMHost $VMHost -Server $Server -Standard -ErrorAction Stop)) {
                $switch = [string](Get-ESXiField (Get-ESXiField $item VirtualSwitch) Name)
                if ([string]::IsNullOrWhiteSpace($switch) -or [string]::IsNullOrWhiteSpace($item.Name)) { throw 'Port group switch identity unavailable.' }
                $id = 'PortGroup/{0}/{1}' -f [uri]::EscapeDataString($switch),[uri]::EscapeDataString($item.Name)
                New-ESXiEntity $Unit Network $id $item.Name @{Name=[string]$item.Name;Type='PortGroup';VirtualSwitch=$switch;VLanId=$item.VLanId}
            }
        }
        'Network.VMkernel' {
            foreach ($item in @(Get-VMHostNetworkAdapter -VMHost $VMHost -Server $Server -VMKernel -ErrorAction Stop)) {
                $id = Get-ESXiStableId $item @('DeviceName','Name','Id')
                $props = Get-ESXiProjection $item @('Name','IP','SubnetMask','Mac','Mtu','PortGroupName','VMotionEnabled','FaultToleranceLoggingEnabled','ManagementTrafficEnabled','VsanTrafficEnabled','DhcpEnabled','IPv6Enabled')
                $props.Type = 'VMkernel'
                New-ESXiEntity $Unit Network "VMkernel/$id" $item.Name $props
            }
        }
        'Network.PhysicalNics' {
            foreach ($item in @(Get-VMHostNetworkAdapter -VMHost $VMHost -Server $Server -Physical -ErrorAction Stop)) {
                $id = (Get-ESXiStableId $item @('Mac','Id','Name')).ToLowerInvariant().Replace('-',':')
                $props = Get-ESXiProjection $item @('Name','Mac','Driver','AutoNegotiateSupported')
                $props.Type = 'PhysicalNIC'
                New-ESXiEntity $Unit Network "PhysicalNIC/$id" $item.Name $props (Get-ESXiProjection $item @('BitRatePerSec','FullDuplex'))
            }
        }
        'Storage.Datastores' {
            foreach ($item in @(Get-Datastore -VMHost $VMHost -Server $Server -ErrorAction Stop)) {
                $info = Get-ESXiField (Get-ESXiField $item ExtensionData) Info
                $id = [string](Get-ESXiField $info Url)
                if ([string]::IsNullOrWhiteSpace($id)) { $id = Get-ESXiStableId $item @('Id','Uid') }
                $props = Get-ESXiProjection $item @('Name','Type','FileSystemVersion','CapacityGB','StorageIOControlEnabled') @('Type')
                $obs = Get-ESXiProjection $item @('FreeSpaceGB','State') @('State')
                New-ESXiEntity $Unit Storage "Datastore/$id" $item.Name $props $obs
            }
        }
        'Storage.Hbas' {
            foreach ($item in @(Get-VMHostHba -VMHost $VMHost -Server $Server -ErrorAction Stop)) {
                $id = Get-ESXiStableId $item @('Pci','Uid','Device')
                $props = Get-ESXiProjection $item @('Device','Type','Model','Driver','IScsiName','NodeWorldWideName','PortWorldWideName') @('Type','NodeWorldWideName','PortWorldWideName')
                New-ESXiEntity $Unit Storage "HBA/$id" $item.Device $props (Get-ESXiProjection $item @('Status') @('Status'))
            }
        }
        'Storage.Luns' {
            foreach ($item in @(Get-ScsiLun -VMHost $VMHost -Server $Server -ErrorAction Stop | Where-Object { [string]$_.LunType -ine 'cdrom' })) {
                $id = Get-ESXiStableId $item @('CanonicalName')
                $props = Get-ESXiProjection $item @('CanonicalName','CapacityGB','MultipathPolicy','Vendor','Model','LunType') @('MultipathPolicy','LunType')
                New-ESXiEntity $Unit Storage "LUN/$id" $id $props
            }
        }
        'Storage.Paths' {
            foreach ($lun in @(Get-ScsiLun -VMHost $VMHost -Server $Server -ErrorAction Stop | Where-Object { [string]$_.LunType -ine 'cdrom' })) {
                $lunId = Get-ESXiStableId $lun @('CanonicalName')
                foreach ($item in @(Get-ScsiLunPath -ScsiLun $lun -ErrorAction Stop)) {
                    $id = Get-ESXiStableId $item @('Name','Id')
                    $props = Get-ESXiProjection $item @('Name','Preferred','SanId') @('SanId')
                    $props.LUN = $lunId
                    New-ESXiEntity $Unit Storage "Path/$lunId/$id" $id $props (Get-ESXiProjection $item @('State') @('State'))
                }
            }
        }
        'Services' {
            foreach ($item in @(Get-VMHostService -VMHost $VMHost -Server $Server -ErrorAction Stop)) {
                $id = Get-ESXiStableId $item @('Key')
                New-ESXiEntity $Unit Service $id $item.Label (Get-ESXiProjection $item @('Key','Label','Policy','Required') @('Policy')) (Get-ESXiProjection $item @('Running'))
            }
        }
        'AdvancedSettings' {
            foreach ($item in @(Get-AdvancedSetting -Entity $VMHost -Server $Server -ErrorAction Stop)) {
                $selected = $false
                foreach ($pattern in $Patterns) { if ($item.Name -like $pattern) { $selected = $true; break } }
                if ($selected) {
                    $id = Get-ESXiStableId $item @('Name')
                    New-ESXiEntity $Unit AdvancedSetting $id $id (Get-ESXiProjection $item @('Name','Value','Type','Description') @('Type'))
                }
            }
        }
        'Firewall.Exceptions' {
            $reference = Get-ESXiField (Get-ESXiField $VMHost.ExtensionData ConfigManager) FirewallSystem
            if ($null -eq $reference) { throw 'FirewallSystem reference unavailable.' }
            $view = Get-View -Id $reference -Server $Server -Property FirewallInfo -ErrorAction Stop
            $info = Get-ESXiField $view FirewallInfo
            if ($null -eq $info) { throw 'Host firewall configuration unavailable.' }
            foreach ($item in @($info.Ruleset)) {
                $id = Get-ESXiStableId $item @('Key')
                $allowed = Get-ESXiField $item AllowedHosts
                if ($null -eq $allowed) { throw 'Allowed host restrictions unavailable.' }
                $rules = @($item.Rule | ForEach-Object { Get-ESXiProjection $_ @('Port','EndPort','Direction','PortType','Protocol') @('Direction','PortType','Protocol') })
                $networks = @(Get-ESXiField $allowed IpNetwork | ForEach-Object { Get-ESXiProjection $_ @('Network','PrefixLength') })
                $hosts = @{AllIp=(Get-ESXiField $allowed AllIp);IpAddress=@(Get-ESXiField $allowed IpAddress | ForEach-Object { ConvertTo-ESXiAddress $_ });IpNetwork=$networks}
                New-ESXiEntity $Unit Firewall "Ruleset/$id" $item.Label @{Key=$id;Enabled=$item.Enabled;Required=(Get-ESXiField $item Required);Service=(Get-ESXiField $item Service);Rules=$rules;AllowedHosts=$hosts}
            }
        }
        'Firewall.Policy' {
            $reference = Get-ESXiField (Get-ESXiField $VMHost.ExtensionData ConfigManager) FirewallSystem
            if ($null -eq $reference) { throw 'FirewallSystem reference unavailable.' }
            $view = Get-View -Id $reference -Server $Server -Property FirewallInfo -ErrorAction Stop
            $policy = Get-ESXiField (Get-ESXiField $view FirewallInfo) DefaultPolicy
            if ($null -eq $policy) { throw 'Host firewall default policy unavailable.' }
            New-ESXiEntity $Unit Firewall DefaultPolicy 'Default policy' (Get-ESXiProjection $policy @('IncomingBlocked','OutgoingBlocked'))
        }
        'Accounts.Users' {
            foreach ($item in @(Get-VMHostAccount -Server $Server -User -ErrorAction Stop)) {
                $id = Get-ESXiStableId $item @('Id')
                New-ESXiEntity $Unit Account "User/$id" $item.Name (Get-ESXiProjection $item @('Id','Name','Description'))
            }
        }
        'Accounts.Permissions' {
            foreach ($item in @(Get-VIPermission -Entity $VMHost -Server $Server -ErrorAction Stop)) {
                $principal = Get-ESXiStableId $item @('Principal')
                $isGroup = [bool]$item.IsGroup
                $id = 'Permission/{0}/{1}' -f $isGroup,[uri]::EscapeDataString($principal)
                New-ESXiEntity $Unit Account $id $principal (Get-ESXiProjection $item @('Principal','Role','IsGroup','Propagate') @('Role'))
            }
        }
        default { throw 'Unregistered ESXi collection unit.' }
    }
}
