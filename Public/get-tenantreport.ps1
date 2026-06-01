# get-tenantreport.ps1
# Produces a snapshot health report for a tenant.
# Useful as a first-look when picking up a new client, or as a weekly check.
#
# Covers:
#   - Licence summary (assigned vs available)
#   - Admin role holders
#   - Users with no MFA
#   - Disabled accounts still holding licences
#   - Shared mailboxes with licences (usually unnecessary cost)
#   - Guest account count
#   - Last AD Connect sync (if hybrid)
#   - M365 service health status
#
# Requires: Graph (User.Read.All, Directory.Read.All, Organization.Read.All,
#           ServiceHealth.Read.All) + Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -DisableWAM }
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.Read.All","Directory.Read.All","Organization.Read.All","ServiceHealth.Read.All","RoleManagement.Read.Directory","UserAuthenticationMethod.Read.All" -ContextScope Process
}

$report = [System.Collections.Generic.List[string]]::new()
$issues = [System.Collections.Generic.List[PSCustomObject]]::new()

function Section($title) {
    $line = "`n" + ("=" * 60) + "`n  $title`n" + ("=" * 60)
    Write-Host $line -ForegroundColor Cyan
    $report.Add($line)
}

function Row($label, $value, $flag = $false) {
    $colour = if ($flag) { "Yellow" } else { "White" }
    $line = "  {0,-40} {1}" -f $label, $value
    Write-Host $line -ForegroundColor $colour
    $report.Add($line)
    if ($flag) {
        $issues.Add([PSCustomObject]@{ Finding = $label; Value = $value })
    }
}

# --- Organisation info ---
Section "Tenant Overview"
$org = Get-MgOrganization
Row "Tenant Name"     $org.DisplayName
Row "Tenant ID"       $org.Id
Row "Default Domain"  ($org.VerifiedDomains | Where-Object { $_.IsDefault }).Name

# --- Licence summary ---
Section "Licence Summary"
$skus = Get-MgSubscribedSku
foreach ($sku in $skus) {
    $used      = $sku.ConsumedUnits
    $total     = $sku.PrepaidUnits.Enabled
    $available = $total - $used
    $flag      = $available -le 2
    Row "$($sku.SkuPartNumber)" "$used / $total used ($available available)" $flag
}

# --- Admin role holders ---
Section "Admin Role Holders"
$adminRoles = Get-MgDirectoryRole | Where-Object { $_.DisplayName -match "Admin|Global" }
foreach ($role in $adminRoles) {
    $members = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id
    if ($members.Count -gt 0) {
        $names = ($members | ForEach-Object {
            try { (Get-MgUser -UserId $_.Id -Property DisplayName).DisplayName } catch { $_.Id }
        }) -join ", "
        $flag = ($role.DisplayName -eq "Global Administrator" -and $members.Count -gt 3)
        Row $role.DisplayName "$($members.Count) member(s): $names" $flag
    }
}

# --- Users with no MFA registered ---
Section "Users Without MFA"
Write-Host "  Checking MFA registration (this takes a while)..." -ForegroundColor DarkGray
$allUsers = Get-MgUser -All -Property "DisplayName,UserPrincipalName,AccountEnabled" |
    Where-Object { $_.AccountEnabled -eq $true -and $_.UserPrincipalName -notmatch "#EXT#" }

$noMfa = foreach ($u in $allUsers) {
    $methods = Get-MgUserAuthenticationMethod -UserId $u.Id
    # Filter out the default password method — everyone has that
    $realMethods = $methods | Where-Object { $_.OdataType -ne "#microsoft.graph.passwordAuthenticationMethod" }
    if ($realMethods.Count -eq 0) { $u.UserPrincipalName }
}

if ($noMfa.Count -eq 0) {
    Row "Users without MFA" "None — all good" $false
} else {
    Row "Users without MFA" "$($noMfa.Count) found" $true
    $noMfa | ForEach-Object { Row "  $_" "" $false }
}

