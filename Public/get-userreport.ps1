# get-userreport.ps1
# Full profile dump for a single user — useful at the start of a support call
# or before making changes. Prints everything you'd want to know in one shot.
#
# Covers: account status, licences, group memberships, mailbox permissions,
#         MFA methods, admin roles, last activity, forwarding, archive status
#
# Requires: Graph (User.Read.All, Directory.Read.All,
#           UserAuthenticationMethod.Read.All) + Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -DisableWAM }
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.Read.All","Directory.Read.All","UserAuthenticationMethod.Read.All" -ContextScope Process
}

$upn = Read-Host "Enter UPN"

$user = Get-MgUser -Filter "userPrincipalName eq '$upn'" `
    -Property "Id,DisplayName,UserPrincipalName,AccountEnabled,AssignedLicenses,CreatedDateTime,JobTitle,Department,OfficeLocation,MobilePhone"

if (-not $user) { Write-Host "User not found: $upn" -ForegroundColor Red; return }

$skus = Get-MgSubscribedSku
$skuLookup = @{}
foreach ($sku in $skus) { $skuLookup[$sku.SkuId] = $sku.SkuPartNumber }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  USER REPORT: $($user.DisplayName)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Account basics
Write-Host "--- Account ---" -ForegroundColor Yellow
Write-Host "  UPN:          $($user.UserPrincipalName)"
Write-Host "  Enabled:      $($user.AccountEnabled)"
Write-Host "  Created:      $($user.CreatedDateTime)"
Write-Host "  Title:        $($user.JobTitle)"
Write-Host "  Department:   $($user.Department)"
Write-Host "  Mobile:       $($user.MobilePhone)"

# Licences
Write-Host "`n--- Licences ---" -ForegroundColor Yellow
if ($user.AssignedLicenses.Count -eq 0) {
    Write-Host "  None assigned"
} else {
    $user.AssignedLicenses.SkuId | ForEach-Object { Write-Host "  $($skuLookup[$_])" }
}

# Groups
Write-Host "`n--- Group Memberships ---" -ForegroundColor Yellow
$groups = Get-MgUserMemberOf -UserId $user.Id | Where-Object { $_.OdataType -eq "#microsoft.graph.group" }
if ($groups.Count -eq 0) { Write-Host "  None" }
else { $groups | ForEach-Object { Write-Host "  $($_.AdditionalProperties.displayName)" } }

# Admin roles
Write-Host "`n--- Admin Roles ---" -ForegroundColor Yellow
$roles = Get-MgUserMemberOf -UserId $user.Id | Where-Object { $_.OdataType -eq "#microsoft.graph.directoryRole" }
if ($roles.Count -eq 0) { Write-Host "  None" }
else { $roles | ForEach-Object { Write-Host "  $($_.AdditionalProperties.displayName)" } }

# MFA methods
Write-Host "`n--- MFA Methods ---" -ForegroundColor Yellow
$methods = Get-MgUserAuthenticationMethod -UserId $user.Id |
    Where-Object { $_.OdataType -ne "#microsoft.graph.passwordAuthenticationMethod" }
if ($methods.Count -eq 0) { Write-Host "  None registered" -ForegroundColor Red }
else { $methods | ForEach-Object { Write-Host "  $($_.OdataType -replace '#microsoft.graph.','')" } }

# Mailbox info
Write-Host "`n--- Mailbox ---" -ForegroundColor Yellow
try {
    $mbx = Get-Mailbox -Identity $upn -ErrorAction Stop
    Write-Host "  Type:         $($mbx.RecipientTypeDetails)"
    Write-Host "  Hidden GAL:   $($mbx.HiddenFromAddressListsEnabled)"
    Write-Host "  Forwarding:   $($mbx.ForwardingSMTPAddress)"
    Write-Host "  Keep copy:    $($mbx.DeliverToMailboxAndForward)"
    Write-Host "  Archive:      $($mbx.ArchiveStatus)"
    Write-Host "  Auto-expand:  $($mbx.AutoExpandingArchiveEnabled)"

    $stats = Get-MailboxStatistics -Identity $upn -ErrorAction SilentlyContinue
    if ($stats) { Write-Host "  Last activity: $($stats.LastLogonTime)" }
} catch {
    Write-Host "  No mailbox found or access denied"
}

# Mailbox permissions (who has access)
Write-Host "`n--- Mailbox Permissions (who has access) ---" -ForegroundColor Yellow
try {
    $perms = Get-MailboxPermission -Identity $upn | Where-Object { $_.User -notlike "NT AUTHORITY*" -and $_.User -notlike "S-1-5*" }
    if ($perms.Count -eq 0) { Write-Host "  No delegated access" }
    else { $perms | ForEach-Object { Write-Host "  $($_.User) — $($_.AccessRights)" } }
} catch { Write-Host "  Unable to retrieve" }

Write-Host "`n========================================`n" -ForegroundColor Cyan
