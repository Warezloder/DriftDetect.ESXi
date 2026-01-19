#Requires -Version 7.0

function New-ESXiSnapshot {
    <#
    .SYNOPSIS
        Captures a snapshot of ESXi host configuration.
    
    .DESCRIPTION
        Collects detailed configuration data from a standalone ESXi host including
        system settings, network, storage, services, advanced settings, firewall rules,
        and user accounts. Returns an ESXiSnapshot object that can be exported to file
        for comparison.
    
    .PARAMETER VMHost
        The ESXi host object (from Get-VMHost or Connect-VIServer).
    
    .PARAMETER IncludeAdvancedSettings
        Include advanced system settings. Can generate significant data.
    
    .PARAMETER IncludeAccounts
        Include local user accounts and permissions.
    
    .PARAMETER IncludeFirewall
        Include firewall rules and exceptions.
    
    .PARAMETER OutputPath
        Path to export the snapshot JSON file. If not specified, returns snapshot object only.
    
    .EXAMPLE
        PS> $vmhost = Connect-VIServer -Server esxi-01.domain.local
        PS> $snapshot = New-ESXiSnapshot -VMHost $vmhost -OutputPath "baseline.json"
        Captures a basic snapshot of the ESXi host.
    
    .EXAMPLE
        PS> New-ESXiSnapshot -VMHost $vmhost -IncludeAdvancedSettings -IncludeAccounts -IncludeFirewall
        Captures a comprehensive snapshot including all configuration areas.
    
    .NOTES
        Requires active connection to ESXi host (Connect-VIServer).
        ESXi 8.0+ recommended.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]$VMHost,

        [Parameter()]
        [switch]$IncludeAdvancedSettings,

        [Parameter()]
        [switch]$IncludeAccounts,

        [Parameter()]
        [switch]$IncludeFirewall,

        [Parameter()]
        [string]$OutputPath
    )

    begin {
        Write-Verbose "Starting snapshot capture from $($VMHost.Name)"
    }

    process {
        try {
            # Create snapshot object
            $snapshot = [ESXiSnapshot]::new()
            $snapshot.HostName = $VMHost.Name
            $snapshot.HostVersion = $VMHost.Version
            $snapshot.HostBuild = $VMHost.Build

            # Always collect System configuration
            Write-Verbose "Collecting system configuration..."
            $systemCollector = [SystemCollector]::new()
            $systemEntities = $systemCollector.Collect($VMHost)
            $snapshot.AddEntities($systemEntities)
            Write-Verbose "Collected $($systemEntities.Count) system entities"

            # Always collect Network configuration
            Write-Verbose "Collecting network configuration..."
            $networkCollector = [NetworkCollector]::new()
            $networkEntities = $networkCollector.Collect($VMHost)
            $snapshot.AddEntities($networkEntities)
            Write-Verbose "Collected $($networkEntities.Count) network entities"

            # Always collect Storage configuration
            Write-Verbose "Collecting storage configuration..."
            $storageCollector = [StorageCollector]::new()
            $storageEntities = $storageCollector.Collect($VMHost)
            $snapshot.AddEntities($storageEntities)
            Write-Verbose "Collected $($storageEntities.Count) storage entities"

            # Always collect Services
            Write-Verbose "Collecting services..."
            $serviceCollector = [ServiceCollector]::new()
            $serviceEntities = $serviceCollector.Collect($VMHost)
            $snapshot.AddEntities($serviceEntities)
            Write-Verbose "Collected $($serviceEntities.Count) service entities"

            # Optional: Advanced Settings
            if ($IncludeAdvancedSettings) {
                Write-Verbose "Collecting advanced settings..."
                $advSettingsCollector = [AdvancedSettingsCollector]::new()
                $advEntities = $advSettingsCollector.Collect($VMHost)
                $snapshot.AddEntities($advEntities)
                Write-Verbose "Collected $($advEntities.Count) advanced setting entities"
            }

            # Optional: Firewall Rules
            if ($IncludeFirewall) {
                Write-Verbose "Collecting firewall rules..."
                $firewallCollector = [FirewallCollector]::new()
                $firewallEntities = $firewallCollector.Collect($VMHost)
                $snapshot.AddEntities($firewallEntities)
                Write-Verbose "Collected $($firewallEntities.Count) firewall entities"
            }

            # Optional: Accounts
            if ($IncludeAccounts) {
                Write-Verbose "Collecting user accounts..."
                $accountCollector = [AccountCollector]::new()
                $accountEntities = $accountCollector.Collect($VMHost)
                $snapshot.AddEntities($accountEntities)
                Write-Verbose "Collected $($accountEntities.Count) account entities"
            }

            # Add metadata
            $snapshot.Metadata['CaptureParameters'] = @{
                IncludeAdvancedSettings = $IncludeAdvancedSettings.IsPresent
                IncludeAccounts = $IncludeAccounts.IsPresent
                IncludeFirewall = $IncludeFirewall.IsPresent
            }

            # Export if path specified
            if ($OutputPath) {
                $snapshot.Export($OutputPath)
                Write-Verbose "Snapshot exported to $OutputPath"
            }

            return $snapshot
        }
        catch {
            Write-Error "Failed to capture snapshot: $_"
            throw
        }
    }
}
