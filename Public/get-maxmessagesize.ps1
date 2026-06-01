# get-maxmessagesize.ps1
# Shows the current MaxSendSize and MaxReceiveSize for a mailbox.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false -DisableWAM }

$identity = Read-Host "Mailbox (UPN or primary SMTP)"

try {
    $mbx = Get-Mailbox -Identity $identity -ErrorAction Stop
} catch {
    Write-Host "Mailbox not found: $identity" -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "  $($mbx.DisplayName) [$($mbx.PrimarySmtpAddress)]" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Max Send Size:    $($mbx.MaxSendSize)"
Write-Host "  Max Receive Size: $($mbx.MaxReceiveSize)"
Write-Host ""
