# new-user.ps1
# Creates a new M365 user, copies group memberships from a template user,
# then optionally adds extra groups manually.
# Requires: Graph (User.ReadWrite.All, Group.ReadWrite.All, Directory.Read.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.Read.All" -ContextScope Process
}

$displayName = Read-Host "Display Name (eg. Jane Smith)"
$upn         = Read-Host "UPN (eg. jane.smith@domain.com)"
$securePw    = Read-Host "Initial password" -AsSecureString
$forceChange = (Read-Host "Force password change on first login? (y/n)") -eq "y"

# PasswordProfile takes a plain string; convert at the point of use and
# clear the local copy as soon as the call returns.
$plainPw = [System.Net.NetworkCredential]::new('', $securePw).Password

Write-Host "`nCreating user..."
try {
    $newUser = New-MgUser -DisplayName $displayName `
        -UserPrincipalName $upn `
        -MailNickname ($upn.Split("@")[0]) `
        -AccountEnabled $true `
        -PasswordProfile @{
            Password = $plainPw
            ForceChangePasswordNextSignIn = $forceChange
        }
} finally {
    $plainPw = $null
}

Write-Host "Created: $($newUser.DisplayName) ($($newUser.Id))"

# Copy groups from template user
$templateUPN = Read-Host "`nTemplate user UPN to copy groups from (leave blank to skip)"

if ($templateUPN) {
    $templateUser = Get-MgUser -Filter "userPrincipalName eq '$templateUPN'"

    if (-not $templateUser) {
        Write-Host "Template user not found. Skipping group copy."
    } else {
        $groups = Get-MgUserMemberOf -UserId $templateUser.Id | Where-Object { $_.OdataType -eq "#microsoft.graph.group" }

        if ($groups.Count -eq 0) {
            Write-Host "Template user has no group memberships to copy."
        } else {
            Write-Host "Copying $($groups.Count) group(s) from $templateUPN..."
            foreach ($group in $groups) {
                try {
                    New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $newUser.Id
                    Write-Host "  + $($group.AdditionalProperties.displayName)"
                } catch {
                    Write-Host "  ! Failed: $($group.AdditionalProperties.displayName) — $_"
                }
            }
        }
    }
}

# Manually add extra groups
$addMore = (Read-Host "`nAdd extra groups manually? (y/n)") -eq "y"

while ($addMore) {
    $groupName = Read-Host "Group display name (exact match)"
    $group = Get-MgGroup -Filter "displayName eq '$groupName'"

    if (-not $group) {
        Write-Host "  ! Not found: '$groupName'"
    } elseif ($group.Count -gt 1) {
        Write-Host "  ! Multiple matches — be more specific"
    } else {
        try {
            New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $newUser.Id
            Write-Host "  + Added to $($group.DisplayName)"
        } catch {
            Write-Host "  ! Failed: $_"
        }
    }

    $addMore = (Read-Host "Add another? (y/n)") -eq "y"
}

Write-Host "`n--- Done ---"
Write-Host "User:         $displayName"
Write-Host "UPN:          $upn"
Write-Host "Password:     (set — not echoed)"
Write-Host "Force change: $forceChange"
