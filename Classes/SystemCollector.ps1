#Requires -Version 7.0

<#
.SYNOPSIS
    Collector for ESXi system configuration (hostname, DNS, NTP, time, etc.).
#>

class SystemCollector : ESXiCollectorBase {
    SystemCollector() : base('System') {}

    [ESXiEntity[]] Collect([object]$vmHost) {
        $entities = [System.Collections.ArrayList]::new()
        
        # Basic host info
        $props = @{
            Name = $vmHost.Name
            Version = $vmHost.Version
            Build = $vmHost.Build
            Model = $vmHost.Model
            Manufacturer = $vmHost.Manufacturer
            ProcessorType = $vmHost.ProcessorType
            NumCpu = $vmHost.NumCpu
            CpuTotalMhz = $vmHost.CpuTotalMhz
            MemoryTotalGB = [math]::Round($vmHost.MemoryTotalGB, 2)
            HyperthreadingActive = $vmHost.HyperthreadingActive
            PowerState = $vmHost.PowerState.ToString()
            ConnectionState = $vmHost.ConnectionState.ToString()
            LicenseKey = $this.GetProperty($vmHost, 'LicenseKey', 'Evaluation')
        }

        # Time zone
        try {
            $tz = Get-VMHostNetwork -VMHost $vmHost -ErrorAction SilentlyContinue
            if ($tz) {
                $props['TimeZone'] = $this.GetProperty($tz, 'TimeZone', 'UTC')
            }
        } catch {
            $props['TimeZone'] = 'Unknown'
        }

        # DNS configuration
        try {
            $net = Get-VMHostNetwork -VMHost $vmHost -ErrorAction SilentlyContinue
            if ($net) {
                $props['HostName'] = $net.HostName
                $props['DomainName'] = $net.DomainName
                $props['DnsServers'] = @($net.DnsAddress)
                $props['SearchDomains'] = @($net.SearchDomain)
            }
        } catch {
            Write-Verbose "Failed to get network info: $_"
        }

        # NTP servers
        try {
            $ntp = Get-VMHostNtpServer -VMHost $vmHost -ErrorAction SilentlyContinue
            if ($ntp) {
                $props['NtpServers'] = @($ntp)
            }
        } catch {
            $props['NtpServers'] = @()
        }

        # Date/Time configuration
        try {
            $dateTime = Get-VMHostService -VMHost $vmHost | Where-Object {$_.Key -eq 'ntpd'} -ErrorAction SilentlyContinue
            if ($dateTime) {
                $props['NtpServiceRunning'] = $dateTime.Running
                $props['NtpServicePolicy'] = $dateTime.Policy
            }
        } catch {
            Write-Verbose "Failed to get NTP service info: $_"
        }

        # Syslog configuration
        try {
            $syslog = Get-VMHostSysLogServer -VMHost $vmHost -ErrorAction SilentlyContinue
            if ($syslog) {
                $props['SyslogServers'] = @($syslog.Host)
                $props['SyslogPort'] = $syslog.Port
            } else {
                $props['SyslogServers'] = @()
            }
        } catch {
            $props['SyslogServers'] = @()
        }

        $entity = [ESXiEntity]::new('System', $vmHost.Name, 'System', $props)
        $entities.Add($entity) | Out-Null

        return $entities.ToArray()
    }
}
