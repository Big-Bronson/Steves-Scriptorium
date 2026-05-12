## Public\remove-forwarding.ps1

### What This File Does
This script safely removes SMTP forwarding rules from a single Exchange Online mailbox. An MSP engineer runs it interactively, provides a mailbox identity (UPN or SMTP address), reviews the current forwarding destination, confirms the removal, and the script clears both the `ForwardingSMTPAddress` and `DeliverToMailboxAndForward` settings in one atomic operation.

### Why It Exists
Mail forwarding configuration is common in M365 tenants—employees move teams, leave the company, or consolidate inboxes. However, removing forwarding requires Exchange Online PowerShell access and knowledge of the correct cmdlet parameters. This script eliminates friction by automating the lookup, confirmation, and removal workflow so helpdesk staff don't have to remember syntax or manually craft Set-Mailbox commands. It also prevents accidental removals by showing what will be deleted and requiring explicit confirmation.

### What It Protects Against
**Mailbox not found / identity typo:** The script validates the mailbox exists before attempting any changes; a mistyped address fails fast with a clear error message rather than silently failing or corrupting data.

**Removing forwarding that doesn't exist:** The script checks whether `ForwardingSMTPAddress` is actually set; if it's blank, it exits gracefully rather than running a redundant or confusing removal operation.

**Accidental deletion:** The script displays the current forwarding address and requires the operator to type "y" to confirm; this two-stage gate prevents muscle-memory mistakes.

**Orphaned DeliverToMailboxAndForward setting:** The script explicitly sets `DeliverToMailboxAndForward` to `$false` alongside clearing the address, preventing a state where forwarding is removed but the "keep a copy" flag remains enabled and causes confusion.

### Invariants
- Exchange Online PowerShell must be connected (or connectable) when the script runs.
- The mailbox identity provided must resolve to a valid Exchange Online mailbox.
- The operator must have permissions to modify mailbox forwarding settings (typically Exchange Admin or Helpdesk Admin role).
- The mailbox must not be in a state that prevents Set-Mailbox modifications (soft-deleted, on litigation hold with frozen forwarding, etc.).

### Evolution Notes
This file was introduced in a single commit and has not been modified since. The script arrived in its final form as part of a feature pair with `set-forwarding.ps1`, both designed together to provide complementary add and remove operations for mail forwarding. No subsequent bugs, feature requests, or edge cases have prompted changes.

### Change Log
- 2026-05-08: Initial commit; added remove-forwarding script with mailbox validation, current-state display, and confirmation prompt.