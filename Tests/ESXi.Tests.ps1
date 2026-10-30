BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '..\DriftDetect.ESXi.psd1') -Force -ErrorAction Stop
}

Describe 'ESXi offline interface' {
    It 'persists deep entity additions without truncating comparison output' {
        $rules=New-DDRuleSet; $target=@{Id='fixture';Name='fixture'}
        $props=@{Leaf='deep-leaf'}; 1..63 | ForEach-Object {$props=@{Child=$props}}
        $entity=New-DDEntity System fixture fixture Main $props
        $a=New-DDSnapshot -Technology ESXi -Target $target -Collections @((New-DDCollection -Id Main -Status Success)) -RuleSet $rules
        $b=New-DDSnapshot -Technology ESXi -Target $target -Collections @((New-DDCollection -Id Main -Status Success -Entities @($entity))) -RuleSet $rules
        $path=Join-Path $TestDrive 'deep-result.json'
        $null=Compare-ESXiSnapshot -BaselineSnapshot $a -CurrentSnapshot $b -OutputPath $path
        $json=Get-Content -LiteralPath $path -Raw
        $json | Should -Match 'deep-leaf'; $json | Should -Not -Match 'System.Collections'
    }
    It 'loads only Core as a required dependency' {
        $manifest = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\DriftDetect.ESXi.psd1')
        $manifest.ModuleVersion | Should -Be '2.0.0'
        @($manifest.RequiredModules).Count | Should -Be 1
        $manifest.RequiredModules[0].ModuleName | Should -Be 'DriftDetect.Core'
        (Get-Command New-ESXiSnapshot).Parameters.Keys | Should -Contain 'IncludeAll'
        (Get-Command New-ESXiSnapshot).Parameters.Keys | Should -Contain 'Strict'
        (Get-Command Compare-ESXiSnapshot).Parameters.Keys | Should -Contain 'AllowPartial'
        Get-Command Export-ESXiConfigurationReport | Should -Not -BeNullOrEmpty
    }
    It 'round trips and compares plain snapshots using literal paths' {
        $rules = Import-DDRuleSet (Join-Path $PSScriptRoot '..\Config\SeverityRules.json')
        $unit = New-DDCollection -Id 'Services' -Status Success -Entities @()
        $snapshot = New-DDSnapshot -Technology ESXi -Target @{Id='uuid-test';Name='test';IdentitySource='HardwareUuid';Version='8.0';Build='1'} -Collections @($unit) -RuleSet $rules
        $path = Join-Path $TestDrive 'snapshot [test].json'
        Export-DDSnapshot $snapshot $path
        $loaded = Get-ESXiSnapshot $path
        (Compare-ESXiSnapshot -BaselineSnapshot $snapshot -CurrentSnapshot $loaded).TotalChanges | Should -Be 0
    }
    It 'imports legacy snapshots for inspection and rejects their comparison' {
        $path = Join-Path $TestDrive 'legacy.json'
        @{SchemaVersion='1.0';HostName='legacy';SnapshotId=[guid]::NewGuid().ToString();CapturedAt='2026-10-01T00:00:00Z';Entities=@{System=@(@{Name='legacy';Path='System';Properties=@{Version='8.0'}})}} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path
        $legacy = Get-ESXiSnapshot -Path $path
        $legacy.Metadata.Legacy | Should -BeTrue
        { Compare-ESXiSnapshot -BaselineSnapshot $legacy -CurrentSnapshot $legacy -AllowPartial } | Should -Throw '*Legacy*'
    }
}

