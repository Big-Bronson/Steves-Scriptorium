# get-listsmsmfa.ps1
# Bulk list of all users with SMS/phone MFA methods registered.
# Makes one Graph call per user — expect a few minutes on large tenants.
# Requires: Graph (User.Read.All, UserAuthenticationMethod.Read.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.Read.All","UserAuthenticationMethod.Read.All" -ContextScope Process
}

Write-Host ""
Write-Host "  Fetching users..." -ForegroundColor DarkGray

try {
    $users = Get-MgUser -All -Property "Id,DisplayName,UserPrincipalName" -ErrorAction Stop
} catch {
    Write-Host "  Failed to retrieve users: $_" -ForegroundColor Red
    return
}

Write-Host "  Checking phone methods for $($users.Count) users..." -ForegroundColor DarkGray

$results = foreach ($user in $users) {
    try {
        $phoneMethods = Get-MgUserAuthenticationPhoneMethod -UserId $user.Id -ErrorAction Stop
        foreach ($method in $phoneMethods) {
            [PSCustomObject]@{
                UserPrincipalName = $user.UserPrincipalName
                DisplayName       = $user.DisplayName
                PhoneType         = $method.PhoneType
                PhoneNumber       = $method.PhoneNumber
            }
        }
    } catch {
        Write-Host "  [SKIPPED] $($user.UserPrincipalName): $_" -ForegroundColor DarkGray
    }
}

if (-not $results) {
    Write-Host "  No SMS/phone MFA methods found." -ForegroundColor Yellow
    return
}

Write-Host ""
$results | Format-Table -AutoSize
Write-Host "  $($results.Count) phone method(s) found across $($users.Count) users." -ForegroundColor Green

$export = Read-Host "  Export to CSV? (y/n)"
if ($export -eq "y") {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $csvPath   = "C:\smsmfa-$timestamp.csv"
    try {
        $results | Export-Csv -Path $csvPath -NoTypeInformation -ErrorAction Stop
        Write-Host "  Exported: $csvPath" -ForegroundColor Green
    } catch {
        Write-Host "  Export failed: $_" -ForegroundColor Red
    }
}
Write-Host ""
