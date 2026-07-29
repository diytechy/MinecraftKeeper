# Stakeholder Needs (SN-###)

Owned by the **Stakeholder** hat. Plain-language needs + edge-case expectations
for MinecraftKeeper; engineering translations live in `system-requirements.csv`
(referenced by `SN-Refs`). Priority: **M**=Must · **S**=Should · **C**=Could.

The stakeholder is **the Owner as server operator**: they run a live Paper/Bukkit
homelab server and want its health, settings backup, and plugin currency handled
with minimal hand-holding, surfaced on the NagLight dashboard.

## Core needs

| SN-ID | Need (plain language) | Why it matters | Priority | Acceptance intent (how we'd know it's met) |
|---|---|---|---|---|
| SN-001 | See at a glance whether the server is up and running a current Paper build, reported automatically to the home dashboard. | Manual checking doesn't happen; a silent outage or stale build should be visible. | M | A scheduled checker posts fresh server-up + Paper-version items to NagLight; a checker that stops posting reads STALE, never silent-green. |
| SN-002 | Server settings are backed up on a schedule to a safe destination. | Config loss (server.properties, plugin configs) is painful to rebuild; worlds are handled separately (they're huge). | M | A scheduled run produces a timestamped archive of settings + plugin configs at a configured destination; worlds excluded unless explicitly requested. |
| SN-003 | Know which installed plugins are outdated and where each comes from, and update them safely. | The Owner forks most plugins; a mixed fork/Modrinth/Hangar/Spigot fleet is hard to track by hand. | M | Inventory maps every jar to fork / canonical source / unmapped (honestly); updates are dry-run by default, verified before any swap, with backup + rollback. |
| SN-004 | Bring the Owner's plugin forks current for a new Minecraft version through a guided workflow. | When MC updates, forked plugins need source fixes + rebuilds; this is the hardest, least-automatable rung. | S | Per-fork status is detected automatically; the fix/build workflow is documented; publishing to a fork repo stays a human (the Owner) action. |

## Edge-case expectations

| SN-ID | Lifecycle | Scenario | Expected behavior |
|---|---|---|---|
| SN-010 | Startup | Invalid / missing config at launch | Fail loud with a message pointing at the example config; never run against a guessed path. |
| SN-011 | Startup→Runtime | Unattended/scheduled run | Never blocks on a prompt; any failure is reported to NagLight as ok=false with a note, not skipped. |
| SN-012 | Runtime | NagLight or an upstream API (PaperMC/Modrinth/GitHub) is unreachable or changed | Report the affected check as not-current/ok=false with an explanatory note — never a fabricated green (staleness-ladder honesty). |
| SN-013 | Runtime | The live server share is the input | All read paths treat it as READ-ONLY; any write path (jar swap) is dry-run by default and gated behind an explicit flag. |
| SN-014 | Runtime | A plugin jar is missing plugin.yml / unparseable | Recorded honestly (unmapped / parse note); the run continues and inventories the rest. |
| SN-015 | Runtime | A jar swap (irreversible) fails partway | Back up the current jar first; on any failure, roll back to the backed-up jar. |
| SN-016 | Provision | Real config would expose secrets (rcon password, player names, LAN paths) | Only a sanitized example config and a redacted inventory are ever committed; real config + output are git-ignored. |
