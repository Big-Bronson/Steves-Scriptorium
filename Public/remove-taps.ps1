# remove-taps.ps1
# Removes all Temporary Access Pass methods from a user. TAPs expire naturally
# but removing them immediately prevents further use (e.g. after a phishing report).
# Requires: Graph (UserAuthenticationMethod.ReadWrite.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "UserAuthenticationMethod.ReadWrite.All" -ContextScope Process
}

$upn = Read-Host "Enter UPN"

$user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property "Id,DisplayName" -ErrorAction SilentlyContinue
if (-not $user) { Write-Host "User not found: $upn" -ForegroundColor Red; return }

$taps = @(Get-MgUserAuthenticationTemporaryAccessPassMethod -UserId $user.Id -ErrorAction SilentlyContinue)

if ($taps.Count -eq 0) {
    Write-Host "No TAPs found for $($user.DisplayName)." -ForegroundColor DarkGray
    return
}

Write-Host ""
Write-Host "  Found $($taps.Count) TAP(s) for $($user.DisplayName):" -ForegroundColor Cyan
$taps | ForEach-Object {
    Write-Host "  - Created: $($_.CreatedDateTime)  Expires: $($_.StartDateTime.AddMinutes($_.LifetimeInMinutes))  OneTime: $($_.IsUsableOnce)"
}
Write-Host ""

if ((Read-Host "Remove all TAPs? (y/n)") -ne "y") { Write-Host "Aborted." -ForegroundColor Red; return }

$removed = 0
foreach ($tap in $taps) {
    try {
        Remove-MgUserAuthenticationTemporaryAccessPassMethod -UserId $user.Id `
            -TemporaryAccessPassAuthenticationMethodId $tap.Id `
            -ErrorAction Stop
        $removed++
    } catch {
        Write-Host "  Failed to remove TAP $($tap.Id): $_" -ForegroundColor Red
    }
}

Write-Host "Removed $removed of $($taps.Count) TAP(s)." -ForegroundColor Green
