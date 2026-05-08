# get-mailboxperms.ps1
# Shows who has delegated access (Full Access and Send As) to a specific mailbox.
# Filters out NT AUTHORITY / S-1-5 system ACEs automatically.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false }

$identity = Read-Host "Mailbox to inspect (UPN or primary SMTP)"

try {
    $mbx = Get-Mailbox -Identity $identity -ErrorAction Stop
} catch {
    Write-Host "Mailbox not found: $identity" -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "  Mailbox: $($mbx.PrimarySmtpAddress) [$($mbx.RecipientTypeDetails)]" -ForegroundColor Cyan
Write-Host ""

# Full Access
Write-Host "--- Full Access ---" -ForegroundColor Yellow
try {
    $fullAccess = Get-MailboxPermission -Identity $mbx.PrimarySmtpAddress |
        Where-Object {
            $_.User -notlike "NT AUTHORITY*" -and
            $_.User -notlike "S-1-5*" -and
            $_.AccessRights -contains "FullAccess" -and
            -not $_.Deny
        }
    if ($fullAccess) {
        $fullAccess | ForEach-Object {
            Write-Host ("  {0,-40} {1}" -f $_.User, ($_.AccessRights -join ", "))
        }
    } else {
        Write-Host "  None"
    }
} catch {
    Write-Host "  Unable to retrieve: $_" -ForegroundColor Red
}

# Send As
Write-Host ""
Write-Host "--- Send As ---" -ForegroundColor Yellow
try {
    $sendAs = Get-RecipientPermission -Identity $mbx.PrimarySmtpAddress |
        Where-Object {
            $_.Trustee -notlike "NT AUTHORITY*" -and
            $_.Trustee -notlike "S-1-5*" -and
            $_.AccessRights -contains "SendAs"
        }
    if ($sendAs) {
        $sendAs | ForEach-Object { Write-Host "  $($_.Trustee)" }
    } else {
        Write-Host "  None"
    }
} catch {
    Write-Host "  Unable to retrieve: $_" -ForegroundColor Red
}

Write-Host ""
