## Public\inherit-permissions.ps1

### What This File Does
This script resets NTFS folder permissions so a folder inherits access rules from its parent directory again, rather than maintaining a locked-down set of explicit ACL entries. When an MSP engineer runs it, they point it at a folder path, review what explicit permissions are currently blocking inheritance, optionally re-enable inheritance while preserving existing access during the transition, and optionally strip out the explicit rules that were causing the lockdown. It's a pure local Windows filesystem tool with no M365 or Exchange dependencies.

### Why It Exists
NTFS ACLs often become corrupted or over-locked during folder migrations—particularly when someone copies a folder tree between volumes or drives and then manually adds Allow or Deny rules to debug access issues. These explicit rules accumulate and prevent the normal inheritance chain from the parent folder from taking effect, leaving folders with broken or overly-restrictive permissions. Rather than manually editing each ACL in the GUI (or writing one-off `takeown` and `icacls` commands), this script automates the common remediation pattern: re-enable inheritance safely without briefly breaking access, then offer to clean up the explicit junk that's no longer needed.

### What It Protects Against
1. **Brief access loss during inheritance re-enablement**: The script calls `SetAccessRuleProtection($false, $true)` with the `preserveInheritance` flag set to `$true`, ensuring that inherited rules from the parent are kept in place during the transition so the folder doesn't momentarily lose all access.
2. **Accidentally stripping rules that were intentionally added**: Before removing explicit ACEs, the script lists them and asks for explicit confirmation—and only removes them if the user types 'y', preventing accidental loss of delegated permissions.
3. **Attempting to modify files that aren't folders**: The script validates that the path is a container (folder), not a file, and aborts if it isn't.
4. **Working on paths that don't exist**: Early path validation catches typos or stale paths before any ACL operations.
5. **Permission-denied failures without guidance**: If the Set-Acl call fails (almost always because the user doesn't own the folder), the script catches the exception and suggests the `takeown` command to resolve it.

### Invariants
- The target path must exist and must be a folder (directory), not a file.
- The user running the script must have permission to modify the ACL on the target folder—typically because they are the owner or a member of the local Administrators group.
- When re-enabling inheritance, the parent folder's permission model must be well-formed and suitable as the source of inherited rules (this is assumed; the script does not validate the parent).
- The folder's ACL must be readable via `Get-Acl` before any modification is attempted.

### Evolution Notes
This script was introduced in a single commit on 2026-05-08 as a new file and has not changed since. It arrived fully formed with all its current safeguards, two-step flow (re-enable inheritance, then optionally strip explicit rules), and error-handling hints already in place. No subsequent refinements, bug fixes, or feature additions have been made.

### Change Log
- 2026-05-08: Initial commit. Script added to public module as part of bringing the "inherit-permissions" command from the Planned list into production, alongside disable-autocalevents.