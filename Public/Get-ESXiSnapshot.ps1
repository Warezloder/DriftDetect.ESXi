#Requires -Version 7.0

function Get-ESXiSnapshot {
    <#
    .SYNOPSIS
        Loads an ESXi snapshot from a JSON file.
    
    .DESCRIPTION
        Imports a previously captured ESXi host snapshot from JSON format. Returns an
        ESXiSnapshot object that can be used for comparison or inspection.
    
    .PARAMETER Path
        Path to the snapshot JSON file.
    
    .EXAMPLE
        PS> $snapshot = Get-ESXiSnapshot -Path "C:\Snapshots\baseline.json"
        PS> $snapshot.HostName
        Loads a snapshot and displays the host name.
    
    .EXAMPLE
        PS> $snap = Get-ESXiSnapshot -Path baseline.json
        PS> $snap.Entities.Keys
        Shows entity types captured in the snapshot.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path $_ })]
        [Alias('FilePath', 'FullName')]
        [string]$Path
    )

    process {
        try {
            Write-Verbose "Loading snapshot from $Path"
            $snapshot = [ESXiSnapshot]::Import($Path)
            
            Write-Verbose "Snapshot loaded:"
            Write-Verbose "  - Snapshot ID: $($snapshot.SnapshotId)"
            Write-Verbose "  - Host: $($snapshot.HostName)"
            Write-Verbose "  - Version: $($snapshot.HostVersion)"
            Write-Verbose "  - Build: $($snapshot.HostBuild)"
            Write-Verbose "  - Captured: $($snapshot.CapturedAt)"
            Write-Verbose "  - Entity types: $($snapshot.Entities.Keys -join ', ')"

            return $snapshot
        }
        catch {
            Write-Error "Failed to load snapshot: $_"
            throw
        }
    }
}
