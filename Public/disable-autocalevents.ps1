# disable-autocalevents.ps1
# Disables "Events from email" across the entire tenant. Outlook will stop
# auto-creating calendar entries from flight confirmations, hotel bookings,
# and parcel notifications. Loops every user mailbox and shared mailbox.
#
# This is a tenant-wide change. The script forces the operator to type the
# tenant's primary domain to confirm before touching anything.
#
# Requires: Exchange Online (Mailbox role) + Graph (Organization.Read.All)
#           — Graph is used only to fetch the tenant name for confirmation.

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false -DisableWAM }
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "Organization.Read.All" -ContextScope Process
}

# --- Confirm we're aiming at the right tenant -----------------------------
$org = Get-MgOrganization
$tenantName    = $org.DisplayName
$primaryDomain = ($org.VerifiedDomains | Where-Object { $_.IsDefault }).Name

Write-Host ""
Write-Host "  Tenant: $tenantName" -ForegroundColor Cyan
Write-Host "  Domain: $primaryDomain" -ForegroundColor Cyan
Write-Host ""
Write-Host "  This disables 'Events from email' on every user and shared" -ForegroundColor Yellow
Write-Host "  mailbox in this tenant. Outlook will stop auto-creating" -ForegroundColor Yellow
Write-Host "  calendar entries from flight, hotel, and parcel notifications." -ForegroundColor Yellow
Write-Host ""

$typed = Read-Host "Type the primary domain ($primaryDomain) to confirm"
if ($typed -ne $primaryDomain) {
    Write-Host "Confirmation failed. Aborted." -ForegroundColor Red
    return
}

# --- Enumerate and apply --------------------------------------------------
Write-Host ""
Write-Host "Enumerating mailboxes..." -ForegroundColor DarkGray
$mailboxes = Get-Mailbox -RecipientTypeDetails UserMailbox,SharedMailbox -ResultSize Unlimited
Write-Host "Found $($mailboxes.Count) mailbox(es)." -ForegroundColor DarkGray
Write-Host ""

$log = [System.Collections.Generic.List[PSCustomObject]]::new()
$ok = 0; $skipped = 0; $failed = 0; $i = 0

foreach ($mbx in $mailboxes) {
    $i++
    Write-Progress -Activity "Disabling Events from email" `
        -Status "$($mbx.PrimarySmtpAddress) ($i of $($mailboxes.Count))" `
        -PercentComplete (($i / $mailboxes.Count) * 100)

    try {
        $cfg = Get-MailboxCalendarConfiguration -Identity $mbx.PrimarySmtpAddress -ErrorAction Stop
        if (-not $cfg.EventsFromEmailEnabled) {
            $log.Add([PSCustomObject]@{
                UPN    = $mbx.PrimarySmtpAddress
                Status = "SKIPPED"
                Notes  = "Already disabled"
            })
            $skipped++
            continue
        }
        Set-MailboxCalendarConfiguration -Identity $mbx.PrimarySmtpAddress `
            -EventsFromEmailEnabled $false -ErrorAction Stop
        $log.Add([PSCustomObject]@{
            UPN    = $mbx.PrimarySmtpAddress
            Status = "OK"
            Notes  = ""
        })
        $ok++
    } catch {
        $log.Add([PSCustomObject]@{
            UPN    = $mbx.PrimarySmtpAddress
            Status = "FAILED"
            Notes  = $_.Exception.Message
        })
        $failed++
    }
}

Write-Progress -Activity "Disabling Events from email" -Completed

# --- Summary --------------------------------------------------------------
Write-Host ""
Write-Host "  Disabled:    $ok"      -ForegroundColor Green
Write-Host "  Already off: $skipped" -ForegroundColor DarkGray
Write-Host "  Failed:      $failed"  -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'DarkGray' })

$safeDomain = $primaryDomain -replace '\.', '_'
$path = "$env:USERPROFILE\Desktop\AutoCalEvents_${safeDomain}_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
$log | Export-Csv -Path $path -NoTypeInformation
Write-Host ""
Write-Host "Log saved to: $path" -ForegroundColor Cyan
