# Changelog

All notable changes to StevesScriptorium will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [Unreleased]

### Added
- `disable-autocalevents` — disables Outlook "Events from email" across the tenant. Forces the operator to type the tenant primary domain before running. Logs every mailbox to a CSV on the Desktop.
- `inherit-permissions` — resets NTFS folder ACL to inherit from parent, with optional removal of explicit ACEs. Pure local; no Graph/Exchange.

### Changed
### Fixed

---

## [1.0.1] — 2026-05-08

### Fixed
- `toolkit` command lookup now uses `.Contains()` instead of `.ContainsKey()` on `[ordered]` hashtables — fixes `InvalidOperation` crash when running any named command
- `LicenseUri` and `ProjectUri` in the manifest pointed at `Big-Bronson/StevesScriptorium` (404). Corrected to `Big-Bronson/Steves-Scriptorium`. Same fix applied to `README.md` clone URL and `Install.ps1` usage example.
- `Publish.ps1` string interpolation fixes (GUID error path, API key fallback)

### Changed
- `FunctionsToExport` trimmed to match the scripts that actually ship in `Public/`. The 1.0.0 manifest declared 30 functions; 17 had no matching script. Removed entries: `reset-password`, `get-userperms`, `get-mailboxperms`, `add-mailboxperms`, `set-forwarding`, `remove-forwarding`, `get-archive`, `enable-autoexpand`, `disable-autocalevents`, `get-smsmfa`, `set-smsmfa`, `add-smsmfa`, `add-tap`, `remove-taps`, `inherit-permissions`, `kill-graph`. These are tracked in the README "Planned" section and will return as they ship.
- `toolkit` menu trimmed to match. Empty sections (MFA & Auth, System) removed; `get-licensedusers` ghost entry removed.
- `Publish.ps1` rewritten with pre-flight checks: manifest validation, parse-check of all Public scripts, `FunctionsToExport` sync check, clean git tree enforcement, CHANGELOG presence check, API key read from Windows Credential Manager (with `$env:PSGALLERY_API_KEY` fallback).
- README publishing instructions updated to match the new `Publish.ps1` interface (no `-ApiKey` parameter).

### Added
- `CLAUDE.md` — shared project context for Claude Code sessions
- `get-inactiveusers` command

---

## [1.0.0] — 2026-04-01

### Added
- Initial release
- `toolkit` CLI dispatcher with numeric and named command lookup
- User lifecycle: `new-user`, `offboard-user`, `reset-password`, `set-userlicence`
- User reports: `get-userreport`, `get-allusers`, `get-mfaaudit`, `get-guestaudit`, `get-signinlogs`
- Tenant health: `get-tenantreport`
- Mailbox & Exchange: `get-userperms`, `get-mailboxperms`, `add-mailboxperms`, `set-forwarding`, `remove-forwarding`, `get-archive`, `enable-autoexpand`, `disable-autocalevents`, `check-mailflow`, `get-sharedmailboxaudit`
- Groups: `get-groupmembers`
- MFA & Auth: `get-smsmfa`, `set-smsmfa`, `add-smsmfa`, `add-tap`, `remove-taps`
- System: `inherit-permissions`, `kill-graph`
