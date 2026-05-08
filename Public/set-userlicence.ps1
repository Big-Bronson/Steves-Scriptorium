# set-userlicence.ps1
# Assign or remove a licence from a user interactively.
# Lists available SKUs so you don't need to remember the names.
# Requires: Graph (User.ReadWrite.All, Directory.ReadWrite.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All" -ContextScope Process
}

$upn = Read-Host "Enter UPN"
$user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property "Id,DisplayName,AssignedLicenses"
if (-not $user) { Write-Host "User not found." -ForegroundColor Red; return }

# Build SKU lookup
$skus = Get-MgSubscribedSku
$skuLookup = @{}
foreach ($sku in $skus) { $skuLookup[$sku.SkuId] = $sku.SkuPartNumber }

# Show current licences
Write-Host "`nCurrent licences for $($user.DisplayName):"
if ($user.AssignedLicenses.Count -eq 0) {
    Write-Host "  None"
} else {
    $user.AssignedLicenses.SkuId | ForEach-Object { Write-Host "  $($skuLookup[$_]) ($_)" }
}

# Show available SKUs with space remaining
Write-Host "`nAvailable SKUs in tenant:"
$i = 1
$skuList = @()
foreach ($sku in $skus) {
    $available = $sku.PrepaidUnits.Enabled - $sku.ConsumedUnits
    Write-Host ("  {0,2}. {1,-45} {2} available" -f $i, $sku.SkuPartNumber, $available)
    $skuList += $sku
    $i++
}

$action = Read-Host "`nAction — (1) Assign  (2) Remove"
$index  = [int](Read-Host "Enter SKU number from list above") - 1

if ($index -lt 0 -or $index -ge $skuList.Count) {
    Write-Host "Invalid selection." -ForegroundColor Red; return
}

$selectedSku = $skuList[$index]

if ($action -eq "1") {
    try {
        Set-MgUserLicense -UserId $user.Id -AddLicenses @{ SkuId = $selectedSku.SkuId } -RemoveLicenses @()
        Write-Host "`nDone. Assigned $($selectedSku.SkuPartNumber) to $upn" -ForegroundColor Green
    } catch { Write-Host "Failed: $_" -ForegroundColor Red }
} elseif ($action -eq "2") {
    try {
        Set-MgUserLicense -UserId $user.Id -AddLicenses @() -RemoveLicenses @($selectedSku.SkuId)
        Write-Host "`nDone. Removed $($selectedSku.SkuPartNumber) from $upn" -ForegroundColor Green
    } catch { Write-Host "Failed: $_" -ForegroundColor Red }
} else {
    Write-Host "Invalid action." -ForegroundColor Red
}
