## Public\get-allusers.ps1

### What This File Does

This script generates a comprehensive inventory of all users in an M365 tenant, displaying their display name, UPN, assigned licenses, last mailbox login time, and status notes. The results are printed to the console as a formatted table and exported to a timestamped CSV file on the user's desktop. It requires connections to both Microsoft Graph (for user and license data) and Exchange Online (for mailbox activity metrics).

### Why It Exists

M365 helpdeks need a quick, single-run report to answer questions like "who hasn't logged in in six months?" or "which users have no licenses assigned?" without requiring Entra ID Premium licenses (which gate access to sign-in logs). By combining Graph's user directory with Exchange mailbox statistics—a cheaper, more universally available data source—the script provides the essentials of a user audit report that works in any tenant.

### What It Protects Against

**Null-UPN orphan accounts crashing the entire export.** During the initial release, the script would call `.ToLower()` on every user's UPN without checking whether the UPN field existed. Orphaned or partially-provisioned directory objects (rare but real, from failed provisioning or incomplete deletions) have no UPN assigned. When the script hit such an account, it threw a NullReferenceException and aborted, killing the report for the entire tenant. The fix (committed in 1.1.0) guards the UPN lookup with an explicit null check and surfaces orphans in the export with the note "No UPN — orphan account" rather than crashing. The script deliberately does not skip orphans because surfacing them is exactly the point of a user inventory report.

### Invariants

- Both Exchange Online and Microsoft Graph connections must exist before the script runs (the script will attempt to establish them if they don't).
- Every licensed SKU in the tenant must be retrievable via `Get-MgSubscribedSku` so that the SKU lookup table can map SKU IDs to human-readable product names.
- Mailbox statistics must be queryable without time limits; the script uses `-ResultSize Unlimited` and assumes the query completes.
- User UPNs (when present) must be case-insensitive matchable to mailbox statistics UPNs for the last-login lookup to work.

### Evolution Notes

This file was introduced in the initial release (2026-05-07) with a critical defensive gap: it did not handle accounts with missing UPN fields. When the 1.1.0 release shipped on 2026-05-11, it was patched to check for null UPN before attempting string operations, and to label such accounts as orphans rather than silently failing or misclassifying them. No other functional changes have been made. The extensive comments explaining the null-UPN guard were added at that time to document the fix and prevent future regressions.

### Change Log

- 2026-05-11: Defensive fix—get-allusers no longer aborts on accounts with null UPN; orphans now surface in the export with the note "No UPN — orphan account".
- 2026-05-07: Initial Release.