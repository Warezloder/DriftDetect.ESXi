function Export-ESXiDriftReport {
    <# .SYNOPSIS
    Exports the shared HTML drift report; PSWriteHTML is needed only at export.
    #>
    [CmdletBinding(DefaultParameterSetName='Object')]
    param(
        [Parameter(Mandatory,ParameterSetName='Object',ValueFromPipeline)][object]$DriftResult,
        [Parameter(Mandatory,ParameterSetName='Path')][string]$DriftResultPath,
        [Parameter(Mandatory)][string]$OutputPath,
        [string]$Title = 'ESXi Configuration Drift Report'
    )
    process {
        $arguments = @{} + $PSBoundParameters
        $arguments.Title = $Title
        Export-DDDriftReport @arguments
    }
}
