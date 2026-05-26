# add-tap.ps1
# Creates a Temporary Access Pass for a user. Defaults: multi-use, 60 minutes.
# Requires: Graph (UserAuthenticationMethod.ReadWrite.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "UserAuthenticationMethod.ReadWrite.All","User.Read.All" -ContextScope Process
}

$upn = Read-Host "Enter UPN"

$user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property "Id,DisplayName" -ErrorAction SilentlyContinue
if (-not $user) { Write-Host "User not found: $upn" -ForegroundColor Red; return }

# Default: one-time, 60 min. Operator can override.
$lifetimeMins = Read-Host "TAP lifetime in minutes (default 60)"
if (-not $lifetimeMins -or $lifetimeMins -notmatch '^\d+$') { $lifetimeMins = 60 }
else { $lifetimeMins = [int]$lifetimeMins }

$isUsableOnce = (Read-Host "One-time use only? (y/n, default n)") -eq "y"

try {
    $params = @{
        IsUsableOnce        = $isUsableOnce
        LifetimeInMinutes   = $lifetimeMins
        StartDateTime       = (Get-Date).ToUniversalTime().ToString("o")
    }
    $tap = New-MgUserAuthenticationTemporaryAccessPassMethod -UserId $user.Id `
        -BodyParameter $params `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "  TAP created for $($user.DisplayName)" -ForegroundColor Green
    Write-Host "  Pass:       $($tap.TemporaryAccessPass)" -ForegroundColor Cyan
    Write-Host "  Starts:     $($tap.StartDateTime)"
    Write-Host "  Expires:    $($tap.StartDateTime.AddMinutes($lifetimeMins))"
    Write-Host "  One-time:   $isUsableOnce"
    Write-Host ""
    Write-Host "  Give this pass to the user now — it cannot be retrieved again." -ForegroundColor Yellow
    Write-Host ""
} catch {
    Write-Host "Failed: $_" -ForegroundColor Red
    Write-Host "(A user can only have one active TAP at a time. Use remove-taps first if needed.)" -ForegroundColor DarkGray
}
