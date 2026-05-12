## Public\get-guestaudit.ps1

### What This File Does
This script audits all guest accounts in an M365 tenant, returning their display name, UPN, invitation status, creation date, and a risk categorization. It exports the results to a timestamped CSV on the user's desktop and displays a sorted table in the console. The categorization flags guests with pending invitations, those inactive for 90+ days, and recent additions—making it immediately actionable for quarterly access reviews.

### Why It Exists
Guest account hygiene is a compliance and security requirement but lacks built-in reporting in the M365 admin center. An MSP engineer running access reviews needed a quick way to identify stale guest accounts (never accepted invites, dormant for months) without manually querying Graph or wading through tenant reports. This script automates that discovery and produces an auditable export in seconds—turning a 20-minute manual task into a repeatable 30-second run.

### What It Protects Against
The script defends against two classes of failure:

1. **Graph authentication loss mid-session**: If the calling shell loses its Graph context, the initial `Get-MgContext` check reconnects with the correct scopes rather than failing silently downstream. This matters because the script is dot-sourced by the toolkit's main entry point and runs in the user's session context—a stale token would otherwise fail at the first `Get-MgUser` call.

2. **Session termination on early exit**: The original code used `exit` when no guests were found, which terminates the entire PowerShell session when the script is dot-sourced (rather than spawning a subprocess). This was fixed in May 2026 to use `return` instead, preserving the user's session and any variables or history in the parent shell.

### Invariants
- The Graph SDK (`Microsoft.Graph` module) must be installed and importable.
- The authenticated user must hold at least `User.Read.All` and `Directory.Read.All` scopes; scripts will reconnect if scopes are missing.
- The user's Desktop folder (`$env:USERPROFILE\Desktop`) must be writable.
- Guest accounts must have a `CreatedDateTime` field populated (standard for all M365 users).
- The 90-day cutoff is calculated at runtime using the local system clock, so clock skew between the client and Azure will introduce drift in the "Active >90 days ago" categorization.

### Evolution Notes
The script has undergone one substantive fix since its initial release. It was introduced in May 2026 with a critical portability bug: it used `exit` instead of `return` when no guests were found, which would terminate the user's entire PowerShell session when invoked through the toolkit's dot-sourcing loader. This was identified during v1.0.1 review and corrected in the May 8, 2026 commit as part of a broader audit of script lifecycle handling across the Spellbook module. The fix ensures the script behaves as a safe, embedded cmdlet rather than an external process that hijacks session control.

### Change Log
- 2026-05-08: Replace `exit` with `return` to prevent session termination when dot-sourced by the toolkit.
- 2026-05-07: Initial release.