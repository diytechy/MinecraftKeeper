#requires -Version 7.0
# bin\Invoke-Update.ps1 — plan (and, with -Execute, apply) plugin updates.
#
# DRY-RUN BY DEFAULT. Without -Execute this only inventories, computes the update
# plan, stages+verifies candidate jars, and prints what it WOULD do. -Execute
# performs the backup-old-then-install swap (with rollback) for verified updates.
#   Plan only:     pwsh -File bin\Invoke-Update.ps1
#   Apply for real: pwsh -File bin\Invoke-Update.ps1 -Execute
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath,
    [switch]$Execute
)

Import-Module (Join-Path $PSScriptRoot '..\src\MinecraftKeeper\MinecraftKeeper.psd1') -Force
$cfg = Import-KeeperConfig -Path $ConfigPath

$ver = Get-McPaperCurrency -ServerRoot $cfg.ServerRoot -Project ($cfg.PaperProject ?? 'paper') -ApiBase ($cfg.PaperApiBase ?? 'https://fill.papermc.io/v3')
$mcVer = $ver.InstalledVersion
if (-not $mcVer) { throw "Cannot determine server MC version (jar parse: $($ver.Note)). Aborting update to avoid an unsafe swap." }

Write-Host "Server MC version: $mcVer"
$inv = Get-McPluginInventory -ServerRoot $cfg.ServerRoot
$plan = Get-McPluginUpdatePlan -Inventory $inv -McVersion $mcVer

Write-Host "`n=== Update plan (MC $mcVer) ==="
$plan | Format-Table Name, Installed, Latest, NeedsUpdate, Source, Reason -AutoSize

$staging = $cfg.StagingDir ?? (Join-Path $PSScriptRoot '..\out\staging')
$results = Invoke-McPluginUpdate -Plan $plan -ServerRoot $cfg.ServerRoot -StagingDir $staging -McVersion $mcVer -Execute:$Execute

Write-Host "`n=== Update results ($([bool]$Execute ? 'EXECUTED' : 'DRY-RUN')) ==="
if ($results.Count) { $results | Format-Table Name, From, To, Staged, Verified, Swapped, Note -AutoSize }
else { Write-Host 'No downloadable updates to apply.' }
