function New-ESXiSnapshot {
    <#
    .SYNOPSIS
    Captures configuration from the supplied PowerCLI VMHost and its owning connection.
    .DESCRIPTION
    Read-only collection. Optional areas require include switches or IncludeAll. Failed
    units remain visible; Strict rejects any requested applicable unit that is incomplete.
    PowerCLI commands are resolved at capture, never at module import. No connections are
    opened or disconnected. Credentials and license keys are never persisted.
    .PARAMETER Server
    Optional connected VIServer for a non-default connection. Must match VMHost.Uid.
    .PARAMETER AdvancedSettingName
    Exact selection patterns; the effective patterns are embedded into the unit scope.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNull()][object]$VMHost,
        [switch]$IncludeAdvancedSettings,
        [switch]$IncludeAccounts,
        [switch]$IncludeFirewall,
        [string]$OutputPath,
        [switch]$IncludeAll,
        [switch]$Strict,
        [object]$Server,
        [ValidateNotNullOrEmpty()][string[]]$AdvancedSettingName = @(
            'Config.HostAgent.log.level','Security.PasswordQualityControl','Security.AccountLockFailures',
            'Security.AccountUnlockTime','UserVars.ESXiShellInteractiveTimeOut','UserVars.ESXiShellTimeOut',
            'UserVars.SuppressShellWarning','Net.DVFilterBindIpAddress','Mem.AllocGuestLargePage',
            'Mem.ShareForceSalting','VSAN.*','Vpx.Vpxa.*'
        )
    )
    $owningServer = Resolve-ESXiServer -VMHost $VMHost -Server $Server
    $hardware = Get-ESXiField (Get-ESXiField $VMHost ExtensionData) Hardware
    $uuid = [string](Get-ESXiField (Get-ESXiField $hardware SystemInfo) Uuid)
    $parsedUuid = [guid]::Empty
    if (-not [guid]::TryParse($uuid,[ref]$parsedUuid) -or $parsedUuid -eq [guid]::Empty -or $parsedUuid.ToString() -eq 'ffffffff-ffff-ffff-ffff-ffffffffffff') {
        throw 'Cannot establish trustworthy target identity: ESXi hardware UUID is unavailable.'
    }
    $patterns = @($AdvancedSettingName | Sort-Object -Unique)
    $enabled = @{AdvancedSettings=($IncludeAll -or $IncludeAdvancedSettings);Accounts=($IncludeAll -or $IncludeAccounts);Firewall=($IncludeAll -or $IncludeFirewall)}
    $collections = [System.Collections.Generic.List[object]]::new()
    foreach ($definition in @(Get-ESXiUnitDefinitions)) {
        $scope = [ordered]@{}
        if ($definition.Id -eq 'AdvancedSettings') { $scope.Patterns = $patterns }
        if ($definition.Id -eq 'Accounts.Users') { $scope.ConnectionType = [string](Get-ESXiField $owningServer ProductLine) }
        if ($definition.Optional -and -not $enabled[$definition.Optional]) {
            $unit = New-DDCollection -Id $definition.Id -Status Skipped -Scope $scope -Reason 'Omitted by capture options.'
        }
        elseif ($definition.Id -eq 'Accounts.Users' -and [string](Get-ESXiField $owningServer ProductLine) -cne 'embeddedEsx') {
            $unit = New-DDCollection -Id $definition.Id -Status Unsupported -Scope $scope -Reason 'Local accounts require a direct standalone ESXi VIServer connection (ProductLine embeddedEsx).'
        }
        else {
            $missing = @($definition.Commands | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
            if ($missing.Count -gt 0) {
                $unit = New-DDCollection -Id $definition.Id -Status Unsupported -Scope $scope -Reason ('PowerCLI command unavailable: {0}. Install VMware.PowerCLI 12+ or VCF.PowerCLI.' -f ($missing -join ', '))
            }
            else {
                $unit = Invoke-DDCollector -Id $definition.Id -Scope $scope -ScriptBlock {
                    param($id,$target,$connection,$selection)
                    Invoke-ESXiUnit -Unit $id -VMHost $target -Server $connection -Patterns $selection
                } -ArgumentList @($definition.Id,$VMHost,$owningServer,$patterns)
            }
        }
        $collections.Add($unit)
        if ($unit.Status -in @('Partial','Failed','Unsupported')) {
            if ($Strict) { throw "Requested collection '$($definition.Id)' is $($unit.Status). $($unit.Reason)" }
            Write-Warning "Collection '$($definition.Id)' is $($unit.Status); snapshot coverage is incomplete."
        }
    }
    $target = @{Id=$parsedUuid.ToString();Name=[string]$VMHost.Name;IdentitySource='HardwareUuid';Version=[string]$VMHost.Version;Build=[string]$VMHost.Build}
    $profile = @{IncludeAdvancedSettings=[bool]$enabled.AdvancedSettings;IncludeAccounts=[bool]$enabled.Accounts;IncludeFirewall=[bool]$enabled.Firewall;AdvancedSettingNames=$patterns;ExcludedFields=@('System.LicenseKey')}
    $rules = Import-DDRuleSet -Path (Join-Path $script:ModuleRoot 'Config\SeverityRules.json')
    $snapshot = New-DDSnapshot -Technology ESXi -Target $target -Collections $collections.ToArray() -CollectionProfile $profile -RuleSet $rules -ProviderVersion '2.0.0'
    if ($OutputPath) { Export-DDSnapshot -Snapshot $snapshot -Path $OutputPath | Out-Null }
    return $snapshot
}
