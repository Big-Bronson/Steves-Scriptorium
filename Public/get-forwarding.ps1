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
Write-Host "--- Forwarding ---" -ForegroundColor Yellow

$hasForward = $false

if ($mbx.ForwardingSmtpAddress) {
    Write-Host ("  SMTP Forward:       {0}" -f $mbx.ForwardingSmtpAddress) -ForegroundColor Green
    $hasForward = $true
}

if ($mbx.ForwardingAddress) {
    Write-Host ("  Internal Forward:   {0}" -f $mbx.ForwardingAddress) -ForegroundColor Green
    $hasForward = $true
}

if ($hasForward) {
    Write-Host ("  Keep Local Copy:    {0}" -f $mbx.DeliverToMailboxAndForward)
} else {
    Write-Host "  No forwarding configured." -ForegroundColor DarkGray
}

Write-Host ""
