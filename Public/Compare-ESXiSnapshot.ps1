function Compare-ESXiSnapshot {
    <# .SYNOPSIS
    Compares ESXi snapshots using embedded rules, strict coverage or explicit AllowPartial.
    #>
    [CmdletBinding(DefaultParameterSetName='Path')]
    param(
        [Parameter(Mandatory,ParameterSetName='Path')][string]$BaselinePath,
        [Parameter(Mandatory,ParameterSetName='Path')][string]$CurrentPath,
        [Parameter(Mandatory,ParameterSetName='Object')][object]$BaselineSnapshot,
        [Parameter(Mandatory,ParameterSetName='Object')][object]$CurrentSnapshot,
        [string]$SeverityConfigPath,
        [string]$OutputPath,
        [switch]$AllowPartial
    )
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $BaselineSnapshot = Get-ESXiSnapshot -Path $BaselinePath
        $CurrentSnapshot = Get-ESXiSnapshot -Path $CurrentPath
    }
    Assert-ESXiTechnology $BaselineSnapshot
    Assert-ESXiTechnology $CurrentSnapshot
    $arguments = @{BaselineSnapshot=$BaselineSnapshot;CurrentSnapshot=$CurrentSnapshot;AllowPartial=$AllowPartial}
    if ($SeverityConfigPath) { $arguments.RuleSet = Import-DDRuleSet -Path $SeverityConfigPath }
    $result = Compare-DDSnapshot @arguments
    if ($OutputPath) { $result | ConvertTo-Json -Depth 100 -WarningAction Stop | Set-Content -LiteralPath $OutputPath -Encoding utf8 -ErrorAction Stop }
    return $result
}
