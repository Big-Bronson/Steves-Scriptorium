# get-groupmembers.ps1
# Lists all members of a group. Useful for auditing distribution lists,
# security groups, and M365 groups.
# Requires: Graph (Group.Read.All, User.Read.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All" -ContextScope Process
}

$groupName = Read-Host "Enter group display name (exact match)"
$group = Get-MgGroup -Filter "displayName eq '$groupName'"

if (-not $group) { Write-Host "Group not found: $groupName" -ForegroundColor Red; return }
if ($group.Count -gt 1) { Write-Host "Multiple matches — be more specific." -ForegroundColor Red; return }

Write-Host "`nGroup: $($group.DisplayName)"
Write-Host "Type:  $($group.GroupTypes -join ', ') | Mail: $($group.MailEnabled) | Security: $($group.SecurityEnabled)`n"

$members = Get-MgGroupMember -GroupId $group.Id -All
if ($members.Count -eq 0) {
    Write-Host "No members."
} else {
    $results = foreach ($m in $members) {
        try {
            $u = Get-MgUser -UserId $m.Id -Property "DisplayName,UserPrincipalName" -ErrorAction Stop
            [PSCustomObject]@{
                "Display Name" = $u.DisplayName
                "UPN"          = $u.UserPrincipalName
            }
        } catch {
            [PSCustomObject]@{
                "Display Name" = $m.Id
                "UPN"          = "(non-user object)"
            }
        }
    }
    $results | Sort-Object "Display Name" | Format-Table -AutoSize

    $export = (Read-Host "Export to CSV? (y/n)") -eq "y"
    if ($export) {
        $safe = $groupName -replace '[\\/:*?"<>|]', '_'
        $path = "$env:USERPROFILE\Desktop\Group_${safe}_$(Get-Date -Format 'yyyyMMdd').csv"
        $results | Export-Csv -Path $path -NoTypeInformation
        Write-Host "Exported to $path"
    }
}
