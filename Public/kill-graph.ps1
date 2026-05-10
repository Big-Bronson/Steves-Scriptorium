# kill-graph.ps1
# -----------------------------------------------------------------------------
# Disconnects the current Microsoft Graph PowerShell session.
#
# Why this script exists
# ----------------------
# Many Public/*.ps1 scripts call Connect-MgGraph with a -Scopes list scoped to
# only what they need (per-script self-contained connections — see ADR-0003).
# Once a Graph session is established it persists for the life of the
# PowerShell session, with whatever scopes were consented to on first connect.
# Engineers commonly want to "reset" — typically when:
#   - They consented to a narrow scope and now need a broader one (Graph reuses
#     the existing token until disconnected, so a second Connect-MgGraph with
#     more scopes silently won't add them).
#   - They're switching between tenants.
#   - They're at the end of a session and want to invalidate the local token.
#
# Why the unconditional Disconnect-MgGraph was a bug
# --------------------------------------------------
# The previous two-line implementation called Disconnect-MgGraph without first
# checking that a session existed. When no context was present the cmdlet
# threw a terminating error ("There is no active Microsoft Graph session"),
# which surfaced to the operator as a red wall of text — confusing, since
# "no session to disconnect" is the desired end state. Defensive guard added,
# documented in ADR-0020.
#
# Requires: Microsoft.Graph.Authentication (Get-MgContext, Disconnect-MgGraph)

# Get-MgContext returns $null when there is no active session. We test for
# that explicitly rather than letting Disconnect-MgGraph throw, so the user
# sees a friendly informational message instead of an exception.
$context = Get-MgContext

if (-not $context) {
    # No-op path. DarkGray signals "informational, nothing went wrong" — same
    # convention used elsewhere (e.g. offboard-user SKIPPED rows).
    Write-Host "  No active Microsoft Graph session." -ForegroundColor DarkGray
    # Use `return` not `exit` per ADR-0016 — `exit` from a dot-sourced script
    # terminates the operator's entire PowerShell session.
    return
}

# Capture an identifier for the disconnect message before we tear down the
# session. TenantId is the most reliable field; Account (the signed-in UPN)
# is the next-best fallback; if both are unexpectedly empty we fall back to
# a generic phrase rather than printing "Disconnected from ." or similar.
$identifier = if ($context.TenantId)   { "tenant $($context.TenantId)" }
              elseif ($context.Account) { "account $($context.Account)" }
              else                      { "active session" }

# Wrap the disconnect itself in try/catch so any transient error (network
# blip during token revocation, SDK internal issue) is reported as a normal
# operator-visible failure in red, not a raw exception trace.
try {
    Disconnect-MgGraph | Out-Null
    Write-Host "  Disconnected from Microsoft Graph ($identifier)." -ForegroundColor Green
} catch {
    Write-Host "  Failed to disconnect: $_" -ForegroundColor Red
}
