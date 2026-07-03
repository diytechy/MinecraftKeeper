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
  - **In flight:** none (session complete).
- **Assumptions (unattended):** see the list below — confirm/revert at next gate.
- **Next action:** Peter reviews commits and pushes; then WI-10.7/10.8 are ready
  to schedule on Mini-serv.

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
- Any **write** to the server (jar swap `-Execute`); scheduled-task registration;
  NagLight POSTs (exercised only in `-WhatIfPost` mode — no live NagLight here);
  the fork auto-fix pipeline.

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

<!-- agent-setup --> Agent setup (2026-07-03): agents=`claude`; skills materialized: downstream-resync, gate-advance, registry-hygiene. AGENTS.md remains the canonical, agent-neutral guide (skills are opt-in accelerators, not a process gate).
