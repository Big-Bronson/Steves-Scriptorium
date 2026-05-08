# set-smsmfa.ps1
# Updates the phone number on an existing SMS/phone MFA method for a user.
# Use add-smsmfa to register a new method first.
# Requires: Graph (UserAuthenticationMethod.ReadWrite.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "UserAuthenticationMethod.ReadWrite.All" -ContextScope Process
}

$upn = Read-Host "Enter UPN"

$user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property "Id,DisplayName" -ErrorAction SilentlyContinue
if (-not $user) { Write-Host "User not found: $upn" -ForegroundColor Red; return }

$methods = @(Get-MgUserAuthenticationPhoneMethod -UserId $user.Id -ErrorAction SilentlyContinue)

if ($methods.Count -eq 0) {
    Write-Host "No phone methods registered. Use add-smsmfa to add one." -ForegroundColor Yellow
    return
}

Write-Host ""
$i = 1
$methods | ForEach-Object {
    Write-Host ("  {0}. [{1}] {2}" -f $i, $_.PhoneType, $_.PhoneNumber)
    $i++
}
Write-Host ""

$pick = Read-Host "Which method to update (1-$($methods.Count))"
if (-not ($pick -match '^\d+$') -or [int]$pick -lt 1 -or [int]$pick -gt $methods.Count) {
    Write-Host "Invalid selection." -ForegroundColor Red
    return
}
$target = $methods[[int]$pick - 1]

$newNumber = Read-Host "New phone number (E.164 format, e.g. +61412345678)"
if (-not $newNumber) { Write-Host "Aborted." -ForegroundColor Red; return }

try {
    Update-MgUserAuthenticationPhoneMethod -UserId $user.Id `
        -PhoneAuthenticationMethodId $target.Id `
        -PhoneNumber $newNumber `
        -PhoneType $target.PhoneType `
        -ErrorAction Stop
    Write-Host "Phone number updated to $newNumber." -ForegroundColor Green
} catch {
    Write-Host "Failed: $_" -ForegroundColor Red
}
