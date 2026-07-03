# MinecraftKeeper.psm1 — module loader.
# Dot-sources Private (internal helpers) then Public (exported cmdlets), and
# exports only the Public function names. Keeps a small, testable core separate
# from the entry-point scripts in bin\.

$ErrorActionPreference = 'Stop'

$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$public  = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public')  -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in @($private + $public)) {
    . $file.FullName
}

Export-ModuleMember -Function $public.BaseName
