function Export-ESXiConfigurationReport {
    <# .SYNOPSIS
    Exports all captured ESXi configuration and explicit collection coverage as HTML.
    #>
    [CmdletBinding(DefaultParameterSetName='Object')]
    param(
        [Parameter(Mandatory,ParameterSetName='Object',ValueFromPipeline)][object]$Snapshot,
        [Parameter(Mandatory,ParameterSetName='Path')][string]$SnapshotPath,
        [Parameter(Mandatory)][string]$OutputPath,
        [string]$Title = 'ESXi Configuration Report'
    )
    process {
        $arguments = @{} + $PSBoundParameters
        $arguments.Title = $Title
        Export-DDConfigurationReport @arguments
    }
}
