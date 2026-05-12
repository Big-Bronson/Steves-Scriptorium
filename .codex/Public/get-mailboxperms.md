## Public\get-mailboxperms.ps1

### What This File Does

This script audits delegated mailbox access for a single target mailbox, displaying both Full Access and Send As permissions while automatically filtering out system-generated ACEs that clutter the output. An MSP engineer runs it when a customer asks "who can access this mailbox?" and needs a quick, human-readable answer without wading through NT AUTHORITY noise.

### Why It Exists

Exchange Online's native `Get-MailboxPermission` and `Get-RecipientPermission` cmdlets return raw ACL data that includes dozens of inherited system entries (NT AUTHORITY\SELF, S-1-5 SIDs, etc.) that obscure the actual delegated access an MSP cares about. The engineer was manually filtering these every time or copy-pasting the same Where-Object blocks across tickets. This script encapsulates that repeated filtering logic, validates the mailbox exists upfront, and presents results in a clean, color-coded format that fits into a helpdesk workflow.

### What It Protects Against

**Non-existent mailbox lookup:** The script wraps the initial `Get-Mailbox` call in try-catch and exits gracefully with a red error message rather than letting an invalid identity cascade through to subsequent permission queries.

**System ACE noise:** Filters explicitly on `NT AUTHORITY*` and `S-1-5*` patterns to hide inherited system permissions that would otherwise dominate the output and make real delegations invisible.

**Deny ACEs in Full Access:** The Full Access filter includes `-not $_.Deny`, preventing the script from flagging explicit deny permissions as positive grants—a subtle but important distinction when auditing.

**Missing Exchange Online connection:** Checks for an active connection at the start and connects automatically if needed, avoiding the silent failure where cmdlets fail without warning.

**Partial permission retrieval:** Both Full Access and Send As queries are wrapped in separate try-catch blocks so that if one permission type fails to retrieve, the other still displays.

### Invariants

- Exchange Online PowerShell must be available and connectable (or already connected).
- The user input must resolve to a valid mailbox via `Get-Mailbox -Identity`.
- The mailbox's primary SMTP address must be accessible and queryable via `Get-MailboxPermission` and `Get-RecipientPermission`.
- The tenant must have either no delegated permissions or permissions assigned to named principals (users/groups), not purely system SIDs.

### Evolution Notes

This file was introduced in a single commit as part of a three-script permissions family (alongside `get-userperms` and `add-mailboxperms`) and has not been changed since. It arrived feature-complete with its current filtering logic, error handling, and output formatting.

### Change Log

- 2026-05-08: Initial commit—added mailbox permissions family with Full Access and Send As auditing and automatic system ACE filtering.