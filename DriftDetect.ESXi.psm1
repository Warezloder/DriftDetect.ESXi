#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
# Bind compatible exports locally even if another Core major owns global commands.
$core = Import-Module DriftDetect.Core -MinimumVersion 1.0.0 -MaximumVersion '1.*' -Scope Local -PassThru -ErrorAction Stop
if (-not $core -or $core.Name -ne 'DriftDetect.Core' -or $core.Version.Major -ne 1) { throw 'DriftDetect.ESXi 2.x requires DriftDetect.Core 1.x.' }
$script:ModuleRoot = $PSScriptRoot
foreach ($folder in @('Private','Collectors','Public')) {
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot $folder) -Filter '*.ps1' -ErrorAction Stop | Sort-Object Name)) { . $file.FullName }
}
Export-ModuleMember -Function New-ESXiSnapshot,Get-ESXiSnapshot,Compare-ESXiSnapshot,Export-ESXiDriftReport,Export-ESXiConfigurationReport
