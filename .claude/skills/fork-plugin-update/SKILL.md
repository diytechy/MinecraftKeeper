---
name: fork-plugin-update
description: Use when a new Minecraft/Paper version breaks one of Peter's personal plugin forks (github.com/diytechy) and the fork needs to be fixed and rebuilt. Covers the per-fork detection → diagnose → fix → build → verify workflow. The final publish/push to a fork repo is ALWAYS Peter-gated — this skill builds and stages, it never pushes.
stacks: [powershell, any]
domains: [game]
phases: [maintenance]
tags: [minecraft, paper, plugins, forks, build, java, gradle, maven]
scope: this-repo
---

# Fork plugin update (fix a diytechy plugin fork for a new MC version)

This is the **last rung** of MinecraftKeeper's automation ladder (WI-10.9). When a
Minecraft/Paper update lands, most plugins update from their canonical source
(handled by `Get-McPluginUpdatePlan` / `Invoke-McPluginUpdate`). The exceptions
are the plugins Peter maintains as **personal forks** — those need source changes
to compile against the new API, then a rebuilt jar.

**Hard gate — read first.** This skill's automation ends at a *verified local
build*. Anything that mutates a fork repo — commit, tag, push, publish a release —
is **Peter's decision, made by Peter**. An agent may prepare a branch and a diff
and *describe* the release, but never runs `git push` or the GitHub release API
against a `diytechy/*` fork. This mirrors the whole-project rule: agent sessions
lack the push key and never self-authorize a publish.

## Step 0 — Detect which forks need attention (mechanized, safe)

```powershell
Import-Module .\src\MinecraftKeeper\MinecraftKeeper.psd1
$inv = Get-McPluginInventory -ServerRoot <server-root>
Get-McForkStatus -Inventory $inv | Format-Table Name, Fork, Installed, LatestRelease, Status
```

`Get-McForkStatus` reports, per fork: latest published release/tag and whether it
ships a jar asset. Combine with `Get-McPaperCurrency` (the target MC version) to
decide the work list: a fork whose newest release predates the current MC version,
or that has `Status = fork-no-releases-or-tags`, is a candidate for a fix pass.

## Step 1 — Reproduce the break

For each candidate fork:
1. Clone `git@github.com:diytechy/<Fork>.git` into a scratch workspace (NOT under
   this repo, NOT onto the server share).
2. Identify the build system (Gradle `build.gradle[.kts]` or Maven `pom.xml`) and
   the pinned Paper/Spigot API version.
3. Bump the API/dependency version to the target MC version and attempt a build.
   Capture the first compile errors — they localize the break (renamed/removed
   API, Mojang-mapping changes, a moved package).

## Step 2 — Fix against the new API (the agent's real work)

- Work on a branch: `fix/mc-<version>`.
- Make the **minimal** source changes to compile and pass the fork's own tests.
- Prefer the upstream project's own fix if one exists (check the upstream repo for
  the same version bump) and cherry-pick/adapt rather than reinventing.
- Keep a written diff summary: what broke, what changed, why.

## Step 3 — Build + verify locally (mechanized)

- Produce the jar (`gradlew build` / `mvn package`).
- Verify it the same way `Invoke-McPluginUpdate` verifies a downloaded jar:
  `plugin.yml` parses and its `api-version` is compatible with the target MC
  version (`Test-ApiVersionCompatible`). Optionally smoke-test on a throwaway
  server instance — never the live one.

## Step 4 — STOP. Hand off to Peter (the gate)

Present to Peter: the branch, the diff summary, the built jar path, and the verify
result. Peter decides whether to:
- push the branch / open the PR on `diytechy/<Fork>`,
- tag + publish a GitHub release with the jar asset, and
- let MinecraftKeeper's updater pick it up (once the fork publishes a jar asset,
  it becomes just another source `Get-McPluginUpdatePlan` can stage).

An agent may draft all of the above as text/patches; **executing** the push or
release is Peter's, every time.

## What this skill deliberately does NOT do this session

The auto-fix code itself (Steps 1–3 as an unattended pipeline) is **not built** —
only the detection (`Get-McForkStatus`) and this documented workflow exist. Fixing
arbitrary Java against arbitrary API breakage is not yet a safe unattended
operation; it stays a guided, human-in-the-loop workflow until proven per-fork.
