# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** Then, if you're a workstream
> agent, [`_agents/workstreams.md`](_agents/workstreams.md) and your brief in `_agents/streams/`.

_Last updated: 2026-09-15. **All five overnight streams are merged into `main`** and verified together._

## Current state (main)

- **Play it:**
  - `make skirmish`: squads vs a seeded budgeted CPU army, with the RTS 3D camera, radar, fog of war, touch controls, shields, ammo, heat, lasers, scouts, artillery, cyberpunk look, banners, and sound. Try `CONTROL=1` for the center control point, `ENEMY=cpu:siege`, and `SEED=3`.
  - `make garage`: build an army on a budget, then FIGHT.
  - `make title`: the animated title screen.
  - `make play-relay`, then open `http://localhost:8060/?lobby`: player-hosted multiplayer through the relay broker, with room codes.
  - Also: `make vehicle-gallery`, `make hud-gallery`, `make fx-bench`, `make assets-gallery THEME=neon_kit NIGHT=1`, and `make assets-unit THEME=prison_dozer`.
- **Verified 2026-09-15 on merged `main`:**
  - `make check`: 292 tests plus network, combat, relay, lobby, match, determinism, sim-baseline, and garage smoke tests.
  - `make web-smoke`, and the assets web gallery.
  - `make check-all`: see the Status section of this file's latest commit message, or re-run it.
- **Sim baseline:** `e5cf33921713b657`. Navigation now syncs synchronously, so the baseline is deterministic under machine load (orientation trip-up 57).
- **Web download:** 0.8 MB `.pck`. Candidate art themes and the asset pipeline are excluded from exports (trip-up 56).

## What each stream delivered (details in each brief's Status section)

| Stream | Delivered | Brief |
|---|---|---|
| Gameplay | G0–G7 plus directive set 2: touch input, fog of war + radar, responsive orders, RTS camera, turrets that fight on the move, shields, ammo/heat/lasers, the unit catalog v1 (tank/scout/artillery + components), budgets, CPU armies (`Army`), control point, CPU commander (opt-in) | [gameplay.md](_agents/streams/gameplay.md), [balance.md](_agents/balance.md) |
| Look & feel | FX lab with measured tier budgets; cyberpunk default theme; pooled FX systems; HUD widgets (banners, frames, conductors); quality tiers; synthesized sound; title screen | [look_and_feel.md](_agents/streams/look_and_feel.md), [fx_tricks.md](_agents/streams/references/fx_tricks.md) |
| Assets | GLB normalize/check pipeline; Meshy/Tripo clients; CC0 `kitbash` and procedural `neon_kit` themes; the first production unit, the **prison dozer** (with the lead) | [assets.md](_agents/streams/assets.md), [art_direction.md](_agents/art_direction.md) |
| Netcode | Relay broker (Node); player-hosted matches (`RelayPeer`); touch lobby; reconnect/rejoin; replays; bandwidth + latency measured; **the lockstep spike is bit-identical native vs wasm** | [netcode.md](_agents/streams/netcode.md), [netcode_designs.md](_agents/streams/references/netcode_designs.md) |
| Garage | Touch-first garage; loadouts saved per army; army codes; presets; comparison tables; tips; FIGHT hands over to the skirmish | [garage.md](_agents/streams/garage.md) |

## Integration notes (2026-09-15)

- **Merge order:** gameplay → look & feel (look & feel had rehearsed this merge) → netcode → assets → garage. Text conflicts were only in docs, `game_mode.gd`, the `Makefile`'s `LIGHT_GOALS`, and `mk/core.mk`'s `check`.
- **Garage × gameplay reconciliation.** The garage was built on unit catalog v0 while gameplay shipped v1:
  - **CPU opponents:** one generator, gameplay's `Army`. The garage's opponent picker offers `Army` archetypes; `ArmyPresets` stays for player presets.
  - **Starter army and presets:** built on the "workhorse" (the tank), not the cheapest unit (now scouts).
  - **Zero-valued stats:** they no longer trigger advice (the cannon's `heat_per_shot: 0`).
- **Paint/team split** (look & feel's request, fixed during integration): `Tank.set_team_accent` → slot `set_team_color` (friend or foe); `Tank.set_paint` → slot `set_paint`, only for painted loadouts. Before this, painted tanks lost their team accent lights.
- **Theme flag clash:** `--theme=<candidate theme>` from asset tools no longer warns in `GameTheme` (it broke the browser gallery).
- **Streams' worktrees are now behind `main`.** Before another run, each stream must `git merge main` (or be recreated with `make worktree-remove` + `make worktree`).

## Decisions and questions for the lead (collected from the streams)

**Gameplay**
1. **Shields broke "coordination wins".** Coordinated squads went from 60% to ~5–10% with shields. The center control point restores 50/50. Recommendation: **make `--control` the default skirmish rule**.
2. **Scouts are eyes, not an army.** Scout-heavy armies are non-viable (Swarm ~3%). Is that intended, or should scouts get real firepower or a lower price?
3. **Phones need content scaling:** `display/window/stretch/mode="canvas_items"` in `project.godot` (a shared file, not changed yet).

**Netcode**
4. **When to port the simulation to an integer core for lockstep.** Recommended: after the gameplay rules settle.
5. **Run `?det-spike` on an Android phone.** ARM is the one platform not measured; the hash must read `ea02d9652cc08086`.
6. **Should the web build open the lobby by default?**

**Look & feel**
7. **Run `?fx-bench` on your phone** (`make serve-web WEB_HOST=0.0.0.0`) to calibrate the quality tiers.
8. **Make the title screen the entry point?**
9. **Listen to the synthesized sounds.**

**Assets**
10. **Rotate the Meshy API key.** It was pasted in chat once.
11. **Git LFS for generated art?** The prison dozer is ~27 MB in git.
12. **Check Basis texture load time on a phone.**

## How the parallel setup works

Worktrees, ports, heavy-run slots (`tools/slot.sh`), ownership, contracts, the autonomous and
unattended rules, and merge invariants: [`_agents/workstreams.md`](_agents/workstreams.md). The overnight
`/goal` kickoff used on 2026-09-14 is in the git history of this file (commit `ee20791`).
