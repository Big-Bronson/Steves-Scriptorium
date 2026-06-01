# get-sharedmailboxaudit.ps1
# Lists all shared mailboxes with their delegated permissions, size,
# and whether they have an unnecessary licence assigned.
# Useful for: quarterly mailbox reviews, licence cost audits, offboarding follow-ups.
# Requires: Exchange Online + Graph (User.Read.All)

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -DisableWAM }
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.Read.All" -ContextScope Process
}

Write-Host "Fetching shared mailboxes..."
$shared = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited

$results = foreach ($mbx in $shared) {
    # Get delegated access
    $perms = Get-MailboxPermission -Identity $mbx.PrimarySmtpAddress |
        Where-Object { $_.User -notlike "NT AUTHORITY*" -and $_.AccessRights -contains "FullAccess" }
    $delegates = ($perms.User) -join ", "

    # Get size
    $stats = Get-MailboxStatistics -Identity $mbx.PrimarySmtpAddress -ErrorAction SilentlyContinue
    $size  = if ($stats) { $stats.TotalItemSize } else { "N/A" }

    # Check if licensed (unnecessary for shared mailboxes under 50GB)
    $mgUser   = Get-MgUser -Filter "userPrincipalName eq '$($mbx.PrimarySmtpAddress)'" -Property "AssignedLicenses" -ErrorAction SilentlyContinue
    $licensed = $mgUser -and $mgUser.AssignedLicenses.Count -gt 0

    [PSCustomObject]@{
        "Mailbox"       = $mbx.PrimarySmtpAddress
        "Display Name"  = $mbx.DisplayName
        "Size"          = $size
        "Delegates"     = $delegates
        "Has Licence"   = $licensed
        "Notes"         = if ($licensed) { "Licence may be unnecessary" } else { "OK" }
    }
}

Write-Host "`n$($shared.Count) shared mailbox(es):`n"
$results | Format-Table -AutoSize

$path = "$env:USERPROFILE\Desktop\SharedMailboxAudit_$(Get-Date -Format 'yyyyMMdd').csv"
$results | Export-Csv -Path $path -NoTypeInformation
Write-Host "Exported to $path"
