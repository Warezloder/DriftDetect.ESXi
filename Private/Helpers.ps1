function Get-ESXiField {
    param($Value,[string]$Name,$Default = $null)
    if ($null -eq $Value) { return $Default }
    if ($Value -is [System.Collections.IDictionary]) { if ($Value.Contains($Name)) { return $Value[$Name] }; return $Default }
    $property = $Value.PSObject.Properties[$Name]
    if ($null -ne $property) { return $property.Value }
    return $Default
}

function Resolve-ESXiServer {
    param([object]$VMHost,[object]$Server)
    $hostUid = [string](Get-ESXiField $VMHost Uid)
    if ($hostUid -notmatch '^(?<Connection>/VIServer=[^/]+/)') { throw 'Cannot establish the VMHost owning connection: a PowerCLI VMHost with a valid Uid is required.' }
    $connectionUid = $Matches.Connection
    $candidates = @()
    if ($Server) { $candidates = @($Server) }
    else {
        $associated = Get-ESXiField $VMHost VIServer
        if ($associated) { $candidates = @($associated) }
        else {
            foreach ($variable in @('DefaultVIServers','DefaultVIServer')) {
                $value = Get-Variable -Name $variable -Scope Global -ValueOnly -ErrorAction SilentlyContinue
                if ($null -ne $value) { $candidates += @($value) }
            }
        }
    }
    $matching = @($candidates | Where-Object { ([string](Get-ESXiField $_ Uid)).TrimEnd('/') -ceq $connectionUid.TrimEnd('/') -and (Get-ESXiField $_ IsConnected $false) })
    if ($matching.Count -eq 0) { throw 'Cannot resolve the VMHost owning connection. Supply its connected VIServer with -Server; it must match VMHost.Uid.' }
    return $matching[0]
}

function New-ESXiEntity {
    param([string]$Unit,[string]$Type,[string]$Id,[string]$Name,[System.Collections.IDictionary]$Properties,[System.Collections.IDictionary]$Observations = @{})
    if ([string]::IsNullOrWhiteSpace($Id)) { throw 'A stable entity identifier is unavailable.' }
    New-DDEntity -EntityType $Type -Id $Id -Name $Name -CollectionId $Unit -Path "$Type/$Id" -Properties $Properties -Observations $Observations
}

function Get-ESXiProjection {
    param($Value,[string[]]$Fields,[string[]]$StringFields = @())
    $result = [ordered]@{}
    foreach ($field in $Fields) {
        $item = Get-ESXiField $Value $field
        if ($null -ne $item -and ($StringFields -contains $field -or $item -is [System.Enum])) { $item = [string]$item }
        if ($field -in @('IP','SubnetMask','Network')) { $item = ConvertTo-ESXiAddress $item }
        if ($field -eq 'Mac' -and $null -ne $item) { $item = ([string]$item).ToLowerInvariant().Replace('-',':') }
        $result[$field] = $item
    }
    return ,$result
}

function ConvertTo-ESXiAddress {
    param($Value)
    if ($null -eq $Value) { return $null }
    $address = $null
    if ([System.Net.IPAddress]::TryParse([string]$Value,[ref]$address)) { return $address.ToString() }
    return [string]$Value
}

function Get-ESXiStableId {
    param($Value,[string[]]$Fields)
    foreach ($field in $Fields) {
        $id = [string](Get-ESXiField $Value $field)
        if (-not [string]::IsNullOrWhiteSpace($id)) { return $id }
    }
    throw 'A stable object identifier is unavailable.'
}

function Get-ESXiUnitDefinitions {
    @(
        @{Id='System.Host';Commands=@();Optional=''}
        @{Id='System.Network';Commands=@('Get-VMHostNetwork');Optional=''}
        @{Id='System.Ntp';Commands=@('Get-VMHostNtpServer');Optional=''}
        @{Id='System.Syslog';Commands=@('Get-VMHostSysLogServer');Optional=''}
        @{Id='System.TimeZone';Commands=@('Get-View');Optional=''}
        @{Id='Network.Switches';Commands=@('Get-VirtualSwitch');Optional=''}
        @{Id='Network.PortGroups';Commands=@('Get-VirtualPortGroup');Optional=''}
        @{Id='Network.VMkernel';Commands=@('Get-VMHostNetworkAdapter');Optional=''}
        @{Id='Network.PhysicalNics';Commands=@('Get-VMHostNetworkAdapter');Optional=''}
        @{Id='Storage.Datastores';Commands=@('Get-Datastore');Optional=''}
        @{Id='Storage.Hbas';Commands=@('Get-VMHostHba');Optional=''}
        @{Id='Storage.Luns';Commands=@('Get-ScsiLun');Optional=''}
        @{Id='Storage.Paths';Commands=@('Get-ScsiLun','Get-ScsiLunPath');Optional=''}
        @{Id='Services';Commands=@('Get-VMHostService');Optional=''}
        @{Id='AdvancedSettings';Commands=@('Get-AdvancedSetting');Optional='AdvancedSettings'}
        @{Id='Firewall.Exceptions';Commands=@('Get-View');Optional='Firewall'}
        @{Id='Firewall.Policy';Commands=@('Get-View');Optional='Firewall'}
        @{Id='Accounts.Users';Commands=@('Get-VMHostAccount');Optional='Accounts'}
        @{Id='Accounts.Permissions';Commands=@('Get-VIPermission');Optional='Accounts'}
    )
}

function Assert-ESXiTechnology {
    param([object]$Snapshot)
    $technology = [string](Get-ESXiField $Snapshot Technology)
    if ($technology -cne 'ESXi') { throw 'The snapshot must have Technology ESXi.' }
}
