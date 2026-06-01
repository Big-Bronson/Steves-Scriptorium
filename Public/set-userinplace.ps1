# set-userinplace.ps1
# Assigns an MRM retention policy to a mailbox, chosen from a numbered list.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false -DisableWAM }

$identity = Read-Host "Mailbox (UPN or primary SMTP)"

try {
    $mbx = Get-Mailbox -Identity $identity -ErrorAction Stop
} catch {
    Write-Host "Mailbox not found: $identity" -ForegroundColor Red
    return
}

$current = if ($mbx.RetentionPolicy) { $mbx.RetentionPolicy } else { "Default MRM Policy (tenant default)" }

Write-Host ""
Write-Host "  $($mbx.DisplayName) [$($mbx.PrimarySmtpAddress)]" -ForegroundColor Cyan
Write-Host "  Current policy: $current" -ForegroundColor DarkGray
Write-Host ""

$policies = @(Get-RetentionPolicy | Sort-Object Name)
if ($policies.Count -eq 0) {
    Write-Host "  No retention policies found in this tenant." -ForegroundColor Red
    return
}

Write-Host "  Available policies:" -ForegroundColor Yellow
for ($i = 0; $i -lt $policies.Count; $i++) {
    Write-Host ("  {0,2}. {1}" -f ($i + 1), $policies[$i].Name)
}
Write-Host ""

$selection = Read-Host "Select policy number (leave blank to cancel)"
if (-not $selection) { Write-Host "  Cancelled." -ForegroundColor DarkGray; return }

$index = 0
if (-not [int]::TryParse($selection, [ref]$index) -or $index -lt 1 -or $index -gt $policies.Count) {
    Write-Host "  Invalid selection." -ForegroundColor Red
    return
}

$chosen = $policies[$index - 1].Name

try {
    Set-Mailbox -Identity $mbx.PrimarySmtpAddress -RetentionPolicy $chosen -ErrorAction Stop
    Write-Host "  [OK] $($mbx.PrimarySmtpAddress) — policy set to `"$chosen`"" -ForegroundColor Green
} catch {
    Write-Host "  [FAILED] $_" -ForegroundColor Red
}
