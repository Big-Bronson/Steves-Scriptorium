# CLAUDE.md — Spellbook

Shared context for all Claude Code sessions in this repo. Update this file when you learn something that future Claude sessions should know.

---

## What this project is

A PowerShell module (`Spellbook`) published to the PowerShell Gallery. It's an M365 helpdesk toolkit for MSP engineers — CLI-driven commands for user lifecycle, mailbox management, MFA, Exchange, and tenant auditing. No GUIs.

**Owners:** Steve Vella + one co-engineer. Both use Claude Code.

**GitHub:** `Big-Bronson/Spellbook`

---

## Architecture

```
Spellbook/
├── Spellbook.psm1   # Module root — loads Public/, exposes invoke()
├── Spellbook.psd1   # Manifest — version, PS Gallery metadata, FunctionsToExport
├── invoke-profile.ps1      # Standalone profile version of invoke() (separate from psm1)
├── Public/                  # One .ps1 per command — each is a self-contained script
├── Install.ps1              # Bootstrap installer (clone → run this)
└── Publish.ps1              # PS Gallery publisher
```

The `invoke()` function in `Spellbook.psm1` is the CLI dispatcher. It holds an `[ordered]` hashtable of all command names → descriptions, and a separate `$sectionHeaders` hashtable for display grouping.

---

## How to add a new command

1. Create `Public/your-command-name.ps1`
2. Add an entry to the `$commands` ordered hashtable in `Spellbook.psm1`
3. Add the same entry to `invoke-profile.ps1` if it mirrors the same command set
4. If the command opens a new section in `invoke`, add it to `$sectionHeaders` (psm1) and `$sectionMap` (invoke-profile.ps1)
5. Add to `FunctionsToExport` in `Spellbook.psd1`
6. Add a row to the README command table
7. Bump `ModuleVersion` in the `.psd1`

---

## Known gotchas

### OrderedDictionary — use `.Contains()` not `.ContainsKey()`

`[ordered]@{}` creates a `System.Collections.Specialized.OrderedDictionary`, not a regular hashtable. It does **not** have `.ContainsKey()` — use `.Contains()` instead.

```powershell
# WRONG — throws InvalidOperation on [ordered] hashtables
if ($commands.ContainsKey($key)) { ... }

# CORRECT
if ($commands.Contains($key)) { ... }
```

This has burned us before. Both `Spellbook.psm1` and `invoke-profile.ps1` were patched for this.

### Each Public script connects itself

Scripts call `Connect-MgGraph` and/or `Connect-ExchangeOnline` at the top if not already connected. They request only the scopes they need. Don't add a global connection step — keep it per-script.

### Offboard log goes to Desktop

`offboard-user.ps1` writes a timestamped CSV to `$env:USERPROFILE\Desktop`. That's intentional — engineers need it immediately accessible.

### PSGallery install — use Install-PSResource, not Install-Module

`Install-Module` hits PackageManagement/PowerShellGet locking issues on Windows even after a session restart. Use the newer command instead:

```powershell
# First-time install or reinstall
Install-PSResource -Name Spellbook -Reinstall

# Trust PSGallery to avoid per-module confirmation prompts
Set-PSResourceRepository -Name PSGallery -Trusted
```

`Update-Module` also fails if the module was not originally installed via `Install-Module`. `Install-PSResource -Reinstall` handles both cases.

### Import is slow — this is expected

`Import-Module Spellbook` loads all eight Graph submodules plus ExchangeOnlineManagement at startup due to `RequiredModules` in the manifest. This is by design (ADR-0008) — dependencies surface at import time rather than as runtime errors. Nothing to fix.

---

## Coding conventions

- No comments explaining what the code does — only why, if it's non-obvious
- `Write-Host` with `-ForegroundColor` for all user-facing output; Green = OK, Red = error, Yellow = warning/prompt, DarkGray = informational
- Log entries use `[OK]`, `[FAILED]`, `[SKIPPED]` status strings (see `offboard-user.ps1` for the pattern)
- Error handling: wrap individual steps in `try/catch` and log the failure; don't bail the whole script on one step failing
- PowerShell 5.1 compatibility required (PS 7 preferred, but don't use PS7-only syntax)

---

## Collaboration notes

- Use GitHub branches + PRs for all changes
- This CLAUDE.md is the shared briefing — update it when you discover something future Claude sessions should know
- If you make a decision that isn't obvious from reading the code, note it here

## Architecture Decision Records

Significant design and implementation decisions are documented as ADRs in `docs/decisions/`. Read the existing ADRs before making structural changes — they capture the "why" behind patterns that might otherwise look arbitrary.

**When to write a new ADR:** any time a session introduces a new pattern, changes an existing one, or makes a non-obvious trade-off. Candidates include: new execution patterns, compatibility constraints, safety conventions, CI/publish pipeline changes, or anything where "why not the obvious alternative?" has a non-trivial answer.

**At the end of any session that includes significant commits**, scan for decisions that lack an ADR and flag them to the user — even if you don't write them immediately. The goal is that the "why" is never lost.
