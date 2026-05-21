# Changelog

All notable changes to Spellbook will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [Unreleased]

### Added
- `inv` — short alias for `invoke` (e.g. `inv add-tap`, `inv 3`)
- `invoke` dispatcher now accepts no-hyphen aliases for all commands — e.g. `invoke addtap`, `invoke newuser`, `invoke offboarduser`. Aliases are generated automatically at runtime by stripping hyphens, so new commands get aliases for free. Menu display and numeric shortcuts are unaffected.

### Changed
- `check-mailflow` renamed to `get-mailflow` — consistent `get-` verb prefix with the rest of the module
- `add-mailboxperms` renamed to `set-mailboxperms` — `set-` better reflects granting/updating delegate permissions

### Fixed
- `add-tap` — added missing `User.Read.All` scope to `Connect-MgGraph` call. The script calls `Get-MgUser` to resolve the UPN, which requires this scope; without it the lookup silently returned nothing and the TAP creation failed.

---

## [1.5.0] — 2026-05-19

### Added
- `get-archive` — shows in-place archive status, size, item count, and quota for a mailbox. No-ops cleanly when archive is not enabled.
- `get-forwarding` — shows SMTP and internal forwarding configuration for a mailbox, including whether a local copy is kept.
- `kill-exchange` — disconnects the current Exchange Online session. No-ops cleanly when no session is active (mirrors `kill-graph` pattern).
- `get-connections` — shows current Exchange Online and Microsoft Graph session state (user, tenant, token expiry / scopes) in a single view.

### Changed
- `Spellbook.psd1` — `ModuleVersion` bumped to `1.5.0`.

---

## [1.3.0] — 2026-05-13

### Added
- `get-conditionalaccess` — Retrieves all Conditional Access policies with state (enabled/disabled/report-only), user and group targets, app targets, and grant controls (MFA required, compliant device, etc.). Auto-exports to CSV. Requires `Policy.Read.All`.
- `get-licencegaps` — Licence cost audit: finds users with licences assigned but no interactive sign-in within a configurable threshold (default 90 days). Uses `signInActivity.lastSignInDateTime` from the Graph Users endpoint rather than mailbox activity, which avoids false positives from received mail. Never-signed-in users sort to the top. Auto-exports to CSV. Requires `User.Read.All`, `AuditLog.Read.All`.
- `new-sharedmailbox` — Creates a shared mailbox via Exchange Online, then optionally loops through delegate UPNs to grant Full Access and Send As. Follows the same prompt-then-confirm flow as `new-user`.
- `get-devicereport` — Pulls all Intune-managed devices with OS, compliance state, management state, and last sync date. Flags devices not synced in 30+ days and non-compliant devices (suppresses `unknown` compliance as non-actionable). Flagged devices sort to the top of the output. Auto-exports to CSV. Requires `DeviceManagementManagedDevices.Read.All`.

### Changed
- `Spellbook.psd1` — `ModuleVersion` bumped to `1.3.0`.
- `Spellbook.psd1` — `RequiredModules` expanded with `Microsoft.Graph.DeviceManagement` (needed by `get-devicereport`).

---

## [1.2.0] — 2026-05-13

### Changed
- Project renamed from `StevesScriptorium` to `Spellbook`. PSGallery listing is a new entry (`Spellbook`); the old `StevesScriptorium` listing is retired.
- CLI dispatcher renamed from `toolkit` to `invoke`. Usage: `invoke <command>` or `invoke <number>`.
- `invoke` menu now displays the Arthur C. Clarke quote beneath the header.
- `Publish.ps1` staging fix: module is now copied to a correctly-named temp directory before `Publish-Module` is called, so publishing works regardless of what the repo's working directory is named on disk.

### Added
- `.codex/` — plain-language explanations for all 26 `Public/` scripts and session summaries for each development day, generated from git history via Codex.

---

## [1.1.0] — 2026-05-11

