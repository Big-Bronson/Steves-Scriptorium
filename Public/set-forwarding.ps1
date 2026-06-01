# set-forwarding.ps1
# Configures SMTP forwarding on a mailbox. Verifies the destination exists
# before applying. Asks whether to keep a local copy.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false -DisableWAM }

$source = Read-Host "Mailbox to forward FROM (UPN or primary SMTP)"
$dest   = Read-Host "Forward TO (email address)"

try {
    $mbx = Get-Mailbox -Identity $source -ErrorAction Stop
} catch {
    Write-Host "Source mailbox not found: $source" -ForegroundColor Red
    return
}

# Verify the destination resolves in Exchange
$recipient = Get-Recipient -Identity $dest -ErrorAction SilentlyContinue
if (-not $recipient) {
    Write-Host "Destination not found in Exchange: $dest" -ForegroundColor Red
    Write-Host "Check the address and try again." -ForegroundColor DarkGray
    return
}

$keepCopy = (Read-Host "Keep a copy in the source mailbox too? (y/n)") -eq "y"

$current = $mbx.ForwardingSMTPAddress
if ($current) {
    Write-Host ""
    Write-Host "  Existing forwarding: $current" -ForegroundColor Yellow
    Write-Host "  This will be overwritten." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Source:    $($mbx.PrimarySmtpAddress)" -ForegroundColor Cyan
Write-Host "  Forward:   $dest" -ForegroundColor Cyan
Write-Host "  Keep copy: $keepCopy" -ForegroundColor Cyan
Write-Host ""
if ((Read-Host "Apply? (y/n)") -ne "y") { Write-Host "Aborted." -ForegroundColor Red; return }

try {
    Set-Mailbox -Identity $source `
        -ForwardingSMTPAddress $dest `
        -DeliverToMailboxAndForward $keepCopy `
        -ErrorAction Stop
    Write-Host "Forwarding set." -ForegroundColor Green
} catch {
    Write-Host "Failed: $_" -ForegroundColor Red
}
