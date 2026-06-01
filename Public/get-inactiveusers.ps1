# get-inactiveusers.ps1
# Lists enabled users with no mailbox activity beyond a threshold (default 90 days).
# Accounts that have never logged in are also flagged.
# Requires: ActiveDirectory module (on-prem) OR Exchange Online + Graph for cloud-only tenants

$mode = Read-Host "Tenant type — (1) On-prem AD  (2) Cloud-only M365"

$days = Read-Host "Inactivity threshold in days (default 90)"
if (-not $days) { $days = 90 }
$cutoff = (Get-Date).AddDays(-[int]$days)

if ($mode -eq "1") {
    # On-prem Active Directory path
    Import-Module ActiveDirectory

    $users = Get-ADUser -Filter { Enabled -eq $true } -Properties LastLogonDate, EmailAddress, Department |
        Where-Object { $_.LastLogonDate -lt $cutoff -or $_.LastLogonDate -eq $null } |
        Select-Object @{N="Display Name"; E={$_.Name}},
                      @{N="UPN"; E={$_.UserPrincipalName}},
                      @{N="Email"; E={$_.EmailAddress}},
                      @{N="Department"; E={$_.Department}},
                      @{N="Last Login"; E={$_.LastLogonDate}},
                      @{N="Notes"; E={ if (-not $_.LastLogonDate) { "Never Logged In" } else { "Inactive $days`d" } }} |
        Sort-Object "Last Login"

} else {
    # Cloud-only M365 path (Exchange mailbox stats)
    if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -DisableWAM }
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All" -ContextScope Process
    }

    Write-Host "Fetching users and mailbox stats..."
    $mgUsers = Get-MgUser -All -Property "DisplayName,UserPrincipalName,AccountEnabled" |
        Where-Object { $_.AccountEnabled -eq $true }

    $stats = Get-MailboxStatistics -ResultSize Unlimited | Select-Object UserPrincipalName, LastLogonTime
    $statsIndex = @{}
    foreach ($s in $stats) {
        if ($s.UserPrincipalName) { $statsIndex[$s.UserPrincipalName.ToLower()] = $s.LastLogonTime }
    }

    $users = $mgUsers | ForEach-Object {
        $u = $_
        $last = $statsIndex[$u.UserPrincipalName.ToLower()]
        if (-not $last -or $last -lt $cutoff) {
            [PSCustomObject]@{
                "Display Name" = $u.DisplayName
                "UPN"          = $u.UserPrincipalName
                "Last Login"   = $last
                "Notes"        = if (-not $last) { "No Mailbox Activity" } else { "Inactive $days`d" }
            }
        }
    } | Sort-Object "Last Login"
}

Write-Host "`nFound $($users.Count) inactive/never-logged-in accounts (threshold: $days days)`n"
$users | Format-Table -AutoSize

$export = (Read-Host "Export to CSV on Desktop? (y/n)") -eq "y"
if ($export) {
    $path = "$env:USERPROFILE\Desktop\InactiveUsers_$(Get-Date -Format 'yyyyMMdd').csv"
    $users | Export-Csv -Path $path -NoTypeInformation
    Write-Host "Exported to $path"
}
