# check-mailflow.ps1
# -----------------------------------------------------------------------------
# Traces message delivery for a sender/recipient pair within a date range.
# Useful for: "I didn't receive an email from X", "my email to Y bounced",
# investigating spam-filter blocks, verifying connector behaviour.
#
# V1 → V2 migration (see ADR-0019)
# --------------------------------
# This script previously called Get-MessageTrace and Get-MessageTraceDetail.
# Microsoft has deprecated both V1 cmdlets in favour of Get-MessageTraceV2 /
# Get-MessageTraceDetailV2 (shipped with ExchangeOnlineManagement 3.7.0+,
# announced for hard removal in subsequent module releases). The V2 cmdlets
# differ in three ways that matter to this script:
#
#   1. Pagination is now explicit. V1 returned everything in a single call
#      capped at 5000 rows; V2 caps a single call at 5000 rows but expects
#      callers to paginate using -StartingRecipientAddress as a continuation
#      cursor. The result-accumulation loop below implements that pattern.
#
#   2. The drill-down cmdlet (Get-MessageTraceDetailV2) requires a recipient
#      address alongside the MessageId — V1 accepted MessageId alone. We
#      resolve the recipient from the matching row in $results rather than
#      re-prompting the operator, falling back to the originally-entered
#      recipient filter if the row lookup somehow fails.
#
#   3. Result-object property names are unchanged for the columns we display,
#      so the on-screen and CSV output schema is preserved exactly. Engineer
#      muscle memory (column order, column names) is unaffected.
#
# Requires: ExchangeOnlineManagement (3.7.0 or later for V2 cmdlets)

# Self-contained connection per ADR-0003 — every Public script ensures its
# own connection rather than relying on a shared bootstrap step.
if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false }

# --- Operator inputs ------------------------------------------------------
# Both filters are optional; at least one is recommended in practice but the
# cmdlet allows neither (it will then return all messages in the window).
$sender    = Read-Host "Sender address (leave blank to skip filter)"
$recipient = Read-Host "Recipient address (leave blank to skip filter)"
$hours     = Read-Host "How many hours back to search? (default 24, max 168)"
if (-not $hours) { $hours = 24 }

# Clamp to the documented V2 maximum window of 168 hours (10 days). Without
# the clamp the cmdlet rejects oversize windows server-side with a generic
# error; clamping client-side gives a clearer experience.
$hours = [Math]::Min([int]$hours, 168)

$start = (Get-Date).AddHours(-[int]$hours)
$end   = Get-Date

Write-Host "`nSearching message trace ($hours hours)..."

# --- Build the splat ------------------------------------------------------
# PageSize 1000 balances throughput against the chance of needing many
# round-trips. The V2 hard cap per call is 5000; 1000 is enough that most
# real queries complete in a single call without leaving a lot of unused
# capacity if pagination is needed.
$baseParams = @{
    StartDate = $start
    EndDate   = $end
    PageSize  = 1000
}
if ($sender)    { $baseParams.SenderAddress    = $sender }
if ($recipient) { $baseParams.RecipientAddress = $recipient }

# --- Paginated fetch ------------------------------------------------------
# V2 pagination model: the cursor is the recipient address of the last row
# returned, passed back as -StartingRecipientAddress on the next call. The
# loop terminates when a call returns fewer rows than PageSize (meaning we
# hit the end of the matching set) or when we cross the safety cap below.
#
# Safety cap: 10000 rows. An unfiltered query on a busy tenant could in
# principle paginate forever; the cap means a runaway is bounded and the
# operator gets a clear yellow warning rather than a hung session.
$maxRows  = 10000
$results  = New-Object System.Collections.Generic.List[object]
$cursor   = $null
$truncated = $false

while ($true) {
    $params = $baseParams.Clone()
    if ($cursor) { $params.StartingRecipientAddress = $cursor }

    $page = Get-MessageTraceV2 @params

    if (-not $page) { break }

    # Project to the V1 column shape so on-screen and CSV output is unchanged.
    foreach ($row in $page) {
        $results.Add(($row | Select-Object Received, SenderAddress, RecipientAddress, Subject,
                                            Status, ToIP, FromIP, Size, MessageId))
        if ($results.Count -ge $maxRows) { $truncated = $true; break }
    }
    if ($truncated) { break }

    # End-of-results detection: a partial page means there is no next page.
    if ($page.Count -lt $baseParams.PageSize) { break }

    # Advance the cursor to the recipient on the last row of this page.
    $cursor = $page[-1].RecipientAddress
    if (-not $cursor) { break }   # defensive — shouldn't happen, but bail rather than loop forever
}

if ($truncated) {
    Write-Host "  [WARN] Result set truncated at $maxRows rows. Tighten the filter or shorten the window." -ForegroundColor Yellow
}

# --- Display + optional CSV export ----------------------------------------
if ($results.Count -eq 0) {
    Write-Host "No messages found matching those criteria." -ForegroundColor Yellow
    return
}

Write-Host "Found $($results.Count) message(s):`n"
$results | Format-Table -AutoSize

if ((Read-Host "Export to CSV? (y/n)") -eq "y") {
    $path = "$env:USERPROFILE\Desktop\MailTrace_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
    $results | Export-Csv -Path $path -NoTypeInformation
    Write-Host "Exported to $path"
}

# --- Drill-down on a single message ---------------------------------------
# V2 detail cmdlet requires -RecipientAddress in addition to -MessageId. We
# look up the recipient from the row in $results that matches the operator's
# pasted MessageId, which is more reliable than re-prompting them. If that
# lookup fails we fall back to the recipient filter they originally typed
# (if any), and only as a last resort bail with a red error.
if ((Read-Host "`nDrill into delivery detail for a specific message? (y/n)") -ne "y") { return }

$msgId = Read-Host "Paste the MessageId value"
if (-not $msgId) { Write-Host "No MessageId — aborted." -ForegroundColor DarkGray; return }

$matchedRow = $results | Where-Object { $_.MessageId -eq $msgId } | Select-Object -First 1
$drillRecipient = if ($matchedRow) { $matchedRow.RecipientAddress } else { $recipient }

if (-not $drillRecipient) {
    Write-Host "  Cannot drill: V2 detail cmdlet requires a recipient and none could be inferred." -ForegroundColor Red
    Write-Host "  Re-run the trace with a recipient filter, or paste a MessageId from the table above." -ForegroundColor DarkGray
    return
}

Get-MessageTraceDetailV2 -MessageId $msgId `
                          -RecipientAddress $drillRecipient `
                          -StartDate $start `
                          -EndDate $end |
    Select-Object Date, Event, Action, Detail | Format-Table -AutoSize
