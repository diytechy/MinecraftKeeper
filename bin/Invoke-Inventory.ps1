#requires -Version 7.0
# bin\Invoke-Inventory.ps1 — enumerate installed plugins and map each to a source.
#
# Read-only against the server share. Writes inventory.json + inventory.md to
# -OutDir (default: <repo>\out\, git-ignored). The committed sample under
# docs\evidence\ is a REDACTED copy — never point -OutDir at a tracked path with
# a real live server unless you have reviewed it for secrets first.
#   pwsh -NoProfile -File <repo>\bin\Invoke-Inventory.ps1 -OutDir out
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$ServerRoot,
    [string]$OutDir
)

Import-Module (Join-Path $PSScriptRoot '..\src\MinecraftKeeper\MinecraftKeeper.psd1') -Force
if (-not $ServerRoot) {
    $cfg = Import-KeeperConfig -Path $ConfigPath
    $ServerRoot = $cfg.ServerRoot
}
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '..\out' }

$items = Get-McPluginInventory -ServerRoot $ServerRoot -OutDir $OutDir
$items | Format-Table Jar, Name, Version, Fork, Source -AutoSize
