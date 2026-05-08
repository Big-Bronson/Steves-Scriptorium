# add-mailboxperms.ps1
# Grants delegated mailbox access (Full Access and/or Send As) to a user.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false }

$identity = Read-Host "Mailbox to grant access TO (UPN or primary SMTP)"
$trustee  = Read-Host "User to grant access (UPN)"

try {
    $mbx = Get-Mailbox -Identity $identity -ErrorAction Stop
} catch {
    Write-Host "Mailbox not found: $identity" -ForegroundColor Red
    return
}

$recipient = Get-Recipient -Identity $trustee -ErrorAction SilentlyContinue
if (-not $recipient) {
    Write-Host "Trustee not found in Exchange: $trustee" -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "  Mailbox:  $($mbx.PrimarySmtpAddress)" -ForegroundColor Cyan
Write-Host "  Trustee:  $trustee" -ForegroundColor Cyan
Write-Host ""

$grantFull   = (Read-Host "Grant Full Access? (y/n)") -eq "y"
$autoMap     = $false
if ($grantFull) {
    $autoMap = (Read-Host "  Enable Outlook auto-mapping (mailbox appears automatically)? (y/n)") -eq "y"
}
$grantSendAs = (Read-Host "Grant Send As? (y/n)") -eq "y"

if (-not $grantFull -and -not $grantSendAs) {
    Write-Host "Nothing to do." -ForegroundColor DarkGray
    return
}

if ($grantFull) {
    try {
        Add-MailboxPermission -Identity $identity -User $trustee `
            -AccessRights FullAccess `
            -AutoMapping $autoMap `
            -ErrorAction Stop | Out-Null
        Write-Host "  [OK] Full Access granted (auto-mapping: $autoMap)" -ForegroundColor Green
    } catch {
        Write-Host "  [FAILED] Full Access: $_" -ForegroundColor Red
    }
}

if ($grantSendAs) {
    try {
        Add-RecipientPermission -Identity $identity -Trustee $trustee `
            -AccessRights SendAs `
            -Confirm:$false `
            -ErrorAction Stop | Out-Null
        Write-Host "  [OK] Send As granted" -ForegroundColor Green
    } catch {
        Write-Host "  [FAILED] Send As: $_" -ForegroundColor Red
    }
}

Write-Host ""
