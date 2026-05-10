# ADR-0020: Defensive guard around `Disconnect-MgGraph` in `kill-graph`

**Date:** 2026-05-11
**Status:** Accepted
**Decider:** Steve Vella

---

## Context

`kill-graph.ps1` is the operator's one-liner for tearing down the current Microsoft Graph PowerShell session. Engineers use it for three common reasons:

1. They consented to a narrow `-Scopes` list during a previous script and now need a broader one — `Connect-MgGraph` reuses the existing token rather than incrementally adding scopes, so the only way to consent fresh is to disconnect first.
2. They are switching between tenants.
3. They are wrapping up a session and want to invalidate the local token.

The 1.0.x implementation was two lines:

```powershell
Disconnect-MgGraph | Out-Null
Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Green
```

`Disconnect-MgGraph` throws a terminating error when there is no active session. So if an engineer ran `kill-graph` "just to be sure" — or twice in a row — they were greeted with a red exception trace ("There is no active Microsoft Graph session") even though the desired end state ("no Graph session") was already true. This created a confusing user experience and made the script feel buggy.

---

## Decision

`kill-graph.ps1` now:

1. Calls `Get-MgContext` first.
2. If the context is `$null` (no active session), prints an informational DarkGray message ("No active Microsoft Graph session.") and returns cleanly.
3. If a context exists, captures an identifier (TenantId → Account → "active session" fallback) for the success message before disconnecting.
4. Wraps the `Disconnect-MgGraph` call in `try/catch` so any transient error (network blip during token revocation, internal SDK glitch) is reported as an operator-visible red message rather than a raw exception trace.
5. Uses `return`, not `exit`, per ADR-0016.

---

## Rationale

**Why not let it throw?** The error is informational, not actionable — there is nothing the operator can do differently. Throwing a red exception for the equivalent of "there's nothing to do" trains operators to ignore red text, which is harmful in a tool where red text otherwise means a real failure.

**Why capture an identifier before disconnecting?** Once `Disconnect-MgGraph` returns, `Get-MgContext` will return null — so we can't reach back for the tenant or account name to mention in the success line. Capturing it up front gives the operator a one-line confirmation of what they actually disconnected from, which is especially useful when juggling multiple tenants.

**Why the TenantId → Account → fallback chain?** `TenantId` is the most reliable identifier for "which tenant am I leaving?" but is occasionally empty in unusual contexts (some interactive auth flows return a context with no tenant populated). `Account` (the signed-in UPN) is the next best — humans recognise it immediately. The generic "active session" fallback exists so we never print "Disconnected from ." or similar visual artifact if both fields are unexpectedly empty.

**Why try/catch around the disconnect?** `Disconnect-MgGraph` is a network call: it revokes the local token and (in some configurations) makes a server-side revocation call. Network calls fail transiently. Without the try/catch, a transient failure surfaces as a stack trace; with it, the operator sees a normal red one-liner that they can retry.

---

## Alternatives considered

**`-ErrorAction SilentlyContinue` on `Disconnect-MgGraph`.** Suppresses the error but also suppresses any genuine failure — the operator gets a green "Disconnected" message even if the disconnect didn't happen. Misleads the audit trail. Ruled out.

**`try { Disconnect-MgGraph } catch { }` with no explicit guard.** Works for the no-session case but, like the option above, also swallows real failures. Ruled out.

**Move the script to `Private/` as a helper rather than exposing it as a `toolkit` command.** The script is genuinely useful directly — engineers run it interactively far more often than other scripts call it. Keeping it in `Public/` is correct. (No `Private/` directory exists yet anyway — see ADR-0003 for the per-script-self-contained model.)

---

## Consequences

- Idempotent invocation: running `kill-graph` when nothing is connected is now a no-op with a one-line informational message instead of a red exception. Safe to run repeatedly or "just in case".
- The success message now identifies the tenant (or account) that was disconnected, which is useful evidence in screenshare debugging sessions when the operator can't remember which tenant they were authenticated against.
- Genuine disconnect failures (network, token-server hiccup) are now reported as normal red one-liners, not stack traces — the operator can retry rather than file a bug.
- `Microsoft.Graph.Authentication` is the only Graph submodule needed by this script (declared in `RequiredModules` per ADR-0022). It's also a transitive dependency of every other Graph submodule, so the explicit declaration is belt-and-braces.

---

## Inner workings of the rewritten script (reference)

The new `kill-graph.ps1` has three named branches. Future maintainers should be able to read this section and immediately know what every line in the script is for.

**Branch A — no active session.**

```
$context = Get-MgContext
if (-not $context) {
    Write-Host "  No active Microsoft Graph session." -ForegroundColor DarkGray
    return
}
```

`Get-MgContext` is a pure read against process state — it never throws. `$null` means there's nothing to do. We print in DarkGray (the project's convention for informational output that is neither success nor failure) and `return` out so the operator can chain another command without seeing a red error.

**Branch B — capture identifier, then disconnect.**

```
$identifier = if ($context.TenantId)   { "tenant $($context.TenantId)" }
              elseif ($context.Account) { "account $($context.Account)" }
              else                      { "active session" }

try {
    Disconnect-MgGraph | Out-Null
    Write-Host "  Disconnected from Microsoft Graph ($identifier)." -ForegroundColor Green
} catch {
    Write-Host "  Failed to disconnect: $_" -ForegroundColor Red
}
```

The TenantId / Account / fallback chain is evaluated up front because once `Disconnect-MgGraph` succeeds, `$context` is stale (the live process state has been cleared) and we'd have no way to reach back for the identifier. Wrapping the disconnect in try/catch ensures any failure is visible without being a stack-trace wall.

**Branch C — caught failure.**

The `catch` block prints the failure in red. The operator's recourse is to re-run the script (transient failures usually clear on retry) or, if it persists, to use `Disconnect-MgGraph -Force` manually and inspect the underlying error. We deliberately do NOT add `-Force` automatically — `-Force` can paper over a real underlying problem and we'd rather the operator see the failure once.

---

## Related files

- `Public/kill-graph.ps1` — the rewritten script
- `StevesScriptorium.psd1` — `Microsoft.Graph.Authentication` declared in `RequiredModules` (per ADR-0022)
- `CHANGELOG.md` — entry under `[1.1.0]` → `### Fixed`
- ADR-0003 — per-script self-contained connections (why this stays in `Public/` and isn't promoted to a helper)
- ADR-0016 — `return` not `exit` in public scripts (why both branches use `return`)
- ADR-0022 — explicit Graph submodule pinning (why `Microsoft.Graph.Authentication` is in `RequiredModules`)
