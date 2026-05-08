# inherit-permissions.ps1
# Resets NTFS ACL on a folder so it inherits from its parent again. Useful
# when someone has added explicit Allow/Deny entries (often after a
# copy-paste between volumes) that block proper access.
#
# Two-step flow:
#   1. Re-enable inheritance, preserving currently-inherited rules so the
#      folder doesn't lose access while transitioning.
#   2. Optionally strip the explicit (non-inherited) ACEs that remain.
#
# Pure local — no Graph or Exchange. Requires permission to modify the
# target's ACL (typically NTFS Owner or local Administrators).

$path = Read-Host "Enter folder path"
if (-not (Test-Path -LiteralPath $path)) {
    Write-Host "Path not found: $path" -ForegroundColor Red
    return
}

$item = Get-Item -LiteralPath $path -Force
if (-not $item.PSIsContainer) {
    Write-Host "Path must be a folder, not a file." -ForegroundColor Red
    return
}

$acl = Get-Acl -LiteralPath $item.FullName
$inheritanceBlocked = $acl.AreAccessRulesProtected
$explicitRules = @($acl.Access | Where-Object { -not $_.IsInherited })

Write-Host ""
Write-Host "  Target: $($item.FullName)" -ForegroundColor Cyan
Write-Host "  Inheritance currently: $(if ($inheritanceBlocked) { 'BLOCKED' } else { 'enabled' })"
Write-Host "  Explicit (non-inherited) ACEs: $($explicitRules.Count)"
Write-Host ""

if (-not $inheritanceBlocked -and $explicitRules.Count -eq 0) {
    Write-Host "Folder is already fully inherited. Nothing to do." -ForegroundColor Green
    return
}

if ($explicitRules.Count -gt 0) {
    Write-Host "Explicit rules:" -ForegroundColor Yellow
    foreach ($r in $explicitRules) {
        Write-Host "  $($r.IdentityReference) — $($r.AccessControlType) $($r.FileSystemRights)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

if ((Read-Host "Re-enable inheritance? (y/n)") -ne "y") {
    Write-Host "Aborted." -ForegroundColor Red
    return
}

# SetAccessRuleProtection(isProtected, preserveInheritance):
#   isProtected=$false → folder inherits from parent
#   preserveInheritance=$true → keep currently-inherited rules during the
#                               transition so we don't briefly lose access
$acl.SetAccessRuleProtection($false, $true)

$strip = $false
if ($explicitRules.Count -gt 0) {
    $strip = (Read-Host "Also remove the $($explicitRules.Count) explicit ACE(s) listed above? (y/n)") -eq "y"
    if ($strip) {
        foreach ($r in $explicitRules) { $acl.RemoveAccessRule($r) | Out-Null }
    }
}

try {
    Set-Acl -LiteralPath $item.FullName -AclObject $acl -ErrorAction Stop
    Write-Host ""
    Write-Host "Inheritance re-enabled." -ForegroundColor Green
    if ($strip) { Write-Host "Explicit ACEs removed." -ForegroundColor Green }
} catch {
    Write-Host ""
    Write-Host "Failed: $_" -ForegroundColor Red
    Write-Host "(May need an elevated session, or take ownership first:" -ForegroundColor DarkGray
    Write-Host " takeown /f `"$($item.FullName)`" /r /d y)" -ForegroundColor DarkGray
}
