# Get-McServerStatus.ps1 — is the Minecraft server up?
# Implements: LLR-004 (SR-003)
#
# Primary signal is a TCP connect to the server port (works local or remote and
# needs no rcon/query auth). When -CheckProcess is set AND we're probing
# localhost, a running `java` process is used as a corroborating signal. The
# result is a structured object; the orchestrator decides how to report it.

function Get-McServerStatus {
    [CmdletBinding()]
    param(
        [string]$ServerHost = 'localhost',
        [int]$ServerPort = 25565,
        [int]$TimeoutMs = 3000,
        [switch]$CheckProcess
    )

    $up = $false
    $note = ''
    $procSeen = $null

    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($ServerHost, $ServerPort, $null, $null)
        $connected = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($connected -and $client.Connected) {
            $up = $true
            $note = "TCP $ServerHost`:$ServerPort accepting connections"
            $client.EndConnect($iar)
        } else {
            $note = "TCP $ServerHost`:$ServerPort no response within ${TimeoutMs}ms"
        }
        $client.Close()
    } catch {
        $up = $false
        $note = "up-probe error: $_"
    }

    if ($CheckProcess -and ($ServerHost -in 'localhost','127.0.0.1','::1')) {
        try {
            $procSeen = [bool](Get-Process -Name 'java' -ErrorAction SilentlyContinue)
            if (-not $up -and $procSeen) {
                $note += '; a java process is running but the port is not answering (starting up or bound elsewhere?)'
            }
        } catch { }
    }

    return [pscustomobject]@{
        Up           = $up
        Host         = $ServerHost
        Port         = $ServerPort
        JavaRunning  = $procSeen
        Note         = $note
        CheckedAt    = (Get-Date).ToString('o')
    }
}
