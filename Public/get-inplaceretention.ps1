# get-inplaceretention.ps1
# Lists all MRM retention policies in the tenant with their linked tags and actions.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false -DisableWAM }

Write-Host "Fetching retention policies..." -ForegroundColor DarkGray
$policies = @(Get-RetentionPolicy)

if ($policies.Count -eq 0) {
    Write-Host "No retention policies found." -ForegroundColor Yellow
    return
}

Write-Host ""
foreach ($policy in $policies) {
    $tagLinks = @($policy.RetentionPolicyTagLinks)
    Write-Host "  $($policy.Name)  ($($tagLinks.Count) tag(s))" -ForegroundColor Cyan

    foreach ($tagLink in $tagLinks) {
        $tag = Get-RetentionPolicyTag -Identity $tagLink -ErrorAction SilentlyContinue
        if ($tag) {
            $age = if ($tag.AgeLimitForRetention) { "$($tag.AgeLimitForRetention.Days) days" } else { "no limit" }
            Write-Host ("    {0,-48} {1,-25} {2}" -f $tag.Name, $tag.RetentionAction, $age)
        }
    }
    Write-Host ""
}
