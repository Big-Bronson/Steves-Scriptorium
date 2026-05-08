# Sonnet handoff: finish the Planned commands and ship 1.0.2

> Paste this whole file into a fresh Sonnet session as the opening prompt.
> It is self-contained — no prior conversation context required.

## You are working in

`F:\Codebases\StevesScriptorium` on Windows. PowerShell module published to
PowerShell Gallery as `StevesScriptorium`. GitHub repo:
`https://github.com/Big-Bronson/Steves-Scriptorium`. **Read `CLAUDE.md` first**
— it contains the architecture, conventions, and known gotchas. The biggest
gotchas, repeated here so you don't miss them:

- `[ordered]@{}` requires `.Contains()`, never `.ContainsKey()`.
- Public scripts are dot-sourced by `toolkit()`. Use `return`, not `exit`.
- Public scripts must be self-contained: each connects its own
  `Connect-MgGraph` / `Connect-ExchangeOnline` and requests only the scopes
  it needs.
- `[System.Web.Security.Membership]` is unavailable in PowerShell 7. Don't
  use it. The portable password generator pattern is in `offboard-user.ps1`.

## State of the world

Three open PRs on GitHub, each off `main`. None merged yet:

1. [`fix/script-portability`](https://github.com/Big-Bronson/Steves-Scriptorium/pull/new/fix/script-portability)
   — fixes 8 `exit → return` sites, replaces System.Web password generator
   with a portable RNG-based one in `offboard-user.ps1`, makes `new-user.ps1`
   accept a `SecureString`, and makes the offboard log actually contain the
   generated password. Smoke-tested locally; needs one PS 7 end-to-end
   `offboard-user` run against a throwaway tenant account before publish.

2. [`feat/judgment-commands`](https://github.com/Big-Bronson/Steves-Scriptorium/pull/new/feat/judgment-commands)
   — adds `disable-autocalevents` (tenant-wide; forces typing the primary
   domain to confirm) and `inherit-permissions` (NTFS ACL reset).

3. [`ci/pester-and-actions`](https://github.com/Big-Bronson/Steves-Scriptorium/pull/new/ci/pester-and-actions)
   — Pester smoke tests + GitHub Actions workflow running Pester and
   PSScriptAnalyzer on every push and PR.

The merge order that produces the cleanest history is **fix → judgment → ci**.
All three touch `CHANGELOG.md`'s `[Unreleased]` section, so trivial conflicts
will appear; resolve by combining the bullets.

The published PS Gallery version is **1.0.0**; local manifest says **1.0.1**
but it is **not yet published**. Every change going into the next release
will tag as **1.0.2** unless the user requests a minor bump.

## Your job

Implement the remaining "Planned" commands listed in `README.md`, then cut
1.0.2. Suggested order — do them in batches of 3-4 commands per PR so
review stays sane. After each command:

1. Place it under `Public/` as `<command-name>.ps1`.
2. Add to `FunctionsToExport` in `StevesScriptorium.psd1`.
3. Add to the `$commands` ordered hashtable in `StevesScriptorium.psm1`,
   in the right section. If the section is currently empty, also add the
   first command's key to `$sectionHeaders`.
4. Add a row to the matching table in `README.md`. Remove the entry from
   the README's "Planned" section.
5. Add a bullet to `CHANGELOG.md` under `[Unreleased] → ### Added`.
6. Run `Invoke-Pester ./tests` — must be green before you commit.
7. Commit + push the branch.

Before each PR, run the cross-check inline:

```powershell
$m = Test-ModuleManifest .\StevesScriptorium.psd1
$declared = @($m.ExportedFunctions.Keys)
$actual = @(Get-ChildItem .\Public -Filter *.ps1 | Select -Expand BaseName)
$declared | Where { $_ -notin $actual -and $_ -ne 'toolkit' }  # must be empty
$actual   | Where { $_ -notin $declared }                       # must be empty
```

### Suggested PR batches

**PR A: System & basic auth** — `kill-graph` (one-liner: `Disconnect-MgGraph`),
`reset-password`. Mirror the password handling pattern from offboard-user
step 2 (use the portable generator if generating randomly; or read the
SecureString via the new-user pattern if the operator types one).

**PR B: Forwarding family** — `set-forwarding`, `remove-forwarding`. Both
are EXO `Set-Mailbox -ForwardingSMTPAddress` / `-DeliverToMailboxAndForward`.
Confirm the recipient exists before applying. Ask whether to keep a copy.

**PR C: Mailbox permissions family** — `get-userperms`, `get-mailboxperms`,
`add-mailboxperms`. `Get-MailboxPermission` and `Add-RecipientPermission` /
`Add-MailboxPermission`. Filter out NT AUTHORITY/S-1-5 noise. The
`get-userreport.ps1` mailbox-permissions block is a good template for
what to filter.

**PR D: Archive family** — `get-archive`, `enable-autoexpand`. EXO's
`Get-Mailbox -Archive` and `Enable-Mailbox -Archive` /
`Set-OrganizationConfig -AutoExpandingArchive`. Keep tenant-wide changes
behind the same domain-confirmation pattern used in `disable-autocalevents`.

**PR E: MFA family** — `get-smsmfa`, `set-smsmfa`, `add-smsmfa`, `add-tap`,
`remove-taps`. Patterns:
- SMS: `Get-MgUserAuthenticationPhoneMethod` / `New-MgUserAuthenticationPhoneMethod` /
  `Update-MgUserAuthenticationPhoneMethod` / `Remove-MgUserAuthenticationPhoneMethod`.
- TAP: `New-MgUserAuthenticationTemporaryAccessPassMethod` /
  `Get-MgUserAuthenticationTemporaryAccessPassMethod` /
  `Remove-MgUserAuthenticationTemporaryAccessPassMethod`.

The `offboard-user.ps1` "Remove MFA methods" step uses these cmdlets — copy
the shape.

### Cutting 1.0.2

Once all three open PRs and your batches have merged:

1. Smoke-test `offboard-user` end-to-end on PS 7 against a throwaway
   tenant account. The portable password generator is new code; confirm
   `Update-MgUser -PasswordProfile` accepts the generated string. (Graph
   sometimes rejects passwords that pass complexity rules but trip a
   separate dictionary check.)
2. Bump `ModuleVersion` in `StevesScriptorium.psd1` to `1.0.2`.
3. Update `ReleaseNotes` in the manifest's `PrivateData.PSData` block.
4. Cut CHANGELOG `[Unreleased]` into a dated `[1.0.2] — <today>` section,
   seed a fresh empty `[Unreleased]` above it.
5. Commit with message like `Release 1.0.2`.
6. Tag: `git tag v1.0.2 && git push origin main && git push origin v1.0.2`.
7. Run `.\Publish.ps1 -WhatIf` first, then `.\Publish.ps1`. The gallery
   takes 15-30 minutes to index.

**Caveat about Publish.ps1's CHANGELOG check:** the script throws if
`[Unreleased]` is empty. Once you've cut 1.0.2 the `[Unreleased]` is empty
by design, so the check fires spuriously. For 1.0.2 itself this isn't an
issue (you're publishing the dated section). For future cuts, expect to
add a single placeholder bullet under `[Unreleased]` before publishing.
This is a known minor flaw worth fixing separately.

## Things to NOT do

- Don't add scripts to `toolkit-profile.ps1`. That's a standalone snippet
  for users who don't install the module and isn't part of the package.
- Don't add new dependencies in `RequiredModules` unless absolutely needed.
  The current six are enough for everything in scope.
- Don't write Pester tests that hit a real tenant. The CI runner has no
  credentials; the tests are static checks only.
- Don't echo plain-text passwords in script output. Pattern: read with
  `-AsSecureString`, convert at the API call site, clear the variable in
  a `finally` block. See `new-user.ps1` (after fix/script-portability lands).
- Don't `Set-ExecutionPolicy` from inside scripts. The installer does it
  once at install time; scripts should assume it's already set.

## Things you CAN do without asking

- Local edits, parse-checks, running Pester.
- Creating branches off `main` and pushing them.

## Things to ASK first

- Pushing to `main` directly (use a branch + PR).
- Force-pushing anything.
- Running `Publish.ps1` without `-WhatIf`.
- Bumping the major or minor version. Default to patch (1.0.2 → 1.0.3).
- Removing or renaming any existing exported function — Gallery consumers
  may depend on it.

## Open questions to surface to the user as you go

- For `reset-password`: should the new password be generated automatically
  or operator-supplied? `offboard-user` generates; `new-user` accepts. Ask.
- For `enable-autoexpand`: per-mailbox or tenant-wide? The current README
  description says nothing specific. Ask.
- For `add-tap`: TAPs have a configurable lifetime and can be one-time or
  multi-use. Default to one-time, 60-minute lifetime, but confirm with
  the user.
