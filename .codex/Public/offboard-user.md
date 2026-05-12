## Public\offboard-user.ps1

### What This File Does

This script performs a complete M365 user offboarding workflow: it disables the account, resets the password, revokes active sessions, strips group memberships and admin roles, removes MFA methods, cancels future calendar events, converts the mailbox to shared ownership (preserving data while freeing the licence), sets an out-of-office reply, hides the user from the address list, removes all licence assignments, and logs every action—success or failure—to a timestamped CSV file saved on the engineer's desktop for audit purposes.

### Why It Exists

Manual offboarding across M365 is error-prone and incomplete: an engineer might forget to revoke sessions, miss a hidden group membership, or leave MFA methods in place, creating security gaps. The operational need was to codify the complete offboarding checklist into a single atomic script that enforces sequence, captures every step, and produces an audit trail without requiring the engineer to remember or manually execute 12 separate cmdlet chains across Graph and Exchange Online.

### What It Protects Against

- **Silent password-reset failures**: Uses a custom password generator (`New-OffboardPassword`) instead of the Windows-only `[System.Web.Security.Membership]` class, ensuring the script runs on PowerShell 7 across any platform.
- **Weak passwords**: The password generator guarantees at least one character from each complexity class (uppercase, lowercase, digit, symbol) to satisfy M365 rules on the first attempt.
- **Incomplete audit trails**: Per-item failures (e.g., removing a single group membership or MFA method) now log as separate CSV rows instead of being swallowed by try-catch blocks, so the engineer sees exactly which group removal failed and why.
- **Missing user**: Validates the user exists before proceeding and provides clear feedback if the UPN is not found.
- **Accidental execution**: Requires explicit `y` confirmation before touching any data.

### Invariants

- The script must have active connections to both Graph (with the four scopes listed) and Exchange Online before executing the main offboarding logic.
- The user specified by UPN must exist in the tenant at the moment the script runs.
- The engineer's Desktop folder must be writable (log export will fail silently if not).
- The user's current password policy and security posture must permit a random 20-character password assignment.

### Evolution Notes

The script was introduced in the initial release (2026-05-07) with a complete 12-step workflow. One month later (2026-05-11, release 1.1.0), it was refined in three ways: (1) steps 4, 5, and 6—group removal, admin role removal, and MFA method removal—were hardened to log per-item failures as individual CSV rows instead of silent exceptions, closing an audit-log integrity gap; (2) the script remained stable through the broader release cycle that bumped module requirements and deprecated Exchange cmdlets elsewhere in Spellbook; (3) no changes to the core offboarding sequence or password-handling logic since the initial commit. The script has not broken or required bug fixes to its own logic.

### Change Log

- 2026-05-11: Per-item failures in group removal, role removal, and MFA method removal now logged as individual CSV rows (ADR-0021).
- 2026-05-07: Initial release with complete 12-step offboarding workflow, custom password generator for PowerShell 7 portability, and CSV audit log.