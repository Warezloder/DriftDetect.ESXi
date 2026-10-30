<img width="2560" height="1280" alt="esxi-banner-01" src="https://github.com/user-attachments/assets/3f3e3243-9b10-4042-8218-bd615a3c4729" />

# DriftDetect.ESXi 2.0

Capture and compare ESXi 8 configuration using PowerShell 7+ and DriftDetect.Core 1.x. Importing JSON and comparing snapshots need neither PowerCLI nor PSWriteHTML. Capture uses VMware.PowerCLI 12+ or VCF.PowerCLI; HTML exports load PSWriteHTML 0.0.170+ on demand through Core.

Install Core alongside the module in a directory on `PSModulePath`. For workspace development, use the parent staging/test script or prepend the workspace parent to the **current process** module path. The shipping module has no sibling fallback or global installation behavior.

```powershell
Import-Module DriftDetect.ESXi
$connection = Connect-VIServer -Server 'esxi01.example.test' -Credential (Get-Credential)
$vmhost = Get-VMHost -Server $connection
$baseline = New-ESXiSnapshot -VMHost $vmhost -Server $connection -IncludeAll -Strict -OutputPath 'baseline.json'
$current = New-ESXiSnapshot -VMHost $vmhost -Server $connection -IncludeAll
$drift = Compare-ESXiSnapshot -BaselineSnapshot $baseline -CurrentSnapshot $current
Export-ESXiConfigurationReport -Snapshot $current -OutputPath 'configuration.html'
Export-ESXiDriftReport -DriftResult $drift -OutputPath 'drift.html'
```

All queries are read-only and bound to the supplied VMHost and its owning VIServer. `-VMHost` takes the host returned by `Get-VMHost`, not the object returned by `Connect-VIServer`. `-Server` is optional for a default connection: the adapter resolves the exact VIServer prefix of `VMHost.Uid`. A caller connection is never opened or disconnected. Non-default connections should be supplied explicitly; mismatched associations abort capture. Local accounts require a direct ESXi connection (`ProductLine=embeddedEsx`); vCenter-backed account units are explicitly Unsupported. Permissions remain scoped to the supplied host.

Hardware UUID establishes target identity; a missing, invalid, all-zero or all-ones UUID aborts capture. Renaming a host keeps its identity. Datastores use their volume URL (falling back to provider ID); NICs use MAC where available; LUNs use canonical names; port group identity includes its switch. Unavailable stable entity identifiers fail their unit rather than create fake identities.

The original switches `-IncludeAdvancedSettings`, `-IncludeAccounts` and `-IncludeFirewall` remain optional and default off. `-IncludeAll` enables all three. `-Strict` rejects any requested Failed, Partial or Unsupported unit. Without Strict, capture warns and preserves useful inventory with incomplete coverage. No exception text or credentials are persisted. License keys are excluded and the collection profile records this exclusion.

| Collection units | Captured configuration |
| --- | --- |
| System.Host | Hardware and software configuration; license key excluded |
| System.Network | Host/domain names, ordered DNS/search domains, gateways |
| System.Ntp, System.Syslog | NTP servers and syslog destinations |
| System.TimeZone | Actual DateTimeSystem.DateTimeInfo.TimeZone; missing source fails |
| Network.Switches, Network.PortGroups | Standard switches/uplinks and switch-scoped port groups/VLANs |
| Network.VMkernel, Network.PhysicalNics | VMkernel addressing/traffic flags and physical NIC configuration |
| Storage.Datastores, Storage.Hbas | Datastore capacity/filesystem and HBA configuration |
| Storage.Luns, Storage.Paths | Canonical LUNs/multipathing policy and individual path identities/preference |
| Services | Every service including disabled policies |
| AdvancedSettings | Important-setting selection or explicit custom patterns |
| Firewall.Exceptions, Firewall.Policy | Every ruleset including disabled rules, ports/protocols, allowed hosts/networks and incoming/outgoing default policy |
| Accounts.Users, Accounts.Permissions | Direct-host local users and scoped principal/role/propagation |

These 19 independent units always appear in coverage, including Skipped units. Successful empty queries are distinct from failed/unavailable queries. Each unit uses only its own relevant selection in Scope. No distributed-switch collector or exhaustive platform configuration coverage is claimed.

Operational service running state, switch port availability, physical link state, datastore free space/health, HBA status and storage path state are retained in `Observations`, excluded from configuration drift. Known enums and IP/MAC addresses are normalized. DNS order is significant. Uplinks, NTP/syslog destinations and firewall rule/allowed-address lists use explicit set comparison policies.

Advanced settings retain the version 1 important patterns. Use `-AdvancedSettingName 'Security.*','UserVars.*'` with `-IncludeAdvancedSettings` for custom selection, or `'*'` for all settings after reviewing what that wider selection exposes. Effective patterns are embedded in the snapshot and comparison scope. `-IncludeAll` enables this collector with its default important patterns; it does not silently broaden its setting selection. Password-quality, account lock and memory salting severity rules select **entity name plus `/Value`**, with priority over the general Medium Value rule. Firewall/account additions and removals are High.

```powershell
# Offline operations, including literal paths containing brackets.
$baseline = Get-ESXiSnapshot -Path 'baseline [accepted].json'
$drift = Compare-ESXiSnapshot -BaselinePath 'baseline [accepted].json' -CurrentPath 'current.json'
# For diagnosis, explicitly compare only matching successful units.
$partial = Compare-ESXiSnapshot -BaselineSnapshot $baseline -CurrentSnapshot $current -AllowPartial
$partial.IsComplete # False if requested scope or any applicable unit is excluded
$partial.Coverage
```

Strict comparison is the default. Different targets, legacy snapshots, malformed data, changed scope/rules, and incomplete requested units cannot silently produce a clean result. `-AllowPartial` compares only matching successful units and marks exclusions; zero observed events with `IsComplete=$false` is inconclusive. Existing `-SeverityConfigPath` explicitly overrides the embedded policy for both snapshots. Rule files use declarative Core schema 1.0 selectors and JSON Pointer paths; legacy `{Rules:[{EntityType,Property,Severity}]}` files remain accepted with limited selectors.

Version 2 returns plain `DriftDetect.Snapshot` objects. `HostName`, `HostVersion` and `HostBuild` aliases remain available. Replace `[ESXiSnapshot]::Import($path)` with `Get-ESXiSnapshot -Path $path`, `.Export($path)` with `Export-DDSnapshot -Snapshot $snapshot -Path $path`, and direct class construction/engines with the public commands. The old `Classes/` source remains in the repository as unused legacy material and is no longer loaded. Version 1 snapshots can be inspected and reported but **every legacy comparison is rejected**; capture a schema 2 baseline. `TotalChanges` now counts all events, including entity additions and removals; `TotalModified` counts property events. Compatibility `Changes`, `NewEntities`, and `DeletedEntities` are views of `Events` and must not be added to it for counting.

Run tests with Pester 5 and Core discoverable on `PSModulePath`:

```powershell
Invoke-Pester -Path .\Tests -Output Detailed
```

Tests use synthetic provider fixtures and never connect to infrastructure. Windows PowerShell 5.1 is not a supported client. Automated verification on PowerShell 7.6.9 does not establish minimum-client 7.0 or live ESXi compatibility; test capture read-only against your host before adopting a baseline.
