# MinecraftKeeper

Keeps a homelab **Paper/Bukkit Minecraft server** healthy with minimal
hand-holding: it checks that the server is up and current, backs up its
settings on a schedule, inventories installed plugins and maps each to its
source (the Owner's forks / Modrinth / Hangar / SpigotMC), and updates them
**safely** — reporting everything to the [NagLight](https://github.com/diytechy)
dashboard. Built for the Owner as server operator.

Safety posture: the live server directory is a **read-only** input; the only
write to it (a plugin jar swap) is **dry-run by default** and gated behind an
explicit `-Execute` flag with backup-first + rollback. Real configs hold secrets
(rcon password, player names) — only a **sanitized example** config and a
**redacted** inventory are ever committed.

## Run it

PowerShell 7 module + thin entry points in [`bin/`](bin). First, copy the
example config and fill it in (it is git-ignored):

```powershell
Copy-Item config\keeper.config.example.psd1 config\keeper.config.psd1
# edit config\keeper.config.psd1: ServerRoot, ServerHost/Port, BackupDest, NagLight.Url
$env:MCKEEPER_FEED_TOKEN = '<your NagLight feed token>'   # keep the token out of the file
```

| Task | Command | Notes |
|---|---|---|
| Health + version check | `pwsh -File bin\Invoke-Check.ps1 -IncludePlugins` | Scheduled-task entry; add `-WhatIfPost` to trial without posting. |
| Settings backup | `pwsh -File bin\Invoke-Backup.ps1` | Add `-IncludeWorlds` to include worlds (large). |
| Plugin inventory | `pwsh -File bin\Invoke-Inventory.ps1 -OutDir out` | Writes `out\inventory.{json,md}` (git-ignored). |
| Plugin update **plan** | `pwsh -File bin\Invoke-Update.ps1` | Dry-run: plans + stages + verifies, writes nothing to the server. |
| Plugin update **apply** | `pwsh -File bin\Invoke-Update.ps1 -Execute` | Backs up each old jar, installs the new one, rolls back on failure. |

A sample **redacted** inventory of the real fleet lives at
[docs/evidence/inventory.md](docs/evidence/inventory.md). The fork-fix workflow
(bring a personal fork current for a new MC version) is documented in
[skills/fork-plugin-update](skills/fork-plugin-update/SKILL.md) — its publish
step stays a human (the Owner) action.

The root `run.{cmd,sh,command}` launchers are intentionally left inert (this is
an operator toolkit, not a single-command app) — use the `bin\` entry points.

## Getting started (contributors)

The onboarding ladder (docs/process.md §7) — each rung a readable,
consent-first script that explains itself before acting:

1. **Fresh machine → checkout:** double-click `scripts/onboard.*` (`.cmd`
   Windows · `.sh` Linux · `.command` macOS).
2. **Workstation:** `scripts/dev-setup.*` — detects and reports by default;
   installs only with consent.
3. **Product toolchain:** `scripts/setup.*` — dependencies + the pre-commit
   hook.
4. **Verify:** `scripts/check.*` — the gate harness; green means you're set.

## Development

This repo follows a gated, requirement-traced process. The working brief is
[AGENTS.md](AGENTS.md); the method is [docs/process.md](docs/process.md). Start
with the code map in [docs/architecture.md](docs/architecture.md) and the
current state in [docs/status.md](docs/status.md).
