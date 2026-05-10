# ADR-0022: Declare every used Microsoft Graph submodule explicitly in `RequiredModules`

**Date:** 2026-05-11
**Status:** Accepted
**Decider:** Steve Vella

---

## Context

The Microsoft Graph PowerShell SDK is split across many submodules — `Microsoft.Graph.Authentication`, `Microsoft.Graph.Users`, `Microsoft.Graph.Groups`, `Microsoft.Graph.Identity.SignIns`, `Microsoft.Graph.Identity.DirectoryManagement`, `Microsoft.Graph.Reports`, etc. — plus a meta-package `Microsoft.Graph` that takes a dependency on every individual submodule. Each cmdlet lives in exactly one submodule; using a cmdlet from a submodule that is not installed surfaces as `The term 'Get-MgFoo' is not recognised...`.

The 1.0.x manifest declared only three modules in `RequiredModules`:

- `ExchangeOnlineManagement` (≥ 3.0.0)
- `Microsoft.Graph.Users` (≥ 2.0.0)
- `Microsoft.Graph.Identity.SignIns` (≥ 2.0.0)

But the shipped scripts collectively use cmdlets from at least seven Graph submodules (in addition to ExchangeOnlineManagement). Specifically:

- `Microsoft.Graph.Authentication` — `Connect-MgGraph`, `Get-MgContext`, `Disconnect-MgGraph`. Every script that touches Graph needs this. (It is a transitive dependency of every other Graph submodule, so it usually gets installed anyway, but relying on transitive resolution is brittle.)
- `Microsoft.Graph.Groups` — `Get-MgGroup`, `Get-MgGroupMember`, `New-MgGroupMember`, `Remove-MgGroupMemberByRef`. Used by `new-user`, `get-groupmembers`, `offboard-user`.
- `Microsoft.Graph.Users.Actions` — `Set-MgUserLicense`, `Revoke-MgUserSignInSession`. Both moved out of `Microsoft.Graph.Users` into `.Users.Actions` in SDK 2.x. Used by `set-userlicence`, `offboard-user`.
- `Microsoft.Graph.Identity.DirectoryManagement` — `Get-MgOrganization`, `Get-MgSubscribedSku`, `Get-MgDirectoryRole`, `Get-MgDirectoryRoleMember`, `Remove-MgDirectoryRoleMemberByRef`. Used by `disable-autocalevents`, `get-tenantreport`, `get-allusers`, `set-userlicence`, `offboard-user`, `get-userreport`.
- `Microsoft.Graph.Reports` — `Get-MgAuditLogSignIn`, `Get-MgServiceAnnouncementIssue`. Used by `get-signinlogs`, `get-tenantreport`.

Operators installing the module from PS Gallery via `Install-Module StevesScriptorium` would get only the three declared submodules (plus their transitive `Microsoft.Graph.Authentication`). On first run of any script that called a cmdlet from an undeclared submodule, they'd hit "command not recognised". The error is unhelpful — there's no hint that the resolution is to install one more submodule, and no obvious mapping from cmdlet to submodule for someone who isn't already familiar with the SDK split.

The same gap also affected CI: `Test-ModuleManifest` (called inside the Pester suite) imports `RequiredModules`, and the GitHub-hosted runner happened to ship with a working set of Graph submodules pre-installed. The build worked — but it would silently break the next time Microsoft refreshed the runner image. ADR-0014's "static-only CI" promise depends on the manifest faithfully declaring every dependency.

---

## Decision

The `RequiredModules` block in `StevesScriptorium.psd1` now declares every Graph submodule used anywhere in `Public/*.ps1`:

```
ExchangeOnlineManagement                       (>= 3.7.0)
Microsoft.Graph.Authentication                 (>= 2.0.0)
Microsoft.Graph.Users                          (>= 2.0.0)
Microsoft.Graph.Users.Actions                  (>= 2.0.0)
Microsoft.Graph.Groups                         (>= 2.0.0)
Microsoft.Graph.Identity.SignIns               (>= 2.0.0)
Microsoft.Graph.Identity.DirectoryManagement   (>= 2.0.0)
Microsoft.Graph.Reports                        (>= 2.0.0)
```

The minimum-version pin (≥ 2.0.0) is the same one chosen in ADR-0008; this ADR extends that decision's scope to additional submodules without changing the version-pinning strategy.

We do **not** depend on the meta-module `Microsoft.Graph`.

The `.github/workflows/verify.yml` test job installs every module on the list explicitly (rather than relying on the runner image), per the change documented in the same `[1.1.0]` CHANGELOG entry.

---

