@{
    RootModule = 'DriftDetect.ESXi.psm1'
    ModuleVersion = '2.0.1'
    GUID = 'b2f8e3d1-9a5c-4f2e-8d7b-3e9a1c6f4d8e'
    Author = 'Warezloder'
    CompanyName = 'Community'
    Copyright = '(c) 2025 Warezloder. All rights reserved.'
    Description = 'ESXi configuration capture with explicit coverage, shared comparison rules, JSON and HTML reports.'
    PowerShellVersion = '7.0'
    RequiredModules = @(@{ ModuleName = 'DriftDetect.Core'; ModuleVersion = '1.0.1'; MaximumVersion = '1.*' })
    FunctionsToExport = @('New-ESXiSnapshot','Get-ESXiSnapshot','Compare-ESXiSnapshot','Export-ESXiDriftReport','Export-ESXiConfigurationReport')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{ PSData = @{
        Tags = @('VMware','ESXi','Configuration','Drift','PowerCLI','VCF')
        LicenseUri = 'https://github.com/Warezloder/DriftDetect.ESXi/blob/main/LICENSE'
        ProjectUri = 'https://github.com/Warezloder/DriftDetect.ESXi'
        ReleaseNotes = '2.0.1: Compare SSH running state as High drift, validate its boolean state, and mark expanded service scope. Requires Core 1.0.1 and a fresh ESXi baseline.'
    } }
}
