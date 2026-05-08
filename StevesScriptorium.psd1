# StevesScriptorium.psd1
# Module manifest — required for PowerShell Gallery publishing.
# Module manifest — version, metadata, and PS Gallery publishing config.
# Bump ModuleVersion with every release.

@{
    # Module identity
    RootModule        = 'StevesScriptorium.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '31541981-5235-4afe-bf0d-19c7b5fb438c'
    Author            = 'Stephen Vella'
    CompanyName       = 'stephenvella.work'
    Copyright 	      = '(c) 2026 Stephen Vella (email@stephenvella.work). All rights reserved.'
    Description       = 'M365 helpdesk toolkit for user lifecycle, tenant auditing, mailbox management, MFA and Exchange. Built for MSP engineers.'
    PowerShellVersion = '5.1'

    # What this module exports
    FunctionsToExport = @(
        'toolkit'
        'new-user'
        'offboard-user'
        'reset-password'
        'set-userlicence'
        'get-userreport'
        'get-allusers'
        'get-inactiveusers'
        'get-mfaaudit'
        'get-guestaudit'
        'get-signinlogs'
        'get-tenantreport'
        'get-userperms'
        'get-mailboxperms'
        'add-mailboxperms'
        'set-forwarding'
        'remove-forwarding'
        'get-archive'
        'enable-autoexpand'
        'disable-autocalevents'
        'check-mailflow'
        'get-sharedmailboxaudit'
        'get-groupmembers'
        'get-smsmfa'
        'set-smsmfa'
        'add-smsmfa'
        'add-tap'
        'remove-taps'
        'inherit-permissions'
        'kill-graph'
    )

    CmdletsToExport   = @()
    AliasesToExport   = @()
    VariablesToExport = @()

    # External module dependencies
    RequiredModules   = @(
        @{ ModuleName = 'ExchangeOnlineManagement'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'Microsoft.Graph.Users';    ModuleVersion = '2.0.0' }
        @{ ModuleName = 'Microsoft.Graph.Identity.SignIns'; ModuleVersion = '2.0.0' }
    )

    # PS Gallery metadata (shown on the module page)
    PrivateData = @{
        PSData = @{
            Tags         = @('M365', 'Microsoft365', 'Exchange', 'Helpdesk', 'MSP', 'Entra', 'PowerShell', 'Toolkit', 'MFA', 'Offboarding', 'Onboarding')
            LicenseUri   = 'https://github.com/Big-Bronson/StevesScriptorium/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/Big-Bronson/StevesScriptorium'
            ReleaseNotes = 'Initial release. User lifecycle, tenant health, mailbox auditing, MFA management, Exchange tools.'
        }
    }
}
