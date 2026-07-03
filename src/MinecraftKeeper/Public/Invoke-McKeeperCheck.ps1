# Invoke-McKeeperCheck.ps1 — the scheduled checker: probe + version + report.
# Implements: LLR-006 (SR-003, SR-002)
#
# WI-10.7 v1 orchestrator. Runs the server-up probe and the Paper version-
# currency check, then reports each to NagLight via POST /api/feed. Designed to
# run on a schedule (Mini-serv Task Scheduler). Staleness-ladder honesty: every
# enabled check posts on every run, and posts ok=$false with a note whenever it
# can't positively confirm health — a dead check must never read as silent-green.
#
# -IncludePlugins also runs the plugin inventory + update plan and reports an
# "outdated plugins (N)" signal (WI-10.8). -WhatIfPost runs everything but only
# prints what it would POST (safe for agent/dev runs without a live NagLight).

function Invoke-McKeeperCheck {
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [switch]$IncludePlugins,
        [switch]$WhatIfPost
    )

    $cfg = Import-KeeperConfig -Path $ConfigPath
    $nl = $cfg.NagLight
    $token = if ($nl) { $nl.Token } else { $null }
    $url = if ($nl -and $nl.Url) { $nl.Url } else { 'http://localhost:8787' }
    $checks = if ($nl -and $nl.Checks) { $nl.Checks } else { @{ ServerUp='mc-server-up'; Version='mc-update'; Plugins='mc-plugins' } }

    $report = {
        param($checkId, $ok, $note)
        Send-NagLightFeed -Check $checkId -Ok $ok -Note $note -Url $url -Token $token -WhatIfPost:$WhatIfPost
    }

    $results = [ordered]@{}

    # --- 1) server-up probe ---
    $status = Get-McServerStatus -ServerHost $cfg.ServerHost -ServerPort $cfg.ServerPort -CheckProcess
    $results.ServerUp = $status
    & $report $checks.ServerUp ([bool]$status.Up) $status.Note | Out-Null

    # --- 2) Paper version currency ---
    $apiBase = if ($cfg.PaperApiBase) { $cfg.PaperApiBase } else { 'https://fill.papermc.io/v3' }
    $project = if ($cfg.PaperProject) { $cfg.PaperProject } else { 'paper' }
    $ver = Get-McPaperCurrency -ServerRoot $cfg.ServerRoot -Project $project -ApiBase $apiBase
    $results.Version = $ver
    & $report $checks.Version ([bool]$ver.Ok) $ver.Note | Out-Null

    # --- 3) optional: plugin currency ---
    if ($IncludePlugins) {
        try {
            $inv = Get-McPluginInventory -ServerRoot $cfg.ServerRoot
            $mcVer = if ($ver.InstalledVersion) { $ver.InstalledVersion } else { $null }
            if ($mcVer) {
                $plan = Get-McPluginUpdatePlan -Inventory $inv -McVersion $mcVer
                $outdated = @($plan | Where-Object { $_.NeedsUpdate }).Count
                $ok = ($outdated -eq 0)
                $note = if ($ok) { "all $($inv.Count) plugins current for MC $mcVer (best-effort)" } else { "$outdated plugin(s) outdated for MC $mcVer" }
                $results.Plugins = [pscustomobject]@{ Ok = $ok; Outdated = $outdated; Total = $inv.Count; Plan = $plan }
                & $report $checks.Plugins $ok $note | Out-Null
            } else {
                & $report $checks.Plugins $false 'cannot determine MC version for plugin currency' | Out-Null
            }
        } catch {
            & $report $checks.Plugins $false "plugin check failed: $_" | Out-Null
        }
    }

    return [pscustomobject]$results
}
