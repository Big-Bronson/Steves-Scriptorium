## Public\get-userreport.ps1

### What This File Does
This script generates a comprehensive single-user profile dump for M365 support investigations by querying Azure AD and Exchange Online to surface account status, license assignments, group and admin role memberships, MFA configuration, mailbox settings, permissions, and recent activity—all printed to the console in a structured report in one operation.

### Why It Exists
Helpdesk engineers need a complete picture of a user's M365 state before troubleshooting or making changes, but gathering this information manually requires running dozens of separate cmdlets across Graph and Exchange Online. `get-userreport` collapses that workflow into a single command that pulls everything relevant in one shot, reducing call time and the chance of missing a configuration detail that explains the user's issue (for example, an unexpected mailbox permission or a missing MFA method).

### What It Protects Against
The script guards against several real failure modes:

1. **Missing connections**: It checks for active Graph and Exchange Online sessions and auto-connects if either is missing, preventing the user from discovering mid-execution that they forgot to authenticate.

2. **User not found**: It validates the UPN lookup succeeds before proceeding, exiting cleanly with a red error message instead of failing silently or crashing on downstream operations.

3. **Mailbox access failures**: Mailbox operations are wrapped in try-catch blocks, so if the user lacks a mailbox or permissions are denied, the script prints a graceful message instead of terminating the entire report.

4. **Session termination on error**: The initial version used `exit`, which would terminate the user's PowerShell session entirely when the script was dot-sourced (invoked by the toolkit wrapper). The May 8 fix changed this to `return`, ensuring script failure doesn't kill the user's session.

5. **Stale or incomplete data**: It filters authentication methods to exclude password-only entries (which aren't useful for MFA assessment) and excludes system accounts from mailbox permissions, reducing noise and focusing attention on actual security-relevant configurations.

### Invariants
- The executing user must hold Graph scopes `User.Read.All`, `Directory.Read.All`, and `UserAuthenticationMethod.Read.All`.
- The executing user must have Exchange Online mailbox permissions (View Only Organization Management or equivalent).
- The target UPN must exist in Azure AD; if it does not, the script exits early.
- At least one subscription SKU must exist in the tenant (needed to build the license lookup table).

### Evolution Notes
This script was introduced in the initial release and has undergone one substantive fix. The only change was in the error-handling path: when a user lookup fails, the original code called `exit`, which would terminate the operator's entire PowerShell session if the script was dot-sourced (as it is when invoked through the toolkit). The May 8 commit replaced this with `return`, allowing the script to fail gracefully without collateral damage to the user's session. This was part of a larger portability review across five scripts in the module that all had the same `exit` problem.

### Change Log
- 2026-05-08: Fix script portability — replace `exit` with `return` to prevent session termination when script is dot-sourced.
- 2026-05-07: Initial Release