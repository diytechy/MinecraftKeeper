#requires -Version 7.0
# Pester 5 tests for MinecraftKeeper. Unit-level, no live server or network:
# fixtures are built in a temp dir and the feed client is exercised in -WhatIfPost
# mode. Integration cases against the live share (TC-005/007/010/011/012) are
# Release/Full-tier and run by hand — see docs/status.md "What was executed".

BeforeAll {
    $moduleManifest = Join-Path $PSScriptRoot '../src/MinecraftKeeper/MinecraftKeeper.psd1'
    Import-Module $moduleManifest -Force
    $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ("mckeeper-tests-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:tmp -Force | Out-Null

    # Build a fixture plugin jar (a zip carrying plugin.yml) for the manifest test.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $stage = Join-Path $script:tmp 'jarstage'
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    @"
name: FixturePlugin
version: 1.2.3
api-version: 1.20
main: com.example.Fixture
author: tester
depend: [WorldEdit]
"@ | Set-Content -Path (Join-Path $stage 'plugin.yml') -Encoding UTF8
    $script:fixtureJar = Join-Path $script:tmp 'FixturePlugin-1.2.3.jar'
    [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $script:fixtureJar)
}

AfterAll {
    Remove-Item -Path $script:tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Import-KeeperConfig (SR-001/TC-001)' {
    It 'throws a helpful error when no config is found' {
        { Import-KeeperConfig -Path (Join-Path $script:tmp 'does-not-exist.psd1') } |
            Should -Throw -ExpectedMessage '*copy config\keeper.config.example.psd1*'
    }
    It 'overrides the NagLight token from MCKEEPER_FEED_TOKEN' {
        $cfgPath = Join-Path $script:tmp 'c.psd1'
        "@{ ServerRoot='x'; ServerHost='h'; ServerPort=1; NagLight=@{ Url='u'; Token='FILE' } }" |
            Set-Content -Path $cfgPath -Encoding UTF8
        $env:MCKEEPER_FEED_TOKEN = 'ENVTOKEN'
        try {
            $cfg = Import-KeeperConfig -Path $cfgPath
            $cfg.NagLight.Token | Should -Be 'ENVTOKEN'
        } finally { Remove-Item Env:\MCKEEPER_FEED_TOKEN -ErrorAction SilentlyContinue }
    }
}

Describe 'Send-NagLightFeed (SR-002/TC-002)' {
    It 'in -WhatIfPost mode returns Posted=false and does not POST' {
        $r = Send-NagLightFeed -Check 'unit-test' -Ok $true -Note 'n' -WhatIfPost
        $r.Posted | Should -BeFalse
        $r.Check  | Should -Be 'unit-test'
        $r.Ok     | Should -BeTrue
    }
}

Describe 'Get-PluginManifest (SR-004/TC-006)' {
    It 'parses name/version/api-version from a jar plugin.yml' {
        InModuleScope MinecraftKeeper -Parameters @{ Jar = $script:fixtureJar } {
            param($Jar)
            $m = Get-PluginManifest -JarPath $Jar
            $m.Parsed     | Should -BeTrue
            $m.Name       | Should -Be 'FixturePlugin'
            $m.Version    | Should -Be '1.2.3'
            $m.ApiVersion | Should -Be '1.20'
            $m.Depend     | Should -Contain 'WorldEdit'
        }
    }
    It 'records a note (not a crash) for a jar without plugin.yml' {
        $empty = Join-Path $script:tmp 'empty.jar'
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $z = [System.IO.Compression.ZipFile]::Open($empty, 'Create'); $z.Dispose()
        InModuleScope MinecraftKeeper -Parameters @{ Jar = $empty } {
            param($Jar)
            $m = Get-PluginManifest -JarPath $Jar
            $m.Parsed | Should -BeFalse
            $m.Note   | Should -Match 'no plugin.yml'
        }
    }
}

Describe 'Get-McServerStatus (SR-003/TC-003)' {
    It 'reports Up=false for a closed port' {
        $s = Get-McServerStatus -ServerHost '127.0.0.1' -ServerPort 59999 -TimeoutMs 800
        $s.Up | Should -BeFalse
        $s.Note | Should -Match 'no response|error'
    }
}

Describe 'Test-ApiVersionCompatible (SR-006/TC-009)' {
    It 'accepts api-version <= server MC version and rejects greater' {
        InModuleScope MinecraftKeeper {
            Test-ApiVersionCompatible -ApiVersion '1.16' -McVersion '26.2' | Should -BeTrue
            Test-ApiVersionCompatible -ApiVersion '26.2' -McVersion '26.2' | Should -BeTrue
            Test-ApiVersionCompatible -ApiVersion '99'   -McVersion '26.2' | Should -BeFalse
            Test-ApiVersionCompatible -ApiVersion '1.21.4' -McVersion '1.21.1' | Should -BeFalse
        }
    }
}

Describe 'Resolve-ActivePaperJar (SR-003/TC-004)' {
    It 'prefers the jar named on an uncommented START.bat line' {
        $sr = Join-Path $script:tmp 'srv'; New-Item -ItemType Directory -Path $sr -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $sr 'paper-26.1.2-67.jar') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $sr 'paper-26.2-34.jar') -Force | Out-Null
        "::java -jar paper-26.1.2-67.jar`r`njava -Xms2G -jar paper-26.2-34.jar -nogui" |
            Set-Content -Path (Join-Path $sr 'START.bat') -Encoding UTF8
        InModuleScope MinecraftKeeper -Parameters @{ Root = $sr } {
            param($Root)
            Resolve-ActivePaperJar -ServerRoot $Root -Project 'paper' | Should -Be 'paper-26.2-34.jar'
        }
    }
}