## Rationale

**Why explicit submodules and not the `Microsoft.Graph` meta-module?**

The meta-module pulls in **every** Graph submodule — currently around 40 of them. Most of those won't ever be used by this toolkit. The cost of taking the meta-module is:

- **Install size and time.** Installing the meta-module takes minutes and several hundred MB on a fresh PowerShell host; installing the seven submodules we actually use takes seconds and tens of MB. Engineers run `Install-Module StevesScriptorium` from a fresh shell more often than you'd expect (new laptop, jump box, build agent), and the difference is operator-visible.
- **Surface area for security advisories and version skew.** A vulnerability in any submodule of the meta-package becomes a problem we have to triage, even when we don't use the affected cmdlets.
- **Granularity of version pinning.** Pinning the meta-module pins every submodule together. We want to bump (say) `Microsoft.Graph.Reports` independently when a service-announcement cmdlet shape changes, without simultaneously taking on a new `Microsoft.Graph.DeviceManagement.Beta` version.

**Why not pin upper bounds?**

Same reasoning as ADR-0008: the SDK is on a steady release cadence and we want to allow newer versions automatically. Lockstep upper bounds would create an upgrade burden disproportionate to the risk. If a future SDK release introduces a breaking change that affects this toolkit, we add an upper bound at that point and document it in a follow-up ADR.

**Why declare `Microsoft.Graph.Authentication` explicitly when it's a transitive dependency of every other Graph submodule?**

Belt-and-braces. Transitive resolution works in practice but is not contractual — if any of our direct dependencies ever changes its dependency declaration, we'd lose `.Authentication` and every Graph script would break. Declaring it directly insulates us from that risk. The cost is one extra line in the manifest.

**Why bump `ExchangeOnlineManagement` to 3.7.0 in the same ADR?**

Strictly this is from ADR-0019 (V2 message-trace migration), but the version bumps for both are landing in the same `1.1.0` release so we update both pins together. The ADR-0019 change is the load-bearing reason for 3.7.0 specifically; the explicit-submodules decision here is independent.

---

## Alternatives considered

**Take a dependency on `Microsoft.Graph` (the meta-module) for simplicity.** Discussed above. The install-time and disk-space cost on every fresh host is the dealbreaker; the pinning-granularity issue is the sealed-in dealbreaker.

**Leave the manifest understated and document the additional install steps in the README.** Asks every operator to do manual install gymnastics. Defeats the point of a PowerShell Gallery distribution. Also doesn't fix the CI fragility — `Test-ModuleManifest` still wouldn't be able to import a partially-declared manifest. Ruled out.

**Add a `Private/Ensure-GraphModules.ps1` helper that runtime-installs missing submodules.** Two problems: (1) the user may not have install rights on shared hosts; (2) hides the dependency surface from `Install-Module` and `Get-Module -ListAvailable`, which administrators legitimately use to audit what's installed where. ADR-0008 is explicit that dependencies belong in the manifest, not in runtime-fix-up code. Ruled out.

**Audit each script and remove cmdlet usage from underclared submodules.** Would require dropping or reimplementing several useful scripts (e.g. `get-tenantreport`, `set-userlicence`). Massive scope reduction for a problem that has a much cheaper fix. Ruled out.

---

## Consequences

- Operators installing the module from PS Gallery now get a working install on first try. No mystery "cmdlet not recognised" errors on first run.
- Install size on a clean host is moderately larger than the 1.0.x baseline (seven additional submodules) but very much smaller than taking the meta-module. The trade-off is intentional and documented here.
- CI no longer depends on the runner image shipping any specific set of Graph submodules. The build is reproducible across runner-image refreshes.
- When a new script introduces a cmdlet from a Graph submodule not on the list, the corresponding line must be added here. Catching this early belongs in code review — there is no automatic check that fails the Pester suite when an undeclared cmdlet is used. (A future ADR may add such a static check, but it would need a curated cmdlet→submodule lookup table.)
- This ADR partially supersedes ADR-0008's narrower scope, but does not contradict it: ADR-0008 establishes the *principle* of pinning minimum versions, this ADR extends the *list* of pinned submodules.

---

## Cmdlet → submodule mapping (reference)

For each declared submodule, the cmdlets across `Public/*.ps1` that drive the requirement. Use this when judging whether a future change can safely remove a `RequiredModules` entry.

### `ExchangeOnlineManagement` (≥ 3.7.0)

