[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ApiKey
)

$moduleName = 'StevesScriptorium'
$modulePath  = $PSScriptRoot

Write-Host ''
Write-Host '  Steves Scriptorium - Publisher' -ForegroundColor Cyan
Write-Host '  ================================' -ForegroundColor Cyan
Write-Host ''

$manifest = Import-PowerShellDataFile (Join-Path $modulePath "$moduleName.psd1")
$version   = $manifest.ModuleVersion
Write-Host "  Module:  $moduleName"
Write-Host "  Version: $version"
Write-Host ''

Write-Host '  Validating module manifest...' -ForegroundColor Yellow
try {
    Test-ModuleManifest -Path (Join-Path $modulePath "$moduleName.psd1") | Out-Null
    Write-Host '  [OK] Manifest valid' -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Manifest validation failed: $_" -ForegroundColor Red
    exit 1
}

$manifestRaw = Get-Content (Join-Path $modulePath "$moduleName.psd1") -Raw
if ($manifestRaw -match 'YOUR-ORG') {
    Write-Host '  [ERROR] Replace YOUR-ORG placeholder in the manifest before publishing.' -ForegroundColor Red
    exit 1
}

Write-Host '  [OK] No placeholder values detected' -ForegroundColor Green
Write-Host ''

if ($WhatIfPreference) {
    Write-Host "  [WHATIF] Would publish $moduleName v$version to PS Gallery" -ForegroundColor DarkYellow
    exit 0
}

$confirm = Read-Host "  Publish $moduleName v$version to PowerShell Gallery? (y/n)"
if ($confirm -ne 'y') { Write-Host '  Aborted.'; exit 0 }

Write-Host ''
Write-Host '  Publishing...' -ForegroundColor Yellow
try {
    Publish-Module -Path $modulePath -NuGetApiKey $ApiKey -Repository PSGallery -Verbose
    Write-Host ''
    Write-Host "  [OK] Published $moduleName v$version to PS Gallery" -ForegroundColor Green
    Write-Host "  View at: https://www.powershellgallery.com/packages/$moduleName" -ForegroundColor Cyan
} catch {
    Write-Host "  [ERROR] Publish failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host '  Team install command:' -ForegroundColor White
Write-Host '  Install-Module StevesScriptorium -Scope CurrentUser' -ForegroundColor Yellow
Write-Host ''
