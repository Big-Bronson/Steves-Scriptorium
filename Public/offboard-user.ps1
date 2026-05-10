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
# -------------------------------------------------------------------------
# Iterate-and-collect pattern (see ADR-0021): for batch operations where
# individual items can fail independently, we count successes and failures
# separately, then write ONE summary line plus ONE per-failure line per
# failed item. This keeps the audit log honest — without this, a partial
# failure would be invisible in the CSV (the previous implementation
# silently swallowed exceptions and reported the attempted count as the
# "OK" count). Honest audit trails matter for offboarding above all other
# operations, since the CSV is the engineer's only proof that each step
# was performed (or attempted).
try {
    $groups = Get-MgUserMemberOf -UserId $user.Id | Where-Object { $_.OdataType -eq "#microsoft.graph.group" }
    $succeeded = 0
    $failures  = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($group in $groups) {
        # Best-effort name resolution. The displayName lives in the group's
        # AdditionalProperties bag; if the lookup throws (rare — usually a
        # transient Graph hiccup) we fall back to the GUID so the CSV row
        # still identifies the group unambiguously.
        $groupName = try { $group.AdditionalProperties.displayName } catch { $group.Id }
        if (-not $groupName) { $groupName = $group.Id }
        try {
            Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $user.Id -ErrorAction Stop
            $succeeded++
        } catch {
            $failures.Add([PSCustomObject]@{ Name = $groupName; Error = $_.Exception.Message })
        }
    }
    # Conditional summary status: OK if everything worked or some worked,
    # FAILED only if nothing worked. The Notes column distinguishes the
    # mixed-success case so the engineer sees at a glance whether follow-up
    # is needed.
    $summary = if ($failures.Count -eq 0) {
        "OK", "Removed from $succeeded group(s)"
    } elseif ($succeeded -gt 0) {
        "OK", "Removed from $succeeded group(s); $($failures.Count) failed (see rows below)"
    } else {
        "FAILED", "$($failures.Count) failure(s) (see rows below); 0 succeeded"
    }
    Log-Action "Remove group memberships" $summary[0] $summary[1]
    # Per-failure detail rows. The leading "↳" makes the parent/child
    # relationship visible in the CSV when sorted by timestamp; Log-Action
    # also colours these red on screen so the operator sees them live.
    foreach ($f in $failures) {
        Log-Action "  ↳ group: $($f.Name)" "FAILED" $f.Error
    }
} catch { Log-Action "Remove group memberships" "FAILED" $_ }

# 5. Remove admin roles
# -------------------------------------------------------------------------
# Same iterate-and-collect pattern as step 4. Admin role failures are
# arguably more important to surface than group failures — a left-over
# admin role on a departed user is a real security exposure.
try {
    $roles = Get-MgUserMemberOf -UserId $user.Id | Where-Object { $_.OdataType -eq "#microsoft.graph.directoryRole" }
    $succeeded = 0
    $failures  = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($role in $roles) {
        $roleName = try { $role.AdditionalProperties.displayName } catch { $role.Id }
        if (-not $roleName) { $roleName = $role.Id }
        try {
            Remove-MgDirectoryRoleMemberByRef -DirectoryRoleId $role.Id -DirectoryObjectId $user.Id -ErrorAction Stop
            $succeeded++
        } catch {
            $failures.Add([PSCustomObject]@{ Name = $roleName; Error = $_.Exception.Message })
        }
    }
    $summary = if ($failures.Count -eq 0) {
        "OK", "Removed $succeeded role(s)"
    } elseif ($succeeded -gt 0) {
        "OK", "Removed $succeeded role(s); $($failures.Count) failed (see rows below)"
    } else {
        "FAILED", "$($failures.Count) failure(s) (see rows below); 0 succeeded"
    }
    Log-Action "Remove admin roles" $summary[0] $summary[1]
    foreach ($f in $failures) {
        Log-Action "  ↳ role: $($f.Name)" "FAILED" $f.Error
    }
} catch { Log-Action "Remove admin roles" "FAILED" $_ }

# 6. Remove MFA methods
# -------------------------------------------------------------------------
# Two enumerations (phone methods, TAPs) that previously had no per-item
# error handling at all — a single failure aborted the whole step. Same
# iterate-and-collect treatment applied; phone methods and TAPs are
# tracked together since they're both "credentials to revoke" from the
# operator's perspective. The per-failure rows distinguish them via the
# Step prefix ("phone" vs "tap").
try {
    $succeeded = 0
    $failures  = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($pm in (Get-MgUserAuthenticationPhoneMethod -UserId $user.Id -ErrorAction SilentlyContinue)) {
        # Identifier for the failure row: phone type + first 8 chars of the
        # method ID is enough to distinguish multiple methods of the same
        # type without dumping the full GUID into the CSV.
        $label = "$($pm.PhoneType) [$($pm.Id.Substring(0,[Math]::Min(8,$pm.Id.Length)))]"
        try {
            Remove-MgUserAuthenticationPhoneMethod -UserId $user.Id -PhoneAuthenticationMethodId $pm.Id -ErrorAction Stop
            $succeeded++
        } catch {
            $failures.Add([PSCustomObject]@{ Kind = "phone"; Name = $label; Error = $_.Exception.Message })
        }
    }

    foreach ($tap in (Get-MgUserAuthenticationTemporaryAccessPassMethod -UserId $user.Id -ErrorAction SilentlyContinue)) {
        $label = "tap [$($tap.Id.Substring(0,[Math]::Min(8,$tap.Id.Length)))]"
        try {
            Remove-MgUserAuthenticationTemporaryAccessPassMethod -UserId $user.Id -TemporaryAccessPassAuthenticationMethodId $tap.Id -ErrorAction Stop
            $succeeded++
        } catch {
            $failures.Add([PSCustomObject]@{ Kind = "tap"; Name = $label; Error = $_.Exception.Message })
        }
    }

    $summary = if ($failures.Count -eq 0) {
        "OK", "Removed $succeeded method(s)"
    } elseif ($succeeded -gt 0) {
        "OK", "Removed $succeeded method(s); $($failures.Count) failed (see rows below)"
    } else {
        "FAILED", "$($failures.Count) failure(s) (see rows below); 0 succeeded"
    }
    Log-Action "Remove MFA methods" $summary[0] $summary[1]
    foreach ($f in $failures) {
        Log-Action "  ↳ $($f.Kind): $($f.Name)" "FAILED" $f.Error
    }
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
