# Add this entire block to your PowerShell profile.
# To open your profile: notepad $PROFILE
# If the file doesn't exist yet: New-Item -Path $PROFILE -Force
# After pasting, save, then run: . $PROFILE

function toolkit {
    param([string]$Command)

    # Update this to match your scripts folder path
    $scriptsPath = "$env:USERPROFILE\Scripts"

    $commands = [ordered]@{
        # --- User Lifecycle ---
        "new-user"              = "Create a new M365 user and assign groups"
        "offboard-user"         = "Full user offboarding — block, wipe, convert, export log"
        "reset-password"        = "Reset a Microsoft 365 account password"
        "set-userlicence"       = "Assign or remove a licence from a user"
        "rename-pc"             = "Rename a computer and restart"

        # --- User Reports & Auditing ---
        "get-userreport"        = "Full profile dump for a single user"
        "get-allusers"          = "All users with licences and last login — full export"
        "get-inactiveusers"     = "Users with no recent activity (AD or M365)"
        "get-mfaaudit"          = "All users and their MFA registration status"
        "get-guestaudit"        = "Guest accounts with invite status and age"
        "get-signinlogs"        = "Recent sign-in events for a user"
        "get-licensedusers"     = "All licensed users export"

        # --- Tenant Health ---
        "get-tenantreport"      = "Full tenant health snapshot — licences, MFA, roles, sync, service health"

        # --- Mailbox & Exchange ---
        "get-userperms"         = "List all mailboxes a user has access to"
        "get-mailboxperms"      = "List who has access to a specific mailbox"
        "add-mailboxperms"      = "Grant Full Access and Send As on a mailbox"
        "set-forwarding"        = "Enable email forwarding from a mailbox"
        "remove-forwarding"     = "Remove email forwarding from a mailbox"
        "get-archive"           = "Check archive size and quota for a mailbox"
        "enable-autoexpand"     = "Enable auto-expanding archive"
        "disable-autocalevents" = "Disable automatic calendar events tenant-wide"
        "check-mailflow"        = "Trace message delivery for a sender/recipient pair"
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
    }

    # No argument — print the full list
    if (-not $Command) {
        Write-Host ""
        Write-Host "  toolkit <command>" -ForegroundColor Cyan
        Write-Host ""

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
        Write-Host "  Example: toolkit new-user    |    toolkit 2    |    toolkit get-tenantreport" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    # Resolve numeric shortcut (eg. toolkit 5)
    if ($Command -match '^\d+$') {
        $index = [int]$Command
        $keys  = @($commands.Keys)
        if ($index -lt 1 -or $index -gt $keys.Count) {
            Write-Host "  No command at index $index. Run 'toolkit' to see the list." -ForegroundColor Red
            return
        }
        $Command = $keys[$index - 1]
        Write-Host "  Running: $Command" -ForegroundColor DarkGray
    }

    # Match and run
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
        Write-Host "  Run 'toolkit' to see available commands." -ForegroundColor DarkGray
    }
}
