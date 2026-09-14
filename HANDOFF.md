# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** Then [`_agents/game_design.md`](_agents/game_design.md)
> (what the game is), and if you're a workstream agent, [`_agents/workstreams.md`](_agents/workstreams.md) and your
> brief in `_agents/streams/`.

_Last updated: 2026-09-15. **Round 1 is merged and pushed; round 2 is planned and its worktrees are fresh from `main`.**_

## Current state (main)

- **Play it:**
  - `make skirmish`: squads vs a seeded budgeted CPU army, with the RTS camera, radar, fog of war, touch controls, shields, ammo, heat, lasers, scouts, artillery, the Meshy prison-dozer tanks, and the cyberpunk look and sound. Try `CONTROL=1` (center control point), `ENEMY=cpu:siege`, `SEED=3`.
  - `make garage`: build an army on a budget, then FIGHT.
  - `make title`: the title screen.
  - `make play-relay`, then `http://localhost:8060/?lobby`: player-hosted multiplayer through the relay broker.
  - Also: `make vehicle-gallery`, `make assets-unit THEME=prison_dozer`, `make fx-bench`.
- **Verified:** `make check` (294 tests + network, relay, lobby, combat, match, determinism, sim baseline, garage smoke), `make check-all`, `make web-smoke`.
- **Sim baseline:** `e5cf33921713b657`. **Web `.pck`:** 11.8 MB (the dozer's textures ship three times: an art-stream fix).
- **What round 1 built, in detail:** [`_agents/roadmap.md`](_agents/roadmap.md) and the archived reports in `_agents/streams/archive/round1/`.

## The lead's decisions for round 2 (2026-09-15)

Recorded in full in [`_agents/game_design.md`](_agents/game_design.md) and [`_agents/vision.md`](_agents/vision.md):
- **Fixed unit types, no loadouts.** StarCraft-style counters: a scout with a fixed hood gun, a tank with a slow turret, an IFV with a fast 30 mm turret, artillery, and the laser as its own unit.
- **Squads and progression:** up to 5 squads; a budget per round; credits from wins unlock units and budget tiers.
- **Friendly fire on;** sophisticated unit AI (cover, peeking, fire discipline).
- **Tap-only commanding:** tap a squad, then the ground or the radar; formation icons; a camera that follows orders.
- **Arena and art:** a gladiator arena with crowds; textured ground; better lighting; more Meshy art, with the lead reviewing concept images before any 3D.
- **The vibe:** over-the-top eccentric vehicles (the up-armored bus).
- **Business:** a die-hard game with no pay-to-win; free web, paid Android app.

## Round 2: five streams

| Stream | Brief | Outcome |
|---|---|---|
| rules | [streams/rules.md](_agents/streams/rules.md) | Unit catalog v2 (checkpoint 1), counters from mechanics, friendly fire, ≤ 5 squads, arena layouts as data, matchup matrix |
| ai | [streams/ai.md](_agents/streams/ai.md) | Cover and peeking, fire discipline, matchup targeting, squad tactics, AI ladder |
| command | [streams/command.md](_agents/streams/command.md) | Tap-only grammar, squad bar, formation/drill icons, camera follow, readability |
| art | [streams/art.md](_agents/streams/art.md) | Review-gated Meshy roster and arena, vehicle readability, lighting, textured ground, crowds |
| army | [streams/army.md](_agents/streams/army.md) | Army builder on catalog v2, progression, the full match loop, economy |

Netcode is **paused** (its smokes stay in `make check`). Ownership, contracts C1–C8, and lead gates: [`_agents/workstreams.md`](_agents/workstreams.md).

**Start each agent** in its worktree (`cd ~/projects/godot-<stream> && claude`), the same text for all five:

> /goal You are a Tank Squad round-2 workstream agent. Your stream is determined by your working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>` (one of rules, ai, command, art, army). Run `pwd` and `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an answer except at the lead gates in `_agents/workstreams.md`; record questions in your brief's Status and keep working. Read CLAUDE.md, HANDOFF.md, `_agents/orientation.md`, `_agents/game_design.md`, `_agents/workstreams.md` (especially *Lead gates*, *Autonomous mandate*, *Unattended runs*, and the contracts), then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch items: build, test, `make check`, smoke test and look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the Status holds a report (done, decisions, questions for the lead, requests to other streams, what to playtest).

**Orchestrator duties** (a Claude session in `~/projects/godot`):
1. **Checkpoint 1:** when rules reports R1 (catalog v2 + army JSON v2), merge `stream/rules` into `main` after `make check`, then have the other streams `git merge main`.
2. Relay art's review sheets to the lead (`build/review/index.html` in the art worktree) and record approvals in `streams/art.md`.
3. **Final integration order:** rules → ai → command → army → art, running `make check` after each; then playtest `make skirmish` with the lead.

## Open questions for the lead

1. **Control point as the default rule?** Round 1 measured that it restores "coordination wins" under shields.
2. **Meshy spending cap for round 2?** The art stream logs credits per request in `assets/meshy_ledger.md`.
3. **Carried over:** rotate the Meshy API key (it was pasted in chat once); Git LFS for generated art; phone runs of `?fx-bench` and `?det-spike`; move `MESHY_API_KEY` above the interactive guard in `~/.bashrc` so agent shells see it.
