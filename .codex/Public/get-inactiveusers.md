## Public\get-inactiveusers.ps1

### What This File Does
When an MSP engineer runs this script against a customer M365 tenant, it identifies enabled user accounts that have not logged in or accessed their mailbox within a configurable threshold (default 90 days), flags accounts that have never logged in at all, and exports the results to a timestamped CSV file on the engineer's desktop for review, remediation, or license optimization. The script operates in two distinct modes: on-premises Active Directory environments and cloud-only M365 tenants, automatically detecting which data sources to query based on the engineer's initial input.

### Why It Exists
Inactive accounts are a persistent operational and security liability—they consume licenses, create orphaned mailboxes, present credential exposure risk if not promptly disabled, and complicate compliance audits. While raw `Get-ADUser`, `Get-MailboxStatistics`, and `Get-MgUser` cmdlets can retrieve inactivity data, they require the engineer to manually correlate results across multiple sources, calculate cutoff dates, filter by enabled status, and normalize output across on-prem and cloud architectures. This script consolidates that workflow into a single interactive tool that eliminates manual date math, normalizes terminology ("Never Logged In" vs. "No Mailbox Activity"), and handles the credential/connection logic that differs between hybrid and cloud-native tenants.

### What It Protects Against
The script guards against several practical failures:

- **Connection state ambiguity**: It checks for existing Exchange Online and Graph connections before attempting to establish new ones, preventing spurious re-authentication or session conflicts.
- **Null comparison crashes**: It explicitly guards against `LastLogonDate -eq $null` (on-prem) and missing mailbox statistics (cloud), which would cause filtering logic to fail silently or throw unhandled exceptions.
- **Case-sensitivity data loss**: It normalizes UPNs to lowercase when indexing mailbox stats, preventing mismatches in hashtable lookups that would incorrectly classify a user as having "No Mailbox Activity."
- **Empty input defaults**: It provides a sensible 90-day default if the engineer presses Enter without typing a threshold, preventing the script from halting on invalid input.
- **Orphaned mailboxes in cloud tenants**: By cross-referencing Graph users with actual mailbox statistics, it distinguishes between accounts that have never been assigned a mailbox and those with inactive mailboxes.

### Invariants
For this script to execute correctly, the following must hold true:

1. The engineer running the script must have appropriate permissions: `Get-ADUser` rights for on-prem mode, or `User.Read.All` + `Directory.Read.All` Graph scopes and Exchange Online admin access for cloud mode.
2. The ActiveDirectory PowerShell module must be installed and available on the system for on-prem mode; Exchange Online Management and Microsoft.Graph modules must be available for cloud mode.
3. The cutoff date calculation assumes the system clock is accurate (it uses `Get-Date` without UTC coercion).
4. Cloud-only mode assumes that `Get-MailboxStatistics` returns a `UserPrincipalName` property; if the mailbox lacks a UPN reference, it will silently not appear in the `$statsIndex` hashtable and be flagged as "No Mailbox Activity."
5. The Desktop export path must be writable (uses `$env:USERPROFILE\Desktop`).

### Evolution Notes
This script was introduced in the initial release (May 7, 2026) with full feature parity across on-prem and cloud modes. On May 8, 2026, it underwent a single refactoring: the cloud-mode user enumeration loop was converted from a `foreach` statement to a pipeline-style `$mgUsers | ForEach-Object` pattern. This change was not driven by a bug or missing feature, but rather by a tooling-wide consistency initiative (visible in the commit message) to align loop patterns across the Spellbook module. The script's core logic—threshold calculation, connection handling, output formatting—has remained stable since inception.

### Change Log
- 2026-05-08: Convert foreach statement to ForEach-Object pipeline pattern for consistency with module conventions.
- 2026-05-07: Initial release with dual on-prem/cloud-only mode support, 90-day default threshold, and CSV export.