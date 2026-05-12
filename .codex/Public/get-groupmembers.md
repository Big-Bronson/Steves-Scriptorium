## Public\get-groupmembers.ps1

### What This File Does
This script audits the membership of a Microsoft 365 group by querying the Microsoft Graph API, resolving each member object to a user display name and UPN, and optionally exporting the roster to a timestamped CSV file on the engineer's desktop. It's a targeted investigation tool for helpdesk staff who need to answer "who is actually in this distribution list or security group?" without navigating the M365 admin portal.

### Why It Exists
Distribution lists and security groups accumulate members over months or years, and the admin portal doesn't give a quick, exportable snapshot. When an MSP engineer inherits a customer tenant or responds to "we think John still has access to X," they need to rapidly enumerate group membership, spot non-user objects (like service accounts or nested groups), and document findings. This script eliminates the portal clicks and provides an auditible export.

### What It Protects Against
**Non-user group members:** The script encounters resources that are group members but are not user objects (service principals, mail contacts, or nested groups). Rather than crashing on the `Get-MgUser` lookup, a try-catch wrapper falls back to displaying the object ID and marking it "(non-user object)" so the engineer knows something unusual is in the group and can investigate further.

**Ambiguous group names:** If the user types a group name that matches multiple M365 groups, the script rejects the operation and asks for specificity, preventing silent enumeration of the wrong group.

**Uninitialized Graph context:** If the engineer hasn't authenticated to Graph in the current session, the script automatically connects with the necessary scopes rather than failing cryptically.

**Unsafe filenames:** When exporting to CSV, the script sanitizes the group display name by replacing Windows-illegal characters (`\/:*?"<>|`) with underscores, preventing file-write failures on names like "IT / Security (Prod)".

**Script termination in a dot-sourced context:** The original code used `exit`, which would terminate the engineer's entire PowerShell session if the script was dot-sourced by the toolkit. The May 8 fix changed this to `return`, which exits only the script.

### Invariants
- The Microsoft Graph PowerShell SDK (`Microsoft.Graph.*` modules) must be installed.
- The authenticated user or service principal must hold `Group.Read.All` and `User.Read.All` permissions.
- The group display name must be an exact, case-sensitive match (the script does not perform fuzzy or substring matching).
- The engineer's desktop directory must be writable if CSV export is selected.

### Evolution Notes
The script was introduced as-is in the initial release (May 7) and remained functionally stable. The only change (May 8) was a portability fix that replaced `exit` with `return` on two error paths. This fix was not a logic correction but a session-safety improvement—the original code worked locally but broke the MSP toolkit's dot-sourcing pattern, which invokes all public scripts in the current session scope. Once changed to `return`, the script became safely nestable and prevented accidental user session termination.

### Change Log
- 2026-05-08: Replace `exit` with `return` to prevent terminating the PowerShell session when invoked as a dot-sourced script within the toolkit.
- 2026-05-07: Initial release.