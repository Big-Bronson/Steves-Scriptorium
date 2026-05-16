# invoke-profile.ps1
# -----------------------------------------------------------------------------
# Standalone profile-snippet version of the invoke() dispatcher.
#
# Why this file exists alongside Spellbook.psm1
# -----------------------------------------------------
# This is the dual-distribution counterpart described in ADR-0002. The .psm1
# is for engineers who install via PowerShell Gallery (Install-Module). This
# file is for engineers who'd rather drop the dispatcher straight into their
# $PROFILE and keep their own Public/*.ps1 scripts somewhere on disk
# ($env:USERPROFILE\Scripts by default). Same dispatcher behaviour, no module
# install required.
#
# How to use
# ----------
# 1. Open your profile:                notepad $PROFILE
# 2. If it doesn't exist:              New-Item -Path $PROFILE -Force
# 3. Paste the contents of this file in, save.
# 4. Reload your shell:                . $PROFILE
# 5. Adjust $scriptsPath below if your scripts live elsewhere.
#
# Ghost-command discipline
# ------------------------
# CLAUDE.md flags "ghost commands" (menu entries with no matching .ps1 on
# disk) as a known anti-pattern: the user sees the entry, types it, and
# gets a confusing "Script not found" error. The list below is curated to
# match the shipped Public/*.ps1 set in Spellbook. If you fork
# this snippet for a personal invoke with custom scripts, keep this list
# in sync with what's actually on disk.

function invoke {
    param([string]$Command)

    # Adjust this to wherever your standalone scripts live.
    $scriptsPath = "$env:USERPROFILE\Scripts"

    # $commands is declared [ordered] so the numeric shortcut (invoke 3)
    # resolves to a stable position. See ADR-0010 for why this matters
    # AND why the membership check below uses .Contains() rather than
    # .ContainsKey() — OrderedDictionary does not expose ContainsKey and
    # using it throws InvalidOperation at runtime.
    $commands = [ordered]@{
        # --- User Lifecycle ---
        "new-user"              = "Create a new M365 user and assign groups"
        "offboard-user"         = "Full user offboarding — block, wipe, convert, export log"
        "set-userlicence"       = "Assign or remove a licence from a user"

        # --- User Reports & Auditing ---
        "get-userreport"        = "Full profile dump for a single user"
        "get-allusers"          = "All users with licences and last login — full export"
        "get-inactiveusers"     = "Users with no recent activity (AD or M365)"
        "get-mfaaudit"          = "All users and their MFA registration status"
        "get-guestaudit"        = "Guest accounts with invite status and age"
        "get-signinlogs"        = "Recent sign-in events for a user"
        "get-licencegaps"       = "Licensed users with no recent sign-in — cost-saving audit"

        # --- Tenant Health ---
        "get-tenantreport"      = "Full tenant health snapshot — licences, MFA, roles, sync, service health"
        "get-conditionalaccess" = "All Conditional Access policies — state, targets, grant controls"
        "get-devicereport"      = "Intune managed devices — compliance, sync status, flagged issues"

        # --- Mailbox & Exchange ---
        "get-userperms"         = "List all mailboxes a user has access to"
        "get-mailboxperms"      = "List who has access to a specific mailbox"
        "add-mailboxperms"      = "Grant Full Access and Send As on a mailbox"
        "get-forwarding"        = "Show forwarding configuration on a mailbox"
        "set-forwarding"        = "Enable email forwarding from a mailbox"
        "remove-forwarding"     = "Remove email forwarding from a mailbox"
        "disable-autocalevents" = "Disable automatic calendar events tenant-wide"
        "new-sharedmailbox"     = "Create a shared mailbox and assign delegates"
        "check-mailflow"        = "Trace message delivery for a sender/recipient pair"
        "get-archive"           = "In-place archive size, item count, and quota for a mailbox"
        "get-sharedmailboxaudit"= "All shared mailboxes with delegates, size, and licence status"

        # --- Groups ---
        "get-groupmembers"      = "List all members of a group"

        # --- MFA & Auth ---
        "get-smsmfa"            = "Check SMS MFA number on an account"
        "set-smsmfa"            = "Update existing SMS MFA number"
        "add-smsmfa"            = "Add SMS MFA number to an account"
        "add-tap"               = "Create a Temporary Access Pass"
        "remove-taps"           = "Remove all Temporary Access Passes from a user"

        # --- System ---
        "inherit-permissions"   = "Reset folder permissions to inherited"
        "kill-graph"            = "Disconnect from Microsoft Graph"
        "kill-exchange"         = "Disconnect the current Exchange Online session"
        "get-connections"       = "Show active Exchange Online and Graph connection status"
    }

    # No argument — print the full list
    if (-not $Command) {
        Write-Host ""
        Write-Host "  invoke <command>" -ForegroundColor Cyan
        Write-Host ""
        Write-Host '  "Any sufficiently advanced technology is indistinguishable from magic."' -ForegroundColor DarkGray
        Write-Host "                                                     -- Arthur C. Clarke" -ForegroundColor DarkGray
        Write-Host ""

        # $sectionMap drives the Yellow header rendering during enumeration:
        # when we walk $commands in order and hit a key listed here, print
        # the corresponding section header above it. Plain @{} is fine here
        # (lookup-only, no iteration), but we still need .Contains() not
        # .ContainsKey() for consistency with $commands' rules and to avoid
        # accidentally introducing the OrderedDictionary bug if anyone ever
        # converts this to [ordered].
        $currentSection = ""
        $sectionMap = [ordered]@{
            "new-user"               = "User Lifecycle"
            "get-userreport"         = "User Reports & Auditing"
            "get-tenantreport"       = "Tenant Health"
            "get-userperms"          = "Mailbox & Exchange"
            "get-groupmembers"       = "Groups"
            "get-smsmfa"             = "MFA & Auth"
            "inherit-permissions"    = "System"
        }

        $i = 1
        foreach ($key in $commands.Keys) {
            if ($sectionMap.Contains($key)) {
                Write-Host ""
                Write-Host "  $($sectionMap[$key]):" -ForegroundColor Yellow
            }
            Write-Host ("  {0,2}. {1,-32} {2}" -f $i, $key, $commands[$key])
            $i++
        }

        Write-Host ""
        Write-Host "  Example: invoke new-user    |    invoke 2    |    invoke get-tenantreport" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    # Resolve numeric shortcut (eg. invoke 5)
    if ($Command -match '^\d+$') {
        $index = [int]$Command
        $keys  = @($commands.Keys)
        if ($index -lt 1 -or $index -gt $keys.Count) {
            Write-Host "  No command at index $index. Run 'invoke' to see the list." -ForegroundColor Red
            return
        }
        $Command = $keys[$index - 1]
        Write-Host "  Running: $Command" -ForegroundColor DarkGray
    }

    # Match and run. .Contains() not .ContainsKey() — see ADR-0010.
    $scriptFile = Join-Path $scriptsPath "$Command.ps1"

    if ($commands.Contains($Command)) {
        if (Test-Path $scriptFile) {
            & $scriptFile
        } else {
            Write-Host "  Script not found: $scriptFile" -ForegroundColor Red
            Write-Host "  Make sure $Command.ps1 exists in $scriptsPath" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  Unknown command: '$Command'" -ForegroundColor Red
        Write-Host "  Run 'invoke' to see available commands." -ForegroundColor DarkGray
    }
}
