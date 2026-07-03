@{
    RootModule        = 'MinecraftKeeper.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'dc1750b5-1f26-41cd-b671-b266dd7f27fe'
    Author            = 'diytechy'
    Description       = 'Homelab Minecraft (Paper/Bukkit) status checker, settings backup, and plugin inventory/update automation. Read paths are safe against a live server; write paths are dry-run-by-default.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Import-KeeperConfig',
        'Send-NagLightFeed',
        'Get-McServerStatus',
        'Get-McPaperCurrency',
        'Invoke-McKeeperCheck',
        'Backup-McSettings',
        'Get-McPluginInventory',
        'Get-McPluginUpdatePlan',
        'Invoke-McPluginUpdate',
        'Get-McForkStatus'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
