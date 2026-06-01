# set-maxmessagesize.ps1
# Sets MaxReceiveSize and MaxSendSize on mailboxes.
# Scope: all mailboxes in the tenant, or a single mailbox.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false -DisableWAM }

$sendInput = Read-Host "Max send size in MB (default 50)"
if (-not $sendInput) { $sendInput = "50" }

$recvInput = Read-Host "Max receive size in MB (default 50)"
if (-not $recvInput) { $recvInput = "50" }

$sendMB = [int]$sendInput
$recvMB = [int]$recvInput

$scope = Read-Host "Apply to: (1) All mailboxes  (2) Single mailbox"

if ($scope -eq "2") {
    $identity = Read-Host "Mailbox (UPN or primary SMTP)"
    try {
        $mailboxes = @(Get-Mailbox -Identity $identity -ErrorAction Stop)
    } catch {
        Write-Host "Mailbox not found: $identity" -ForegroundColor Red
        return
    }
} else {
    Write-Host "Fetching all mailboxes..." -ForegroundColor DarkGray
    $mailboxes = Get-Mailbox -ResultSize Unlimited
}

Write-Host ""
Write-Host "  Scope:      $($mailboxes.Count) mailbox(es)" -ForegroundColor Cyan
Write-Host "  Send limit: $sendMB MB" -ForegroundColor Cyan
Write-Host "  Recv limit: $recvMB MB" -ForegroundColor Cyan
Write-Host ""
if ((Read-Host "Apply? (y/n)") -ne "y") { Write-Host "Aborted." -ForegroundColor Red; return }

$ok = 0; $failed = 0; $i = 0

foreach ($mbx in $mailboxes) {
    $i++
    Write-Progress -Activity "Setting message size limits" `
        -Status "$($mbx.PrimarySmtpAddress) ($i of $($mailboxes.Count))" `
        -PercentComplete (($i / $mailboxes.Count) * 100)

    try {
        Set-Mailbox -Identity $mbx.PrimarySmtpAddress `
            -MaxSendSize "${sendMB}MB" `
            -MaxReceiveSize "${recvMB}MB" `
            -ErrorAction Stop
        $ok++
    } catch {
        Write-Host "  [FAILED] $($mbx.PrimarySmtpAddress) — $_" -ForegroundColor Red
        $failed++
    }
}

Write-Progress -Activity "Setting message size limits" -Completed

Write-Host ""
Write-Host "  Updated: $ok" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "  Failed:  $failed" -ForegroundColor Red
}
