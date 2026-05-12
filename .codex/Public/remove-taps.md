## Public\remove-taps.ps1

### What This File Does
When an MSP engineer runs this script, it prompts for a user's UPN, retrieves all active Temporary Access Pass (TAP) authentication methods from that user's M365 account, displays their creation and expiry times, asks for confirmation, and then removes every TAP in a single operation. This is a destructive action — once confirmed, all TAPs for that user are permanently revoked.

### Why It Exists
Temporary Access Passes are intended as emergency one-time credentials that expire naturally after a set period. However, in incident response scenarios — particularly after a phishing attack or credential compromise — waiting for natural expiry is unacceptable. An attacker who obtained a user's compromised credentials could potentially use an active TAP if they knew the user's UPN and the TAP value. This script allows a helpdesk operator to immediately and completely revoke all TAPs without manual Graph API calls or portal navigation, closing that attack vector in seconds.

### What It Protects Against
- **Silent TAP persistence after compromise:** The script prevents an attacker from using a valid TAP even if they've obtained the user's primary credentials.
- **Operator uncertainty about expiry:** By displaying creation time, expiry time, and one-time-use status before deletion, the script prevents accidental removal of TAPs the user still needs (though it removes all anyway — the display is informational).
- **Partial failures:** The script counts successful removals and reports how many of N TAPs were actually deleted, so the operator knows whether all TAPs are truly gone or whether some deletion calls failed silently.
- **Graph context loss:** The script checks for an active `MgGraph` context and connects with the correct scope (`UserAuthenticationMethod.ReadWrite.All`) if needed, preventing "not connected" errors mid-execution.
- **User lookup failure:** The script validates that the UPN actually exists in the tenant before attempting to fetch TAPs, avoiding confusing error messages.

### Invariants
- The user running the script must have delegated permissions for `UserAuthenticationMethod.ReadWrite.All` in the M365 tenant (either via app-based or interactive authentication).
- The UPN entered must match a valid user object in the tenant's Azure AD.
- The Graph SDK (`Microsoft.Graph.Authentication` and `Microsoft.Graph.Users`) must be installed and importable.
- All TAPs for a user share the same `UserId`, allowing batch removal in a single loop.

### Evolution Notes
This file was introduced in commit `a6ccdcf` on 2026-05-08 as part of the initial MFA family feature release and has not been modified since. It arrived fully formed with confirmation prompts, detailed TAP metadata display, error handling, and success counters.

### Change Log
- 2026-05-08: Initial commit — add remove-taps script to revoke all active TAPs for a user after phishing or compromise incidents.