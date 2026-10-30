function Get-ESXiSnapshot {
    <# .SYNOPSIS
    Imports an ESXi snapshot for offline inspection; legacy snapshots are report-only.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)][Alias('FilePath','FullName')][string]$Path)
    process {
        $snapshot = Import-DDSnapshot -Path $Path
        Assert-ESXiTechnology $snapshot
        return $snapshot
    }
}
