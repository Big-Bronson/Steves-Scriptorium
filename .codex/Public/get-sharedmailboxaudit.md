## Public\get-sharedmailboxaudit.ps1

### What This File Does
This script audits all shared mailboxes in an M365 tenant and produces a compliance-ready report showing who has delegated access to each mailbox, how much storage each one consumes, and whether it holds an unnecessary licence assignment. The engineer runs it once per quarter (or during offboarding) to identify cost waste and permission sprawl, then exports the findings to a timestamped CSV for stakeholder review or remediation.

### Why It Exists
Shared mailboxes are org-wide resources, but they frequently accumulate unnecessary licences (shared mailboxes under 50 GB should never be licensed) and delegated access permissions that outlive their business purpose. Manual inspection via the Exchange Admin Center is tedious for large tenants, and there's no built-in report that surfaces all three data points—permissions, size, and licence status—in one view. This script exists to automate that audit and make it repeatable, so helpdesk teams can justify licence removals to finance and detect orphaned access during employee offboarding.

### What It Protects Against
**Silent licence waste.** A shared mailbox can hold a licence indefinitely without triggering any alert; this script finds them. **Orphaned permissions.** When an employee leaves, their Full Access permission to shared mailboxes may not be revoked; the script surfaces those by filtering out system accounts and listing only human delegates. **Missing connection state.** The script verifies both Exchange Online and Microsoft Graph are connected before running queries, preventing silent failures where cmdlets return empty results because authentication dropped. **Missing mailbox stats.** Some mailboxes fail to return statistics; the script catches that with error suppression and returns "N/A" rather than crashing. **Graph lookup failures.** A mailbox PrincipalSmtpAddress might not map to a Graph user object (edge case in hybrid tenants); the script wraps that query in error suppression so one bad lookup doesn't halt the entire audit.

### Invariants
- Exchange Online and Microsoft Graph must be connected before execution.
- Every shared mailbox must have a PrimarySmtpAddress (guaranteed by the Get-Mailbox cmdlet).
- The running user must hold at least Mailbox Auditor role in Exchange Online and User.Read.All in Graph.
- Delegated permissions are meaningfully identified by filtering out NT AUTHORITY accounts (system-generated, not human).
- A shared mailbox is considered "over-licensed" if it holds any assigned licence, regardless of SKU or size.

### Evolution Notes
This file was introduced in the initial release on 2026-05-07 in complete, working form. The subsequent commit on the same day touched only Publish.ps1 (a string interpolation fix for GUID error messages) and did not alter the logic or structure of get-sharedmailboxaudit.ps1. The script has remained unchanged since inception—no bugs were found, no features were added, and no edge cases required patching.

### Change Log
- 2026-05-07: Initial Release — script created to audit shared mailbox permissions, size, and licence assignments across the tenant.