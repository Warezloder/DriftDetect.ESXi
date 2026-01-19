#Requires -Version 7.0

function Compare-ESXiSnapshot {
    <#
    .SYNOPSIS
        Compares two ESXi host snapshots to detect configuration drift.
    
    .DESCRIPTION
        Analyzes two snapshots (baseline and current) to identify configuration changes.
        Detects modified properties, new entities, and deleted entities. Assigns severity
        levels to changes based on configurable rules.
    
    .PARAMETER BaselinePath
        Path to the baseline snapshot JSON file.
    
    .PARAMETER CurrentPath
        Path to the current snapshot JSON file.
    
    .PARAMETER BaselineSnapshot
        Baseline ESXiSnapshot object (alternative to BaselinePath).
    
    .PARAMETER CurrentSnapshot
        Current ESXiSnapshot object (alternative to CurrentPath).
    
    .PARAMETER SeverityConfigPath
        Path to custom severity rules JSON. Uses default rules if not specified.
    
    .PARAMETER OutputPath
        Path to export the drift comparison results as JSON.
    
    .EXAMPLE
        PS> $drift = Compare-ESXiSnapshot -BaselinePath baseline.json -CurrentPath current.json
        Compares two snapshot files.
    
    .EXAMPLE
        PS> Compare-ESXiSnapshot -BaselineSnapshot $snap1 -CurrentSnapshot $snap2 -OutputPath drift.json
        Compares snapshot objects and exports results.
    
    .NOTES
        Severity levels: Critical, High, Medium, Low
    #>
    [CmdletBinding(DefaultParameterSetName='Path')]
    param(
        [Parameter(Mandatory, ParameterSetName='Path')]
        [ValidateScript({ Test-Path $_ })]
        [string]$BaselinePath,

        [Parameter(Mandatory, ParameterSetName='Path')]
        [ValidateScript({ Test-Path $_ })]
        [string]$CurrentPath,

        [Parameter(Mandatory, ParameterSetName='Object')]
        [ESXiSnapshot]$BaselineSnapshot,

        [Parameter(Mandatory, ParameterSetName='Object')]
        [ESXiSnapshot]$CurrentSnapshot,

        [Parameter()]
        [string]$SeverityConfigPath,

        [Parameter()]
        [string]$OutputPath
    )

    begin {
        # Determine default config path
        if (-not $SeverityConfigPath) {
            $SeverityConfigPath = Join-Path $PSScriptRoot "..\Config\SeverityRules.json"
        }

        Write-Verbose "Using severity rules from: $SeverityConfigPath"
    }

    process {
        try {
            # Load snapshots
            if ($PSCmdlet.ParameterSetName -eq 'Path') {
                Write-Verbose "Loading baseline from $BaselinePath"
                $baseline = [ESXiSnapshot]::Import($BaselinePath)
                
                Write-Verbose "Loading current from $CurrentPath"
                $current = [ESXiSnapshot]::Import($CurrentPath)
            }
            else {
                $baseline = $BaselineSnapshot
                $current = $CurrentSnapshot
            }

            # Create drift engine
            $engine = [ESXiDriftEngine]::new()
            
            # Load severity rules
            if (Test-Path $SeverityConfigPath) {
                $engine.LoadSeverityRules($SeverityConfigPath)
                Write-Verbose "Loaded severity rules"
            }
            else {
                Write-Warning "Severity config not found: $SeverityConfigPath. Using default severity (Low)."
            }

            # Perform comparison
            Write-Verbose "Comparing snapshots..."
            $result = $engine.Compare($baseline, $current)

            Write-Verbose "Comparison complete:"
            Write-Verbose "  - Changes: $($result.TotalChanges)"
            Write-Verbose "  - New entities: $($result.TotalNew)"
            Write-Verbose "  - Deleted entities: $($result.TotalDeleted)"
            Write-Verbose "  - Critical: $($result.SeveritySummary.Critical)"
            Write-Verbose "  - High: $($result.SeveritySummary.High)"
            Write-Verbose "  - Medium: $($result.SeveritySummary.Medium)"
            Write-Verbose "  - Low: $($result.SeveritySummary.Low)"

            # Export if requested
            if ($OutputPath) {
                $result | ConvertTo-Json -Depth 20 | Set-Content -Path $OutputPath -Encoding UTF8
                Write-Verbose "Results exported to $OutputPath"
            }

            return $result
        }
        catch {
            Write-Error "Failed to compare snapshots: $_"
            throw
        }
    }
}
