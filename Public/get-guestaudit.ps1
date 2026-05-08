# get-guestaudit.ps1
# Lists all guest accounts in the tenant with invite status and last sign-in.
# Useful for quarterly access reviews — guests that have never signed in
# or haven't been active in 90+ days are candidates for removal.
# Requires: Graph (User.Read.All, Directory.Read.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All" -ContextScope Process
}

Write-Host "Fetching guest accounts..."
$guests = Get-MgUser -All -Filter "userType eq 'Guest'" `
    -Property "DisplayName,UserPrincipalName,CreatedDateTime,ExternalUserState,ExternalUserStateChangeDateTime"

if ($guests.Count -eq 0) {
    Write-Host "No guest accounts found."
    return
}

$cutoff = (Get-Date).AddDays(-90)

$results = foreach ($g in $guests) {
    $notes = if ($g.ExternalUserState -eq "PendingAcceptance") {
        "Invite never accepted"
    } elseif ($g.CreatedDateTime -lt $cutoff) {
        "Active >90 days ago"
    } else {
        "Recent"
    }

    [PSCustomObject]@{
        "Display Name"   = $g.DisplayName
        "UPN"            = $g.UserPrincipalName
        "Invite Status"  = $g.ExternalUserState
        "Created"        = $g.CreatedDateTime
        "Notes"          = $notes
    }
}

Write-Host "`n$($guests.Count) guest account(s) found:`n"
$results | Sort-Object "Notes", "Created" | Format-Table -AutoSize

$path = "$env:USERPROFILE\Desktop\GuestAudit_$(Get-Date -Format 'yyyyMMdd').csv"
$results | Export-Csv -Path $path -NoTypeInformation
Write-Host "Exported to $path"
