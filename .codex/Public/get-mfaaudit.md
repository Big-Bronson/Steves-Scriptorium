## Public\get-mfaaudit.ps1

### What This File Does
This script audits every user in an M365 tenant and reports their multi-factor authentication (MFA) registration status. It connects to Microsoft Graph, enumerates all non-guest users, queries each one's registered authentication methods, then outputs a sorted table and exports the full results to a timestamped CSV file on the engineer's desktop. The script explicitly flags accounts with no MFA registered, making it trivial to spot compliance gaps or identify accounts that need cleanup before enforcing Conditional Access policies.

### Why It Exists
MSPs and security teams need visibility into MFA coverage across a tenant, but no built-in M365 report gives you a simple "who has MFA and who doesn't" list. The Microsoft Graph API provides the raw data, but requires orchestration: fetch all users, filter out guest accounts, iterate through each one to check their authentication methods, then format the output in a way helpdesk engineers actually use. This script automates that entire workflow in one command, eliminating the manual work of building queries, looping through users, and exporting results.

### What It Protects Against
**Guest account noise:** The script filters out users matching `#EXT#` in their UPN, preventing external guests from cluttering the audit or skewing the MFA count. **Password-only false positives:** It explicitly excludes password authentication methods when counting MFA, since a password alone is not MFA—this prevents accidentally marking an account as "MFA registered" just because it has a password. **Missing Graph context:** The script checks for an active Graph session and auto-connects if needed, so engineers don't fail silently due to lack of authentication. **Slow iteration on large tenants:** The user prompt "this takes a while" sets expectations and prevents premature timeout assumptions.

### Invariants
- The engineer must have the `User.Read.All` and `UserAuthenticationMethod.Read.All` scopes granted in their Graph context (auto-requested on connect).
- Each user object returned by `Get-MgUser` must have a valid `.Id` property for the `Get-MgUserAuthenticationMethod` call to succeed.
- The output table and CSV export will contain exactly one row per internal user in the tenant (excluding guests).
- The script assumes `$env:USERPROFILE\Desktop` exists and is writable.

### Evolution Notes
This file was introduced in the initial release on 2026-05-07 and has not been modified since. The most recent commit (2026-05-07 at 16:14) that touched the file's entry in the repository was actually a fix to `Publish.ps1` for string interpolation on a GUID error message—the diff shown reflects that commit's state, but the script's logic itself has remained unchanged. In practice, this means the MFA audit logic has been stable from day one.

### Change Log
- 2026-05-07: Initial release — complete MFA audit script with Graph authentication, user enumeration, method checking, and CSV export.