# ADR-0019: Migrate `check-mailflow` from `Get-MessageTrace` to `Get-MessageTraceV2`

**Date:** 2026-05-11
**Status:** Accepted
**Decider:** Steve Vella

---

## Context

`check-mailflow.ps1` is the operator's first-line tool for "did this email actually get delivered?" investigations. The 1.0.x implementation called `Get-MessageTrace` and `Get-MessageTraceDetail`, both of which Microsoft has deprecated in the ExchangeOnlineManagement module starting at version 3.7.0 in favour of `Get-MessageTraceV2` and `Get-MessageTraceDetailV2`. The deprecation is scheduled to become a hard removal in a subsequent module release (Microsoft has historically given ~6 months notice and then removed deprecated message-trace cmdlets without further warning).

Engineers updating their ExchangeOnlineManagement module would silently see `check-mailflow` start returning empty results or throwing "command not recognised" — without any code change on our side. Because the script is the team's primary mail-flow tool, breaking it on a routine module update is unacceptable.

---

## Decision

`check-mailflow.ps1` now uses `Get-MessageTraceV2` for the search and `Get-MessageTraceDetailV2` for the drill-down. The manifest's `RequiredModules` minimum version for `ExchangeOnlineManagement` is bumped from `3.0.0` to `3.7.0` to guarantee both V2 cmdlets are present.

The output schema (column order, column names) shown to the operator and written to the CSV is preserved exactly. Engineer muscle memory is unchanged.

---

## Rationale

**Forward-only.** The V1 cmdlets are going away; there is no benefit to maintaining a fallback path. A single rewrite is cleaner than a `try V2 / catch / fall back to V1` shim that will need to be torn out anyway.

**Schema preservation.** The script's output is the operator's working surface. We `Select-Object` the V2 result rows down to the same column set the V1 script produced (`Received`, `SenderAddress`, `RecipientAddress`, `Subject`, `Status`, `ToIP`, `FromIP`, `Size`, `MessageId`). The V2 cmdlet returns additional properties that we deliberately don't expose, so the operator's table looks identical.

**Explicit pagination.** V2 caps each call at 5000 rows and expects the caller to paginate using `-StartingRecipientAddress` as a continuation cursor. We do this in a `while($true)` loop guarded by:
1. An end-of-results detector — a partial page (fewer rows than `PageSize`) means we've hit the tail.
2. A safety cap (10000 rows total) — protects against unfiltered queries on busy tenants paginating indefinitely. When tripped, the operator sees a clear yellow warning.
3. A defensive cursor null-check — if the cursor field is unexpectedly empty we bail rather than re-issuing the same query forever.

**Drill-down recipient inference.** `Get-MessageTraceDetailV2` requires `-RecipientAddress` alongside `-MessageId` (V1 did not). The operator typically pastes a `MessageId` from the table they're already looking at — so we look the recipient up from the matching row in `$results` rather than re-prompting. If the lookup fails (rare — e.g. they pasted a MessageId from somewhere else), we fall back to the recipient filter they originally typed. If both are unavailable, we abort with a red error explaining the issue rather than calling the cmdlet with a missing required parameter.

---

## Alternatives considered

**Keep V1, pin `ExchangeOnlineManagement` to a pre-deprecation version.** Buys time but kicks the can down the road; eventually the module would need security patches and the V1 cmdlets would still go away. Also forces all installers onto an older module version. Ruled out.

**Try-V2-then-V1 fallback.** Self-defeating — the whole point of the migration is to be on V2 ahead of the hard removal. A fallback path adds code surface to maintain and would silently let the script keep "working" on the V1 path until the day it doesn't, which is the failure mode we're trying to prevent. Ruled out.

**Keep using the deprecated V1 cmdlets but suppress the deprecation warning.** Deferring a known breaking change for cosmetic reasons. Ruled out.

**Wrap the V2 cmdlets in a private helper and call the helper from `check-mailflow`.** A reasonable refactor, but premature: only one script in the toolkit uses message-trace cmdlets. ADR-0003 (per-script self-contained scripts) argues against pulling shared logic out unless it's used in more than one place. If/when other scripts need message-trace, revisit.

---

## Consequences

- `ExchangeOnlineManagement` minimum version is now 3.7.0. Operators on older versions will be blocked at `Install-Module`/`Update-Module` time with a clear version-conflict error rather than getting a silently-broken `check-mailflow`.
- The `[Unreleased]` → `1.1.0` CHANGELOG entry calls this out under `### Changed` so anyone reading the diff understands why the dependency floor moved.
- Future Microsoft Graph SDK / EXO module changes that touch the message-trace surface should re-read this ADR — the explicit pagination loop is the most opinionated piece and would need updating if the cursor parameter name or the per-call limit changes.

---

## Inner workings of the rewritten script (reference)

For future maintainers, here is what `check-mailflow.ps1` does step by step after the rewrite:

1. **Connection.** `Connect-ExchangeOnline -ShowBanner:$false` if there is no current connection (per ADR-0003 every public script self-connects).
2. **Operator inputs.** Sender, recipient, and hours-back. Hours is clamped to 168 (the V2 documented maximum window); without the clamp the cmdlet rejects oversize windows server-side with a less actionable error.
3. **Splat construction.** `StartDate`, `EndDate`, `PageSize = 1000` always present; `SenderAddress` and `RecipientAddress` added only if non-empty (an empty string would over-filter to zero rows).
4. **Pagination loop.**
   - Issue the cmdlet with the current cursor (none on the first call).
   - Project each returned row through `Select-Object` to the V1 column set, append to `$results`.
   - Stop if the safety cap (10000 rows) is hit — set `$truncated = $true` and break.
   - Stop if the page is shorter than `PageSize` — that's the natural end.
   - Otherwise, set the cursor to the recipient on the last row and loop.
5. **Truncation warning.** If `$truncated`, print a yellow `[WARN]` so the operator knows the result is partial and should tighten the filter.
6. **Display + optional CSV export.** `Format-Table -AutoSize` for on-screen, then prompt for CSV. CSV path follows the project convention (Desktop, dated filename — see ADR-0004).
7. **Drill-down (optional).** Operator pastes a `MessageId`. We resolve the recipient from the matching row in `$results` (most common case), or fall back to the originally-entered recipient filter, or bail with a red error. Then `Get-MessageTraceDetailV2` is called with all three required parameters and the result projected to `Date, Event, Action, Detail`.

The script is approximately 110 lines including comments — the comment density is high deliberately (per the project's session-specific commenting policy at the time this ADR was written) so future readers can follow the V1→V2 reasoning at every decision point without re-deriving it.

---

## Related files

- `Public/check-mailflow.ps1` — the rewritten script
- `StevesScriptorium.psd1` — `RequiredModules` entry for `ExchangeOnlineManagement` bumped to 3.7.0
- `CHANGELOG.md` — entry under `[1.1.0]` → `### Changed`
- ADR-0003 — per-script self-contained connections (why we don't extract a shared message-trace helper yet)
- ADR-0004 — Desktop CSV destinations (drives the export path)
- ADR-0008 — minimum-version pinning in `RequiredModules` (the pattern this ADR applies to EXO)
- Microsoft docs: https://learn.microsoft.com/en-us/powershell/module/exchange/get-messagetracev2
