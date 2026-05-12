## Public\get-tenantreport.ps1

### What This File Does

This script generates a single-page health snapshot of an M365 tenant, designed for an MSP engineer to run at first engagement with a new client or as part of a weekly governance check. It gathers data across licensing, security posture (MFA coverage, admin role distribution), cost waste (disabled accounts holding licenses, shared mailboxes with unnecessary SKUs), directory synchronization status, and service health, then displays the results in a formatted console report while collecting flagged issues into a structured list for escalation or follow-up.

### Why It Exists

MSP helpdesk engineers need a fast, single command to answer "what's broken or unusual about this tenant right now?" without chaining together a dozen separate Graph queries or opening multiple portals. The script exists because production M365 tenants often accumulate silent inefficiencies—disabled accounts still burning licensing costs, excessive admin role assignments, users who've never enrolled in MFA—that don't surface in reactive ticket handling. A proactive snapshot report catches these before they become compliance or budget problems. It's also a structured way to onboard a new client: run it once, review the yellow-flagged findings, and you have a baseline understanding of what you inherited.

### What It Protects Against

- **Silent license bleed**: Detects disabled accounts still holding SKUs and shared mailboxes with E5 licenses when they only need a room mailbox license, preventing wasted spend from going unnoticed.
- **Security gaps masquerading as "nobody complained"**: Identifies users with no MFA registered despite global enforcement policies, and flags when Global Administrator role is held by more than three people (indicates lack of PIM or governance).
- **AD Connect failures going dark**: Checks last sync time so hybrid infrastructure doesn't silently stop synchronizing without immediate visibility.
- **Guest account sprawl**: Counts guest accounts to catch unauthorized bulk invitations or deprovisioning failures.
- **Service health blindness**: Surfaces M365 service incidents so you know when user reports are infrastructure-driven rather than tenant misconfiguration.
- **Connection state assumptions**: Explicitly checks for and establishes both Exchange Online and Microsoft Graph connections before querying, preventing silent failures if the session was closed.

### Invariants

- The calling user must hold at least Directory.Reader, User.Reader, and ServiceHealthReader permissions in the tenant (the scope declarations enforce this for Graph).
- Exchange Online and Microsoft Graph modules must be installed locally; the script will attempt to connect but cannot proceed if modules don't exist.
- The tenant must have at least one verified domain and one subscribed license SKU; empty tenants will produce empty sections but not error.
- The Microsoft Graph PowerShell SDK must be version 1.x or later (uses `Get-MgContext`, `Get-MgUser -All`, etc.).
- MFA detection relies on the authentication method API; if a user has deleted all non-password methods, they correctly appear as "no MFA" even if Conditional Access policies mandate it at sign-in.

### Evolution Notes

This file entered the codebase as a complete script in the initial release (May 7, 2026) and has not been modified in its actual logic or output. The second commit on the same day touched `Publish.ps1` (the build/release script), not this file, though the git history artifact shows a second entry for this file. In practical terms: **the script has remained functionally unchanged since release**. This suggests it shipped mature, having been tested against real tenant scenarios before publication, rather than being a minimal viable product that evolved through iteration.

### Change Log

- 2026-05-07: Initial release—shipped as a fully-formed tenant health snapshot tool with nine coverage areas (licensing, admin roles, MFA, disabled accounts, shared mailbox waste, guest counts, AD Connect sync, service health, and role membership visualization).