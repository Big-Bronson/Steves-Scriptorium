## Public\add-smsmfa.ps1

### What This File Does
This script registers a new SMS/phone-based MFA authentication method for a specified M365 user by prompting the engineer to supply a UPN and phone number, then letting them choose whether the phone should be registered as a primary mobile (SMS + voice capable), alternate mobile, or office line before pushing the configuration to Azure AD via the Microsoft Graph API.

### Why It Exists
Helpdesk engineers need a quick, interactive way to add phone-based MFA to user accounts without manually navigating the Azure portal or writing raw Graph API calls. The script encapsulates the common workflow: find the user, collect the phone details, validate the input format, choose the phone type, and register it—all in one guided experience. This is particularly useful in bulk onboarding scenarios or when a user's existing MFA method has failed and a phone fallback is needed immediately.

### What It Protects Against
The script defends against several failure modes:

- **User not found**: It validates that the UPN exists in the tenant before attempting to register a phone method, preventing orphaned or failed Graph requests against non-existent user IDs.
- **Empty phone number input**: It rejects empty phone input with an explicit abort rather than allowing the Graph call to fail silently.
- **Invalid phone type selection**: The switch statement has a safe default (`mobile`) so that any unrecognized input (including just pressing Enter) maps to a sensible choice rather than passing garbage to the API.
- **Missing Graph context**: It auto-connects to Microsoft Graph with the required `UserAuthenticationMethod.ReadWrite.All` scope if the engineer isn't already authenticated, avoiding "not connected" errors mid-run.
- **Graph API exceptions**: The `New-MgUserAuthenticationPhoneMethod` call is wrapped in try-catch with `-ErrorAction Stop`, so transient or permission errors are caught and displayed in red rather than crashing the script.

### Invariants
For this script to work correctly, these conditions must hold:

1. The engineer must have a valid M365 tenant with Azure AD and Microsoft Graph API access.
2. The UPN provided must exist in the tenant's user directory.
3. The phone number must be supplied in E.164 format (e.g., `+61412345678`), or the Graph API will reject it.
4. The service principal or account running the script must hold the `UserAuthenticationMethod.ReadWrite.All` permission on the Microsoft Graph API.
5. The user's authentication policy must not prohibit phone-based MFA (some orgs block it in favor of passwordless methods).

### Evolution Notes
This script was introduced in a single commit (2026-05-08) as part of a cohesive MFA family feature alongside `get-smsmfa`, `set-smsmfa`, `add-tap`, and `remove-taps`. The file has not changed since its introduction; it has remained stable and functionally complete. The initial design already included proper error handling, Graph context auto-connection, and user-friendly menu prompts, so no refinements or bug fixes have been necessary.

### Change Log
- 2026-05-08: Initial commit—added script to register new SMS/phone MFA methods with support for mobile, alternate mobile, and office phone types.