Describe 'ESXi report forwarding' {
    InModuleScope DriftDetect.ESXi {
        BeforeEach {
            Mock Export-DDConfigurationReport { 'configuration.html' }
            Mock Export-DDDriftReport { 'drift.html' }
        }
        It 'forwards pipeline configuration objects and technology default title' {
            [pscustomobject]@{Technology='ESXi'} | Export-ESXiConfigurationReport -OutputPath 'configuration.html'
            Should -Invoke Export-DDConfigurationReport -Times 1 -ParameterFilter { $Snapshot.Technology -eq 'ESXi' -and $Title -eq 'ESXi Configuration Report' }
        }
        It 'forwards configuration path and custom title' {
            Export-ESXiConfigurationReport -SnapshotPath 'snapshot [literal].json' -OutputPath 'configuration.html' -Title 'Custom'
            Should -Invoke Export-DDConfigurationReport -Times 1 -ParameterFilter { $SnapshotPath -eq 'snapshot [literal].json' -and $Title -eq 'Custom' }
        }
        It 'forwards drift path and technology default title' {
            Export-ESXiDriftReport -DriftResultPath 'result [literal].json' -OutputPath 'drift.html'
            Should -Invoke Export-DDDriftReport -Times 1 -ParameterFilter { $DriftResultPath -eq 'result [literal].json' -and $Title -eq 'ESXi Configuration Drift Report' }
        }
        It 'forwards pipeline drift objects and custom title' {
            [pscustomobject]@{Technology='ESXi'} | Export-ESXiDriftReport -OutputPath 'drift.html' -Title Custom
            Should -Invoke Export-DDDriftReport -Times 1 -ParameterFilter { $DriftResult.Technology -eq 'ESXi' -and $Title -eq 'Custom' }
        }
    }
}

