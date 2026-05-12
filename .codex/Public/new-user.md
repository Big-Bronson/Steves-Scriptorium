## Public\new-user.ps1

### What This File Does
When a helpdesk engineer needs to onboard a new M365 user, this script automates the three-step process: it creates the user account with an initial password, optionally clones group memberships from an existing template user to preserve role-based access patterns, and then allows manual addition of any extra groups that don't fit the template model. It walks the engineer through each step interactively rather than requiring pre-built CSV files or manual Graph API calls.

### Why It Exists
Bulk user creation in M365 can be done through the admin portal, but it's slow and error-prone—especially the group membership step. An engineer onboarding a new hire typically needs that person to have the same Teams, SharePoint, and security groups as someone in the same role. Rather than manually looking up the template user's groups and clicking "Add member" five or ten times, this script finds and applies them automatically. The manual group addition at the end handles exceptions: niche teams or special-access groups that don't follow the template pattern.

### What It Protects Against
**Password exposure in scrollback.** The original script read the password as plain text via `Read-Host`, which meant it was visible in the PowerShell console history and the command line itself. The current version reads it as a `SecureString`, converts it to plain text only at the exact moment the Graph API call needs it (inside the `New-MgUser` call), and immediately clears the local variable in a `finally` block. The trailing summary now shows "(set — not echoed)" instead of echoing the actual password back to the screen.

**Template user not found.** The script explicitly checks whether the template user exists before attempting to read their groups, and gracefully skips the copy step rather than failing partway through.

**Group name ambiguity during manual add.** When the engineer types a group name, the script detects both "no match" and "multiple matches" cases and asks for clarification rather than guessing or failing silently.

**Individual group add failures.** If one group membership fails (e.g., due to permissions or a constraint), the script catches the exception, logs it, and continues to the next group instead of halting the entire onboarding.

### Invariants
- The Microsoft Graph PowerShell SDK must be installed and the required scopes (`User.ReadWrite.All`, `Group.ReadWrite.All`, `Directory.Read.All`) must be consented.
- The UPN provided must be unique in the tenant (the Graph API will reject duplicates).
- The template user UPN, if provided, must exist in the tenant and be retrievable via `Get-MgUser`.
- The engineer must have permissions to create users and add group members; if not, the script will fail when it attempts those operations, which is expected behavior.

### Evolution Notes
This file was introduced in the initial release (2026-05-07) as a straightforward interactive user creation and group-copying tool. One day later (2026-05-08), it underwent a security and portability revision. The password handling was hardened to prevent exposure in console history—the core change. No other functional changes to the script's logic or flow have occurred since; the tool has remained stable after that single, critical fix.

### Change Log
- 2026-05-08: Fix script portability and password handling — read initial password as SecureString, convert to plain text only at API call site, clear local copy immediately after, hide password from summary output.
- 2026-05-07: Initial Release.