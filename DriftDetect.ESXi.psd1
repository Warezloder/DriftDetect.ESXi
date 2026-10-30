@{
    RootModule = 'DriftDetect.ESXi.psm1'
    ModuleVersion = '2.0.0'
    GUID = 'b2f8e3d1-9a5c-4f2e-8d7b-3e9a1c6f4d8e'
    Author = 'Warezloder'
    CompanyName = 'Community'
    Copyright = '(c) 2025 Warezloder. All rights reserved.'
    Description = 'ESXi configuration capture with explicit coverage, shared comparison rules, JSON and HTML reports.'
    PowerShellVersion = '7.0'
    RequiredModules = @(@{ ModuleName = 'DriftDetect.Core'; ModuleVersion = '1.0.0'; MaximumVersion = '1.*' })
    FunctionsToExport = @('New-ESXiSnapshot','Get-ESXiSnapshot','Compare-ESXiSnapshot','Export-ESXiDriftReport','Export-ESXiConfigurationReport')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{ PSData = @{
        Tags = @('VMware','ESXi','Configuration','Drift','PowerCLI','VCF')
        LicenseUri = 'https://github.com/Warezloder/DriftDetect.ESXi/blob/main/LICENSE'
        ProjectUri = 'https://github.com/Warezloder/DriftDetect.ESXi'
        ReleaseNotes = '2.0: Shared Core, schema 2.0 plain objects, explicit collection coverage, scoped PowerCLI queries, stable identities and configuration reports. PowerCLI required only for capture; PSWriteHTML only for reports.'
    } }
}
