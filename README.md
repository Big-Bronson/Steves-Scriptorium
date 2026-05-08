# Steve's Scriptorium

> M365 helpdesk toolkit for user lifecycle, tenant auditing, mailbox management, MFA, and Exchange.  
> Built for MSP engineers. No fluff, no GUIs — just fast CLI commands that get the job done.

---

## Install

### From PowerShell Gallery (recommended)

```powershell
Install-Module StevesScriptorium -Scope CurrentUser
```

Import it in your session (or add to your `$PROFILE` to auto-load):

```powershell
Import-Module StevesScriptorium
```

### From GitHub (clone and install)

```powershell
git clone https://github.com/Big-Bronson/Steves-Scriptorium.git
cd Steves-Scriptorium
.\Install.ps1
```

`Install.ps1` handles dependencies, copies the module to your PS module path, and adds the import to your profile automatically.

---

## Usage

```powershell
toolkit                   # list all commands
toolkit new-user          # run a command by name
toolkit 3                 # run a command by number
```

---

## Commands

### User Lifecycle

| Command | Description |
|---|---|
| `toolkit new-user` | Create a new M365 user and assign groups |
| `toolkit offboard-user` | Full offboarding — block, wipe, convert mailbox, export log |
| `toolkit set-userlicence` | Assign or remove a licence from a user |

### User Reports & Auditing

| Command | Description |
|---|---|
| `toolkit get-userreport` | Full profile dump for a single user |
| `toolkit get-allusers` | All users with licences and last login |
| `toolkit get-inactiveusers` | Users with no recent mailbox activity |
| `toolkit get-mfaaudit` | All users and their MFA registration status |
| `toolkit get-guestaudit` | Guest accounts with invite status and age |
| `toolkit get-signinlogs` | Recent sign-in events for a user |

### Tenant Health

| Command | Description |
|---|---|
| `toolkit get-tenantreport` | Full tenant snapshot — licences, MFA gaps, admin roles, sync status, service health |

### Mailbox & Exchange

| Command | Description |
|---|---|
| `toolkit check-mailflow` | Trace message delivery for a sender/recipient pair |
| `toolkit get-sharedmailboxaudit` | Shared mailboxes with delegates, size, licence status |
| `toolkit set-forwarding` | Enable SMTP forwarding on a mailbox |
| `toolkit remove-forwarding` | Remove SMTP forwarding from a mailbox |
| `toolkit get-mailboxperms` | Who has delegated access (Full Access, Send As) to a mailbox |
| `toolkit get-userperms` | Which mailboxes a user has delegated access to |
| `toolkit add-mailboxperms` | Grant Full Access and/or Send As on a mailbox |
| `toolkit disable-autocalevents` | Disable "Events from email" tenant-wide (requires typing tenant domain to confirm) |

### Groups

| Command | Description |
|---|---|
| `toolkit get-groupmembers` | List all members of a group with CSV export |


### MFA & Auth

| Command | Description |
|---|---|
| `toolkit get-smsmfa` | Show SMS/phone MFA methods registered for a user |
| `toolkit set-smsmfa` | Update the phone number on an existing SMS MFA method |
| `toolkit add-smsmfa` | Register a new SMS/phone MFA method for a user |
| `toolkit add-tap` | Create a Temporary Access Pass (one-time, 60 min default) |
| `toolkit remove-taps` | Remove all Temporary Access Passes for a user |

### System

| Command | Description |
|---|---|
| `toolkit kill-graph` | Disconnect the current Microsoft Graph session |
| `toolkit inherit-permissions` | Reset NTFS folder permissions to inherited; optionally strip explicit ACEs |


### Planned

Tracked in the issue tracker; not yet shipped:

- User Lifecycle: `reset-password`
- Mailbox & Exchange: `get-userperms`, `get-mailboxperms`, `add-mailboxperms`, `get-archive`, `enable-autoexpand`, `disable-autocalevents`
- Mailbox & Exchange: `get-archive`, `enable-autoexpand`, `disable-autocalevents`
- MFA & Auth: `get-smsmfa`, `set-smsmfa`, `add-smsmfa`, `add-tap`, `remove-taps`
- System: `inherit-permissions`

- Mailbox & Exchange: `get-archive`, `enable-autoexpand`, `disable-autocalevents`
- System: `inherit-permissions`, `kill-graph`

- Mailbox & Exchange: `get-userperms`, `get-mailboxperms`, `add-mailboxperms`, `set-forwarding`, `remove-forwarding`, `get-archive`, `enable-autoexpand`
- MFA & Auth: `get-smsmfa`, `set-smsmfa`, `add-smsmfa`, `add-tap`, `remove-taps`
- System: `kill-graph`


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
| `User.ReadWrite.All` | new-user, offboard-user, reset-password, set-userlicence |
| `User.Read.All` | get-allusers, get-userreport, get-mfaaudit, get-tenantreport |
| `Directory.ReadWrite.All` | offboard-user, new-user |
| `Directory.Read.All` | get-tenantreport, get-userreport, get-guestaudit |
| `UserAuthenticationMethod.ReadWrite.All` | add/set/get-smsmfa, add-tap, remove-taps |
| `UserAuthenticationMethod.Read.All` | get-mfaaudit, get-userreport |
| `AuditLog.Read.All` | get-signinlogs |
| `ServiceHealth.Read.All` | get-tenantreport |
| `RoleManagement.ReadWrite.Directory` | offboard-user |
| Exchange Online | all mailbox/Exchange commands |

---

## Repo Structure

```
StevesScriptorium/
├── StevesScriptorium.psm1   # Module root — loads all scripts, exposes toolkit()
├── StevesScriptorium.psd1   # Module manifest — version, dependencies, PS Gallery metadata
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

1. Update `ModuleVersion` in `StevesScriptorium.psd1`
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
(target `PSGallery-StevesScriptorium`) with `$env:PSGALLERY_API_KEY` as
fallback.

---

## Contributing

Adding a new command:

1. Create `Public/your-command-name.ps1`
2. Add the entry to the `$commands` ordered hashtable in `StevesScriptorium.psm1`
3. Add it to `FunctionsToExport` in `StevesScriptorium.psd1`
4. Add a row to the README command table
5. Bump the module version

---

## Licence

MIT — use it, fork it, share it with your team.
