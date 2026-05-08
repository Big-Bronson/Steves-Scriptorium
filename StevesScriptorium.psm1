# StevesScriptorium.psm1
# Module root. Dot-sources all Public scripts and wires up the toolkit() command.

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

# Store the function map for the toolkit command to reference
$script:ToolkitFunctions = $PublicFunctions

# -----------------------------------------------------------------
# toolkit() — the CLI dispatcher
# Usage:
#   toolkit              → print all commands
#   toolkit new-user     → run new-user.ps1
#   toolkit 3            → run command at position 3
# -----------------------------------------------------------------

function global:toolkit {
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

        # Tenant Health
        "get-tenantreport"       = "Full tenant health snapshot"

        # Mailbox & Exchange
        "check-mailflow"         = "Trace message delivery for a sender/recipient"
        "get-sharedmailboxaudit" = "Shared mailboxes with delegates, size, licence status"
        "disable-autocalevents"  = "Disable automatic calendar events tenant-wide"

        # Groups
        "get-groupmembers"       = "List all members of a group"

        # System
        "inherit-permissions"    = "Reset folder permissions to inherited"
    }

    $sectionHeaders = @{
        "new-user"               = "User Lifecycle"
        "get-userreport"         = "User Reports & Auditing"
        "get-tenantreport"       = "Tenant Health"
        "check-mailflow"         = "Mailbox & Exchange"
        "get-groupmembers"       = "Groups"
        "inherit-permissions"    = "System"
    }

    if (-not $Command) {
        Write-Host ""
        Write-Host "  Steve's Scriptorium" -ForegroundColor Cyan
        Write-Host "  toolkit <command>  |  toolkit <number>" -ForegroundColor DarkGray
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
            Write-Host "  No command at index $index. Run 'toolkit' to see the list." -ForegroundColor Red
            return
        }
        $Command = $keys[$index - 1]
        Write-Host "  Running: $Command" -ForegroundColor DarkGray
    }

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
        Write-Host "  Run 'toolkit' to see available commands." -ForegroundColor DarkGray
    }
}
