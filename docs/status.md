# Project Status — Blackboard

Live coordination for the gated process (see [process.md](process.md)). Keep the
**Current State** header short and current; append the audit log below.

---

## Current State

- **Active gate:** G1 — Requirements, UX & constraints (mirrored in `docs/gate`).
  Implementation exists and runs, but coverage is claimed honestly at G1 while
  the spine is young (ADOPTING.md "Backfill from the boundary").
- **Round:** 1
- **Open items:**
  - **Needs Peter:**
    - OI-1 — review + `git push` all commits (agent sessions lack the push key) →
      whole repo.
    - OI-2 — confirm the NagLight `check` ids (`mc-server-up`, `mc-update`,
      `mc-plugins`, `mc-settings-backup`) match the `automated` item definitions
      you create in NagLight, or tell me the ids to use →
      [config example](../config/keeper.config.example.psd1).
    - OI-3 — react to the fork-fix rung: detection is built; the auto-fix pipeline
      is deliberately NOT built this session (see Assumptions) →
      [skills/fork-plugin-update](../skills/fork-plugin-update/SKILL.md).
    - OI-4 (WI-10.16) — there is no formal `Restore-McPlugin`/rollback cmdlet;
      the manual recovery path is "copy the timestamped `.bak` from
      `<StagingDir>/jar-backups/` back over `plugins/<jar>`", which this session
      proved byte-identical against the sim fixture. Flagging in case Peter wants
      a proper `Restore-McPluginBackup` cmdlet wrapping that — not built
      unrequested (no gold-plating).
  - **In flight:** none (session complete).
- **Assumptions (unattended):** see the list below — confirm/revert at next gate.
- **Next action:** Peter reviews commits and pushes; WI-10.16's V2 evidence
  (below) means the `--execute` swap+rollback path has now been run for real —
  it no longer needs a live-server trial to be trusted structurally.

## Scope (restated from the brief)

- **Goal:** WI-10.7 (scaffold + status/version checker v1) and WI-10.8 (settings
  backup + plugin inventory/update automation) for the live Paper/Bukkit server.
- **Stakeholders / end user(s):** Peter as server operator; NagLight as the
  reporting sink.
- **Supported platforms:** Windows (PowerShell 7) first — runs on Mini-serv. A
  container path is left open (see Assumptions).
- **Constraints:** `\\Mini-serv\...\MINECRAFT_SERVER` is READ-ONLY for agents;
  public-facing repo → sanitized examples only, no real secrets/IPs/usernames;
  commit as `diytechy`, never Peter's personal identity; agents never push.
- **Non-goals (this session):** the unattended fork auto-fix pipeline; container
  packaging; live jar swaps against the production server.
- **Definition of done:** checker + backup + inventory + update-plan run for real
  read-only against the share; write paths dry-run-by-default; redacted evidence
  committed; gate green; assumptions recorded.

## Gate Sign-offs

| Gate | Stakeholder | UX/Docs | System Eng | Test Eng | Human |
|---|---|---|---|---|---|
| G1 — Requirements/UX/Constraints | DRIVER | DRIVER | DRIVER | n/a | PENDING |
| G2 — Decomposition & Test Coverage | n/a | n/a | PENDING | PENDING | PENDING |
| G3 — Implementation | n/a | n/a | PENDING | PENDING | PENDING |
| G-Final — Acceptance | PENDING | n/a | n/a | (evidence) | PENDING |

---

## Assumptions (unattended — confirm or revert)

- **A1 — Implementation language = PowerShell 7.** The checker runs on Mini-serv
  (Windows) initially; PowerShell 7 was the plan's suggested default and matches
  the seed feeder. Containerization is deferred (a `pwsh` container is the
  natural later step; the module has no Windows-only assumptions beyond
  `Get-Process java` corroboration, which is optional).
