# get-userperms.ps1
# Shows which mailboxes a given user has delegated access to (Full Access
# and Send As). Iterates all mailboxes — warn the operator this is slow on
# large tenants.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false -DisableWAM }

$upn = Read-Host "User UPN to check delegated access for"

# Verify the user exists as a recipient
$trustee = Get-Recipient -Identity $upn -ErrorAction SilentlyContinue
if (-not $trustee) {
    Write-Host "Recipient not found: $upn" -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "  Scanning all mailboxes for delegated access granted to: $upn" -ForegroundColor Cyan
Write-Host "  (This may take a moment on large tenants.)" -ForegroundColor DarkGray
Write-Host ""

$mailboxes = Get-Mailbox -ResultSize Unlimited

$fullAccessList  = [System.Collections.Generic.List[string]]::new()
$sendAsList      = [System.Collections.Generic.List[string]]::new()
$i = 0

foreach ($mbx in $mailboxes) {
    $i++
    Write-Progress -Activity "Scanning mailboxes" `
        -Status "$($mbx.PrimarySmtpAddress) ($i of $($mailboxes.Count))" `
        -PercentComplete (($i / $mailboxes.Count) * 100)

    $fa = Get-MailboxPermission -Identity $mbx.PrimarySmtpAddress -User $upn -ErrorAction SilentlyContinue |
        Where-Object { $_.AccessRights -contains "FullAccess" -and -not $_.Deny }
    if ($fa) { $fullAccessList.Add($mbx.PrimarySmtpAddress) }

    $sa = Get-RecipientPermission -Identity $mbx.PrimarySmtpAddress -Trustee $upn -ErrorAction SilentlyContinue |
        Where-Object { $_.AccessRights -contains "SendAs" }
    if ($sa) { $sendAsList.Add($mbx.PrimarySmtpAddress) }
}

Write-Progress -Activity "Scanning mailboxes" -Completed

Write-Host "--- Full Access ($($fullAccessList.Count)) ---" -ForegroundColor Yellow
if ($fullAccessList.Count -eq 0) { Write-Host "  None" }
else { $fullAccessList | ForEach-Object { Write-Host "  $_" } }

Write-Host ""
Write-Host "--- Send As ($($sendAsList.Count)) ---" -ForegroundColor Yellow
if ($sendAsList.Count -eq 0) { Write-Host "  None" }
else { $sendAsList | ForEach-Object { Write-Host "  $_" } }

Write-Host ""
