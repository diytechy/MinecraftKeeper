# MinecraftKeeper configuration (EXAMPLE — sanitized).
#
# Copy this file to `keeper.config.psd1` (git-ignored) and fill in real values
# for your host. NEVER commit a filled-in config: the server root can expose
# rcon passwords and real player names. Only this sanitized example is tracked.
#
# Load order (Import-KeeperConfig): explicit -Path wins; else
# $env:MCKEEPER_CONFIG; else ./config/keeper.config.psd1 beside this example.
@{
    # Root of the live Paper/Bukkit server. On Mini-serv this is the production
    # share; treat it as READ-ONLY for every read-path tool (checker, inventory).
    # Use a UNC path or a local path. Example is generic on purpose.
    ServerRoot = 'C:\path\to\MINECRAFT_SERVER'

    # How the up-probe reaches the server. Host/port only — no LAN hostnames in
    # the tracked example.
    ServerHost = 'localhost'
    ServerPort = 25565

    # PaperMC project + downloads API base for the version-currency check.
    # NOTE: the legacy v2 API (api.papermc.io/v2) has been SUNSET; use the v3
    # "fill" API. The checker treats any unexpected API response as not-current
    # (never silent-green), so a future API change surfaces instead of hiding.
    PaperProject = 'paper'
    PaperApiBase = 'https://fill.papermc.io/v3'

    # Settings backup output. Archives are written here, NEVER into the repo or
    # onto the read-only server share. Worlds are excluded unless -IncludeWorlds.
    BackupDest    = 'C:\McKeeper\backups'
    IncludeWorlds = $false

    # Plugin update staging. New jars are downloaded/verified here and only moved
    # into <ServerRoot>\plugins by an explicit -Execute run (backup + rollback).
    StagingDir = 'C:\McKeeper\staging'

    # NagLight feed reporting (POST /api/feed). The token is read from
    # $env:MCKEEPER_FEED_TOKEN when Token is blank (preferred — keep secrets out
    # of config files too).
    NagLight = @{
        Url    = 'http://localhost:8787'
        Token  = ''
        # Map each MinecraftKeeper signal to the `check` id of an `automated`
        # item defined in NagLight. Staleness ladder (NagLight DESIGN §6): a
        # dead feeder must read as STALE, never silent-green — so the checker
        # posts ok=false with a note on any failure and never skips a post.
        Checks = @{
            ServerUp = 'mc-server-up'
            Version  = 'mc-update'
            Plugins  = 'mc-plugins'
            Backup   = 'mc-settings-backup'
        }
    }
}