- **A2 — NagLight `check` ids.** Chose `mc-server-up`, `mc-update` (reusing the
  existing feeder's id), `mc-plugins`, `mc-settings-backup`. They live in the
  config so Peter can rename them to match his NagLight definitions (OI-2).
- **A3 — Staleness-ladder honesty enforced in code, not assumed.** Every check
  posts on every run and posts `ok=false` with a note on any failure; nothing
  ever fabricates `ok=true`. A dead scheduled task therefore reads stale.
- **A4 — PaperMC API: the legacy v2 API is SUNSET.** The seed logic used
  `api.papermc.io/v2`, which now returns `{error:"sunset"}`. Switched to the v3
  "fill" API (`fill.papermc.io/v3`). This was verified live against the real
  server's build (paper-26.2-34, latest 47).
- **A5 — Fork mapping is a committed snapshot, best-effort.** `data/diytechy-repos.txt`
  is a point-in-time capture of Peter's public repos (refresh command in the
  file). Name-matching is fuzzy; ambiguous cases are recorded `unmapped`, never
  guessed.
- **A6 — Update auto-download source = Modrinth (v1).** Modrinth is queried live.
  Hangar/SpigotMC without a recorded id, and fork-only plugins, are flagged for a
  human rather than auto-downloaded. GitHub-release download for forks is a
  deferred extension.
- **A7 — Fork auto-fix pipeline NOT built (per the plan).** Only per-fork
  *detection* (`Get-McForkStatus`) and the documented workflow exist. Fixing
  arbitrary Java against API breakage is not yet a safe unattended op; publish
  stays Peter-gated.
- **A8 — Kit arch-map not ported to PowerShell.** `gen_arch_map.py` is Python-only,
  so the generated module map stays empty; the hand-written table in
  `architecture.md` is the source of truth. A `gen_arch_map.ps1` port is a
  deferred nicety, not wired into the G1 gate (ADOPTING.md §3, option 2).
- **A9 (WI-10.16) — `file://` test seam in `Invoke-McPluginUpdate`.** The
  mini-serv-sim fixture plugins (`SimGreeter`/`SimEconomy`/`SimBackupHelper`)
  are fictional names with no real Modrinth listing, so
  `Get-McPluginUpdatePlan` correctly reports them `unmapped` and never
  downloads anything for them — there was no real candidate to stage. To
  exercise the stage→verify→swap→rollback path for real, `Invoke-McPluginUpdate`
  now accepts a `file://` `DownloadUrl` (`Copy-Item` instead of
  `Invoke-WebRequest`), used to hand-build a sim-only Plan entry pointing at a
  locally-manufactured candidate jar. `Get-McPluginUpdatePlan` (the production
  path) only ever emits `https://` Modrinth URLs, so this branch is inert
  against a live server; it exists purely for validation/dev use.

## What was actually EXECUTED (real, read-only) vs DESIGNED

Executed for real against `\\Mini-serv\...\MINECRAFT_SERVER` (read-only):
- **Plugin inventory** — 16 plugins; 14 mapped to a source; 6 matched to a
  diytechy fork (Chunky, CoreProtect, Geyser, Multiverse-Core, Terra, WorldGuard);
  2 honestly unmapped (ExtraContexts, LPC). Redacted output committed at
  `docs/evidence/`.
- **Paper version currency** — installed paper-26.2 build 34 is **behind** latest
  build 47 (v3 fill API, live).
- **Update plan (live Modrinth)** — 4 plugins have a newer build for MC 26.2:
  BlueMap 5.20→5.22, LuckPerms 5.5.42→5.5.53, Multiverse-Portals 5.2.2→5.2.3,
  WorldGuard SNAPSHOT→7.0.17.
- **Update dry-run** — WorldGuard candidate downloaded to staging, sha512 +
  plugin.yml + api-version verified, swap correctly withheld (no `-Execute`).
- **Settings backup** — produced a 2.89 MB archive of 1163 config files (worlds
  excluded) to a scratch destination.
- **Fork status** — GitHub API queried for all 6 forks; Terra publishes a release
  matching the installed build; others have no published release/tags.
- **Server-up probe** — returns down when probing localhost from the dev box
  (expected; on Mini-serv it probes the real port).
- **Unit tests** — 8/8 Pester tests pass; `python scripts/check.py` green at G1.

Designed but NOT executed against the live server:
- Any **write** to the server (jar swap `-Execute`) — **now exercised for real
  against the Mini-serv-sim fixture, see WI-10.16 below** — is still untried
  against the actual production share (still correctly read-only for agents);
  scheduled-task registration; the fork auto-fix pipeline.

