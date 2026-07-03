# Invoke-McPluginUpdate.ps1 — stage, verify, and (only with -Execute) swap plugin jars.
# Implements: LLR-013 (SR-006)
#
# SAFETY MODEL (dry-run by default):
#   * Downloads land in a STAGING dir, never straight into plugins\.
#   * Each staged jar is VERIFIED: sha512 matches the source, plugin.yml parses,
#     and its api-version is compatible with the target MC version.
#   * A swap PLAN (backup old jar -> place new jar) is produced always; it only
#     EXECUTES when -Execute is passed. Execution backs up the current jar first
#     and ROLLS BACK on any failure.
# Without -Execute nothing under ServerRoot is ever written.

function Invoke-McPluginUpdate {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]$Plan,        # output of Get-McPluginUpdatePlan
        [Parameter(Mandatory)][string]$ServerRoot,
        [Parameter(Mandatory)][string]$StagingDir,
        [string]$McVersion,
        [switch]$Execute
    )

    $pluginsDir = Join-Path $ServerRoot 'plugins'
    $backupDir = Join-Path $StagingDir 'jar-backups'
    if (-not (Test-Path $StagingDir)) { New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null }

    $results = foreach ($item in ($Plan | Where-Object { $_.NeedsUpdate -and $_.Downloadable })) {
        $r = [ordered]@{
            Name = $item.Name; Jar = $item.Jar; From = $item.Installed; To = $item.Latest
            Staged = $false; Verified = $false; Swapped = $false; RolledBack = $false; Note = ''
        }
        try {
            # --- download to staging ---
            $stagedJar = Join-Path $StagingDir ("{0}__{1}.jar" -f ($item.Name -replace '[^\w.-]','_'), ($item.Latest -replace '[^\w.-]','_'))
            Invoke-WebRequest -Uri $item.DownloadUrl -OutFile $stagedJar -TimeoutSec 60 -ErrorAction Stop
            $r.Staged = $true

            # --- verify: hash ---
            if ($item.Sha512) {
                $actual = (Get-FileHash -Path $stagedJar -Algorithm SHA512).Hash.ToLowerInvariant()
                if ($actual -ne $item.Sha512.ToLowerInvariant()) { throw "sha512 mismatch (expected $($item.Sha512.Substring(0,12))..., got $($actual.Substring(0,12))...)" }
            } else {
                $r.Note += 'no sha provided by source; '
            }

            # --- verify: manifest parses + api compatible ---
            $man = Get-PluginManifest -JarPath $stagedJar
            if (-not $man.Parsed) { throw "staged jar plugin.yml did not parse ($($man.Note))" }
            if ($McVersion -and $man.ApiVersion) {
                if (-not (Test-ApiVersionCompatible -ApiVersion $man.ApiVersion -McVersion $McVersion)) {
                    throw "api-version $($man.ApiVersion) not compatible with MC $McVersion"
                }
            }
            $r.Verified = $true

            # --- swap plan / execution ---
            $targetJar = Join-Path $pluginsDir $item.Jar
            if ($Execute) {
                if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
                $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
                $backupJar = Join-Path $backupDir ("{0}.{1}.bak" -f $item.Jar, $stamp)
                if ($PSCmdlet.ShouldProcess($targetJar, "backup old jar then install $($item.Latest)")) {
                    if (Test-Path $targetJar) { Copy-Item -Path $targetJar -Destination $backupJar -Force }
                    try {
                        Copy-Item -Path $stagedJar -Destination $targetJar -Force
                        $r.Swapped = $true
                    } catch {
                        # rollback
                        if (Test-Path $backupJar) { Copy-Item -Path $backupJar -Destination $targetJar -Force }
                        $r.RolledBack = $true
                        throw "swap failed, rolled back: $_"
                    }
                }
            } else {
                $r.Note += "DRY-RUN: verified staged jar; would back up '$($item.Jar)' and install $($item.Latest). Re-run with -Execute to apply."
            }
        } catch {
            $r.Note += "FAILED: $_"
        }
        [pscustomobject]$r
    }

    return @($results)
}

function Test-ApiVersionCompatible {
    # A plugin's api-version is the MINIMUM server API it targets; it is
    # compatible if it is <= the server's MC version. Compare as version tuples,
    # tolerating 2-part (26.2) and 3-part (1.21.1) forms. Best-effort: unknown or
    # unparseable inputs return $true (don't block on a parse we can't trust —
    # the human review gate catches the rest).
    [CmdletBinding()]
    param([string]$ApiVersion, [string]$McVersion)
    $parse = {
        param($v)
        if (-not $v) { return $null }
        $nums = ($v -split '\.') | ForEach-Object { ($_ -replace '[^\d]','') } | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ }
        if (-not $nums) { return $null }
        return ,$nums
    }
    $a = & $parse $ApiVersion
    $m = & $parse $McVersion
    if (-not $a -or -not $m) { return $true }
    for ($i = 0; $i -lt [Math]::Max($a.Count, $m.Count); $i++) {
        $av = if ($i -lt $a.Count) { $a[$i] } else { 0 }
        $mv = if ($i -lt $m.Count) { $m[$i] } else { 0 }
        if ($av -lt $mv) { return $true }
        if ($av -gt $mv) { return $false }
    }
    return $true  # equal
}
