## Public\add-tap.ps1

### What This File Does
This script creates a Temporary Access Pass (TAP) for a Microsoft Entra user, allowing helpdesk operators to issue emergency passwordless sign-in credentials. The operator supplies a user's UPN, then configures lifetime and reusability constraints, and the script generates a single-use or multi-use temporary credential that the user can exchange for MFA-free access within a defined window—typically one hour.

### Why It Exists
Temporary Access Passes solve a critical operational bottleneck: users who are locked out of their accounts or unable to satisfy MFA requirements (lost phone, broken authenticator, etc.) need a way back in without requiring password resets or administrative account takeovers. Before this script, helpdesk staff had to manually construct Graph API calls or rely on the Azure portal UI, which is slow and error-prone at scale. This script bundles the entire TAP creation workflow—user lookup, parameter validation, credential issuance, and display—into a single command, reducing mean-time-to-recovery and enforcing sensible security defaults (one-time use, 60-minute expiry).

### What It Protects Against
The script defends against several real failure modes:

1. **User-not-found mishaps**: It filters users by UPN and validates the result before attempting to create a TAP, preventing crashes or accidental TAP issuance to wrong accounts.

2. **Invalid lifetime input**: It regex-validates the operator's minute input and falls back to 60 minutes if garbage (letters, empty string, negative numbers) is supplied, preventing API rejections or nonsensical TAPs with zero or infinite lifespans.

3. **Lost credentials at display time**: It shows the TAP exactly once, on-screen, with a warning that it cannot be retrieved afterward. This forces the operator to copy it before closing the terminal, reducing "I forgot to copy it" support tickets.

4. **Duplicate active TAPs**: It catches the Graph API error that fires when a user already has an active TAP and provides a hint to run `remove-taps` first, preventing silent failures or operator confusion about why creation "failed."

5. **Unauthenticated context**: It auto-connects to Microsoft Graph if no context exists, removing the need for separate login steps and reducing permission-scope bugs.

### Invariants
- The operator must have valid Graph credentials with `UserAuthenticationMethod.ReadWrite.All` scope—the script will fail at the API call if scopes are insufficient.
- The user identified by UPN must exist in the tenant and be in a state where TAP creation is allowed (e.g., not a service principal or external user in some tenant configurations).
- At most one active TAP can exist per user at any given moment; attempting to create a second will raise an error.
- The TAP is generated server-side by Graph and shown exactly once; if the operator does not copy it, it is permanently lost.
- The `StartDateTime` must be in UTC ISO 8601 format; the script enforces this by calling `.ToUniversalTime().ToString("o")`.

### Evolution Notes
This file was introduced in a single commit (May 8, 2026) as part of the MFA family feature set, alongside `get-smsmfa`, `set-smsmfa`, `add-smsmfa`, and `remove-taps`. It has never been changed since introduction. The design—interactive prompts, default lifetimes, one-time-use preselection, and inline error guidance—reflects the original author's understanding of helpdesk workflows and has proven stable enough not to require updates.

### Change Log
- 2026-05-08: Initial commit; creates TAP with interactive UPN, lifetime, and one-time-use configuration.