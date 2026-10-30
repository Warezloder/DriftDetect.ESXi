---
title: DriftDetect.ESXi 2.0 implementation report
date: 2026-10-29
status: implemented-awaiting-combined-review
branch: feat/shared-core
---

# ESXi adapter implementation

Implemented the approved shared-core plan, task 3, exclusively in the DriftDetect.ESXi repository. No Core or Windows files were changed by this worker. No live connections, infrastructure mutations, commits, pushes, file deletions, or vault/session records were created.

## Delivered

- Module 2.0.0 requires Core 1.x, exports the four original commands plus Export-ESXiConfigurationReport, and loads no legacy Classes files. Classes remain untouched as unused historical source.
- New-ESXiSnapshot adds IncludeAll, Strict, optional Server and custom AdvancedSettingName selection. VMHost is a plain object parameter so importing offline commands does not require PowerCLI type resolution.
- Exact VMHost.Uid ownership resolves the connected VIServer among defaults; optional Server supports non-default connections and must match. All query commands take the supplied VMHost/Entity and owning Server where their installed API supports it. Get-ScsiLunPath takes the scoped ScsiLun object because it has no Server parameter. No connection is opened or disconnected.
- Capture validates a real nonzero/non-placeholder hardware UUID before any collection. Missing association or identity aborts. Capability checks occur at capture. Unsupported capabilities give installation instructions; query failures become sanitized Failed units rather than empty inventory.
- Nineteen explicit independent units cover System.Host/Network/Ntp/Syslog/TimeZone, Network.Switches/PortGroups/VMkernel/PhysicalNics, Storage.Datastores/Hbas/Luns/Paths, Services, AdvancedSettings, Firewall.Exceptions/Policy, Accounts.Users/Permissions. Optional omissions remain Skipped records; empty successful units remain Success with EntityCount 0. Strict rejects incomplete requested units.
- Timezone comes from scoped HostDateTimeSystem.DateTimeInfo.TimeZone. Firewall rules come from scoped HostFirewallSystem.FirewallInfo.Ruleset, including disabled rules, ports/protocols and AllowedHosts.AllIp/IpAddress/IpNetwork. Default incoming/outgoing policy is collected separately.
- Stable volume URLs/provider IDs, LUN canonical names, MAC identities, per-LUN path identities and switch-qualified port group IDs avoid name collisions. Known enum and IP/MAC normalization is explicit.
- Runtime service state, datastore free space/health, available switch ports, link state, HBA and path state are Observations; configuration policies and multipathing remain Properties. Raw LicenseKey is excluded with explicit CollectionProfile.ExcludedFields coverage and README documentation.
- Declarative default rules embed selection and policy. DNS is ordered; uplinks and relevant firewall/NTP/syslog lists are sets. Password-quality/account-lock/salting rules use entity name plus /Value with priority 10. Account/firewall entity additions/removals are High. Default policy modifications remain Critical.
- Thin Core wrappers implement literal-path JSON import/compare, explicit severity overrides, AllowPartial and both shared report exports. Embedded policy is used by default. Schema 1 imports are inspectable and all legacy comparisons are rejected.
- README documents dependencies, coverage, connection ownership, important-setting selection, changed counts, plain-object/class migration, partial-result interpretation and validation limits.

## Verification evidence

PowerShell 7.6.9 and Pester 5.7.1, 2026-10-29:

```powershell
$env:PSModulePath = 'C:\Tools\Repositories\DriftDetect;' + $env:PSModulePath
Import-Module Pester -MinimumVersion 5.0
$result = Invoke-Pester -Path '.\DriftDetect.ESXi\Tests' -Output Detailed -PassThru
```

**44 tests passed, 0 failed, 0 skipped, 0 inconclusive**, latest complete run 21.21 seconds. All collection tests use synthetic objects and mocked provider functions; no infrastructure access occurs.

TDD evidence: the initial suite found 12 failures in version 1 behavior (missing new interface, plain-object type binding and Core APIs). Added UUID/address tests first failed on placeholder identity acceptance and noncanonical IPv6/MAC output, then passed after fixes. Default report-title forwarding tests first failed twice, then passed after explicitly forwarding provider titles. Strict missing-capability test first failed because its exception omitted the install instruction, then passed after adding the sanitized unit reason.

Coverage includes multi-server account/network scoping; connection/UUID failures; all 18 independently queried unit failures; success-empty/skipped distinction; failure text sanitization; Strict/IncludeAll; actual timezone and missing-timezone failure; disabled firewall/allowed networks; advanced severity and custom selection; matching shared scopes under AllowPartial; path enumeration failures and observations; DNS priority drift; runtime-state exclusion; unavailable-command instructions; stable datastore and switch-qualified port group identity; offline literal-path roundtrip/legacy rejection; object/path/pipeline report forwarding and default/custom titles.

Additional fresh-process checks:

- Test-ModuleManifest succeeds: DriftDetect.ESXi 2.0.0 with five exports.
- Import-Module DriftDetect.ESXi loads **zero VMware/VCF modules and zero PSWriteHTML modules**.
- PowerShell parser reports **zero errors** across Public, Private, Collectors and Tests.
- git diff --check exits 0. Git prints only existing LF-to-CRLF working-copy conversion notices.
- git branch --show-current is feat/shared-core.
- Installed PowerCLI 13.4.0 / VCF.PowerCLI 9.0 local interface inspection confirms VMHost UID/ExtensionData fields, account Server-only scope, Get-ScsiLunPath parameter shape, VMware.Vim.HostFirewallRule/HostFirewallRuleset/HostFirewallRulesetIpList/HostFirewallRulesetIpNetwork field names and timezone source. This inspection makes no remote calls.

## Limits and integration notes

Live ESXi 8 collection and the minimum PowerShell 7.0 / PowerCLI 12 clients remain untested. Default connection resolution requires the owning connection to be a current default; callers using -NotDefault must pass it with Server. Account collection through a vCenter connection is intentionally Unsupported. The adapter covers standard switching, not distributed switches. IncludeAll enables the advanced collector with its default important patterns; callers must explicitly select '*' for wider advanced-setting exposure.

Root integration owns staging, combined module import-order testing, common HTML rendering/visual verification, independent code review and final delivery. Adapter report tests prove forwarding; they do not independently claim rendered HTML visual validation. No pending Core signature mismatch was observed in the complete suite.

## Final integration follow-up
Root completed the reviewed comparison JSON depth fix and added a deep entity-addition persistence regression. The final staged ESXi package has 45 passing tests. Combined Core/adapter/integration verification passes 142 tests. See ../review-artifacts/implementation-review-resolutions.md for final evidence and limits.


## 2026-10-30 Core compatibility follow-up
Manifest and module-scoped imports now require Core >=1.0.0 and <2.0.0. Fresh-process tests verify compatible command dispatch with both majors installed, Core 2.x preloaded, both majors preloaded, and rejection when only 2.x is available. ESXi package: 49 passed. Full staged Core/adapter/integration suite: 165 passed, zero failed/skipped. Parser/manifests and git diff checks pass. This PR also carries the previously local shared-Core migration because ESXi origin/main did not yet contain it; the upstream README banner is preserved.