Describe 'ESXi scoped collection' {
    InModuleScope DriftDetect.ESXi {
        BeforeAll {
            # Stubs avoid loading PowerCLI or performing any live infrastructure queries.
            function Get-VMHostNetwork { [CmdletBinding()]param($VMHost,$Server) }
            function Get-VMHostNtpServer { [CmdletBinding()]param($VMHost,$Server) }
            function Get-VMHostSysLogServer { [CmdletBinding()]param($VMHost,$Server) }
            function Get-VirtualSwitch { [CmdletBinding()]param($VMHost,$Server,[switch]$Standard) }
            function Get-VirtualPortGroup { [CmdletBinding()]param($VMHost,$Server,[switch]$Standard) }
            function Get-VMHostNetworkAdapter { [CmdletBinding()]param($VMHost,$Server,[switch]$VMKernel,[switch]$Physical) }
            function Get-Datastore { [CmdletBinding()]param($VMHost,$Server) }
            function Get-VMHostHba { [CmdletBinding()]param($VMHost,$Server) }
            function Get-ScsiLun { [CmdletBinding()]param($VMHost,$Server) }
            function Get-ScsiLunPath { [CmdletBinding()]param($ScsiLun) }
            function Get-VMHostService { [CmdletBinding()]param($VMHost,$Server) }
            function Get-AdvancedSetting { [CmdletBinding()]param($Entity,$Server) }
            function Get-VMHostAccount { [CmdletBinding()]param($Server,[switch]$User) }
            function Get-VIPermission { [CmdletBinding()]param($Entity,$Server) }
            function Get-View { [CmdletBinding()]param($Id,$Server,$Property) }
            $script:owner = [pscustomobject]@{Name='esxi-a';Uid='/VIServer=user@esxi-a:443/';IsConnected=$true;ProductLine='embeddedEsx'}
            $script:other = [pscustomobject]@{Name='esxi-b';Uid='/VIServer=user@esxi-b:443/';IsConnected=$true;ProductLine='embeddedEsx'}
        }
        BeforeEach {
            $script:hostFixture = [pscustomobject]@{Name='esxi-a';Uid='/VIServer=user@esxi-a:443/VMHost=ha-host/';Id='HostSystem-ha-host';Version='8.0';Build='123';Model='test';Manufacturer='test';MemoryTotalGB=64;NumCpu=8;PowerState='PoweredOn';ConnectionState='Connected';ExtensionData=[pscustomobject]@{Hardware=[pscustomobject]@{SystemInfo=[pscustomobject]@{Uuid='12345678-1234-1234-1234-123456789abc'}};ConfigManager=[pscustomobject]@{DateTimeSystem='datetime';FirewallSystem='firewall'}}}
            Mock Get-VMHostNetwork { [pscustomobject]@{HostName='esxi-a';DomainName='example.test';DnsAddress=@('10.0.0.2','10.0.0.1');SearchDomain=@('example.test')} }
            Mock Get-VMHostNtpServer { '10.0.0.3' }
            Mock Get-VMHostSysLogServer { }
            Mock Get-VirtualSwitch { }
            Mock Get-VirtualPortGroup { }
            Mock Get-VMHostNetworkAdapter { }
            Mock Get-Datastore { }
            Mock Get-VMHostHba { }
            Mock Get-ScsiLun { }
            Mock Get-ScsiLunPath { }
            Mock Get-VMHostService { [pscustomobject]@{Key='ntpd';Label='NTP';Policy='on';Required=$false;Running=$true} }
            Mock Get-AdvancedSetting { [pscustomobject]@{Name='Security.PasswordQualityControl';Value='retry=3';Type='String';Description='test'} }
            Mock Get-VMHostAccount { [pscustomobject]@{Id='root';Name='root';Description='test'} }
            Mock Get-VIPermission { }
            Mock Get-View {
                if ($Id -eq 'datetime') { return [pscustomobject]@{DateTimeInfo=[pscustomobject]@{TimeZone=[pscustomobject]@{Key='Europe/Berlin';Name='Europe/Berlin'}}} }
                return [pscustomobject]@{FirewallInfo=[pscustomobject]@{DefaultPolicy=[pscustomobject]@{IncomingBlocked=$true;OutgoingBlocked=$false};Ruleset=@([pscustomobject]@{Key='sshServer';Label='SSH Server';Enabled=$false;Rule=@([pscustomobject]@{Direction='inbound';PortType='dst';Protocol='tcp';Port=22;EndPort=22});AllowedHosts=[pscustomobject]@{AllIp=$false;IpAddress=@('10.0.0.10');IpNetwork=@([pscustomobject]@{Network='10.1.0.0';PrefixLength=16})}})}}
            }
        }
        It 'resolves the matching connection among multiple defaults and never uses the other host' {
            $previousDefaults = Get-Variable -Name DefaultVIServers -Scope Global -ValueOnly -ErrorAction SilentlyContinue
            $global:DefaultVIServers = @($other,$owner)
            try {
                $snap = New-ESXiSnapshot -VMHost $hostFixture -IncludeAccounts
                $snap.Target.Id | Should -Be '12345678-1234-1234-1234-123456789abc'
                Should -Invoke Get-VMHostAccount -Times 1 -ParameterFilter { $Server.Uid -ceq '/VIServer=user@esxi-a:443/' -and $User }
                Should -Invoke Get-VMHostNetwork -Times 1 -ParameterFilter { $VMHost.Uid -ceq $hostFixture.Uid -and $Server.Uid -ceq $owner.Uid }
            } finally { $global:DefaultVIServers = $previousDefaults }
        }
        It 'aborts when trustworthy identity is missing or connection association differs' {
            $hostFixture.ExtensionData.Hardware.SystemInfo.Uuid = ''
            { New-ESXiSnapshot -VMHost $hostFixture -Server $owner } | Should -Throw '*identity*'
            { New-ESXiSnapshot -VMHost $hostFixture -Server $other } | Should -Throw '*connection*'
        }
        It 'keeps independent successful empty units and explicit skipped optional units' {
            $snap = New-ESXiSnapshot -VMHost $hostFixture -Server $owner
            ($snap.Collections | Where-Object Id -EQ 'Storage.Datastores').Status | Should -Be Success
            ($snap.Collections | Where-Object Id -EQ 'Storage.Datastores').EntityCount | Should -Be 0
            ($snap.Collections | Where-Object Id -EQ 'Accounts.Users').Status | Should -Be Skipped
            @($snap.Collections).Count | Should -Be 19
        }
        It 'marks failed queries as failed with sanitized diagnostics and supports strict capture' {
            Mock Get-Datastore { throw 'password=never-persist' }
            $snap = New-ESXiSnapshot -VMHost $hostFixture -Server $owner -WarningAction SilentlyContinue
            ($snap.Collections | Where-Object Id -EQ 'Storage.Datastores').Status | Should -Be Failed
            ($snap | ConvertTo-Json -Depth 64) | Should -Not -Match 'never-persist'
            { New-ESXiSnapshot -VMHost $hostFixture -Server $owner -Strict } | Should -Throw '*Storage.Datastores*'
        }
        It 'reads actual timezone and preserves DNS preference order' {
            $snap = New-ESXiSnapshot -VMHost $hostFixture -Server $owner
            ($snap.Entities.System | Where-Object CollectionId -EQ 'System.TimeZone').Properties.TimeZone | Should -Be 'Europe/Berlin'
            ($snap.Entities.System | Where-Object CollectionId -EQ 'System.Network').Properties.DnsServers[0] | Should -Be '10.0.0.2'
            Should -Invoke Get-View -Times 1 -ParameterFilter { $Id -eq 'datetime' -and $Server.Uid -ceq $owner.Uid }
        }
        It 'captures disabled firewall rules with allowed hosts and network prefixes' {
            $snap = New-ESXiSnapshot -VMHost $hostFixture -Server $owner -IncludeFirewall
            $rule = $snap.Entities.Firewall | Where-Object Id -EQ 'Ruleset/sshServer'
            $rule.Properties.Enabled | Should -BeFalse
            $rule.Properties.AllowedHosts.AllIp | Should -BeFalse
            $rule.Properties.AllowedHosts.IpAddress | Should -Contain '10.0.0.10'
            $rule.Properties.AllowedHosts.IpNetwork[0].PrefixLength | Should -Be 16
        }
        It 'separates operational observations and stable datastore identities' {
            Mock Get-Datastore { [pscustomobject]@{Name='Renamable';ExtensionData=[pscustomobject]@{Info=[pscustomobject]@{Url='/vmfs/volumes/uuid-volume'}};CapacityGB=100;FreeSpaceGB=40;State='Available';Type='VMFS';FileSystemVersion='6'} }
            $snap = New-ESXiSnapshot -VMHost $hostFixture -Server $owner
            $snap.Entities.Service[0].Properties.Contains('Running') | Should -BeFalse
            $snap.Entities.Service[0].Observations.Running | Should -BeTrue
            $snap.Entities.Storage[0].Id | Should -Be 'Datastore//vmfs/volumes/uuid-volume'
            $snap.Entities.Storage[0].Properties.Contains('FreeSpaceGB') | Should -BeFalse
            $snap.Entities.Storage[0].Observations.FreeSpaceGB | Should -Be 40
        }
        It 'includes the switch in port group identity' {
            Mock Get-VirtualPortGroup { @('switch-a','switch-b') | ForEach-Object { [pscustomobject]@{Name='same';VirtualSwitch=[pscustomobject]@{Name=$_};VLanId=10} } }
            $snap = New-ESXiSnapshot -VMHost $hostFixture -Server $owner
            @($snap.Entities.Network).Count | Should -Be 2
            $snap.Entities.Network[0].Id | Should -Not -BeExactly $snap.Entities.Network[1].Id
        }
        It 'reports vCenter account scope unsupported but retains permission coverage' {
            $owner.ProductLine = 'vpx'
            try {
                $snap = New-ESXiSnapshot -VMHost $hostFixture -Server $owner -IncludeAccounts -WarningAction SilentlyContinue
                ($snap.Collections | Where-Object Id -EQ 'Accounts.Users').Status | Should -Be Unsupported
                ($snap.Collections | Where-Object Id -EQ 'Accounts.Permissions').Status | Should -Be Success
                Should -Invoke Get-VMHostAccount -Times 0
            } finally { $owner.ProductLine = 'embeddedEsx' }
        }
        It 'uses specific advanced severity and records exact selection scope' {
            $baseline = New-ESXiSnapshot -VMHost $hostFixture -Server $owner -IncludeAll
            Mock Get-AdvancedSetting { [pscustomobject]@{Name='Security.PasswordQualityControl';Value='retry=5';Type='String';Description='test'} }
            $current = New-ESXiSnapshot -VMHost $hostFixture -Server $owner -IncludeAll
            $result = Compare-ESXiSnapshot -BaselineSnapshot $baseline -CurrentSnapshot $current
            $result.TotalChanges | Should -Be 1
            $result.Events[0].Severity | Should -Be High
            ($baseline.Collections | Where-Object Id -EQ 'AdvancedSettings').Scope.Patterns | Should -Contain 'Security.PasswordQualityControl'
        }
        It 'rejects malformed hardware UUIDs rather than accepting placeholder identity' {
            $hostFixture.ExtensionData.Hardware.SystemInfo.Uuid = 'Unknown'
            { New-ESXiSnapshot -VMHost $hostFixture -Server $owner } | Should -Throw '*identity*'
        }
        It 'normalizes IP and MAC addresses using explicit provider rules' {
            Mock Get-VMHostNetworkAdapter {
                if ($VMKernel) { [pscustomobject]@{Name='vmk0';IP='2001:0db8:0000:0000:0000:0000:0000:0001';SubnetMask='ffff:ffff:ffff:ffff::';Mac='AA-BB-CC-DD-EE-FF';Mtu=1500} }
            }
            $snap = New-ESXiSnapshot -VMHost $hostFixture -Server $owner
            $snap.Entities.Network[0].Properties.IP | Should -BeExactly '2001:db8::1'
            $snap.Entities.Network[0].Properties.Mac | Should -BeExactly 'aa:bb:cc:dd:ee:ff'
        }
        It 'detects DNS priority changes while ignoring runtime service and free-space changes' {
            $baseline = New-ESXiSnapshot -VMHost $hostFixture -Server $owner
            Mock Get-VMHostService { [pscustomobject]@{Key='ntpd';Label='NTP';Policy='on';Required=$false;Running=$false} }
            $observed = New-ESXiSnapshot -VMHost $hostFixture -Server $owner
            (Compare-ESXiSnapshot -BaselineSnapshot $baseline -CurrentSnapshot $observed).TotalChanges | Should -Be 0
            Mock Get-VMHostNetwork { [pscustomobject]@{HostName='esxi-a';DomainName='example.test';DnsAddress=@('10.0.0.1','10.0.0.2');SearchDomain=@('example.test')} }
            $current = New-ESXiSnapshot -VMHost $hostFixture -Server $owner
            $result = Compare-ESXiSnapshot -BaselineSnapshot $baseline -CurrentSnapshot $current
            $result.TotalChanges | Should -Be 1
            $result.Events[0].PropertyPath | Should -Be '/DnsServers'
        }
        It 'supports custom advanced selection while comparing unaffected units in partial mode' {
            $baseline = New-ESXiSnapshot -VMHost $hostFixture -Server $owner -IncludeAdvancedSettings
            $current = New-ESXiSnapshot -VMHost $hostFixture -Server $owner -IncludeAdvancedSettings -AdvancedSettingName 'Security.*'
            { Compare-ESXiSnapshot -BaselineSnapshot $baseline -CurrentSnapshot $current } | Should -Throw
            $partial = Compare-ESXiSnapshot -BaselineSnapshot $baseline -CurrentSnapshot $current -AllowPartial
            $partial.IsComplete | Should -BeFalse
            $partial.TotalChanges | Should -Be 0
            @($partial.Coverage | Where-Object { $_.CollectionId -eq 'Services' -and $_.Compared }).Count | Should -Be 1
        }
        It 'preserves unrelated successful units after a path enumeration failure' {
            Mock Get-ScsiLun { [pscustomobject]@{CanonicalName='naa.123';LunType='disk';MultipathPolicy='Fixed';CapacityGB=10} }
            Mock Get-ScsiLunPath { throw 'secret-query-text' }
            $snap = New-ESXiSnapshot -VMHost $hostFixture -Server $owner -WarningAction SilentlyContinue
            ($snap.Collections | Where-Object Id -EQ 'Storage.Luns').Status | Should -Be Success
            ($snap.Collections | Where-Object Id -EQ 'Storage.Paths').Status | Should -Be Failed
            @($snap.Entities.Storage | Where-Object CollectionId -EQ 'Storage.Paths').Count | Should -Be 0
        }
        It 'captures LUN paths as configuration identities with operational state as observation' {
            Mock Get-ScsiLun { [pscustomobject]@{CanonicalName='naa.123';LunType='disk';MultipathPolicy='Fixed';CapacityGB=10} }
            Mock Get-ScsiLunPath { [pscustomobject]@{Name='vmhba1:C0:T0:L0';Preferred=$true;SanId='123';State='Active'} }
            $snap = New-ESXiSnapshot -VMHost $hostFixture -Server $owner
            $path = $snap.Entities.Storage | Where-Object CollectionId -EQ 'Storage.Paths'
            $path.Id | Should -Be 'Path/naa.123/vmhba1:C0:T0:L0'
            $path.Properties.Preferred | Should -BeTrue
            $path.Properties.Contains('State') | Should -BeFalse
            $path.Observations.State | Should -Be Active
            Should -Invoke Get-ScsiLunPath -Times 1 -ParameterFilter { $ScsiLun.CanonicalName -eq 'naa.123' }
        }
        It 'makes unavailable capability explicit and gives a capture-time installation instruction' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Get-VMHostHba' }
            $snap = New-ESXiSnapshot -VMHost $hostFixture -Server $owner -WarningAction SilentlyContinue
            $unit = $snap.Collections | Where-Object Id -EQ 'Storage.Hbas'
            $unit.Status | Should -Be Unsupported
            $unit.Reason | Should -Match 'Install VMware.PowerCLI'
        }
        It 'gives a strict capture dependency failure an actionable installation instruction' -Tag Prerequisite {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Get-VMHostHba' }
            { New-ESXiSnapshot -VMHost $hostFixture -Server $owner -Strict } | Should -Throw '*Install VMware.PowerCLI*'
        }
        It 'fails an unavailable timezone without inventing UTC' {
            Mock Get-View { [pscustomobject]@{} } -ParameterFilter { $Id -eq 'datetime' }
            $snap = New-ESXiSnapshot -VMHost $hostFixture -Server $owner -WarningAction SilentlyContinue
            ($snap.Collections | Where-Object Id -EQ 'System.TimeZone').Status | Should -Be Failed
            @($snap.Entities.System | Where-Object CollectionId -EQ 'System.TimeZone').Count | Should -Be 0
        }
        It 'marks <Unit> failed when its required query fails' -ForEach @(
            @{Unit='System.Network';Command='Get-VMHostNetwork'},@{Unit='System.Ntp';Command='Get-VMHostNtpServer'},
            @{Unit='System.Syslog';Command='Get-VMHostSysLogServer'},@{Unit='System.TimeZone';Command='Get-View'},
            @{Unit='Network.Switches';Command='Get-VirtualSwitch'},@{Unit='Network.PortGroups';Command='Get-VirtualPortGroup'},
            @{Unit='Network.VMkernel';Command='Get-VMHostNetworkAdapter'},@{Unit='Network.PhysicalNics';Command='Get-VMHostNetworkAdapter'},
            @{Unit='Storage.Datastores';Command='Get-Datastore'},@{Unit='Storage.Hbas';Command='Get-VMHostHba'},
            @{Unit='Storage.Luns';Command='Get-ScsiLun'},@{Unit='Storage.Paths';Command='Get-ScsiLun'},
            @{Unit='Services';Command='Get-VMHostService'},@{Unit='AdvancedSettings';Command='Get-AdvancedSetting'},
            @{Unit='Firewall.Exceptions';Command='Get-View'},@{Unit='Firewall.Policy';Command='Get-View'},
            @{Unit='Accounts.Users';Command='Get-VMHostAccount'},@{Unit='Accounts.Permissions';Command='Get-VIPermission'}
        ) {
            Mock $Command { throw 'secret provider error' }
            $snap = New-ESXiSnapshot -VMHost $hostFixture -Server $owner -IncludeAll -WarningAction SilentlyContinue
            ($snap.Collections | Where-Object Id -EQ $Unit).Status | Should -Be Failed
            ($snap | ConvertTo-Json -Depth 64) | Should -Not -Match 'secret provider error'
        }
    }
}