## WI-10.16 — `--execute` validation vs Mini-serv-sim (V2 evidence, 2026-07-04)

Ran MinecraftKeeper for real on **Linux** (PowerShell 7.4.2 on `pwsh` inside a
`mcr.microsoft.com/powershell` container, cifs-mounting
`//mini-serv/minecraft` from the MiniPC-Deployer `sim/mini-serv-sim` Samba
fixture on the `awow-sim_default` network) — this doubles as cross-platform
proof, not just a Windows/Mini-serv trial. The real live `\\Mini-serv` share
was never touched; only the fixture.

**Cross-platform findings, fixed:**
- `Import-KeeperConfig` and every `bin/*.ps1` entry point joined paths with a
  literal `\` (e.g. `'..\src\MinecraftKeeper\MinecraftKeeper.psd1'`,
  `'config\keeper.config.psd1'`). Verified this does **not** actually break on
  Linux — PowerShell's own FileSystem provider normalizes `\` → `/` inside
  `Join-Path` output on non-Windows platforms — but switched all of them to
  literal `/` anyway so correctness doesn't depend on that runtime
  normalization. Files: `src/MinecraftKeeper/Public/Import-KeeperConfig.ps1`,
  `bin/Invoke-Check.ps1`, `bin/Invoke-Backup.ps1`, `bin/Invoke-Inventory.ps1`,
  `bin/Invoke-Update.ps1`, `tests/MinecraftKeeper.Tests.ps1`.
- `Get-McServerStatus -CheckProcess` (`Get-Process -Name java`) and
  `Backup-McSettings`'s `[System.IO.Compression.ZipFile]` both ran correctly
  unmodified on Linux — no fix needed, recorded as verified.
- Added the `file://` test seam in `Invoke-McPluginUpdate` (A9 above) — the
  one real code addition, not a bug fix.

**Executed for real, step by step:**
1. **Read-only paths** (against the read-only `//mini-serv/minecraft` cifs
   mount): `Get-McPluginInventory` parsed all 3 fixture plugins
   (SimGreeter/SimEconomy/SimBackupHelper, `ManifestOk=True`), correctly
   `unmapped` (none are real Modrinth/fork names — honest, not a bug).
   `Get-McPaperCurrency` parsed `paper-1.20.4-435.jar` and made a **live**
   PaperMC v3 fill-API call: installed build 435 vs latest **499 (STABLE)** →
   correctly reports `Ok=False` / "behind", exactly the expected behavior for
   an old fixture build. `Backup-McSettings` archived 5 settings files
   including `server.properties`; confirmed the fixture's fake
   `rcon.password=sim-fake-rcon-DoNotUse-2026` round-trips into the archive
   (at the off-repo `/tmp` destination) and does **not** leak into any
   tracked/working file in the repo (grepped the whole tree post-run).
2. **Writable workspace + `-Execute` swap + rollback:** copied the read-only
   fixture tree to a writable workspace (mirrors the real deployment: the tool
   runs ON the server with write access). Manufactured a local candidate
   `SimGreeter-1.3.0.jar` (valid `plugin.yml`, api-version `1.20`) since the
   fixture's plugin names don't exist on Modrinth; hand-built a Plan entry with
   a `file://` `DownloadUrl` and its real sha512.
   - **Dry-run** (no `-Execute`): staged + verified (hash + manifest parse),
     `Swapped=False`, workspace jar byte-identical to the original
     (`sha256 9ED234CD…`) — confirmed unchanged.
   - **`-Execute`**: swap succeeded; `plugins/SimGreeter.jar` now matches the
     candidate's bytes exactly; the pre-swap original was backed up to
     `jar-backups/SimGreeter.jar.<timestamp>.bak`, verified **byte-identical**
     to the original before the swap.
   - **Rollback**: manually restored the `.bak` over the swapped-in jar;
     result is **byte-identical** to the pre-swap original
     (`sha256 9ED234CD…`, same hash as before). Whole-tree file listing
     diffed clean against the read-only mount afterward — nothing else was
     touched.
