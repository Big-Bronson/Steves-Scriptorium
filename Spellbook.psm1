# Spellbook.psm1
# Module root. Dot-sources all Public scripts and wires up the invoke() command.

$PublicPath  = Join-Path $PSScriptRoot "Public"
$PrivatePath = Join-Path $PSScriptRoot "Private"

# Load private helpers first (if any)
if (Test-Path $PrivatePath) {
    Get-ChildItem -Path $PrivatePath -Filter "*.ps1" | ForEach-Object { . $_.FullName }
}

# Load and export all public scripts as functions
$PublicFunctions = @{}

Get-ChildItem -Path $PublicPath -Filter "*.ps1" | ForEach-Object {
    $funcName = $_.BaseName  # filename without extension = function name
    $scriptPath = $_.FullName

    # Define a named function that calls the script
    $funcBlock = [scriptblock]::Create(". `"$scriptPath`"")
    Set-Item -Path "function:global:$funcName" -Value $funcBlock

    $PublicFunctions[$funcName] = $scriptPath
}

# Store the function map for the invoke command to reference
$script:ToolkitFunctions = $PublicFunctions

# -----------------------------------------------------------------
# invoke() — the CLI dispatcher
# Usage:
#   invoke              → print all commands
#   invoke new-user     → run new-user.ps1
#   invoke 3            → run command at position 3
# -----------------------------------------------------------------

function global:invoke {
    param([string]$Command)

    # Menu must match Public/*.ps1 — keep this list honest. Ghost commands
    # surface as "Script not found" when run.
    $commands = [ordered]@{
        # User Lifecycle
        "new-user"               = "Create a new M365 user and assign groups"
        "offboard-user"          = "Full offboarding — block, wipe, convert, log"
        "set-userlicence"        = "Assign or remove a licence from a user"

        # User Reports & Auditing
        "get-userreport"         = "Full profile dump for a single user"
        "get-allusers"           = "All users with licences and last login"
        "get-inactiveusers"      = "Users with no recent activity"
        "get-mfaaudit"           = "All users and their MFA registration status"
        "get-guestaudit"         = "Guest accounts with invite status and age"
        "get-signinlogs"         = "Recent sign-in events for a user"
        "get-licencegaps"        = "Licensed users with no recent sign-in — cost-saving audit"

        # Tenant Health
        "get-tenantreport"       = "Full tenant health snapshot"
        "get-conditionalaccess"  = "All Conditional Access policies — state, targets, grant controls"
        "get-devicereport"       = "Intune managed devices — compliance, sync status, flagged issues"

        # Mailbox & Exchange
        "get-mailflow"           = "Trace message delivery for a sender/recipient"
        "get-archive"            = "In-place archive size, item count, and quota for a mailbox"
        "get-sharedmailboxaudit" = "Shared mailboxes with delegates, size, licence status"
        "get-forwarding"         = "Show forwarding configuration on a mailbox"
        "set-forwarding"         = "Enable SMTP forwarding on a mailbox"
        "remove-forwarding"      = "Remove SMTP forwarding from a mailbox"
        "get-mailboxperms"       = "Who has delegated access to a mailbox"
        "get-userperms"          = "Which mailboxes a user has delegated access to"
        "set-mailboxperms"       = "Grant Full Access and/or Send As to a mailbox"
        "disable-autocalevents"  = "Disable automatic calendar events tenant-wide"
        "new-sharedmailbox"      = "Create a shared mailbox and assign delegates"

        # Groups
        "get-groupmembers"       = "List all members of a group"

        # System
        "kill-graph"             = "Disconnect the current Microsoft Graph session"
        "kill-exchange"          = "Disconnect the current Exchange Online session"
        "get-connections"        = "Show active Exchange Online and Graph connection status"
        # MFA & Auth
        "get-smsmfa"             = "Show SMS/phone MFA methods for a user"
        "get-listsmsmfa"         = "All users with SMS/phone MFA registered — bulk export"
        "set-smsmfa"             = "Update the phone number on an existing SMS MFA method"
        "add-smsmfa"             = "Register a new SMS/phone MFA method for a user"
        "add-tap"                = "Create a Temporary Access Pass for a user"
        "remove-taps"            = "Remove all Temporary Access Passes for a user"
        # System
        "inherit-permissions"    = "Reset folder permissions to inherited"
    }

    $sectionHeaders = @{
        "new-user"               = "User Lifecycle"
        "get-userreport"         = "User Reports & Auditing"
        "get-tenantreport"       = "Tenant Health"
        "get-mailflow"           = "Mailbox & Exchange"
        "get-groupmembers"       = "Groups"
        "kill-graph"             = "System"
        "get-smsmfa"             = "MFA & Auth"
        "inherit-permissions"    = "System"

    }

    $aliases = @{}
    foreach ($key in $commands.Keys) {
        $stripped = $key -replace '-', ''
        if ($stripped -ne $key) { $aliases[$stripped] = $key }
    }

    if (-not $Command) {
        Write-Host ""
        Write-Host "  Spellbook" -ForegroundColor Cyan
        Write-Host "  invoke <command>  |  invoke <number>" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host '  "Any sufficiently advanced technology is indistinguishable from magic."' -ForegroundColor DarkGray
        Write-Host "                                                     -- Arthur C. Clarke" -ForegroundColor DarkGray
        Write-Host ""
        $i = 1
        foreach ($key in $commands.Keys) {
            if ($sectionHeaders.ContainsKey($key)) {
                Write-Host ""
                Write-Host "  $($sectionHeaders[$key]):" -ForegroundColor Yellow
            }
            Write-Host ("  {0,2}. {1,-32} {2}" -f $i, $key, $commands[$key])
            $i++
        }
        Write-Host ""
        return
    }

    # Numeric shortcut
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

    if ($aliases.ContainsKey($Command)) { $Command = $aliases[$Command] }

    if ($commands.Contains($Command)) {
        $scriptFile = Join-Path (Join-Path $PSScriptRoot "Public") "$Command.ps1"
        if (Test-Path $scriptFile) {
            . $scriptFile
        } else {
            Write-Host "  Script not found: $scriptFile" -ForegroundColor Red
            Write-Host "  The command is registered but the .ps1 is missing from Public/." -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  Unknown command: '$Command'" -ForegroundColor Red
        Write-Host "  Run 'invoke' to see available commands." -ForegroundColor DarkGray
    }
}

Set-Alias -Name inv -Value invoke -Scope Global
