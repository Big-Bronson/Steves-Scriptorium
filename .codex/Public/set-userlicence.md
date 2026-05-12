## Public\set-userlicence.ps1

### What This File Does

This script provides an interactive menu-driven interface for assigning or removing Microsoft 365 licenses from individual users. An engineer runs it, supplies a user's UPN, sees their current licenses and all available SKUs with seat counts, selects a license and an action (assign or remove), and the script executes the Graph API call. It eliminates the need to memorize SKU GUIDs or perform manual license math.

### Why It Exists

Manual license assignment via the M365 admin portal is slow for bulk or rapid operations, and scripting it directly requires the engineer to know the exact SkuId GUID for each product (E3, E5, Teams, etc.) ahead of time. This script surfaces both current state and available inventory in a numbered menu, letting helpdesk staff perform the most common licensing task without leaving PowerShell or consulting external lookup tables.

### What It Protects Against

The script defends against four concrete failure modes:

1. **Session termination on early exit** — The original code used `exit` statements, which terminate the entire PowerShell session when the script is dot-sourced (run within the user's session context). This was fixed to `return` so that user input errors (invalid UPN, invalid menu selection) exit the script without killing the session.

2. **Missing or invalid Graph context** — Before attempting any user lookup, the script checks for an active Graph connection and auto-connects if absent, preventing authentication errors midway through execution.

3. **Null reference on user not found** — If the UPN lookup fails, the script exits early rather than attempting to call Set-MgUserLicense against a null user object.

4. **Out-of-bounds menu selection** — The script validates that the SKU index is within the bounds of the available list before dereferencing it.

### Invariants

- A valid Microsoft Graph PowerShell SDK context must exist or be establishable (requires appropriate tenant permissions).
- The user's UPN must match exactly as stored in the tenant's directory.
- At least one SKU must be subscribed to in the tenant (otherwise the available SKU list is empty and no action can be taken).
- The supplied action code must be "1" or "2"; any other input is rejected.

### Evolution Notes

The script was released in its essentially complete form on 2026-05-07. It received exactly one functional correction on 2026-05-08: all early-exit points were changed from `exit` to `return`. This fix addressed a critical portability issue where running the script via the Spellbook toolkit's dot-sourcing pattern would terminate the user's entire PowerShell session on validation failures (e.g., invalid UPN or invalid menu choice). The change was motivated by discovering that public scripts in the module are always dot-sourced by the toolkit wrapper, making `exit` semantically wrong. No other logic, UI, or algorithm changes have occurred.

### Change Log

- 2026-05-08: Replace `exit` with `return` throughout to prevent terminating user's PowerShell session when script is dot-sourced.
- 2026-05-07: Initial release.