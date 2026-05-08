# get-smsmfa.ps1
# Shows the SMS/phone MFA methods registered for a user.
# Requires: Graph (UserAuthenticationMethod.Read.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "UserAuthenticationMethod.Read.All" -ContextScope Process
}

$upn = Read-Host "Enter UPN"

$user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property "Id,DisplayName" -ErrorAction SilentlyContinue
if (-not $user) { Write-Host "User not found: $upn" -ForegroundColor Red; return }

$methods = Get-MgUserAuthenticationPhoneMethod -UserId $user.Id -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  $($user.DisplayName) — phone MFA methods" -ForegroundColor Cyan
Write-Host ""

if (-not $methods -or $methods.Count -eq 0) {
    Write-Host "  No phone methods registered." -ForegroundColor DarkGray
} else {
    $methods | ForEach-Object {
        Write-Host ("  [{0}]  {1,-8}  {2}" -f $_.Id.Substring(0,8), $_.PhoneType, $_.PhoneNumber)
    }
}

Write-Host ""
