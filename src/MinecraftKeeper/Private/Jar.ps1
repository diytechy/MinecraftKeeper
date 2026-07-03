# Jar.ps1 — read plugin.yml metadata out of a plugin .jar without extracting it.
# Implements: LLR-010 (SR-004)
#
# A Bukkit/Paper plugin jar carries a top-level plugin.yml (or paper-plugin.yml).
# We open the jar as a zip and parse the few fields we need. Read-only: the jar
# is opened for read and never modified — safe against the live server share.

function Get-PluginManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$JarPath
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

    $result = [ordered]@{
        File       = Split-Path -Leaf $JarPath
        Name       = $null
        Version    = $null
        ApiVersion = $null
        Main       = $null
        Authors    = @()
        Depend     = @()
        SoftDepend = @()
        Parsed     = $false
        Note       = ''
    }

    $zip = $null
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($JarPath)
        $entry = $zip.Entries | Where-Object { $_.FullName -eq 'plugin.yml' } | Select-Object -First 1
        if (-not $entry) {
            $entry = $zip.Entries | Where-Object { $_.FullName -eq 'paper-plugin.yml' } | Select-Object -First 1
        }
        if (-not $entry) {
            $result.Note = 'no plugin.yml/paper-plugin.yml in jar'
            return [pscustomobject]$result
        }
        $reader = New-Object System.IO.StreamReader($entry.Open())
        $yaml = $reader.ReadToEnd()
        $reader.Close()

        # Deliberately tiny YAML field grab — we only want scalar top-level keys.
        # Full YAML parsing is overkill and would pull a dependency; plugin.yml
        # top-level name/version/api-version/main are always simple scalars.
        $scalar = {
            param($key)
            $m = [regex]::Match($yaml, "(?m)^\s*$key\s*:\s*(.+?)\s*$")
            if ($m.Success) { return $m.Groups[1].Value.Trim().Trim('"',"'") }
            return $null
        }
        $result.Name       = & $scalar 'name'
        $result.Version    = & $scalar 'version'
        $result.ApiVersion = & $scalar 'api-version'
        $result.Main       = & $scalar 'main'

        $authorSingle = & $scalar 'author'
        if ($authorSingle) { $result.Authors = @($authorSingle) }
        $listGrab = {
            param($key)
            # Inline list form:  key: [a, b, c]
            $m = [regex]::Match($yaml, "(?m)^\s*$key\s*:\s*\[(.*?)\]")
            if ($m.Success) {
                return @($m.Groups[1].Value -split ',' | ForEach-Object { $_.Trim().Trim('"',"'") } | Where-Object { $_ })
            }
            return @()
        }
        if (-not $result.Authors) { $result.Authors = & $listGrab 'authors' }
        $result.Depend     = & $listGrab 'depend'
        $result.SoftDepend = & $listGrab 'softdepend'
        $result.Parsed     = [bool]$result.Name
        if (-not $result.Parsed) { $result.Note = 'plugin.yml present but name not parseable' }
    } catch {
        $result.Note = "read error: $_"
    } finally {
        if ($zip) { $zip.Dispose() }
    }
    return [pscustomobject]$result
}
