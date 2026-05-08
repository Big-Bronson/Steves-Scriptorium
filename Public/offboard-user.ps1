# offboard-user.ps1
# Full M365 user offboarding. Performs all steps in sequence with confirmation
# and logs every action to a timestamped CSV on the Desktop.
#
# Steps performed:
#   1. Block sign-in
#   2. Reset password to random string
#   3. Revoke all active sessions
#   4. Remove all group memberships
#   5. Remove all admin roles
#   6. Remove MFA methods
#   7. Cancel future calendar events
#   8. Convert mailbox to shared (preserves data, removes licence requirement)
#   9. Set Out of Office reply
#  10. Hide from Global Address List
#  11. Remove licence assignments
#  12. Export summary CSV
#
# Requires: Graph (User.ReadWrite.All, Directory.ReadWrite.All,
#           UserAuthenticationMethod.ReadWrite.All, RoleManagement.ReadWrite.Directory)
#           Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline }
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.ReadWrite.All","Directory.ReadWrite.All","UserAuthenticationMethod.ReadWrite.All","RoleManagement.ReadWrite.Directory" -ContextScope Process
}

$upn = Read-Host "Enter UPN of user to offboard"

# Verify user exists
$user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property "Id,DisplayName,UserPrincipalName,AssignedLicenses"
if (-not $user) {
    Write-Host "User not found: $upn" -ForegroundColor Red
    return
}

Write-Host "`nOffboarding: $($user.DisplayName) ($upn)" -ForegroundColor Yellow
Write-Host "This will perform all offboarding steps. Continue? (y/n)" -ForegroundColor Yellow
if ((Read-Host) -ne "y") { Write-Host "Aborted."; return }

$log = [System.Collections.Generic.List[PSCustomObject]]::new()

function Log-Action {
    param($Step, $Status, $Notes = "")
    $entry = [PSCustomObject]@{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        UPN       = $upn
        Step      = $Step
        Status    = $Status
        Notes     = $Notes
    }
    $log.Add($entry)
    $colour = if ($Status -eq "OK") { "Green" } elseif ($Status -eq "SKIPPED") { "DarkGray" } else { "Red" }
    Write-Host "  [$Status] $Step$(if ($Notes) { " — $Notes" })" -ForegroundColor $colour
}

# Portable password generator — replaces [System.Web.Security.Membership]
# which is unavailable in PowerShell 7. Guarantees one of each character
# class to satisfy M365 complexity rules.
function New-OffboardPassword {
    param([int]$Length = 20)
    $upper = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower = [char[]]'abcdefghjkmnpqrstuvwxyz'
    $digit = [char[]]'23456789'
    $sym   = [char[]]'!@#$%^&*-_=+'
    $all   = @($upper + $lower + $digit + $sym)
    $rng   = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $buf   = [byte[]]::new(4)
    $pick  = {
        param($pool)
        $rng.GetBytes($buf)
        $pool[[BitConverter]::ToUInt32($buf, 0) % [uint32]$pool.Length]
    }
    $chars = [System.Collections.Generic.List[char]]::new()
    $chars.Add((& $pick $upper))
    $chars.Add((& $pick $lower))
    $chars.Add((& $pick $digit))
    $chars.Add((& $pick $sym))
    while ($chars.Count -lt $Length) { $chars.Add((& $pick $all)) }
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $rng.GetBytes($buf)
        $j = [int]([BitConverter]::ToUInt32($buf, 0) % [uint32]($i + 1))
        $tmp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $tmp
    }
    -join $chars
}

Write-Host ""

# 1. Block sign-in
try {
    Update-MgUser -UserId $user.Id -AccountEnabled $false
    Log-Action "Block sign-in" "OK"
} catch { Log-Action "Block sign-in" "FAILED" $_ }

# 2. Reset password to random string. The generated password is recorded
# in the export so the engineer has it for the audit trail; the file lands
# on the offboarder's Desktop, not the user's.
try {
    $rnd = New-OffboardPassword -Length 20
    Update-MgUser -UserId $user.Id -PasswordProfile @{ Password = $rnd; ForceChangePasswordNextSignIn = $false }
    Log-Action "Reset password" "OK" "New password: $rnd"
} catch { Log-Action "Reset password" "FAILED" $_ }

