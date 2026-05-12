## Public\add-mailboxperms.ps1

### What This File Does
This script grants delegated mailbox access permissions to a user in Exchange Online by prompting an MSP helpdesk engineer for a target mailbox and trustee, then applying either Full Access and/or Send As rights through the appropriate Exchange cmdlets. It serves as an interactive wrapper around `Add-MailboxPermission` and `Add-RecipientPermission` that validates both identities exist before attempting to grant anything.

### Why It Exists
Exchange Online permission delegation is a common helpdesk task—users need to access shared mailboxes, managers need Send As rights on department accounts, or IT needs to grant admins temporary access—but the raw cmdlets require the engineer to know which cmdlet handles which permission type and how to construct the parameters correctly. This script collapses that cognitive load into a guided Q&A flow, eliminating the need to juggle two separate cmdlet syntaxes and reducing the chance of applying the wrong permission type. The auto-mapping prompt specifically addresses the UX friction point where Full Access is granted but the mailbox doesn't appear in Outlook unless that flag is set, leading to confused support calls.

### What It Protects Against
**Invalid identity lookup**: The script validates that the target mailbox exists and the trustee exists in Exchange *before* attempting any permission grants, preventing silent failures or cryptic "user not found" errors mid-operation. **Partial success on error**: Each permission type (Full Access and Send As) is wrapped in its own try-catch block so that if one fails, the other can still succeed; the engineer sees exactly which operation failed rather than getting a blanket exception. **Silent no-ops**: If the engineer answers "no" to both Full Access and Send As prompts, the script exits early with a message rather than executing nothing in the background and leaving the engineer uncertain whether it actually did anything.

### Invariants
- Exchange Online must be reachable; the script will auto-connect if not already connected.
- The `$identity` input must resolve to a valid mailbox (user, shared, or resource mailbox).
- The `$trustee` input must resolve to a valid Exchange recipient (the user being granted rights).
- At least one of Full Access or Send As must be selected, otherwise the script exits.

### Evolution Notes
This file was introduced as part of the initial mailbox permissions family in a single commit and has not been modified since. It represents the completed, stable design intent for interactive permission granting without subsequent refinement or bugfixes.

### Change Log
- 2026-05-08: Initial commit introducing add-mailboxperms as part of the mailbox permissions family (alongside get-mailboxperms and get-userperms).