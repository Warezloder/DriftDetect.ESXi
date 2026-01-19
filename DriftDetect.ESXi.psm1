#Requires -Version 7.0

<#
.SYNOPSIS
    DriftDetect.ESXi - Standalone ESXi host configuration drift detection module.

.DESCRIPTION
    Root module file that loads all classes, private functions, and public functions.
    This module provides comprehensive drift detection for standalone ESXi 8.0+ hosts
    using hash-based change tracking and severity scoring.
    
    Supports both VMware.PowerCLI and VCF.PowerCLI.
#>

$ErrorActionPreference = 'Stop'

# Check for required PowerCLI module (VMware.PowerCLI or VCF.PowerCLI)
Write-Verbose "Checking for PowerCLI module..."
$hasPowerCLI = Get-Module -ListAvailable -Name VMware.PowerCLI
$hasVCFPowerCLI = Get-Module -ListAvailable -Name VCF.PowerCLI

if (-not $hasPowerCLI -and -not $hasVCFPowerCLI) {
    throw @"
Required PowerCLI module not found.

Please install one of the following:
  - VMware.PowerCLI:  Install-Module VMware.PowerCLI -MinimumVersion 12.0.0
  - VCF.PowerCLI:     Install-Module VCF.PowerCLI

VCF.PowerCLI is the VMware Cloud Foundation version which includes all PowerCLI modules.
"@
}

if ($hasVCFPowerCLI) {
    Write-Verbose "  Found: VCF.PowerCLI"
}
elseif ($hasPowerCLI) {
    Write-Verbose "  Found: VMware.PowerCLI"
}

# Get module root path
$ModuleRoot = $PSScriptRoot

# Load Classes (order matters - base classes first)
$classLoadOrder = @(
    'EntityBase.ps1'
    'CollectorBase.ps1'
    'SystemCollector.ps1'
    'NetworkCollector.ps1'
    'StorageCollector.ps1'
    'ServiceCollector.ps1'
    'AdvancedSettingsCollector.ps1'
    'FirewallCollector.ps1'
    'AccountCollector.ps1'
    'Snapshot.ps1'
    'DriftEngine.ps1'
)

Write-Verbose "Loading DriftDetect.ESXi classes..."
foreach ($className in $classLoadOrder) {
    $classPath = Join-Path $ModuleRoot "Classes\$className"
    if (Test-Path $classPath) {
        . $classPath
        Write-Verbose "  Loaded: $className"
    }
    else {
        Write-Warning "Class file not found: $classPath"
    }
}

# Load Private functions
Write-Verbose "Loading private functions..."
$privatePath = Join-Path $ModuleRoot 'Private'
if (Test-Path $privatePath) {
    Get-ChildItem -Path $privatePath -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            . $_.FullName
            Write-Verbose "  Loaded: $($_.Name)"
        }
        catch {
            Write-Warning "Failed to load private function $($_.Name): $_"
        }
    }
}

# Load Public functions
Write-Verbose "Loading public functions..."
$publicPath = Join-Path $ModuleRoot 'Public'
if (Test-Path $publicPath) {
    Get-ChildItem -Path $publicPath -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            . $_.FullName
            Write-Verbose "  Loaded: $($_.Name)"
        }
        catch {
            Write-Warning "Failed to load public function $($_.Name): $_"
        }
    }
}

# Export public functions
Export-ModuleMember -Function 'New-ESXiSnapshot', 'Compare-ESXiSnapshot', 'Export-ESXiDriftReport', 'Get-ESXiSnapshot'

Write-Verbose "DriftDetect.ESXi module loaded successfully"