# 3. Revoke sessions
try {
    Revoke-MgUserSignInSession -UserId $user.Id | Out-Null
    Log-Action "Revoke active sessions" "OK"
} catch { Log-Action "Revoke active sessions" "FAILED" $_ }

# 4. Remove group memberships
try {
    $groups = Get-MgUserMemberOf -UserId $user.Id | Where-Object { $_.OdataType -eq "#microsoft.graph.group" }
    $removed = 0
    foreach ($group in $groups) {
        try {
            Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $user.Id
            $removed++
        } catch { }
    }
    Log-Action "Remove group memberships" "OK" "Removed from $removed group(s)"
} catch { Log-Action "Remove group memberships" "FAILED" $_ }

# 5. Remove admin roles
try {
    $roles = Get-MgUserMemberOf -UserId $user.Id | Where-Object { $_.OdataType -eq "#microsoft.graph.directoryRole" }
    $removed = 0
    foreach ($role in $roles) {
        try {
            Remove-MgDirectoryRoleMemberByRef -DirectoryRoleId $role.Id -DirectoryObjectId $user.Id
            $removed++
        } catch { }
    }
    Log-Action "Remove admin roles" "OK" "Removed $removed role(s)"
} catch { Log-Action "Remove admin roles" "FAILED" $_ }

# 6. Remove MFA methods
try {
    # Remove phone methods
    Get-MgUserAuthenticationPhoneMethod -UserId $user.Id | ForEach-Object {
        Remove-MgUserAuthenticationPhoneMethod -UserId $user.Id -PhoneAuthenticationMethodId $_.Id
    }
    # Remove TAPs
    Get-MgUserAuthenticationTemporaryAccessPassMethod -UserId $user.Id | ForEach-Object {
        Remove-MgUserAuthenticationTemporaryAccessPassMethod -UserId $user.Id -TemporaryAccessPassAuthenticationMethodId $_.Id
    }
    Log-Action "Remove MFA methods" "OK"
} catch { Log-Action "Remove MFA methods" "FAILED" $_ }

# 7. Cancel future calendar events
try {
    Remove-CalendarEvents -Identity $upn -CancelOrganizedMeetings -QueryWindowInDays 120 -Confirm:$false
    Log-Action "Cancel future calendar events" "OK" "120 day window"
} catch { Log-Action "Cancel future calendar events" "FAILED" $_ }

# 8. Convert to shared mailbox
try {
    Set-Mailbox -Identity $upn -Type Shared
    Log-Action "Convert to shared mailbox" "OK" "Mailbox preserved, licence can be removed"
} catch { Log-Action "Convert to shared mailbox" "FAILED" $_ }

# 9. Set Out of Office
$oooMessage = Read-Host "`nOut of Office message (leave blank to skip)"
if ($oooMessage) {
    try {
        Set-MailboxAutoReplyConfiguration -Identity $upn `
            -AutoReplyState Enabled `
            -InternalMessage $oooMessage `
            -ExternalMessage $oooMessage
        Log-Action "Set Out of Office" "OK"
    } catch { Log-Action "Set Out of Office" "FAILED" $_ }
} else {
    Log-Action "Set Out of Office" "SKIPPED" "No message provided"
}

# 10. Hide from GAL
try {
    Set-Mailbox -Identity $upn -HiddenFromAddressListsEnabled $true
    Log-Action "Hide from address lists" "OK"
} catch { Log-Action "Hide from address lists" "FAILED" $_ }

# 11. Remove licences
try {
    $licences = (Get-MgUser -UserId $user.Id -Property AssignedLicenses).AssignedLicenses
    if ($licences.Count -gt 0) {
        Set-MgUserLicense -UserId $user.Id -AddLicenses @() -RemoveLicenses ($licences.SkuId)
        Log-Action "Remove licences" "OK" "Removed $($licences.Count) licence(s)"
    } else {
        Log-Action "Remove licences" "SKIPPED" "No licences assigned"
    }
} catch { Log-Action "Remove licences" "FAILED" $_ }

# Export log
$path = "$env:USERPROFILE\Desktop\Offboard_$($upn.Split('@')[0])_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
$log | Export-Csv -Path $path -NoTypeInformation

Write-Host "`nOffboarding complete. Log saved to: $path" -ForegroundColor Cyan
Write-Host "Review the log for any FAILED steps that need manual follow-up." -ForegroundColor Yellow