# --- Disabled accounts with licences (wasted spend) ---
Section "Disabled Accounts With Licences"
$disabledLicensed = Get-MgUser -All -Property "DisplayName,UserPrincipalName,AccountEnabled,AssignedLicenses" |
    Where-Object { $_.AccountEnabled -eq $false -and $_.AssignedLicenses.Count -gt 0 }

if ($disabledLicensed.Count -eq 0) {
    Row "Disabled + licensed accounts" "None found" $false
} else {
    Row "Disabled + licensed accounts" "$($disabledLicensed.Count) found — likely wasted spend" $true
    $disabledLicensed | ForEach-Object { Row "  $($_.UserPrincipalName)" "$($_.AssignedLicenses.Count) licence(s)" $false }
}

# --- Shared mailboxes with licences ---
Section "Shared Mailboxes With Licences"
$sharedWithLicence = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited |
    ForEach-Object {
        $mbx = $_
        $mgUser = Get-MgUser -Filter "userPrincipalName eq '$($mbx.PrimarySmtpAddress)'" -Property AssignedLicenses -ErrorAction SilentlyContinue
        if ($mgUser -and $mgUser.AssignedLicenses.Count -gt 0) { $mbx.PrimarySmtpAddress }
    }

if ($sharedWithLicence.Count -eq 0) {
    Row "Licensed shared mailboxes" "None — no unnecessary spend" $false
} else {
    Row "Licensed shared mailboxes" "$($sharedWithLicence.Count) found" $true
    $sharedWithLicence | ForEach-Object { Row "  $_" "Has licence assigned" $false }
}

# --- Guest accounts ---
Section "Guest Accounts"
$guests = Get-MgUser -All -Filter "userType eq 'Guest'" -Property "DisplayName,UserPrincipalName,CreatedDateTime"
Row "Total guest accounts" $guests.Count ($guests.Count -gt 20)

# --- AD Connect sync (hybrid only) ---
Section "AD Connect / Directory Sync"
try {
    $org2 = Get-MgOrganization -Property "OnPremisesLastSyncDateTime,OnPremisesSyncEnabled"
    if ($org2.OnPremisesSyncEnabled) {
        $lastSync = $org2.OnPremisesLastSyncDateTime
        $syncAge  = (New-TimeSpan -Start $lastSync -End (Get-Date)).TotalMinutes
        $flag     = $syncAge -gt 60
        Row "Directory sync enabled" "Yes"
        Row "Last sync" "$lastSync ($([math]::Round($syncAge)) mins ago)" $flag
    } else {
        Row "Directory sync" "Not enabled (cloud-only tenant)"
    }
} catch {
    Row "Directory sync check" "Unable to retrieve" $false
}

# --- M365 Service Health ---
Section "M365 Service Health"
try {
    $healthIssues = Get-MgServiceAnnouncementIssue -Filter "status ne 'resolved'" |
        Select-Object Title, Service, Status, StartDateTime
    if ($healthIssues.Count -eq 0) {
        Row "Active service issues" "None — all services healthy" $false
    } else {
        Row "Active service issues" "$($healthIssues.Count) open issue(s)" $true
        $healthIssues | ForEach-Object { Row "  [$($_.Service)] $($_.Title)" $_.Status $false }
    }
} catch {
    Row "Service health" "Insufficient permissions (needs ServiceHealth.Read.All)" $false
}

# --- Summary ---
Section "Summary of Findings"
if ($issues.Count -eq 0) {
    Write-Host "  No issues flagged. Tenant looks healthy." -ForegroundColor Green
    $report.Add("  No issues flagged.")
} else {
    Write-Host "  $($issues.Count) item(s) flagged for review:" -ForegroundColor Yellow
    $issues | ForEach-Object {
        $line = "  [!] $($_.Finding): $($_.Value)"
        Write-Host $line -ForegroundColor Yellow
        $report.Add($line)
    }
}

# Export
$tenant = ($org.VerifiedDomains | Where-Object { $_.IsDefault }).Name
$path = "$env:USERPROFILE\Desktop\TenantReport_${tenant}_$(Get-Date -Format 'yyyyMMdd').txt"
$report | Out-File -FilePath $path -Encoding UTF8
Write-Host "`nFull report saved to: $path" -ForegroundColor Cyan
