# Get-McPluginUpdatePlan.ps1 — compute what plugin updates are available.
# Implements: LLR-012 (SR-006)
#
# For each inventoried plugin with a resolvable source, look up the latest build
# COMPATIBLE with the server's Minecraft version and compare to installed. This
# is read-only planning — it downloads nothing. Modrinth is queried live (real
# API); fork/Hangar/Spigot-only or unmapped plugins are flagged for a human
# rather than guessed. Every entry records a Reason so the plan is auditable.

function Get-McPluginUpdatePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Inventory,   # output of Get-McPluginInventory
        [Parameter(Mandatory)][string]$McVersion,
        [string[]]$Loaders = @('paper','spigot','bukkit'),
        [string]$ModrinthApi = 'https://api.modrinth.com/v2'
    )

    $ModrinthApi = $ModrinthApi.TrimEnd('/')
    $plan = foreach ($p in $Inventory) {
        $entry = [ordered]@{
            Name        = $p.Name
            Jar         = $p.Jar
            Installed   = $p.Version
            Source      = $p.Source
            Latest      = $null
            NeedsUpdate = $false
            Downloadable = $false
            DownloadUrl = $null
            Sha512      = $null
            Reason      = ''
        }

        # Pick a Modrinth slug from the Canonical field if present.
        $slug = $null
        if ($p.Canonical -match 'Modrinth:([^\s;?]+)') { $slug = $Matches[1] }

        if (-not $slug) {
            $entry.Reason = if ($p.Fork) { "fork-sourced ($($p.Fork)) — check GitHub releases manually" }
                            elseif ($p.Source -eq 'unmapped') { 'unmapped — no source to check' }
                            else { 'no Modrinth slug — Hangar/Spigot check is manual in v1' }
            [pscustomobject]$entry; continue
        }

        try {
            $gv = ConvertTo-Json @($McVersion) -Compress
            $ld = ConvertTo-Json $Loaders -Compress
            $uri = "$ModrinthApi/project/$slug/version?game_versions=$gv&loaders=$ld"
            $versions = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 15 -ErrorAction Stop
            if (-not $versions -or $versions.Count -eq 0) {
                $entry.Reason = "no Modrinth build listed for MC $McVersion (loaders: $($Loaders -join '/'))"
                [pscustomobject]$entry; continue
            }
            # Newest first by date_published.
            $latest = $versions | Sort-Object { [datetime]$_.date_published } -Descending | Select-Object -First 1
            $file = $latest.files | Where-Object { $_.primary } | Select-Object -First 1
            if (-not $file) { $file = $latest.files | Select-Object -First 1 }

            $entry.Latest = $latest.version_number
            $entry.DownloadUrl = $file.url
            $entry.Sha512 = $file.hashes.sha512
            $entry.Downloadable = [bool]$file.url
            # Compare with build-metadata (SemVer '+...') stripped so a local
            # build hash (7.4.4-beta-01+b969a7f7e) doesn't read as "behind" the
            # same release (7.4.4-beta-01). A '-SNAPSHOT'/'-pre' suffix is kept —
            # that's a genuinely different (pre-release) build.
            $normVer = { param($v) if ($v) { ($v -split '\+')[0].Trim() } else { $v } }
            $insN = & $normVer $p.Version
            $latN = & $normVer $latest.version_number
            $entry.NeedsUpdate = ($insN -and $latN -and ($insN -ne $latN))
            $entry.Reason = if ($entry.NeedsUpdate) { "update $($p.Version) -> $($latest.version_number)" } else { 'up to date (version matches after stripping build metadata)' }
        } catch {
            $entry.Reason = "Modrinth lookup failed: $_"
        }
        [pscustomobject]$entry
    }
    return $plan
}
