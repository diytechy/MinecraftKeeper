# Get-McForkStatus.ps1 — per-fork status detection for the fork-fix pipeline (WI-10.9).
# Implements: LLR-030 (SR-007)
#
# For plugins sourced from one of the Owner's github.com/diytechy forks, detect where
# the fork stands: does it have a published release, what's its latest tag, and
# does the installed build match? This is the DETECTION half of the fork-fix
# rung — it tells an operator (or the fork-plugin-update skill) which forks need
# attention for a new Minecraft version. It NEVER builds, commits, or pushes;
# the actual auto-fix + publish stays Owner-gated (see skills/fork-plugin-update).
#
# Read-only + best-effort: unauthenticated GitHub API (60 req/hr). A repo with no
# releases, or a rate-limit/network failure, yields Status='unknown' with a note
# rather than a false "current".

function Get-McForkStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Inventory,           # output of Get-McPluginInventory
        [string]$Owner = 'diytechy',
        [string]$GitHubApi = 'https://api.github.com'
    )

    $GitHubApi = $GitHubApi.TrimEnd('/')
    $headers = @{ 'User-Agent' = 'MinecraftKeeper'; 'Accept' = 'application/vnd.github+json' }
    if ($env:GITHUB_TOKEN) { $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN" }

    $forks = $Inventory | Where-Object { $_.Fork }
    $out = foreach ($p in $forks) {
        $repo = $p.Fork
        $r = [ordered]@{
            Name = $p.Name; Fork = "$Owner/$repo"; Installed = $p.Version
            LatestTag = $null; LatestRelease = $null; HasReleaseAsset = $false
            Status = 'unknown'; Note = ''
        }
        try {
            # Latest release (may 404 if the fork publishes none).
            try {
                $rel = Invoke-RestMethod -Uri "$GitHubApi/repos/$Owner/$repo/releases/latest" -Headers $headers -TimeoutSec 15 -ErrorAction Stop
                $r.LatestRelease = $rel.tag_name
                $r.HasReleaseAsset = [bool]($rel.assets | Where-Object { $_.name -match '\.jar$' })
            } catch {
                $r.Note += 'no published release; '
            }
            # Latest tag as a fallback signal of upstream-tracking activity.
            $tags = Invoke-RestMethod -Uri "$GitHubApi/repos/$Owner/$repo/tags?per_page=1" -Headers $headers -TimeoutSec 15 -ErrorAction Stop
            if ($tags -and $tags.Count -gt 0) { $r.LatestTag = $tags[0].name }

            $r.Status = if ($r.HasReleaseAsset) { 'fork-publishes-jar' }
                        elseif ($r.LatestRelease) { 'fork-release-no-jar' }
                        elseif ($r.LatestTag) { 'fork-tags-only-no-release' }
                        else { 'fork-no-releases-or-tags' }
            if (-not $r.Note) { $r.Note = 'detection only — build/publish is Owner-gated (skills/fork-plugin-update)' }
        } catch {
            $r.Note += "GitHub lookup failed: $_"
        }
        [pscustomobject]$r
    }
    return @($out)
}
