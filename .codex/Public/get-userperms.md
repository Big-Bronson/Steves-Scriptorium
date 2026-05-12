## Public\get-userperms.ps1

### What This File Does
When an MSP engineer needs to audit a specific user's mailbox delegation rights across an entire M365 tenant, this script performs a tenant-wide scan to answer: "What mailboxes can this person access, and how?" It collects two permission types (Full Access and Send As) and presents them in a simple formatted list, while showing real-time progress to warn the operator that the operation may take significant time on large tenants.

### Why It Exists
The reverse-lookup problem: while `Get-MailboxPermission` can tell you who has access to *one* mailbox, there's no native cmdlet that answers "which mailboxes does *this user* have access to?" An engineer troubleshooting access issues, auditing a departing employee's delegated rights, or validating a permission grant needed a fast way to scan the entire tenant without writing their own loop. This script automates that common investigation task and shields the operator from the cmdlet details.

### What It Protects Against
**Non-existent users causing silent failures:** The script validates the UPN exists as a recipient before iterating all mailboxes, preventing the operator from waste time scanning thousands of mailboxes for a typo'd username. **Explicit Deny permissions being reported as grants:** The Full Access check explicitly filters out `Deny` entries so that negative permissions don't mislead the audit. **Missing Exchange Online session:** The script validates an active Exchange Online connection exists before attempting any cmdlet calls, preventing cryptic "no connection" errors mid-scan.

### Invariants
- Exchange Online PowerShell module must be installed and available
- The input UPN must exist as a valid recipient object in the directory (validated before scan begins)
- All mailboxes must be reachable via `Get-MailboxPermission` and `Get-RecipientPermission` (the script tolerates individual query failures with `-ErrorAction SilentlyContinue`)
- The operator's account must have at least read permissions on mailbox delegation metadata across the tenant

### Evolution Notes
This file was introduced in a single commit alongside two sibling scripts (`get-mailboxperms` and `add-mailboxperms`) as part of a coordinated "mailbox permissions family" feature. Since its introduction, it has not been modified—the implementation shipped in its final form.

### Change Log
- 2026-05-08: Initial commit—added get-userperms to scan all mailboxes and report Full Access and Send As permissions granted to a specified user.