# Feed.ps1 — NagLight feeder client (POST /api/feed).
# Implements: LLR-003 (SR-002)
#
# Contract (NagLight DESIGN §6 / handleAPIFeed): POST {check, ok, note} to
# /api/feed. NagLight locates the `automated` item by its Check field and marks
# it done (ok=true) or failed (ok=false). The staleness ladder means a feeder
# that stops posting — or posts ok=false — surfaces as stale/worsening, NEVER as
# silent-green. So callers must:
#   * post on EVERY run (never skip because "nothing changed"), and
#   * pass ok=$false with an explanatory note whenever the check could not be
#     positively confirmed (missing jar, unreachable API, exception).
# This function never fabricates ok=true; it only transmits what it's given.

function Send-NagLightFeed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][bool]$Ok,
        [string]$Note = '',
        [string]$Url = 'http://localhost:8787',
        [string]$Token,
        # When set, don't POST — just emit what would be sent. Lets the checker
        # run end-to-end without a live NagLight (and keeps agent sessions safe).
        [switch]$WhatIfPost
    )

    $Url = $Url.TrimEnd('/')
    $endpoint = "$Url/api/feed"
    $payload = @{ check = $Check; ok = $Ok }
    if ($Note) { $payload.note = $Note }
    $body = $payload | ConvertTo-Json -Compress

    if ($WhatIfPost) {
        Write-KeeperLog -Level INFO -Message "feed (dry-run) -> $endpoint  $body"
        return [pscustomobject]@{ Check = $Check; Ok = $Ok; Posted = $false; Note = $Note }
    }

    $headers = @{ 'Content-Type' = 'application/json' }
    if ($Token) { $headers['Authorization'] = "Bearer $Token" }

    try {
        $resp = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $body -TimeoutSec 10 -ErrorAction Stop
        Write-KeeperLog -Level OK -Message "feed '$Check' ok=$Ok posted (color=$($resp.color))"
        return [pscustomobject]@{ Check = $Check; Ok = $Ok; Posted = $true; Note = $Note; Color = $resp.color }
    } catch {
        # A failed POST is itself a delivery failure — surface it, but don't
        # crash the whole run (other checks may still post).
        Write-KeeperLog -Level WARN -Message "feed '$Check' FAILED to post: $_"
        return [pscustomobject]@{ Check = $Check; Ok = $Ok; Posted = $false; Note = "post-failed: $_" }
    }
}
