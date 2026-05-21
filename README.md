# Spellbook

> M365 helpdesk toolkit for user lifecycle, tenant auditing, mailbox management, MFA, and Exchange.  
> Built for MSP engineers. No fluff, no GUIs — just fast CLI commands that get the job done.

---

## Install

> **Use `Install-PSResource`, not `Install-Module`.** `Install-Module` is from the legacy PowerShellGet v2 stack and hits NuGet provider locking issues on Windows even after a session restart. `Install-PSResource` is the modern replacement and works cleanly on PS 7.

### From PowerShell Gallery (recommended)

**First-time install:**

```powershell
Install-PSResource -Name Spellbook -Scope CurrentUser
```

**Updating to a newer version:**

```powershell
Install-PSResource -Name Spellbook -Reinstall -SkipDependencyCheck -Scope CurrentUser
```

`-Scope CurrentUser` installs to your personal Modules folder (`$HOME\Documents\PowerShell\Modules`), which is always writable. Omitting it lets `Install-PSResource` default to `AllUsers`, which on the Microsoft Store build of PS 7 targets a locked WindowsApps directory and throws an access denied error on `Import-Module`.

`-SkipDependencyCheck` is required when updating. Without it, `Install-PSResource` tries to reinstall the dependencies (ExchangeOnlineManagement, Microsoft.Graph.*) alongside the module. If any of those are already loaded in your session — which they will be if you've run any Spellbook commands — PowerShell can't overwrite them and the install fails. The dependencies don't change between Spellbook releases, so skipping them is safe.

**Uninstall:**

```powershell
Uninstall-PSResource -Name Spellbook -Scope CurrentUser
```

Import it in your session (or add to your `$PROFILE` to auto-load):

```powershell
Import-Module Spellbook
```

### From GitHub (clone and install)

```powershell
git clone https://github.com/Big-Bronson/Spellbook.git
cd Spellbook
.\Install.ps1
```

`Install.ps1` handles dependencies, copies the module to your PS module path, and adds the import to your profile automatically.

---

## Usage

```powershell
invoke                   # list all commands
invoke new-user          # run a command by name
invoke 3                 # run a command by number
```

---

## Commands

### User Lifecycle

| Command | Description |
|---|---|
| `invoke new-user` | Create a new M365 user and assign groups |
| `invoke offboard-user` | Full offboarding — block, wipe, convert mailbox, export log |
| `invoke set-userlicence` | Assign or remove a licence from a user |

### User Reports & Auditing

| Command | Description |
|---|---|
| `invoke get-userreport` | Full profile dump for a single user |
| `invoke get-allusers` | All users with licences and last login |
| `invoke get-inactiveusers` | Users with no recent mailbox activity |
| `invoke get-mfaaudit` | All users and their MFA registration status |
| `invoke get-guestaudit` | Guest accounts with invite status and age |
| `invoke get-signinlogs` | Recent sign-in events for a user |
| `invoke get-licencegaps` | Licensed users with no recent sign-in — cost-saving audit |

### Tenant Health

| Command | Description |
|---|---|
| `invoke get-tenantreport` | Full tenant snapshot — licences, MFA gaps, admin roles, sync status, service health |
| `invoke get-conditionalaccess` | All Conditional Access policies — state, user/group targets, app targets, grant controls |
| `invoke get-devicereport` | Intune managed devices — compliance state, sync status, flags stale and non-compliant |

### Mailbox & Exchange

| Command | Description |
|---|---|
| `invoke new-sharedmailbox` | Create a shared mailbox and optionally assign Full Access and Send As delegates |
| `invoke get-archive` | In-place archive size, item count, and quota for a mailbox |
| `invoke get-mailflow` | Trace message delivery for a sender/recipient pair |
| `invoke get-sharedmailboxaudit` | Shared mailboxes with delegates, size, licence status |
| `invoke get-forwarding` | Show forwarding configuration on a mailbox |
| `invoke set-forwarding` | Enable SMTP forwarding on a mailbox |
| `invoke remove-forwarding` | Remove SMTP forwarding from a mailbox |
| `invoke get-mailboxperms` | Who has delegated access (Full Access, Send As) to a mailbox |
| `invoke get-userperms` | Which mailboxes a user has delegated access to |
| `invoke set-mailboxperms` | Grant Full Access and/or Send As on a mailbox |
| `invoke disable-autocalevents` | Disable "Events from email" tenant-wide (requires typing tenant domain to confirm) |

### Groups

| Command | Description |
|---|---|
| `invoke get-groupmembers` | List all members of a group with CSV export |


### MFA & Auth

