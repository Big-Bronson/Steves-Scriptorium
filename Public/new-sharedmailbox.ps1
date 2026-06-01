# new-sharedmailbox.ps1
# Creates a shared mailbox and optionally grants Full Access and Send As
# to one or more delegates. Follows the same prompt-then-confirm pattern as new-user.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false -DisableWAM }

$displayName = Read-Host "Display name (eg. Help Desk)"
$alias       = Read-Host "Email alias (the part before @, eg. helpdesk)"

# Strip a domain if the operator typed a full address — Exchange appends the
# tenant's default domain automatically and will reject an alias containing @.
if ($alias -match '@') {
    $alias = $alias.Split('@')[0]
    Write-Host "  Alias trimmed to: $alias" -ForegroundColor DarkGray
}

Write-Host "`nCreating shared mailbox..."
try {
    $mbx = New-Mailbox -Name $displayName -Alias $alias -Shared -ErrorAction Stop
    Write-Host "  [OK] Created: $($mbx.PrimarySmtpAddress)" -ForegroundColor Green
} catch {
    Write-Host "  [FAILED] $_" -ForegroundColor Red
    return
}

# Delegate loop — mirrors the extra-groups loop in new-user
$addDelegates = (Read-Host "`nAdd delegates? (y/n)") -eq "y"

$delegatesAdded = [System.Collections.Generic.List[string]]::new()

while ($addDelegates) {
    $delegateUPN = Read-Host "Delegate UPN"

    $grantFull   = (Read-Host "  Grant Full Access? (y/n)") -eq "y"
    $grantSendAs = (Read-Host "  Grant Send As? (y/n)")    -eq "y"

    if ($grantFull) {
        try {
            Add-MailboxPermission -Identity $mbx.PrimarySmtpAddress `
                -User $delegateUPN `
                -AccessRights FullAccess `
                -AutoMapping $true `
                -ErrorAction Stop | Out-Null
            Write-Host "  [OK] Full Access granted to $delegateUPN" -ForegroundColor Green
        } catch {
            Write-Host "  [FAILED] Full Access for ${delegateUPN}: $_" -ForegroundColor Red
        }
    }

    if ($grantSendAs) {
        try {
            Add-RecipientPermission -Identity $mbx.PrimarySmtpAddress `
                -Trustee $delegateUPN `
                -AccessRights SendAs `
                -Confirm:$false `
                -ErrorAction Stop | Out-Null
            Write-Host "  [OK] Send As granted to $delegateUPN" -ForegroundColor Green
        } catch {
            Write-Host "  [FAILED] Send As for ${delegateUPN}: $_" -ForegroundColor Red
        }
    }

    if ($grantFull -or $grantSendAs) { $delegatesAdded.Add($delegateUPN) }

    $addDelegates = (Read-Host "Add another delegate? (y/n)") -eq "y"
}

Write-Host "`n--- Done ---"
Write-Host "Mailbox:    $displayName"
Write-Host "SMTP:       $($mbx.PrimarySmtpAddress)"
if ($delegatesAdded.Count -gt 0) {
    Write-Host "Delegates:  $($delegatesAdded -join ', ')"
} else {
    Write-Host "Delegates:  None"
}
