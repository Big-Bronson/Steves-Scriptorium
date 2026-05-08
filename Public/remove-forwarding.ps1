# remove-forwarding.ps1
# Removes SMTP forwarding from a mailbox.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false }

$identity = Read-Host "Mailbox to remove forwarding from (UPN or primary SMTP)"

try {
    $mbx = Get-Mailbox -Identity $identity -ErrorAction Stop
} catch {
    Write-Host "Mailbox not found: $identity" -ForegroundColor Red
    return
}

$current = $mbx.ForwardingSMTPAddress
if (-not $current) {
    Write-Host "No forwarding is set on $($mbx.PrimarySmtpAddress)." -ForegroundColor DarkGray
    return
}

Write-Host ""
Write-Host "  Mailbox:         $($mbx.PrimarySmtpAddress)" -ForegroundColor Cyan
Write-Host "  Current forward: $current" -ForegroundColor Cyan
Write-Host ""
if ((Read-Host "Remove forwarding? (y/n)") -ne "y") { Write-Host "Aborted." -ForegroundColor Red; return }

try {
    Set-Mailbox -Identity $identity `
        -ForwardingSMTPAddress $null `
        -DeliverToMailboxAndForward $false `
        -ErrorAction Stop
    Write-Host "Forwarding removed." -ForegroundColor Green
} catch {
    Write-Host "Failed: $_" -ForegroundColor Red
}
