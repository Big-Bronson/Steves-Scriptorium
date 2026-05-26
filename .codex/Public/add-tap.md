## Public/add-tap.ps1

### What This File Does
This script creates a Temporary Access Pass (TAP) — a time-limited authentication credential — for a Microsoft Entra user, allowing them to sign in without their normal MFA methods. It prompts an operator for a user's UPN and TAP parameters, then calls the Microsoft Graph API to generate and display the pass.

### Why It Exists
When users lose or cannot access their MFA devices (phone, authenticator app, hardware key), they are locked out. TAP provides a controlled way for admins to restore access without resetting passwords or requiring account recovery. The script bundles this common recovery operation into an interactive tool so operators don't need to write Graph calls manually.

### What It Protects Against
- **Lost TAP secrets**: The script warns that the pass cannot be retrieved after creation, preventing the operator from assuming they can look it up later.
- **Stale TAP creation**: Enforces that only one active TAP can exist per user at a time, with a hint to use `remove-taps` if that limit is hit.
- **Bad user input**: Validates the UPN exists before attempting TAP creation, and coerces lifetime input to a safe integer (defaulting to 60 minutes if missing or non-numeric).
- **Missing permissions**: Checks for an active Graph context and proactively connects with the required scope if absent.

### Invariants
- A valid Microsoft Entra user with the supplied UPN must exist in the tenant.
- The calling identity must hold `UserAuthenticationMethod.ReadWrite.All` on that user.
- The lifetime input, if provided, must be a non-negative integer; anything else reverts to 60 minutes.
- Only one active TAP can exist per user at any moment.
- The TAP secret is generated once and is not retrievable; it must be copied immediately.

### Key Patterns
- **Interactive CLI**: Uses `Read-Host` to gather parameters rather than accepting them as function arguments, making this a hands-on operator tool rather than an automation primitive.
- **Soft defaults with override**: Lifetime defaults to 60 minutes and one-time use defaults to no (multi-use), but both are operator-overridable via prompts.
- **UTC timestamp normalization**: Converts system time to ISO 8601 UTC format (`"o"` format specifier) for Graph API consistency.
- **Graceful missing-user handling**: Uses `-ErrorAction SilentlyContinue` to avoid script termination on lookup failure, then explicitly checks the result and exits cleanly.
- **Contextual error messaging**: The catch block hints at the one-TAP-per-user constraint as a likely cause of failure, reducing operator confusion.

### Change Log
- 2026-05-08: Added TAP creation feature as part of MFA toolkit (get/set/add-smsmfa, add-tap, remove-taps family).
- 2026-05-26: Default for one-time use flipped to no (multi-use). Prompt updated to reflect new default.