# Get-McPaperCurrency.ps1 — is the installed Paper build current?
# Implements: LLR-005 (SR-003)
#
# Generalized from life-tracker\feeders\minecraft-current.ps1: separates the
# PURE comparison logic (which jar / which version / latest build) from I/O so
# the checker can compose it and report to NagLight itself. Best-effort by
# design — a missing jar or an unreachable/absent API version yields Ok=$false
# with an explanatory note, NEVER a silent pass (staleness-ladder honesty).

function Get-McPaperCurrency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ServerRoot,
        [string]$Project = 'paper',
        # PaperMC "fill" v3 API. The old v2 API (api.papermc.io/v2) was SUNSET —
        # it now returns {error:"sunset"}, which is exactly why the checker must
        # treat an unexpected API response as Ok=false, not silent-green.
        [string]$ApiBase = 'https://fill.papermc.io/v3',
        # Which jar the server actually runs. When omitted we prefer the jar named
        # in START.bat (the source of truth for what's live), else the newest
        # <project>-*.jar by write time.
        [string]$JarName
    )

    $ApiBase = $ApiBase.TrimEnd('/')
    $ok = $false
    $note = ''
    $installedVersion = $null
    $installedBuild = $null
    $latestBuild = $null

    try {
        if (-not $JarName) {
            $JarName = Resolve-ActivePaperJar -ServerRoot $ServerRoot -Project $Project
        }
        if (-not $JarName) { throw "No $Project-*.jar found in '$ServerRoot'" }

        # Expected: <project>-<mcversion>-<build>.jar  e.g. paper-1.21.1-123.jar
        # or paper-26.2-34.jar. Version = one-or-more dotted numeric groups.
        $pattern = "^$([regex]::Escape($Project))-([0-9]+(?:\.[0-9]+)+)-([0-9]+)\.jar$"
        $m = [regex]::Match($JarName, $pattern)
        if (-not $m.Success) { throw "cannot parse version/build from jar name '$JarName'" }
        $installedVersion = $m.Groups[1].Value
        $installedBuild = [int]$m.Groups[2].Value

        # v3 returns an array of builds; each build's number is `id`, its channel
        # is uppercase (STABLE/BETA/ALPHA). Prefer the newest STABLE build if any
        # exist; otherwise the newest build of any channel (this server tracks
        # ALPHA builds, so a channel filter alone would wrongly report "current").
        $apiUrl = "$ApiBase/projects/$Project/versions/$installedVersion/builds"
        $resp = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        if (-not $resp -or $resp.Count -eq 0) { throw "$Project API returned no builds for $installedVersion" }

        $stable = $resp | Where-Object { $_.channel -eq 'STABLE' }
        $latest = if ($stable) { $stable | Sort-Object id -Descending | Select-Object -First 1 }
                  else { $resp | Sort-Object id -Descending | Select-Object -First 1 }
        $latestBuild = [int]$latest.id
        $latestChannel = $latest.channel

        if ($installedBuild -ge $latestBuild) {
            $ok = $true
            $note = "$Project $installedVersion build $installedBuild is current (latest $latestBuild, $latestChannel)"
        } else {
            $ok = $false
            $note = "$Project $installedVersion build $installedBuild is behind (latest $latestBuild, $latestChannel)"
        }
    } catch {
        $ok = $false
        $note = "version check failed: $_"
    }

    return [pscustomobject]@{
        Ok               = $ok
        Project          = $Project
        InstalledVersion = $installedVersion
        InstalledBuild   = $installedBuild
        LatestBuild      = $latestBuild
        Jar              = $JarName
        Note             = $note
    }
}

function Resolve-ActivePaperJar {
    # Which server jar is actually live? Prefer the one named in START.bat (the
    # operator's source of truth), then fall back to the newest matching jar.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ServerRoot,
        [string]$Project = 'paper'
    )
    $startBat = Join-Path $ServerRoot 'START.bat'
    if (Test-Path $startBat) {
        $active = Get-Content -Path $startBat -ErrorAction SilentlyContinue |
            Where-Object { $_ -notmatch '^\s*::' } |               # skip REM-commented lines
            ForEach-Object { [regex]::Match($_, "($([regex]::Escape($Project))-[^\s`"]+\.jar)") } |
            Where-Object { $_.Success } |
            ForEach-Object { $_.Groups[1].Value } |
            Select-Object -First 1
        if ($active) { return $active }
    }
    $jar = Get-ChildItem -Path $ServerRoot -Filter "$Project-*.jar" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($jar) { return $jar.Name }
    return $null
}
