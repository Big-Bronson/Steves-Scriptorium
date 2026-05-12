## Public\check-mailflow.ps1

### What This File Does
When an MSP engineer suspects email delivery problems — "the customer says they never got an email from their vendor," "our email to them bounced," "we think the spam filter is blocking us" — this script queries the Exchange Online message trace to find matching messages within a time window and displays their delivery status, sender, recipient, subject, and IP routing details. On request, it can drill down into a specific message's full delivery trace (hop-by-hop routing and event log) and export results to CSV for documentation or further analysis.

### Why It Exists
The raw `Get-MessageTrace` cmdlet exists, but it returns raw result sets that require the engineer to know which columns to extract, format them sensibly, and manually cross-reference message IDs with `Get-MessageTraceDetail` if they want the full story. This script wraps that workflow into a guided conversation: it prompts for sender, recipient, and time window; constrains the window to documented limits; fetches and displays the results in a readable table; offers CSV export; and provides an interactive drill-down into any single message's trace without making the engineer re-type the message ID or recipient address. It also handles the connection bootstrap itself rather than relying on an external setup step, so it works standalone.

### What It Protects Against
1. **Runaway pagination queries**: An unfiltered search on a busy tenant could theoretically paginate through tens of thousands of rows indefinitely. The script caps total rows at 10,000 with a clear warning, so a typo or over-broad filter doesn't hang the session.
2. **Undocumented API limits**: Microsoft's V2 API rejects search windows larger than 168 hours (10 days) with a cryptic server-side error. The script clamps the window client-side and explains the limit, giving the engineer a clear yellow warning instead of a confusing rejection.
3. **Missing connection state**: If Exchange Online is not connected, the script fails silently or with a confusing error. The script proactively checks `Get-ConnectionInformation` and connects if needed, so it works even if run in a fresh PowerShell session.
4. **Silent drill-down failures under API evolution**: The V2 cmdlets require both a message ID *and* the recipient address for drill-down; V1 only needed the ID. The script extracts the recipient from the matching row automatically rather than re-prompting, so it survives API changes more gracefully.

### Invariants
- ExchangeOnlineManagement module version 3.7.0 or later must be installed (the V2 cmdlets do not exist in earlier versions).
- The caller must have Exchange Online PowerShell read permissions (permission to execute `Get-MessageTrace` and `Get-MessageTraceDetail`).
- The message trace data store must be available and responding (transient connectivity failures will fail the script, not degrade it gracefully).
- The search window cannot exceed 168 hours; if the caller enters a larger value, it is silently clamped without a confirmation prompt.

### Evolution Notes
This script was introduced in the initial release (2026-05-07) using the deprecated `Get-MessageTrace` and `Get-MessageTraceDetail` V1 cmdlets. Microsoft deprecated both V1 cmdlets in favor of V2 equivalents shipped in ExchangeOnlineManagement 3.7.0, with hard removal planned for a subsequent release. On 2026-05-11, the script was migrated wholesale to the V2 API (Get-MessageTraceV2 and Get-MessageTraceDetailV2) in release 1.1.0. The migration required three substantive changes: (1) explicit pagination using `-StartingRecipientAddress` as a continuation cursor instead of a single all-in-one call, (2) automatic inference of the recipient address from the matched row for drill-down since V2 requires it, and (3) a safety cap on total rows to prevent runaway queries on unfiltered searches. The on-screen output schema and column names were preserved so engineer muscle memory (mental model of what columns appear in what order) did not break. The script itself continues to perform the same operational role for helpdesk engineers, but the plumbing under the hood changed to follow Microsoft's API evolution.

### Change Log
- 2026-05-11: Migrated from deprecated Get-MessageTrace/Get-MessageTraceDetail V1 cmdlets to Get-MessageTraceV2/Get-MessageTraceDetailV2; added explicit pagination with -StartingRecipientAddress cursor; implemented 10,000-row safety cap for runaway queries; bumped ExchangeOnlineManagement floor to 3.7.0.
- 2026-05-07: Initial release with Get-MessageTrace and Get-MessageTraceDetail V1 cmdlets, interactive drill-down, and CSV export.