`Connect-ExchangeOnline`, `Get-ConnectionInformation`, `Get-Mailbox`, `Set-Mailbox`, `Get-Recipient`, `Get-MailboxStatistics`, `Get-MailboxPermission`, `Add-MailboxPermission`, `Get-RecipientPermission`, `Add-RecipientPermission`, `Set-MailboxAutoReplyConfiguration`, `Get-MailboxCalendarConfiguration`, `Set-MailboxCalendarConfiguration`, `Remove-CalendarEvents`, `Get-MessageTraceV2`, `Get-MessageTraceDetailV2`. The 3.7.0 floor specifically is to guarantee the V2 message-trace cmdlets per ADR-0019.

### `Microsoft.Graph.Authentication` (≥ 2.0.0)

`Connect-MgGraph`, `Get-MgContext`, `Disconnect-MgGraph`. Required by every script that touches Graph; also a transitive dependency of every other Microsoft.Graph.* submodule. Declared explicitly to insulate us from changes in transitive resolution.

### `Microsoft.Graph.Users` (≥ 2.0.0)

`Get-MgUser`, `New-MgUser`, `Update-MgUser`, `Get-MgUserMemberOf`. Used by `new-user`, `offboard-user`, `set-userlicence`, `get-allusers`, `get-userreport`, `get-mfaaudit`, `get-guestaudit`, `get-inactiveusers`, `get-tenantreport`, and the SMS/MFA/TAP family.

### `Microsoft.Graph.Users.Actions` (≥ 2.0.0)

`Set-MgUserLicense` (used by `set-userlicence`, `offboard-user`), `Revoke-MgUserSignInSession` (used by `offboard-user`). Both moved here from `.Users` in SDK 2.x. Removing this entry breaks `set-userlicence` entirely and breaks step 3 of `offboard-user`.

### `Microsoft.Graph.Groups` (≥ 2.0.0)

`Get-MgGroup` (used by `new-user`, `get-groupmembers`), `Get-MgGroupMember` (used by `get-groupmembers`), `New-MgGroupMember` (used by `new-user`), `Remove-MgGroupMemberByRef` (used by `offboard-user` step 4). No other submodule covers Group cmdlets — removing this breaks group-related operations across three scripts.

### `Microsoft.Graph.Identity.SignIns` (≥ 2.0.0)

`Get-MgUserAuthenticationMethod`, `Get-MgUserAuthenticationPhoneMethod`, `New-MgUserAuthenticationPhoneMethod`, `Update-MgUserAuthenticationPhoneMethod`, `Remove-MgUserAuthenticationPhoneMethod`, `Get-MgUserAuthenticationTemporaryAccessPassMethod`, `New-MgUserAuthenticationTemporaryAccessPassMethod`, `Remove-MgUserAuthenticationTemporaryAccessPassMethod`. Used by the entire SMS/MFA/TAP family (`add/set/get-smsmfa`, `add-tap`, `remove-taps`), plus `get-mfaaudit`, `get-userreport`, `get-tenantreport`, and `offboard-user` step 6.

### `Microsoft.Graph.Identity.DirectoryManagement` (≥ 2.0.0)

`Get-MgOrganization` (used by `disable-autocalevents`, `get-tenantreport`), `Get-MgSubscribedSku` (used by `get-allusers`, `set-userlicence`, `get-userreport`, `get-tenantreport`, `get-sharedmailboxaudit`), `Get-MgDirectoryRole` + `Get-MgDirectoryRoleMember` + `Remove-MgDirectoryRoleMemberByRef` (used by `get-tenantreport` and `offboard-user` step 5).

### `Microsoft.Graph.Reports` (≥ 2.0.0)

`Get-MgAuditLogSignIn` (used by `get-signinlogs`), `Get-MgServiceAnnouncementIssue` (used by `get-tenantreport` service-health section). The service-announcement cmdlet has historically lived in different submodules across SDK versions; if a future SDK split moves it out of `.Reports`, update this entry and add a paragraph to this ADR.

---

## Related files

- `StevesScriptorium.psd1` — `RequiredModules` block (keep the inline crib comments in sync with this ADR)
- `.github/workflows/verify.yml` — test job installs the same list explicitly (the `$modules` array must stay in sync with the manifest)
- `CHANGELOG.md` — entry under `[1.1.0]` → `### Changed`
- `README.md` — module-requirements list (kept in step with the manifest, but the README is allowed to be slightly looser since it's prose)
- ADR-0008 — minimum-version pinning in `RequiredModules` (the principle this ADR extends)
- ADR-0014 — static-only CI tests (the constraint that means CI must be able to import the manifest with no live Graph credentials)
- ADR-0019 — Get-MessageTraceV2 migration (drives the EXO ≥ 3.7.0 floor)
