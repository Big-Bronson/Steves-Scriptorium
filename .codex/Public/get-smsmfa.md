## Public\get-smsmfa.ps1

### What This File Does
When an MSP helpdesk engineer runs this script, it prompts for a user's UPN, retrieves that user from the tenant, queries Microsoft Graph for all phone-based MFA methods registered to them, and displays a formatted table showing the method type (mobile, office, alternate mobile) and phone number for each one. It's a read-only audit tool that answers "what phone MFA does this user have configured right now?"

### Why It Exists
Phone-based MFA (SMS and voice call) is often the first line of support contact when users lose access to authenticator apps or hardware keys. Helpdesk staff needed a fast way to see what phone numbers are registered without digging through the Azure AD portal or Graph Explorer. This script was introduced as part of a broader MFA management family that lets operators query, add, update, and remove phone methods and temporary access passes — turning scattered Graph operations into a cohesive helpdesk toolkit.

### What It Protects Against
**User lookup failure:** If the UPN doesn't exist or is misspelled, the script catches the error from Get-MgUser and exits cleanly with a red-text message instead of proceeding with a $null user object and throwing cryptic downstream errors. **Empty result set:** If a user has no phone methods registered, the script explicitly states that rather than showing an empty table, which could confuse an operator into thinking the query failed. **Missing Graph context:** The script checks whether a Graph session already exists before attempting to connect, avoiding redundant authentication or failing silently if credentials aren't cached.

### Invariants
- Microsoft Graph PowerShell SDK must be installed (`Get-MgContext`, `Get-MgUser`, `Get-MgUserAuthenticationPhoneMethod` cmdlets must exist)
- The executing account must hold `UserAuthenticationMethod.Read.All` permission in the tenant
- The UPN entered must be a valid, resolvable user in the tenant
- The user's Id property and phone method objects must be retrievable from Graph without network failure

### Evolution Notes
This file was introduced in a single commit and has not changed since. It arrived as a complete, stable implementation with no subsequent refinements, bug fixes, or feature additions. The script's design — immediate UPN prompt, inline error handling, simple columnar output — has remained exactly as first written.

### Change Log
- 2026-05-08: Initial introduction as part of MFA management family (get/set/add-smsmfa, add-tap, remove-taps).