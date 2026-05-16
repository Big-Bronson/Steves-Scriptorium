Write-Host ""
Write-Host "--- Exchange Online ---" -ForegroundColor Yellow
$exo = Get-ConnectionInformation -ErrorAction SilentlyContinue
if ($exo) {
    Write-Host "  Connected" -ForegroundColor Green
    Write-Host ("  User:       {0}" -f $exo[0].UserPrincipalName)
    Write-Host ("  Tenant:     {0}" -f $exo[0].TenantId)
    Write-Host ("  Expires:    {0}" -f $exo[0].TokenExpiryTimeUTC)
} else {
    Write-Host "  Not connected" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "--- Microsoft Graph ---" -ForegroundColor Yellow
$graph = Get-MgContext -ErrorAction SilentlyContinue
if ($graph) {
    Write-Host "  Connected" -ForegroundColor Green
    Write-Host ("  Account:    {0}" -f $graph.Account)
    Write-Host ("  Tenant:     {0}" -f $graph.TenantId)
    Write-Host ("  Scopes:     {0}" -f ($graph.Scopes -join ", "))
} else {
    Write-Host "  Not connected" -ForegroundColor DarkGray
}

Write-Host ""
