if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false -DisableWAM }

$identity = Read-Host "Mailbox (UPN or primary SMTP)"

try {
    $mbx = Get-Mailbox -Identity $identity -ErrorAction Stop
} catch {
    Write-Host "Mailbox not found: $identity" -ForegroundColor Red
    return
}

$archiveEnabled = $mbx.ArchiveStatus -eq 'Active'

Write-Host ""
Write-Host "  $($mbx.DisplayName) [$($mbx.PrimarySmtpAddress)]" -ForegroundColor Cyan
Write-Host ""

Write-Host "--- Archive Status ---" -ForegroundColor Yellow
if ($archiveEnabled) {
    Write-Host "  In-Place Archive:   Enabled" -ForegroundColor Green
} else {
    Write-Host "  In-Place Archive:   Not enabled" -ForegroundColor DarkGray
    return
}

Write-Host ""
Write-Host "--- Archive Stats ---" -ForegroundColor Yellow
try {
    $stats = Get-MailboxStatistics -Identity $mbx.PrimarySmtpAddress -Archive -ErrorAction Stop
    Write-Host ("  Size:               {0}" -f $stats.TotalItemSize)
    Write-Host ("  Item Count:         {0}" -f $stats.ItemCount)
} catch {
    Write-Host "  Unable to retrieve archive statistics: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "--- Archive Quota ---" -ForegroundColor Yellow
Write-Host ("  Quota:              {0}" -f $mbx.ArchiveQuota)
Write-Host ("  Warning Quota:      {0}" -f $mbx.ArchiveWarningQuota)
Write-Host ("  Auto-Expanding:     {0}" -f $mbx.AutoExpandingArchiveEnabled)
Write-Host ""