| Command | Description |
|---|---|
| `invoke get-smsmfa` | Show SMS/phone MFA methods registered for a user |
| `invoke set-smsmfa` | Update the phone number on an existing SMS MFA method |
| `invoke add-smsmfa` | Register a new SMS/phone MFA method for a user |
| `invoke add-tap` | Create a Temporary Access Pass (one-time, 60 min default) |
| `invoke remove-taps` | Remove all Temporary Access Passes for a user |

### System

| Command | Description |
|---|---|
| `invoke kill-graph` | Disconnect the current Microsoft Graph session |
| `invoke kill-exchange` | Disconnect the current Exchange Online session |
| `invoke get-connections` | Show active Exchange Online and Graph connection status |
| `invoke inherit-permissions` | Reset NTFS folder permissions to inherited; optionally strip explicit ACEs |


### Planned

Tracked in the issue tracker; not yet shipped:

- User Lifecycle: `reset-password`
- Mailbox & Exchange: `enable-autoexpand`


---

## Requirements

- PowerShell 5.1 or higher (7.x recommended)
- Modules installed automatically by `Install.ps1` or when using PS Gallery:
  - `ExchangeOnlineManagement`
  - `Microsoft.Graph.Users`
  - `Microsoft.Graph.Identity.SignIns`
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.Groups`
  - `Microsoft.Graph.Reports`

> No local admin required. All modules install to `CurrentUser` scope.

---

## Permissions

Each script connects itself and prompts for auth. The Graph scopes required vary by command — each script requests only what it needs. A summary:

| Scope | Used by |
|---|---|
| `User.ReadWrite.All` | new-user, offboard-user, set-userlicence |
| `User.Read.All` | add-tap, get-allusers, get-guestaudit, get-groupmembers, get-inactiveusers, get-mfaaudit, get-sharedmailboxaudit, get-tenantreport, get-userreport |
| `Directory.ReadWrite.All` | offboard-user, set-userlicence |
| `Directory.Read.All` | get-allusers, get-guestaudit, get-inactiveusers, get-signinlogs, get-tenantreport, get-userreport, new-user |
| `Group.ReadWrite.All` | new-user |
| `Group.Read.All` | get-groupmembers |
| `UserAuthenticationMethod.ReadWrite.All` | add-smsmfa, set-smsmfa, add-tap, remove-taps, offboard-user |
| `UserAuthenticationMethod.Read.All` | get-smsmfa, get-mfaaudit, get-userreport, get-tenantreport |
| `Organization.Read.All` | disable-autocalevents, get-tenantreport |
| `RoleManagement.Read.Directory` | get-tenantreport |
| `RoleManagement.ReadWrite.Directory` | offboard-user |
| `AuditLog.Read.All` | get-signinlogs, get-licencegaps |
| `Policy.Read.All` | get-conditionalaccess |
| `DeviceManagementManagedDevices.Read.All` | get-devicereport |
| `ServiceHealth.Read.All` | get-tenantreport |
| Exchange Online | all mailbox/Exchange commands |

---

## Repo Structure

```
Spellbook/
├── Spellbook.psm1   # Module root — loads all scripts, exposes invoke()
├── Spellbook.psd1   # Module manifest — version, dependencies, PS Gallery metadata
├── Install.ps1              # Bootstrap installer (clone → run this)
├── Publish.ps1              # PS Gallery publisher
├── Public/                  # All user-facing scripts (one per command)
├── Private/                 # Internal helpers (not exported)
├── Templates/               # CSV templates for bulk operations
├── docs/                    # Extended documentation
└── README.md
```

---

## Publishing a New Version

1. Update `ModuleVersion` in `Spellbook.psd1`
2. Update `ReleaseNotes` in the manifest
3. Move CHANGELOG `[Unreleased]` content into a dated `[x.y.z]` section
4. Commit and push to GitHub (clean tree on `main` is required)
5. Run:

```powershell
.\Publish.ps1 -WhatIf   # dry run
.\Publish.ps1           # publish
```

`Publish.ps1` runs pre-flight checks (manifest validation, parse-check of all
`Public/*.ps1`, `FunctionsToExport` sync, clean git tree, populated
`[Unreleased]`). The PS Gallery API key is read from Windows Credential Manager
(target `PSGallery-Spellbook`) with `$env:PSGALLERY_API_KEY` as
fallback.

---

## Contributing

Adding a new command:

1. Create `Public/your-command-name.ps1`
2. Add the entry to the `$commands` ordered hashtable in `Spellbook.psm1`
3. Add it to `FunctionsToExport` in `Spellbook.psd1`
4. Add a row to the README command table
5. Bump the module version

---

## Licence

MIT — use it, fork it, share it with your team.
