#requires -Version 7.0
# bin\Invoke-Check.ps1 — scheduled-task entry point for the MinecraftKeeper checker.
#
# Runs the server-up probe + Paper version currency (and, with -IncludePlugins,
# plugin currency) and reports each to NagLight. Point Windows Task Scheduler at:
#   pwsh -NoProfile -File <repo>\bin\Invoke-Check.ps1 -IncludePlugins
#
# Set MCKEEPER_CONFIG (or pass -ConfigPath) and MCKEEPER_FEED_TOKEN in the task's
# environment. Use -WhatIfPost to trial the run without POSTing to NagLight.
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$IncludePlugins,
    [switch]$WhatIfPost
)

Import-Module (Join-Path $PSScriptRoot '..\src\MinecraftKeeper\MinecraftKeeper.psd1') -Force
$result = Invoke-McKeeperCheck -ConfigPath $ConfigPath -IncludePlugins:$IncludePlugins -WhatIfPost:$WhatIfPost
$result | ConvertTo-Json -Depth 5
