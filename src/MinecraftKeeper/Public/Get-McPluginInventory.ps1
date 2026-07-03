# Get-McPluginInventory.ps1 — enumerate installed plugins and map each to a source.
# Implements: LLR-011 (SR-004)
#
# Read-only against <ServerRoot>\plugins. For every *.jar we read plugin.yml
# (name/version/api-version) and resolve a SOURCE:
#   * Fork    — a github.com/diytechy repo whose name matches the plugin/jar
#               (Peter forks almost everything). Snapshot in data\diytechy-repos.txt.
#   * Canonical — Modrinth / Hangar / SpigotMC per data\plugin-sources.psd1.
# When neither resolves confidently the entry is recorded Source='unmapped'
# (honest over a guess). Emits objects; -OutDir writes inventory.json (machine)
# + inventory.md (human). Output carries only jar names/versions/sources — no
# server.properties, rcon secrets, IPs, or player names.

function Get-McPluginInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ServerRoot,
        [string]$DataDir,
        [string]$OutDir
    )

    if (-not $DataDir) {
        $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $DataDir = Join-Path $repoRoot 'data'
    }
    $pluginsDir = Join-Path $ServerRoot 'plugins'
    if (-not (Test-Path $pluginsDir)) { throw "No plugins dir at '$pluginsDir'" }

    # Load the fork snapshot + canonical source map.
    $forkRepos = @()
    $forkFile = Join-Path $DataDir 'diytechy-repos.txt'
    if (Test-Path $forkFile) {
        $forkRepos = Get-Content $forkFile | Where-Object { $_ -and $_ -notmatch '^\s*#' } | ForEach-Object { $_.Trim() }
    }
    $sourceMap = @{}
    $srcFile = Join-Path $DataDir 'plugin-sources.psd1'
    if (Test-Path $srcFile) { $sourceMap = Import-PowerShellDataFile -Path $srcFile }

    $normalize = { param($s) if ($s) { ($s -replace '[^a-zA-Z0-9]','').ToLowerInvariant() } else { '' } }

    $jars = Get-ChildItem -Path $pluginsDir -Filter '*.jar' -File -ErrorAction Stop | Sort-Object Name
    $items = foreach ($jar in $jars) {
        $man = Get-PluginManifest -JarPath $jar.FullName
        $pname = if ($man.Name) { $man.Name } else { [IO.Path]::GetFileNameWithoutExtension($jar.Name) }
        $key = ($man.Name ? $man.Name : '').ToLowerInvariant()

        # Canonical-source lookup (try manifest name, then jar-derived name).
        $srcEntry = $null
        foreach ($cand in @($key, ([IO.Path]::GetFileNameWithoutExtension($jar.Name).ToLowerInvariant()))) {
            if ($cand -and $sourceMap.ContainsKey($cand)) { $srcEntry = $sourceMap[$cand]; break }
        }

        # Fork match: explicit ForkAlias wins, else fuzzy match plugin/jar name
        # against the diytechy repo snapshot (normalized, case-insensitive).
        $fork = $null
        if ($srcEntry -and $srcEntry.ForkAlias) {
            if ($forkRepos -contains $srcEntry.ForkAlias) { $fork = $srcEntry.ForkAlias }
        }
        if (-not $fork) {
            $nName = & $normalize $pname
            $nJar  = & $normalize ([IO.Path]::GetFileNameWithoutExtension($jar.Name))
            foreach ($repo in $forkRepos) {
                $nRepo = & $normalize $repo
                if ($nRepo -and ($nRepo -eq $nName -or ($nName -and $nName.StartsWith($nRepo) -and $nRepo.Length -ge 4) -or ($nJar -and $nJar.StartsWith($nRepo) -and $nRepo.Length -ge 5))) {
                    $fork = $repo; break
                }
            }
        }

        $canonical = @()
        if ($srcEntry) {
            foreach ($k in 'Modrinth','Hangar','Spigot') {
                if ($srcEntry.ContainsKey($k) -and $srcEntry[$k]) { $canonical += "${k}:$($srcEntry[$k])" }
                elseif ($srcEntry.ContainsKey($k)) { $canonical += "${k}:?" }  # known-there, id unrecorded
            }
        }

        $sourceKind = if ($fork -and $canonical) { 'fork+canonical' }
                      elseif ($fork) { 'fork' }
                      elseif ($canonical) { 'canonical' }
                      else { 'unmapped' }

        [pscustomobject]@{
            Jar         = $jar.Name
            Name        = $man.Name
            Version     = $man.Version
            ApiVersion  = $man.ApiVersion
            Authors     = ($man.Authors -join ', ')
            Fork        = $fork
            Canonical   = ($canonical -join '; ')
            Source      = $sourceKind
            ManifestOk  = $man.Parsed
            Note        = $man.Note
        }
    }

    if ($OutDir) {
        if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
        $ts = (Get-Date).ToString('o')
        $mapped = @($items | Where-Object { $_.Source -ne 'unmapped' }).Count
        $withFork = @($items | Where-Object { $_.Fork }).Count
        $payload = [ordered]@{
            generatedAt = $ts
            serverRoot  = '<redacted>'   # never leak the real live path
            pluginCount = $items.Count
            mappedCount = $mapped
            forkCount   = $withFork
            plugins     = $items
        }
        $payload | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $OutDir 'inventory.json') -Encoding UTF8

        $md = New-Object System.Text.StringBuilder
        [void]$md.AppendLine("# Plugin inventory")
        [void]$md.AppendLine("")
        [void]$md.AppendLine("_Generated $ts — $($items.Count) plugins, $mapped mapped to a source, $withFork matched to a diytechy fork._")
        [void]$md.AppendLine("")
        [void]$md.AppendLine("| Jar | Name | Version | api | Fork | Canonical | Source |")
        [void]$md.AppendLine("|---|---|---|---|---|---|---|")
        foreach ($i in $items) {
            [void]$md.AppendLine("| $($i.Jar) | $($i.Name) | $($i.Version) | $($i.ApiVersion) | $($i.Fork) | $($i.Canonical) | $($i.Source) |")
        }
        $md.ToString() | Set-Content -Path (Join-Path $OutDir 'inventory.md') -Encoding UTF8
        Write-KeeperLog -Level OK -Message "inventory written to $OutDir ($($items.Count) plugins, $mapped mapped, $withFork forks)"
    }

    return $items
}
