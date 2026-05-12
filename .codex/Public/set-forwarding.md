## Public\set-forwarding.ps1

### What This File Does
This script configures SMTP forwarding on an Exchange Online mailbox by prompting a helpdesk engineer for a source mailbox and destination address, then applying the forwarding rule after interactive confirmation. It handles the technical detail of setting both the forwarding address and the "deliver to mailbox and forward" flag based on user preference.

### Why It Exists
Email forwarding is a routine helpdesk task—employees leave teams, change roles, or need mail temporarily redirected—but the Exchange Online cmdlets require the engineer to know exact syntax and parameter names. More importantly, forwarding rules can silently fail or be misconfigured if the destination doesn't actually exist in the organization. This script wraps the raw `Set-Mailbox` operation with validation and confirmation steps, reducing the risk of a forwarding rule pointing to a typo'd or invalid address.

### What It Protects Against
**Invalid source mailbox**: The script tries to resolve the source identity before doing anything; if it doesn't exist, it fails cleanly rather than attempting a `Set-Mailbox` operation that would error cryptically.

**Invalid destination address**: The script explicitly calls `Get-Recipient` to verify the destination exists in Exchange. Without this check, an engineer could easily mistype a recipient address, and the forwarding rule would be set to a non-existent address, silently losing mail.

**Accidental overwrite of existing forwarding**: The script displays any existing forwarding rule in yellow before confirmation, so an engineer won't unknowingly replace a previously configured forward.

**Silent loss of local copies**: By asking explicitly whether to keep a copy, the script prevents the common mistake of setting `DeliverToMailboxAndForward` to false when the business need requires the source mailbox to retain incoming mail.

### Invariants
- Exchange Online PowerShell module must be installed and importable
- The engineer must have permissions to read and modify mailbox forwarding rules
- The destination address provided must be resolvable as a recipient in the Exchange organization (internal mailbox, mail contact, or mail-enabled security group)
- The connection to Exchange Online must be active before the script runs (or the auto-connect at the top must succeed)

### Evolution Notes
This file was introduced in a single commit and has not changed since. The script arrived in its current, complete form with source validation, destination validation, confirmation prompts, and visual formatting all present from day one.

### Change Log
- 2026-05-08: Initial commit adding set-forwarding with destination validation and keep-copy confirmation.