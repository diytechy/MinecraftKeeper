# Backup-McSettings.ps1 — timestamped archive of server settings + plugin configs.
# Implements: LLR-020 (SR-005)
#
# Copies the server's SETTINGS (not the whole world) into a timestamped .zip at
# a configured destination — never into the repo and never back onto the live
# share. What's captured: top-level *.properties/*.yml/*.json config, config\,
# and each plugins\<Plugin>\ config file (*.yml/*.conf/*.json/*.txt). Worlds and
# bulky plugin data (CoreProtect DB, BlueMap/dynmap tiles) are EXCLUDED unless
# -IncludeWorlds is set. Scheduled-task-friendly: returns an object and writes
# one archive per run.
#
# NOTE: the archive necessarily contains real secrets (server.properties holds
# rcon.password, etc.). That is fine for Peter's private backup destination — it
# is exactly what a backup is for — but is WHY the destination must never be the
# repo or a public share.

function Backup-McSettings {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$ServerRoot,
        [Parameter(Mandatory)][string]$BackupDest,
        [switch]$IncludeWorlds
    )

    if (-not (Test-Path $ServerRoot)) { throw "ServerRoot not found: $ServerRoot" }
    if (-not (Test-Path $BackupDest)) { New-Item -ItemType Directory -Path $BackupDest -Force | Out-Null }

    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $staging = Join-Path ([IO.Path]::GetTempPath()) "mckeeper-backup-$stamp"
    New-Item -ItemType Directory -Path $staging -Force | Out-Null

    # Config-ish extensions we treat as "settings".
    $configExt = @('.properties','.yml','.yaml','.json','.conf','.toml','.txt')
    # Never-copy noise even when it carries a config extension.
    $excludeNames = @('usercache.json','session.lock')
    $copied = 0

    $copyFile = {
        param($srcFile, $relPath)
        $dest = Join-Path $staging $relPath
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -Path $srcFile -Destination $dest -Force
        $script:__copied++
    }
    $script:__copied = 0

    # 1) Top-level settings files.
    Get-ChildItem -Path $ServerRoot -File -ErrorAction SilentlyContinue | Where-Object {
        $configExt -contains $_.Extension.ToLowerInvariant() -and $excludeNames -notcontains $_.Name.ToLowerInvariant()
    } | ForEach-Object { & $copyFile $_.FullName $_.Name }

    # 2) config\ tree (paper-global.yml, paper-world-defaults.yml, ...).
    $configDir = Join-Path $ServerRoot 'config'
    if (Test-Path $configDir) {
        Get-ChildItem -Path $configDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $configExt -contains $_.Extension.ToLowerInvariant()
        } | ForEach-Object {
            $rel = 'config' + $_.FullName.Substring($configDir.Length)
            & $copyFile $_.FullName $rel
        }
    }

    # 3) plugins\<Plugin>\ CONFIG files only — skip jars and bulky data dirs.
    $pluginsDir = Join-Path $ServerRoot 'plugins'
    $bulkyDirs = @('data','database','logs','web','tiles','cache','.paper-remapped','sqlite','storage')
    if (Test-Path $pluginsDir) {
        Get-ChildItem -Path $pluginsDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $configExt -contains $_.Extension.ToLowerInvariant()
        } | ForEach-Object {
            $rel = 'plugins' + $_.FullName.Substring($pluginsDir.Length)
            $parts = $rel -split '[\\/]'
            $inBulky = $false
            foreach ($p in $parts) { if ($bulkyDirs -contains $p.ToLowerInvariant()) { $inBulky = $true; break } }
            if (-not $inBulky) { & $copyFile $_.FullName $rel }
        }
    }

    # 4) Worlds — optional, they are huge.
    if ($IncludeWorlds) {
        Get-ChildItem -Path $ServerRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
            Test-Path (Join-Path $_.FullName 'level.dat')
        } | ForEach-Object {
            $world = $_.Name
            Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                $rel = $world + $_.FullName.Substring((Join-Path $ServerRoot $world).Length)
                & $copyFile $_.FullName $rel
            }
        }
    }

    $copied = $script:__copied
    $archive = Join-Path $BackupDest "MC_SETTINGS_$stamp.zip"

    if ($PSCmdlet.ShouldProcess($archive, "create settings archive ($copied files)")) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        if (Test-Path $archive) { Remove-Item $archive -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($staging, $archive)
    }
    Remove-Item -Path $staging -Recurse -Force -ErrorAction SilentlyContinue

    $ok = (Test-Path $archive)
    $sizeMB = if ($ok) { [math]::Round((Get-Item $archive).Length / 1MB, 2) } else { 0 }
    if ($ok) { Write-KeeperLog -Level OK -Message "settings backup -> $archive ($copied files, ${sizeMB}MB)" }

    return [pscustomobject]@{
        Ok            = $ok
        Archive       = $archive
        FileCount     = $copied
        SizeMB        = $sizeMB
        IncludeWorlds = [bool]$IncludeWorlds
        CreatedAt     = (Get-Date).ToString('o')
    }
}
