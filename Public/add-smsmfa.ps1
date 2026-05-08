# add-smsmfa.ps1
# Registers a new SMS/phone MFA method for a user.
# Requires: Graph (UserAuthenticationMethod.ReadWrite.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "UserAuthenticationMethod.ReadWrite.All" -ContextScope Process
}

$upn = Read-Host "Enter UPN"

$user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property "Id,DisplayName" -ErrorAction SilentlyContinue
if (-not $user) { Write-Host "User not found: $upn" -ForegroundColor Red; return }

$phoneNumber = Read-Host "Phone number (E.164 format, e.g. +61412345678)"
if (-not $phoneNumber) { Write-Host "Aborted." -ForegroundColor Red; return }

Write-Host ""
Write-Host "  1. Mobile (SMS + voice call)"
Write-Host "  2. AlternateMobile"
Write-Host "  3. Office"
Write-Host ""
$typeChoice = Read-Host "Phone type (1-3, default 1)"
$phoneType = switch ($typeChoice) {
    "2" { "alternateMobile" }
    "3" { "office" }
    default { "mobile" }
}

try {
    $result = New-MgUserAuthenticationPhoneMethod -UserId $user.Id `
        -PhoneNumber $phoneNumber `
        -PhoneType $phoneType `
        -ErrorAction Stop
    Write-Host "Registered $phoneType $($result.PhoneNumber) for $($user.DisplayName)." -ForegroundColor Green
} catch {
    Write-Host "Failed: $_" -ForegroundColor Red
}
