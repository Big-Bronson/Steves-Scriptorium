<#
.SYNOPSIS
Publishes Spellbook to PowerShell Gallery with pre-flight checks.

.DESCRIPTION
Validates the manifest, parse-checks all Public/*.ps1, cross-checks
FunctionsToExport against actual files, ensures the working tree is
clean and on main, ensures CHANGELOG.md has content under [Unreleased],
then publishes. API key is read from Windows Credential Manager via
the Get-StoredSecret helper (defined in $PROFILE).

.PARAMETER WhatIf
Run all checks and show what would happen without publishing.

.PARAMETER SkipGitCheck
Skip the clean-tree-on-main check. Use only when you have a deliberate
reason (e.g. publishing from a release branch).

.EXAMPLE
.\Publish.ps1 -WhatIf

.EXAMPLE
.\Publish.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipGitCheck
)

$ErrorActionPreference = 'Stop'

# --- Configuration ---------------------------------------------------------
$ModuleName   = 'Spellbook'
$ManifestPath = ".\$ModuleName.psd1"
$CredTarget   = 'PSGallery-Spellbook'

# --- Helpers ---------------------------------------------------------------
function Write-Step  { param($m) Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "    OK: $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "    !!  $m" -ForegroundColor Yellow }

# --- Pre-flight: warn early if neither secret source is available ----------
$hasStoredSecret = [bool](Get-Command Get-StoredSecret -ErrorAction SilentlyContinue)
$hasEnvKey       = [bool]$env:PSGALLERY_API_KEY
if (-not $hasStoredSecret -and -not $hasEnvKey) {
    throw @'
No API key source found. Set one up before publishing:

  Option A — Windows Credential Manager (recommended for regular publishers):
    Add Get-StoredSecret / Set-StoredSecret helpers to your $PROFILE, then:
    Set-StoredSecret -Target 'PSGallery-Spellbook' -Secret '<your-key>'

  Option B — Environment variable (simplest for one-off use):
    $env:PSGALLERY_API_KEY = '<your-key>'
    .\Publish.ps1

Your PS Gallery API key: https://www.powershellgallery.com/account/apikeys
'@
}

# --- 1. Manifest validation ------------------------------------------------
Write-Step 'Validating manifest'
if (-not (Test-Path $ManifestPath)) {
    throw "Manifest not found at $ManifestPath. Run from the repo root."
}
$manifest = Test-ModuleManifest -Path $ManifestPath
Write-Ok "Manifest parses, version $($manifest.Version)"

# --- 2. Parse-check Public/*.ps1 -------------------------------------------
Write-Step 'Parse-checking Public/*.ps1'
$parseErrors = @()
Get-ChildItem -Path .\Public -Filter *.ps1 -Recurse | ForEach-Object {
    $tokens = $null
    $errs   = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $_.FullName, [ref]$tokens, [ref]$errs
    ) | Out-Null
    if ($errs) {
        $parseErrors += "$($_.Name): $($errs[0].Message)"
    }
}
if ($parseErrors) {
    $parseErrors | ForEach-Object { Write-Error $_ }
    throw 'Parse errors found. Aborting.'
}
Write-Ok 'All Public/*.ps1 parse cleanly'

# --- 3. Cross-check FunctionsToExport vs actual files ----------------------
Write-Step 'Cross-checking FunctionsToExport against Public/'
$declared = @($manifest.ExportedFunctions.Keys)
$actual   = @(Get-ChildItem .\Public -Filter *.ps1 | Select-Object -ExpandProperty BaseName)

$missingInManifest = $actual   | Where-Object { $_ -notin $declared }
$missingFiles = $declared | Where-Object { $_ -ne 'invoke' -and $_ -notin $actual }

if ($missingInManifest) {
    Write-Warn2 "In Public/ but not in FunctionsToExport: $($missingInManifest -join ', ')"
}
if ($missingFiles) {
    Write-Warn2 "In FunctionsToExport but no .ps1: $($missingFiles -join ', ')"
}
if ($missingInManifest -or $missingFiles) {
    throw 'Manifest and Public/ are out of sync. Fix the manifest before publishing.'
}
Write-Ok 'Manifest and Public/ are in sync'

# --- 4. Clean git tree on main (unless skipped) ----------------------------
if (-not $SkipGitCheck) {
    Write-Step 'Checking git working tree'
    $dirty = git status --porcelain
    if ($dirty) {
        Write-Host $dirty
        throw 'Working tree has uncommitted changes. Commit or stash first.'
    }
    $branch = git rev-parse --abbrev-ref HEAD
    if ($branch -ne 'main') {
        throw "Not on main (current: $branch). Switch to main before publishing."
    }
    Write-Ok 'Clean tree, on main'
}

# --- 5. CHANGELOG sanity ---------------------------------------------------
Write-Step 'Checking CHANGELOG.md'
if (-not (Test-Path .\CHANGELOG.md)) {
    throw 'CHANGELOG.md not found. Create one before publishing.'
}
$changelog = Get-Content .\CHANGELOG.md -Raw
if ($changelog -notmatch '## \[Unreleased\]\s*\r?\n([\s\S]*?)(?=\r?\n## \[|\z)') {
    throw 'CHANGELOG.md missing [Unreleased] section.'
}
$unreleasedBody = $Matches[1].Trim()
# Empty section headers (### Added/Fixed with nothing under them) are OK as scaffolding
$content = $unreleasedBody -replace '###\s+\w+\s*(?=\r?\n###|\z)', ''
if ([string]::IsNullOrWhiteSpace($content.Trim())) {
    throw '[Unreleased] section is empty. Add release notes before publishing.'
}
Write-Ok '[Unreleased] has content'

# --- 6. Read API key (Credential Manager → env var fallback) ---------------
Write-Step 'Reading API key'
$apiKey = $null
if ($hasStoredSecret) {
    $apiKey = Get-StoredSecret -Target $CredTarget
}
if (-not $apiKey) {
    $apiKey = $env:PSGALLERY_API_KEY
}
if (-not $apiKey) {
    throw "API key empty. Check your Credential Manager entry '$CredTarget' or set `$env:PSGALLERY_API_KEY."
}
Write-Ok 'API key retrieved'

# --- 7. Publish ------------------------------------------------------------
# Publish-Module -Path requires the folder name to match the module name.
# Stage to a temp directory named after the module so this works regardless
# of what the repo working directory is called.
Write-Step "Publishing $ModuleName v$($manifest.Version)"
if ($PSCmdlet.ShouldProcess($ModuleName, "Publish v$($manifest.Version) to PSGallery")) {
    $stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) "PSPublish"
    $stagingPath = Join-Path $stagingRoot $ModuleName
    if (Test-Path $stagingPath) { Remove-Item $stagingPath -Recurse -Force }
    New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null

    # Copy only the module artefacts — not dev/repo files
    $include = @("$ModuleName.psd1", "$ModuleName.psm1", "Public", "Private", "LICENSE")
    foreach ($item in $include) {
        $src = Join-Path $PSScriptRoot $item
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $stagingPath $item) -Recurse
        }
    }

    try {
        Publish-Module -Path $stagingPath -NuGetApiKey $apiKey -Verbose
        Write-Ok 'Published. Allow 15-30 minutes for PS Gallery to index.'
    } finally {
        Remove-Item $stagingRoot -Recurse -Force
    }
} else {
    Write-Host '    (WhatIf: skipped Publish-Module)' -ForegroundColor DarkGray
}