### Added
- `kill-graph` — disconnects the current Microsoft Graph session
- `set-forwarding` — enable SMTP forwarding on a mailbox with copy-in-place option
- `remove-forwarding` — remove SMTP forwarding from a mailbox
- `get-mailboxperms` — shows Full Access and Send As delegates on a mailbox (filters NT AUTHORITY / S-1-5 noise)
- `get-userperms` — shows all mailboxes a given user has delegated access to (iterates tenant)
- `add-mailboxperms` — grants Full Access (with auto-map choice) and/or Send As on a mailbox
- `get-smsmfa` — lists SMS/phone MFA methods for a user
- `set-smsmfa` — updates the phone number on an existing SMS MFA method
- `add-smsmfa` — registers a new SMS/phone MFA method (mobile, alternateMobile, or office)
- `add-tap` — creates a Temporary Access Pass (default: one-time, 60 min; operator can override)
- `remove-taps` — removes all active TAPs for a user
- `disable-autocalevents` — disables Outlook "Events from email" across the tenant. Forces the operator to type the tenant primary domain before running. Logs every mailbox to a CSV on the Desktop.
- `inherit-permissions` — resets NTFS folder ACL to inherit from parent, with optional removal of explicit ACEs. Pure local; no Graph/Exchange.
- `tests/Module.Tests.ps1` — Pester smoke tests covering manifest validation, `FunctionsToExport`/`Public/` sync, parse-checks of every public script, and CHANGELOG sanity.
- `.github/workflows/verify.yml` — runs Pester + PSScriptAnalyzer on every push to `main` and every PR. Errors fail the build; warnings are advisory.
- ADR-0019, ADR-0020, ADR-0021, ADR-0022 — design records for the V2 mailflow migration, defensive Graph disconnect, per-iteration failure logging pattern, and explicit Graph submodule pinning.

### Changed
- `new-user` now accepts the initial password as a `SecureString` and no longer echoes it in the summary line. The password is converted to plain only at the `New-MgUser` call site and cleared in a `finally` block.
- `offboard-user` records the generated reset password in the CSV log (the comment claimed this but the value was never written). The log file lands on the offboarder's Desktop.
- `check-mailflow` migrated from deprecated `Get-MessageTrace` / `Get-MessageTraceDetail` to `Get-MessageTraceV2` / `Get-MessageTraceDetailV2`. Output schema preserved; pagination is now explicit (cursor on `-StartingRecipientAddress`); drill-down resolves the recipient from the matching row since V2 requires it. See ADR-0019.
- `RequiredModules` in the manifest expanded to declare every Graph submodule actually used at runtime: `Microsoft.Graph.Authentication`, `Microsoft.Graph.Users.Actions`, `Microsoft.Graph.Groups`, `Microsoft.Graph.Identity.DirectoryManagement`, `Microsoft.Graph.Reports` (in addition to the previously-declared `Microsoft.Graph.Users` and `Microsoft.Graph.Identity.SignIns`). Previously, install-from-PSGallery left users with a partial install. See ADR-0022.
- `ExchangeOnlineManagement` minimum version bumped to 3.7.0 to guarantee the V2 message-trace cmdlets are present.
- CI workflow (`.github/workflows/verify.yml`) now installs every module declared in the manifest's `RequiredModules` explicitly, rather than relying on the GitHub-hosted runner image shipping the Microsoft.Graph.* submodules pre-installed.
- README "Planned" section trimmed to reflect what's actually still planned (`reset-password`, `get-archive`, `enable-autoexpand`); previously listed several already-shipped commands and was duplicated three times.
- README permissions table corrected and expanded — added missing scopes (`Group.ReadWrite.All`, `Group.Read.All`, `Organization.Read.All`, `RoleManagement.Read.Directory`), credited additional consumers on existing rows, removed the stale `reset-password` reference.

