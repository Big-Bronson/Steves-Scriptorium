## Public\kill-graph.ps1

### What This File Does
This script cleanly terminates the current Microsoft Graph PowerShell session by disconnecting the authentication context. When run, it invalidates the locally-cached access token and reports the disconnection status to the operator — or gracefully no-ops if no session exists.

### Why It Exists
Many scripts in the Spellbook module call `Connect-MgGraph` with minimal, script-specific permission scopes (per ADR-0003). Once a Graph session is established, the token persists for the entire PowerShell session — the Graph SDK will not re-consent or add additional scopes on a second `Connect-MgGraph` call, even with a broader `-Scopes` list. Engineers need a way to explicitly reset when they (a) need to request additional permissions after an initial narrow connection, (b) are switching between tenants, or (c) are closing out a session and want to invalidate the token. `kill-graph` provides that reset valve without requiring them to close and reopen their PowerShell terminal.

### What It Protects Against
The original two-line implementation unconditionally called `Disconnect-MgGraph`, which throws a terminating error — `"There is no active Microsoft Graph session"` — when no context exists. This error surfaced as a red wall of exception text to the operator, creating confusion: the desired end state is "no active session," yet the script was screaming that as a failure. The current code guards against this by explicitly checking `Get-MgContext` first and printing a friendly informational message instead. It also wraps the disconnect itself in a try/catch to prevent transient network or SDK errors during token revocation from surfacing as raw exception traces.

### Invariants
- `Microsoft.Graph.Authentication` module must be installed (provides `Get-MgContext` and `Disconnect-MgGraph`).
- If a Graph context exists, it must have at least one of `TenantId`, `Account`, or some sentinel field; the script gracefully degrades to "active session" if both are unexpectedly null.
- The script is dot-sourced (not run in a child process), so `return` correctly exits only the script, not the operator's entire PowerShell session.

### Evolution Notes
This script was introduced in a single commit as a minimal two-liner and has evolved significantly in the subsequent release. The original implementation was defensive-guard-free and would crash on a no-op case. Between the initial commit (2026-05-08) and the 1.1.0 release (2026-05-11), the script was rewritten to (a) check for an active context before attempting disconnect, (b) capture the tenant or account identifier for a meaningful disconnect message, (c) wrap the disconnect in error handling, and (d) use explicit `return` per ADR-0016 to prevent accidental session termination. This evolution was driven by real-world operator feedback (documented in ADR-0020) and represents the module's maturing defensive posture around error messages and edge cases.

### Change Log
- 2026-05-11: Defensive cleanup — added context check, friendlier no-op message, error handling around disconnect, and tenant/account identifier in success message (ADR-0020).
- 2026-05-08: Initial commit — minimal two-line `Disconnect-MgGraph` wrapper with green success message.