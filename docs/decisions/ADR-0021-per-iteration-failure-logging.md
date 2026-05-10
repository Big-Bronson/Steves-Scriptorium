# ADR-0021: Per-iteration failure logging in batch operations (`offboard-user` group/role/MFA cleanup)

**Date:** 2026-05-11
**Status:** Accepted
**Decider:** Steve Vella

---

## Context

`offboard-user.ps1` is the project's most safety-critical script. It performs an irreversible series of changes (block sign-in, reset password, revoke sessions, remove memberships, remove admin roles, remove MFA, convert mailbox, etc.) and emits a CSV log on the offboarder's Desktop. The CSV is the engineer's only proof of what was performed; it is the thing they upload to the ticket and the thing auditors look at if a question comes up later.

The 1.0.x implementation of steps 4 (group memberships), 5 (admin roles), and 6 (MFA methods) iterated over per-user collections and silently swallowed individual failures inside the loop. Stripped to essentials, the pattern was:

```powershell
$removed = 0
foreach ($group in $groups) {
    try {
        Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $user.Id
        $removed++
    } catch { }                                            # silent
}
Log-Action "Remove group memberships" "OK" "Removed from $removed group(s)"
```

Two things were wrong:

1. **`$removed` counted attempted iterations, not actual removals** — the increment was inside the `try` but after the call, so a thrown exception skipped it; that part was correct. But the log line was always status `OK`, even when every item in the loop failed. So a partial failure (say, three groups removed and two failed) showed up as "OK, removed from 3" — with the two failures completely invisible.
2. **Failures were lost from the audit log entirely.** No CSV row, no on-screen mention. If the engineer needed to investigate "why is the user still in those two distribution lists?" three weeks later, the offboarding CSV would actively mislead them — it would say everything was fine.

This is unacceptable for a script whose entire reason to exist is producing a trustworthy paper trail.

The same pattern (or a worse variant — step 6 had no `try/catch` at all inside the iteration) applied to admin roles and MFA methods.

---

## Decision

For each batch step in `offboard-user.ps1` (groups, admin roles, MFA methods), we use an **iterate-and-collect** pattern:

1. Track `$succeeded` (count) and `$failures` (a `List[PSCustomObject]` capturing the item identifier and the exception message) separately.
2. After the loop, write **one** summary log line with conditional status:
   - `OK` with success count if no failures.
   - `OK` with both counts if mixed (some succeeded, some failed) — partial success is still a successful overall step, but the Notes column makes the failures discoverable.
   - `FAILED` if zero items succeeded.
3. Write **one log row per failure**, with the item identifier in the Step column (prefixed with `↳` so the parent/child relationship is visible when sorting by timestamp), status `FAILED`, and the exception message in Notes.

The same pattern applies to any future batch operation in this codebase that loops over Graph or Exchange items. It should be the default style for batch loops, not a special case.

---

## Rationale

**Why a summary line plus per-failure rows, instead of one rolled-up summary?**

A single summary line that says "23 succeeded, 2 failed" leaves the engineer no way to tell *which* two failed without re-running diagnostics. Putting each failure in its own CSV row means: opening the CSV, filtering on `FAILED`, reading off the affected items. Zero re-investigation needed.

**Why the `↳` prefix on the failure rows?**

The CSV is sorted by Timestamp by default. The failure rows for one step are interleaved with the summary rows of subsequent steps. The `↳` prefix and consistent label format ("group: Marketing-Distro", "role: Helpdesk Administrator", "phone: mobile [...]") gives the engineer a clear visual chain from each summary line to its associated failure rows when they scan the CSV.

**Why the `OK` / `OK with mixed` / `FAILED` ladder?**

A binary `OK` / `FAILED` would force the engineer to ignore partial-success cases (call them OK and trust the operator to read the Notes) or treat them as full failures (and panic when most of the work actually succeeded). The three-rung ladder matches the actual operational reality: "all good", "all good but check these specific items", "this step did nothing — needs manual follow-up".

**Why a `List[PSCustomObject]` for failures rather than two parallel lists or a hashtable?**

Keeps the per-failure record (item name + error message) atomic. Two parallel lists could drift if a future maintainer adds one append and forgets the other; a hashtable conflates ordering with semantics. A list of typed records is the cleanest container for this shape and is trivial to iterate at the end of the loop.

**Why best-effort name resolution rather than always using the GUID?**

Engineers reading the CSV want to see "group: Marketing-Distro", not "group: a3f8c2e1-...". The displayName lookup happens in the same iteration so it's free in the success path; the GUID fallback handles the rare case where the AdditionalProperties bag is empty or the property access throws.

**Why `-ErrorAction Stop` on the inner cmdlet calls?**

PowerShell defaults non-terminating errors to `Continue`, which would prevent the catch block from firing. `-ErrorAction Stop` promotes them to terminating so the try/catch actually traps them. Without this the failure-counter logic doesn't work.

---

## Alternatives considered

**Crash-on-first-failure (let the outer try/catch handle it).** Aborts the rest of the loop — so a single transient failure on group #4 means we don't even attempt groups #5..#N. Worse outcome than the original silent-swallow. Ruled out.

