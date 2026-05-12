## Public\get-signinlogs.ps1

### What This File Does
When an MSP helpdesk engineer needs to investigate a user's authentication behavior in M365, this script pulls the most recent sign-in events for that user from Entra ID's audit logs and displays them in a formatted table showing when they signed in, what apps they accessed, their IP address, location, success/failure status, MFA method used, and whether Conditional Access policies were applied. It's the quickest way to answer questions like "Did this user actually log in yesterday?" or "Why are their MFA attempts failing?"

### Why It Exists
Sign-in logs are critical for troubleshooting authentication issues, but accessing them raw through Graph requires the engineer to know the correct Filter syntax, handle the response structure, and understand which fields matter. This script wraps that complexity into an interactive tool that asks for the user's UPN and a log count, then delivers human-readable output without requiring the engineer to know Graph API details. It's a common first-step diagnostic when users report access problems or when security incidents need timeline confirmation.

### What It Protects Against
The script defends against several real failure modes:

- **Missing Graph context**: It checks whether the engineer is already authenticated to Graph before attempting the query, and auto-connects if needed, avoiding "not connected" errors mid-execution.
- **Insufficient licensing silently breaking the tool**: It explicitly warns the user that sign-in logs require Entra ID P1/P2 or Microsoft 365 Business Premium, and handles the case where the log returns empty (a common symptom of missing premium licensing) with a yellow warning rather than silent failure.
- **Confusing error status fields**: The script transforms the raw `Status.ErrorCode` and `Status.FailureReason` fields into a human-readable "Success" or "Failed: [reason]" format, preventing the engineer from having to interpret numeric codes.
- **Permission denials that look like missing data**: The catch block distinguishes between "no logs found" (licensing issue) and "cannot retrieve logs" (permission or Graph error), helping the engineer diagnose whether the problem is scope-related or structural.

### Invariants
- The user running this script must have already been granted `AuditLog.Read.All` and `Directory.Read.All` scopes in their Graph connection, either before script execution or via the auto-connect.
- The target tenant must have Entra ID P1/P2 or Microsoft 365 Business Premium licensing; without it, sign-in logs are unavailable.
- The user must provide a valid UPN in the format `user@domain.com`; the script does not validate this before querying, so malformed input will return empty results.
- The Microsoft Graph PowerShell SDK must be installed and available in the execution environment.

### Evolution Notes
This file was introduced as part of the initial Spellbook release and has not changed since. The commit history shows a later fix labeled "Fix Publish.ps1 string interpolation on GUID error message," but that commit did not actually modify this file—it was likely a build or packaging change unrelated to the script's logic. The get-signinlogs.ps1 script remains in its original form, suggesting it shipped complete and stable without requiring corrections to its core functionality.

### Change Log
- 2026-05-07: Initial Release — script added to Spellbook with interactive UPN and log-count prompts, Graph auto-connect, formatted sign-in output with computed Status and MFA columns, and licensing/permission error handling.