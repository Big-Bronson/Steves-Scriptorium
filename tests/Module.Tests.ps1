# Module.Tests.ps1
# Smoke tests for StevesScriptorium. These are the same checks Publish.ps1
# runs at publish time — extracted so they run on every push/PR. The point
# is to catch manifest drift before someone tries to publish a broken
# module, not to test command behaviour against a tenant.
#
# Run locally:    Invoke-Pester ./tests
# Run in CI:      see .github/workflows/verify.yml

# Resolved at discovery time so -ForEach can iterate it. BeforeAll runs
# during execution, which is too late for parametric tests.
$RepoRoot     = Split-Path -Parent $PSScriptRoot
$PublicScripts = Get-ChildItem -Path (Join-Path $RepoRoot 'Public') -Filter '*.ps1'

BeforeAll {
    $script:RepoRoot     = Split-Path -Parent $PSScriptRoot
    $script:ManifestPath = Join-Path $RepoRoot 'StevesScriptorium.psd1'
    $script:Manifest     = Test-ModuleManifest -Path $ManifestPath
    $script:PublicScripts = Get-ChildItem -Path (Join-Path $RepoRoot 'Public') -Filter '*.ps1'
}

Describe 'Manifest' {
    It 'parses cleanly' {
        $Manifest | Should -Not -BeNullOrEmpty
    }

    It 'has a version' {
        $Manifest.Version | Should -Not -BeNullOrEmpty
    }

    It 'declares ProjectUri pointing at the actual repo' {
        $Manifest.PrivateData.PSData.ProjectUri | Should -Match 'Big-Bronson/Steves-Scriptorium'
    }

    It 'declares LicenseUri pointing at the actual repo' {
        $Manifest.PrivateData.PSData.LicenseUri | Should -Match 'Big-Bronson/Steves-Scriptorium'
    }
}

Describe 'FunctionsToExport vs Public/' {
    BeforeAll {
        $script:Declared = @($Manifest.ExportedFunctions.Keys)
        $script:Actual   = @($PublicScripts.BaseName)
    }

    It 'every script in Public/ is declared in FunctionsToExport' {
        $missing = @($Actual | Where-Object { $_ -notin $Declared })
        $missing | Should -BeNullOrEmpty -Because "scripts exist but are not exported: $($missing -join ', ')"
    }

    It 'every FunctionsToExport entry has a matching Public/ script (toolkit excepted)' {
        $missing = @($Declared | Where-Object { $_ -notin $Actual -and $_ -ne 'toolkit' })
        $missing | Should -BeNullOrEmpty -Because "exported but no script: $($missing -join ', ')"
    }

    It 'declares toolkit explicitly' {
        $Declared | Should -Contain 'toolkit'
    }
}

Describe 'Public scripts parse cleanly' {
    It '<_.Name> parses' -ForEach $PublicScripts {
        $errs   = $null
        $tokens = $null
        [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errs) | Out-Null
        $errs | Should -BeNullOrEmpty
    }
}

Describe 'CHANGELOG' {
    BeforeAll {
        $script:Changelog = Get-Content (Join-Path $RepoRoot 'CHANGELOG.md') -Raw
    }

    It 'has an [Unreleased] section' {
        $Changelog | Should -Match '##\s+\[Unreleased\]'
    }

    It 'has a dated section matching the manifest version' {
        $version = $Manifest.Version.ToString()
        $Changelog | Should -Match ('##\s+\[{0}\]' -f [regex]::Escape($version))
    }
}