**Single rolled-up summary string ("23 ok, 2 failed: Marketing-Distro, Sales-Distro") in the Notes column.** Loses information at scale (100 failed items would not fit), and requires the engineer to parse a delimited string out of a CSV cell. Per-row breakdown is strictly more useful. Ruled out.

**Pause and prompt the operator on each failure.** Defeats the point of the script (which is "do all the offboarding steps in one shot, log everything, move on") and doesn't help — the operator can't usefully react to "couldn't remove from this one group" mid-flow. Ruled out.

**Write a separate failure-detail CSV alongside the main one.** Adds file management overhead for the engineer. The unified CSV with a `FAILED` status filter is simpler and uses a single artifact. Ruled out.

---

## Consequences

- The offboarding CSV is now a complete and trustworthy audit trail. Partial failures are visible at a glance.
- The CSV row count is higher than before (one extra row per failure), but the success path produces no extra rows — operators on clean tenants see no difference.
- The `Log-Action` helper function is unchanged. The pattern is implemented entirely at the call site, which means it's easy to apply to other scripts (e.g. a future `bulk-offboard-users.ps1`) by copy-pasting the loop shape.
- Future batch operations in this codebase should follow the same pattern. If you find yourself writing `foreach { try { … } catch { } }` again, stop and apply this ADR's pattern instead.
- The `↳` character is a single Unicode glyph that renders cleanly in Notepad, Excel, VS Code, and the PowerShell console (all UTF-8 capable). If a future export ever needs to be ASCII-safe, replace with `->` and update the convention here.

---

## Inner workings of the rewritten loop (reference)

For future maintainers, here is the rewritten group-removal block annotated step by step. The admin-role and MFA-method blocks follow the same shape.

```powershell
try {
    # Fetch the user's group memberships. Server-side filter on OdataType
    # because Get-MgUserMemberOf returns a heterogeneous list (groups +
    # roles + administrative units etc.).
    $groups = Get-MgUserMemberOf -UserId $user.Id |
        Where-Object { $_.OdataType -eq "#microsoft.graph.group" }

    # Initialise success counter and failure-record list. List<T> rather
    # than @() because we'll be appending in a hot loop and List<T> is
    # O(1) amortised vs O(n) for array concat.
    $succeeded = 0
    $failures  = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($group in $groups) {
        # Best-effort name lookup. Wrapped in its own try because the
        # AdditionalProperties bag access has bitten us with weird Graph
        # response shapes before; if it throws, fall back to the GUID so
        # the failure row still identifies the group unambiguously.
        $groupName = try { $group.AdditionalProperties.displayName } catch { $group.Id }
        if (-not $groupName) { $groupName = $group.Id }

        try {
            # -ErrorAction Stop promotes non-terminating errors to
            # terminating so the catch fires. Without this the catch
            # never runs and the counter still increments.
            Remove-MgGroupMemberByRef -GroupId $group.Id `
                                       -DirectoryObjectId $user.Id `
                                       -ErrorAction Stop
            $succeeded++
        } catch {
            # Capture name + message together as one record. We'll iterate
            # this list once after the loop to emit the per-failure rows.
            $failures.Add([PSCustomObject]@{
                Name  = $groupName
                Error = $_.Exception.Message
            })
        }
    }

    # Conditional summary status. Three branches map to:
    #   - all succeeded → OK
    #   - mixed         → OK but Notes hint at the failures below
    #   - none          → FAILED, needs manual follow-up
    $summary = if ($failures.Count -eq 0) {
        "OK", "Removed from $succeeded group(s)"
    } elseif ($succeeded -gt 0) {
        "OK", "Removed from $succeeded group(s); $($failures.Count) failed (see rows below)"
    } else {
        "FAILED", "$($failures.Count) failure(s) (see rows below); 0 succeeded"
    }
    Log-Action "Remove group memberships" $summary[0] $summary[1]

    # Per-failure rows. Each gets its own log line with the ↳ prefix so
    # the relationship to the summary above is visible when the CSV is
    # sorted by timestamp.
    foreach ($f in $failures) {
        Log-Action "  ↳ group: $($f.Name)" "FAILED" $f.Error
    }
} catch {
    # Outer catch — only reached if the Get-MgUserMemberOf call itself
    # threw (e.g. the user.Id is invalid or Graph is unreachable). At
    # that point there are no individual items to log, so this stays a
    # single-line FAILED entry.
    Log-Action "Remove group memberships" "FAILED" $_
}
```

The MFA-methods block uses a slight variant: it iterates two enumerations (phone methods + TAPs) within the same try, and the per-failure record carries a `Kind` field ("phone" / "tap") so the `↳` prefix can distinguish them in the CSV.

---

## Related files

- `Public/offboard-user.ps1` — steps 4, 5, 6 rewritten to this pattern
- `CHANGELOG.md` — entry under `[1.1.0]` → `### Fixed`
- ADR-0004 — Desktop CSV destinations (where the log lands)
- ADR-0006 — `[OK]` / `[FAILED]` / `[SKIPPED]` status strings (vocabulary used here)
- ADR-0007 — `Generic.List` for log accumulation (why we use `List<T>` not `@()`)
- ADR-0017 — portable password generator (other safety-critical detail in the same script)
