# plugin-sources.psd1 — canonical upstream source map for known plugins.
#
# Keyed by NORMALIZED plugin name (lower-case, from plugin.yml `name:`, or the
# jar basename when no manifest name is available). Each entry names the
# canonical distribution source(s) so the updater knows where to look for a
# latest-compatible build. `ForkAlias` overrides the automatic diytechy-repo
# name match when the plugin.yml name differs from the repo name.
#
# Honesty rule: only list a source that actually hosts the plugin. Anything not
# in this table (and not matched to a diytechy fork) is reported "unmapped"
# rather than guessed. `Spigot`/`Hangar` ids left blank mean "known to live
# there but resource id not yet recorded" — the updater treats those as
# not-auto-downloadable and flags them for a human.
@{
    'coreprotect'            = @{ Modrinth = 'coreprotect';            ForkAlias = 'CoreProtect' }
    'luckperms'              = @{ Modrinth = 'luckperms' }
    'chunky'                 = @{ Modrinth = 'chunky';                 ForkAlias = 'Chunky' }
    'geyser-spigot'          = @{ Modrinth = 'geyser';                 ForkAlias = 'Geyser' }
    'geyser'                 = @{ Modrinth = 'geyser';                 ForkAlias = 'Geyser' }
    'floodgate'              = @{ Modrinth = 'floodgate' }
    'multiverse-core'        = @{ Modrinth = 'multiverse-core';        ForkAlias = 'Multiverse-Core' }
    'multiverse-inventories' = @{ Modrinth = 'multiverse-inventories' }
    'multiverse-portals'     = @{ Modrinth = 'multiverse-portals' }
    'multiverse-netherportals' = @{ Modrinth = 'multiverse-netherportals' }
    'terra'                  = @{ Modrinth = 'terra';                  ForkAlias = 'Terra' }
    'worldedit'              = @{ Modrinth = 'worldedit' }
    'worldguard'             = @{ Modrinth = 'worldguard';             ForkAlias = 'WorldGuard' }
    'bluemap'                = @{ Modrinth = 'bluemap' }
    'worldborder'            = @{ Spigot = '' }
    'ultimateautorestart'    = @{ Spigot = ''; Hangar = '' }
    # Deliberately unmapped (niche/private addons — record honestly, don't guess):
    #   extracontexts   — LuckPerms context addon, no canonical public listing found
    #   lpc-minimessage — custom LuckPerms chat build, source unknown
}
