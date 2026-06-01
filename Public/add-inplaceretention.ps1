# add-inplaceretention.ps1
# Creates a new archive retention policy by cloning Default MRM Policy and swapping
# the archive tag for one with a user-specified duration. Optionally assigns it to
# a single mailbox or all members of a distribution group.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false -DisableWAM }

$monthsInput = Read-Host "Archive after how many months? (default 12)"
if (-not $monthsInput) { $monthsInput = "12" }
$months = [int]$monthsInput
$days   = [int]($months * 30.44)

# Create the archive tag if it doesn't already exist
$tagName     = "$months Month Archive"
$existingTag = Get-RetentionPolicyTag -Identity $tagName -ErrorAction SilentlyContinue

if ($existingTag) {
    Write-Host "  Tag '$tagName' already exists — reusing." -ForegroundColor DarkGray
} else {
    try {
        New-RetentionPolicyTag $tagName `
            -Type All `
            -RetentionEnabled $true `
            -AgeLimitForRetention $days `
            -RetentionAction MoveToArchive `
            -ErrorAction Stop | Out-Null
        Write-Host "  [OK] Created tag: $tagName ($days days)" -ForegroundColor Green
    } catch {
        Write-Host "  [FAILED] Could not create tag: $_" -ForegroundColor Red
        Write-Host "  Tip: run Enable-OrganizationCustomization if this tenant has never been customised." -ForegroundColor DarkGray
        return
    }
}

# Clone Default MRM Policy, filtering out any existing MoveToArchive tags
$defaultPolicy = Get-RetentionPolicy "Default MRM Policy" -ErrorAction SilentlyContinue
if ($defaultPolicy) {
    $keepTags = $defaultPolicy.RetentionPolicyTagLinks | Where-Object {
        $t = Get-RetentionPolicyTag -Identity $_ -ErrorAction SilentlyContinue
        $t -and $t.RetentionAction -ne "MoveToArchive"
    }
    $newTagSet = @($keepTags) + $tagName
} else {
    Write-Host "  Default MRM Policy not found — new policy will contain only the archive tag." -ForegroundColor Yellow
    $newTagSet = @($tagName)
}

$defaultPolicyName = "$months Month Archive Policy"
$policyName = Read-Host "Policy name (default: $defaultPolicyName)"
if (-not $policyName) { $policyName = $defaultPolicyName }

try {
    New-RetentionPolicy $policyName -RetentionPolicyTagLinks $newTagSet -ErrorAction Stop | Out-Null
    Write-Host "  [OK] Created policy: $policyName" -ForegroundColor Green
} catch {
    Write-Host "  [FAILED] Could not create policy: $_" -ForegroundColor Red
    return
}

# Optional assignment to a mailbox or distribution group
Write-Host ""
$target = Read-Host "Assign to user or group? (leave blank to skip)"
if (-not $target) {
    Write-Host "  No assignment made." -ForegroundColor DarkGray
    return
}

# Try single mailbox first
$mbx = Get-Mailbox -Identity $target -ErrorAction SilentlyContinue
if ($mbx) {
    try {
        Set-Mailbox -Identity $target -RetentionPolicy $policyName -ErrorAction Stop
        Write-Host "  [OK] Policy assigned to $($mbx.PrimarySmtpAddress)" -ForegroundColor Green
    } catch {
        Write-Host "  [FAILED] Could not assign policy: $_" -ForegroundColor Red
    }
    return
}

# Fall back to distribution group
$group = Get-DistributionGroup -Identity $target -ErrorAction SilentlyContinue
if (-not $group) {
    Write-Host "  '$target' not found as a mailbox or distribution group." -ForegroundColor Red
    return
}

$members = @(Get-DistributionGroupMember -Identity $target -ResultSize Unlimited)
Write-Host "  $($members.Count) member(s) in $($group.DisplayName)." -ForegroundColor Cyan
if ((Read-Host "  Apply policy to all? (y/n)") -ne "y") { Write-Host "  Aborted." -ForegroundColor Red; return }

$ok = 0; $failed = 0; $i = 0
foreach ($member in $members) {
    $i++
    Write-Progress -Activity "Assigning retention policy" `
        -Status "$($member.PrimarySmtpAddress) ($i of $($members.Count))" `
        -PercentComplete (($i / $members.Count) * 100)
    try {
        Set-Mailbox -Identity $member.PrimarySmtpAddress -RetentionPolicy $policyName -ErrorAction Stop
        $ok++
    } catch {
        Write-Host "  [FAILED] $($member.PrimarySmtpAddress) — $_" -ForegroundColor Red
        $failed++
    }
}

Write-Progress -Activity "Assigning retention policy" -Completed
Write-Host ""
Write-Host "  Assigned: $ok" -ForegroundColor Green
if ($failed -gt 0) { Write-Host "  Failed:   $failed" -ForegroundColor Red }