3. **Dry-run-is-default, end-to-end:** ran the real `bin/Invoke-Update.ps1`
   entry point with **no flags** against the writable workspace's real
   (unmapped) plugin inventory — it correctly computed "no downloadable
   updates" and made **zero writes** (whole-tree hash comparison before/after
   was identical). Confirms the safety default holds all the way through the
   actual entry point, not just the underlying function.
4. **Sim NagLight feed (optional, non-blocking):** attempted a real POST to
   the sim tracker (`http://tracker:8787/api/feed`) from the runner container.
   It was correctly **rejected** — "multi-user mode requires the
   X-Forwarded-User identity header... this port must never be reachable
   except via the proxy" — which is NagLight's own documented threat model
   working as designed, not a MinecraftKeeper failure. Not pursued further
   (optional per WI-10.16; going through oauth2-proxy from a bare script isn't
   worth building for this validation pass).
5. **Regression check:** all 8 Pester tests pass on both Linux (pwsh 7.4.2,
   inside the container) and Windows (pwsh 7.7.1); `python scripts/check.py`
   stays green at G1 after the edits.

**What remains unexercisable (honest gap):** the real production trigger of
`-Execute` is still untried against the actual live `\\Mini-serv` share (by
design — it stays read-only for agents); the file-based candidate seam is a
sim-only path — a real Modrinth-sourced update swap+rollback (e.g. against
one of the 4 real outdated plugins from the WI-10.8 session) is still
unexercised end-to-end with `-Execute`, though the exact same code path was
just proven correct against the fixture. Scheduled-task registration and the
fork auto-fix pipeline remain out of scope, unchanged from WI-10.8.

## Redaction note (public-facing repo)

The live `server.properties` was observed to contain real secrets
(`rcon.password`, `management-server-secret`, a real `motd`). **None are
committed.** Tracked artifacts are limited to: the sanitized example config
(placeholders only), and `docs/evidence/inventory.{json,md}` (plugin
names/versions/sources + `serverRoot: <redacted>` — scanned for secrets, clean).
Real config, backups, and unredacted output are git-ignored.

---

## Audit log

### DRIVER — G1 — Round 1 — 2026-07-03
Scaffolded from the ai-template kit (minimum profile, dial=MEDIUM). Built the
checker (WI-10.7) and backup + inventory + update automation + fork detection
(WI-10.8), plus the fork-fix skill workflow. Ran the read-only parts for real
against the live share; committed redacted evidence. Gate green at G1; 8 Pester
tests pass. Handoff items OI-1..3 for Peter.

### DRIVER — G1 — Round 1 — 2026-07-04 (WI-10.16 `--execute` validation vs Mini-serv-sim)
Validated the write path Wave 1 couldn't touch safely, against the
MiniPC-Deployer `sim/mini-serv-sim` fixture shares (never the live
`\\Mini-serv` share). Ran entirely on **Linux** (pwsh 7.4.2 in a
`mcr.microsoft.com/powershell` container on the `awow-sim_default` network,
cifs-mounting the fixture) — this also served as the module's first real
cross-platform run. Found and hardened 6 files' path-joins (backslash
literals — verified non-breaking today thanks to PowerShell's own
normalization, fixed anyway for explicit portability); added a `file://`
source-override test seam to `Invoke-McPluginUpdate` (A9) so the sim's
fictional plugin names — which correctly have no real Modrinth listing —
could still exercise stage→verify→swap→rollback with a locally-manufactured
candidate. Result: dry-run confirmed inert; `-Execute` swap landed the
candidate and byte-verified the pre-swap backup; manual rollback from that
backup reproduced the original bytes exactly; whole-tree diff against the
read-only mount was clean; `bin/Invoke-Update.ps1` with no flags made zero
writes end-to-end. 8/8 Pester tests pass on both Linux and Windows;
`check.py` stays green at G1. Full evidence + honest remaining gaps recorded
above. New handoff item OI-4 (optional `Restore-McPluginBackup` cmdlet —
flagged, not built).

<!-- agent-setup --> Agent setup (2026-07-03): agents=`claude`; skills materialized: downstream-resync, gate-advance, registry-hygiene. AGENTS.md remains the canonical, agent-neutral guide (skills are opt-in accelerators, not a process gate).
