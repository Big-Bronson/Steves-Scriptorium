# StevesScriptorium.psd1
# -----------------------------------------------------------------------------
# Module manifest. Bump ModuleVersion with every release. The Publish.ps1
# preflight cross-checks this file against Public/*.ps1 and aborts on drift
# (see ADR-0011 / ADR-0012).

@{
    # Module identity
    RootModule        = 'StevesScriptorium.psm1'
    ModuleVersion     = '1.1.0'
    GUID              = '31541981-5235-4afe-bf0d-19c7b5fb438c'
    Author            = 'Stephen Vella'
    CompanyName       = 'stephenvella.work'
    Copyright 	      = '(c) 2026 Stephen Vella (email@stephenvella.work). All rights reserved.'
    Description       = 'M365 helpdesk toolkit for user lifecycle, tenant auditing, mailbox management, MFA and Exchange. Built for MSP engineers.'
    PowerShellVersion = '5.1'

    # What this module exports — must match Public/*.ps1 files exactly.
    # Publish.ps1 cross-checks this list and aborts on drift.
    FunctionsToExport = @(
        'toolkit'
        'new-user'
        'offboard-user'
        'set-userlicence'
        'get-userreport'
        'get-allusers'
        'get-inactiveusers'
        'get-mfaaudit'
        'get-guestaudit'
        'get-signinlogs'
        'get-tenantreport'
        'check-mailflow'
        'get-sharedmailboxaudit'
        'set-forwarding'
        'remove-forwarding'
        'get-mailboxperms'
        'get-userperms'
        'add-mailboxperms'
        'disable-autocalevents'
        'get-groupmembers'
        'kill-graph'
        'get-smsmfa'
        'set-smsmfa'
        'add-smsmfa'
        'add-tap'
        'remove-taps'
        'inherit-permissions'
    )

    CmdletsToExport   = @()
    AliasesToExport   = @()
    VariablesToExport = @()

    # External module dependencies.
    # ----------------------------------------------------------------------
    # Each entry is required by one or more shipped scripts. ADR-0022 documents
    # the cmdlet→submodule mapping in detail; the inline comments here are a
    # one-line crib for maintainers reading the manifest in isolation. If you
    # remove a script that was the sole consumer of one of these submodules,
    # the corresponding entry can be removed too — but check ADR-0022 first
    # to confirm nothing else still depends on it.
    #
    # We pin minimum versions (not exact versions) per ADR-0008: callers can
    # use newer SDK releases, but anything older than the pin is rejected at
    # install time.
    RequiredModules   = @(
        # Get-Mailbox, Set-Mailbox, Get-MessageTraceV2, Get-RecipientPermission,
        # Add-MailboxPermission, Get-MailboxStatistics, Set-MailboxAutoReplyConfiguration,
        # Remove-CalendarEvents, Set-MailboxCalendarConfiguration, etc.
        @{ ModuleName = 'ExchangeOnlineManagement';                  ModuleVersion = '3.7.0' }

        # Connect-MgGraph, Get-MgContext, Disconnect-MgGraph. Implicit dependency
        # of every other Microsoft.Graph.* submodule but listed explicitly so
        # CI can install it without relying on transitive resolution.
        @{ ModuleName = 'Microsoft.Graph.Authentication';            ModuleVersion = '2.0.0' }

        # Get-MgUser, New-MgUser, Update-MgUser, Get-MgUserMemberOf,
        # phone-method / TAP cmdlets live under .Identity.SignIns (see below).
        @{ ModuleName = 'Microsoft.Graph.Users';                     ModuleVersion = '2.0.0' }

        # Set-MgUserLicense (set-userlicence, offboard-user) and
        # Revoke-MgUserSignInSession (offboard-user). These cmdlets moved
        # out of .Users into .Users.Actions in SDK 2.x — without this entry
        # the offboarding script breaks at the licence-removal step.
        @{ ModuleName = 'Microsoft.Graph.Users.Actions';             ModuleVersion = '2.0.0' }

        # Get-MgGroup (new-user, get-groupmembers), Get-MgGroupMember
        # (get-groupmembers), New-MgGroupMember (new-user), and
        # Remove-MgGroupMemberByRef (offboard-user). Whole .Groups submodule
        # is needed; nothing else here covers Group cmdlets.
        @{ ModuleName = 'Microsoft.Graph.Groups';                    ModuleVersion = '2.0.0' }

        # Phone-method, TAP, and authentication-method cmdlets used across
        # add/set/get-smsmfa, add-tap, remove-taps, get-mfaaudit,
        # get-userreport, get-tenantreport, offboard-user.
        @{ ModuleName = 'Microsoft.Graph.Identity.SignIns';          ModuleVersion = '2.0.0' }

        # Get-MgOrganization (disable-autocalevents, get-tenantreport),
        # Get-MgSubscribedSku (get-allusers, set-userlicence, get-tenantreport,
        # offboard-user, get-userreport), Get-MgDirectoryRole +
        # Get-MgDirectoryRoleMember + Remove-MgDirectoryRoleMemberByRef
        # (get-tenantreport, offboard-user).
        @{ ModuleName = 'Microsoft.Graph.Identity.DirectoryManagement'; ModuleVersion = '2.0.0' }

        # Get-MgAuditLogSignIn (get-signinlogs) and Get-MgServiceAnnouncementIssue
        # (get-tenantreport service-health section). Both currently live in
        # .Reports in the 2.x SDK; if a future SDK move splits ServiceAnnouncement
        # out (it has been in Beta historically), update this entry and ADR-0022.
        @{ ModuleName = 'Microsoft.Graph.Reports';                   ModuleVersion = '2.0.0' }
    )

    # PS Gallery metadata (shown on the module page)
    PrivateData = @{
        PSData = @{
            Tags         = @('M365', 'Microsoft365', 'Exchange', 'Helpdesk', 'MSP', 'Entra', 'PowerShell', 'Toolkit', 'MFA', 'Offboarding', 'Onboarding')
            LicenseUri   = 'https://github.com/Big-Bronson/Steves-Scriptorium/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/Big-Bronson/Steves-Scriptorium'
            ReleaseNotes = '1.1.0 — Added: kill-graph, set/remove-forwarding, get/add-mailboxperms, get-userperms, get/set/add-smsmfa, add-tap, remove-taps, disable-autocalevents, inherit-permissions, Pester smoke tests + GitHub Actions verify workflow. Changed: check-mailflow migrated to Get-MessageTraceV2/Get-MessageTraceDetailV2 (V1 cmdlets are deprecated by Microsoft); RequiredModules expanded to declare every Graph submodule actually used (.Authentication, .Users.Actions, .Groups, .Identity.DirectoryManagement, .Reports). Fixed: offboard-user no longer silently swallows per-item failures during group/role/MFA cleanup; kill-graph no longer throws when no Graph context exists; get-allusers no longer aborts on accounts with null UPN.'
        }
    }
}
