# Config.ps1 — load and validate MinecraftKeeper configuration.
# Implements: LLR-001 (SR-001)

function Import-KeeperConfig {
    <#
    .SYNOPSIS
        Load a MinecraftKeeper config (.psd1) and apply env/secret overrides.
    .DESCRIPTION
        Resolution order: explicit -Path -> $env:MCKEEPER_CONFIG ->
        ./config/keeper.config.psd1 (beside the example). The NagLight token
        falls back to $env:MCKEEPER_FEED_TOKEN when blank, so secrets never have
        to live in the file. Returns a hashtable; throws on a missing file.
    #>
    [CmdletBinding()]
    param(
        [string]$Path
    )

    if (-not $Path) { $Path = $env:MCKEEPER_CONFIG }
    if (-not $Path) {
        # Default to a real config beside the module's config/ dir if present.
        $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $candidate = Join-Path $repoRoot 'config\keeper.config.psd1'
        if (Test-Path $candidate) { $Path = $candidate }
    }
    if (-not $Path -or -not (Test-Path $Path)) {
        throw "No config found. Pass -Path, set MCKEEPER_CONFIG, or create config\keeper.config.psd1 (copy config\keeper.config.example.psd1)."
    }

    $cfg = Import-PowerShellDataFile -Path $Path

    # Secret override: prefer the env var over a token baked into the file.
    if ($env:MCKEEPER_FEED_TOKEN) {
        if (-not $cfg.NagLight) { $cfg.NagLight = @{} }
        $cfg.NagLight.Token = $env:MCKEEPER_FEED_TOKEN
    }

    # Minimal validation — fail loud, early.
    foreach ($key in 'ServerRoot','ServerHost','ServerPort') {
        if (-not $cfg.ContainsKey($key)) { throw "Config missing required key '$key' ($Path)." }
    }
    return $cfg
}
