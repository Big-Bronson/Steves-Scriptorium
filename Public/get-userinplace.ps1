# get-userinplace.ps1
# Shows the MRM retention policy currently assigned to a mailbox.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false -DisableWAM }

$identity = Read-Host "Mailbox (UPN or primary SMTP)"

try {
    $mbx = Get-Mailbox -Identity $identity -ErrorAction Stop
} catch {
    Write-Host "Mailbox not found: $identity" -ForegroundColor Red
    return
}

$policy = if ($mbx.RetentionPolicy) { $mbx.RetentionPolicy } else { "Default MRM Policy (tenant default)" }

Write-Host ""
Write-Host "  $($mbx.DisplayName) [$($mbx.PrimarySmtpAddress)]" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Retention Policy:   $policy"
Write-Host ""