### Fixed
- `offboard-user` no longer depends on `[System.Web.Security.Membership]::GeneratePassword`, which is unavailable on PowerShell 7. Replaced with a portable `RandomNumberGenerator`-based generator that guarantees one of each M365 complexity class (upper, lower, digit, symbol). See ADR-0017.
- All `Public/*.ps1` scripts now use `return` instead of `exit` for early termination. `exit` from a dot-sourced script terminated the user's PowerShell session, not just the script. Affected: `get-guestaudit`, `get-groupmembers`, `get-userreport`, `offboard-user`, `set-userlicence`. See ADR-0016.
- `offboard-user` group/role/MFA cleanup steps now log per-item failures as their own CSV rows (with status `FAILED`) rather than silently swallowing exceptions and reporting the attempted count as the "OK" count. Audit-log integrity restored. See ADR-0021.
- `kill-graph` now no-ops cleanly when no Microsoft Graph session is active, rather than throwing a confusing red exception. See ADR-0020.
- `get-allusers` no longer aborts on accounts with a null `UserPrincipalName` (orphan / partially-provisioned). These now appear in the export with note `"No UPN — orphan account"`.
- `invoke-profile.ps1` ghost commands removed (`reset-password`, `rename-pc`, `get-licensedusers`, `get-archive`, `enable-autoexpand`) — they had no matching `.ps1` and produced "Script not found" when invoked.

---

## [1.0.1] — 2026-05-08

### Fixed
- `invoke` command lookup now uses `.Contains()` instead of `.ContainsKey()` on `[ordered]` hashtables — fixes `InvalidOperation` crash when running any named command
- `LicenseUri` and `ProjectUri` in the manifest pointed at `Big-Bronson/Spellbook` (404). Corrected to `Big-Bronson/Spellbook`. Same fix applied to `README.md` clone URL and `Install.ps1` usage example.
- `Publish.ps1` string interpolation fixes (GUID error path, API key fallback)

### Changed
- `FunctionsToExport` trimmed to match the scripts that actually ship in `Public/`. The 1.0.0 manifest declared 30 functions; 17 had no matching script. Removed entries: `reset-password`, `get-userperms`, `get-mailboxperms`, `add-mailboxperms`, `set-forwarding`, `remove-forwarding`, `get-archive`, `enable-autoexpand`, `disable-autocalevents`, `get-smsmfa`, `set-smsmfa`, `add-smsmfa`, `add-tap`, `remove-taps`, `inherit-permissions`, `kill-graph`. These are tracked in the README "Planned" section and will return as they ship.
- `invoke` menu trimmed to match. Empty sections (MFA & Auth, System) removed; `get-licensedusers` ghost entry removed.
- `Publish.ps1` rewritten with pre-flight checks: manifest validation, parse-check of all Public scripts, `FunctionsToExport` sync check, clean git tree enforcement, CHANGELOG presence check, API key read from Windows Credential Manager (with `$env:PSGALLERY_API_KEY` fallback).
- README publishing instructions updated to match the new `Publish.ps1` interface (no `-ApiKey` parameter).

### Added
- `CLAUDE.md` — shared project context for Claude Code sessions
- `get-inactiveusers` command

---

## [1.0.0] — 2026-04-01

### Added
- Initial release
- `invoke` CLI dispatcher with numeric and named command lookup
- User lifecycle: `new-user`, `offboard-user`, `reset-password`, `set-userlicence`
- User reports: `get-userreport`, `get-allusers`, `get-mfaaudit`, `get-guestaudit`, `get-signinlogs`
- Tenant health: `get-tenantreport`
- Mailbox & Exchange: `get-userperms`, `get-mailboxperms`, `add-mailboxperms`, `set-forwarding`, `remove-forwarding`, `get-archive`, `enable-autoexpand`, `disable-autocalevents`, `check-mailflow`, `get-sharedmailboxaudit`
- Groups: `get-groupmembers`
- MFA & Auth: `get-smsmfa`, `set-smsmfa`, `add-smsmfa`, `add-tap`, `remove-taps`
- System: `inherit-permissions`, `kill-graph`
