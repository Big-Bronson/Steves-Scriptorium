## Public\disable-autocalevents.ps1

### What This File Does
This script disables the "Events from email" feature across every user and shared mailbox in an M365 tenant, preventing Outlook from automatically creating calendar entries from flight confirmations, hotel bookings, parcel notifications, and similar transactional emails. It enumerates all mailboxes via Exchange Online, applies the configuration change to each one, logs results per-mailbox to a CSV file, and reports summary statistics to the operator.

### Why It Exists
Organizations frequently request this as a tenant-wide policy to reduce calendar clutter and prevent automated calendar pollution. Rather than requiring the MSP to manually repeat the same `Set-MailboxCalendarConfiguration` command across hundreds or thousands of mailboxes, this script automates the entire operation in a single run, tracks which mailboxes were already disabled (so re-runs are idempotent), and produces an auditable CSV log. The operational need is scale: what takes minutes per mailbox by hand takes seconds across the entire tenant.

### What It Protects Against
**Accidental tenant scope mistakes**: The script forces the operator to type the primary verified domain name before touching anything—a safeguard against running the script against the wrong tenant or copy-pasting the command into the wrong PowerShell window. A typo aborts immediately with no changes made.

**Silent partial failures**: The script wraps each mailbox operation in try-catch, logs every outcome (OK, SKIPPED, FAILED), and displays per-mailbox error messages so the operator can see exactly which mailboxes succeeded, were already disabled, or encountered permission or service errors.

**Unnecessary re-processing**: The script checks `EventsFromEmailEnabled` before calling `Set-MailboxCalendarConfiguration`; if already disabled, it records SKIPPED instead of re-applying the setting, making re-runs fast and clean.

**Lost audit trail**: All results are exported to a timestamped CSV on the operator's Desktop with the tenant domain name in the filename, ensuring every run is logged and discoverable.

### Invariants
- Exchange Online connectivity must be established (via `Get-ConnectionInformation` or `Connect-ExchangeOnline`).
- Microsoft Graph must be connected with at least `Organization.Read.All` scope to fetch the tenant name and primary domain for confirmation.
- The operator must correctly type the tenant's primary verified domain name to proceed; any typo aborts the script.
- Every mailbox returned by `Get-Mailbox -RecipientTypeDetails UserMailbox,SharedMailbox` must be reachable by `Get-MailboxCalendarConfiguration` and `Set-MailboxCalendarConfiguration`; mailboxes with permission issues or service errors are caught and logged.

### Evolution Notes
This file was introduced in the initial commit and has not changed since. It arrived fully formed as part of moving two "originally-promised commands" from the Planned list into the actual codebase. The design—tenant confirmation via domain typing, per-mailbox try-catch logging, CSV export—was established from the first commit and remains unchanged.

### Change Log
- 2026-05-08: Initial commit; added disable-autocalevents with tenant confirmation safeguard, per-mailbox error handling, and CSV logging.