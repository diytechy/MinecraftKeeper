#requires -Version 7.0
# bin\Invoke-Backup.ps1 — scheduled-task entry point for the settings backup.
#
# Archives server settings + plugin configs to <BackupDest> and reports
# "settings backup ran" to NagLight. Worlds are excluded unless -IncludeWorlds.
#   pwsh -NoProfile -File <repo>\bin\Invoke-Backup.ps1
#
# -WhatIf performs the copy/plan but skips writing the archive (PowerShell's
# standard ShouldProcess). -WhatIfPost skips the NagLight POST only.
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath,
    [switch]$IncludeWorlds,
    [switch]$WhatIfPost
)

Import-Module (Join-Path $PSScriptRoot '..\src\MinecraftKeeper\MinecraftKeeper.psd1') -Force
$cfg = Import-KeeperConfig -Path $ConfigPath

$includeWorldsEff = $IncludeWorlds -or [bool]$cfg.IncludeWorlds
$res = Backup-McSettings -ServerRoot $cfg.ServerRoot -BackupDest $cfg.BackupDest -IncludeWorlds:$includeWorldsEff

$nl = $cfg.NagLight
$checkId = if ($nl -and $nl.Checks -and $nl.Checks.Backup) { $nl.Checks.Backup } else { 'mc-settings-backup' }
$url = if ($nl -and $nl.Url) { $nl.Url } else { 'http://localhost:8787' }
$token = if ($nl) { $nl.Token } else { $null }
$note = if ($res.Ok) { "settings backup: $($res.FileCount) files, $($res.SizeMB)MB" } else { 'settings backup did NOT produce an archive' }
Send-NagLightFeed -Check $checkId -Ok ([bool]$res.Ok) -Note $note -Url $url -Token $token -WhatIfPost:$WhatIfPost | Out-Null

$res | ConvertTo-Json -Depth 4
