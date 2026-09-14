# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** Then, if you're a workstream
> agent, [`_agents/workstreams.md`](_agents/workstreams.md) and your brief in `_agents/streams/`.

_Last updated: 2026-09-13. The repo is prepared for **parallel workstreams**._

## Current state (main)

- **Playable:** `make skirmish` (squad-vs-squad tactical map, elimination, tactical pause), `make play` (browser multiplayer), `make run` (drive a tank), `make watch-match` (two AI doctrines).
- **Verified:** `make check` = lint, 88 tests, network/combat/match smoke tests, determinism, **sim-baseline** (art must never change gameplay). `make check-all` (desktop render, browser checks, server export) passed from a clean build.
- **Measured facts that matter for planning:**
  - Coordinated squads beat uncoordinated ones 60% under current rules (T1 v2, tank_brain.md).
  - Fight pace: first shot ~8 s, first kill ~32 s, matches ~230 s (tactical_map.md Iteration 2).
  - **Native and browser builds do not simulate identically** (streams/netcode.md), which shapes the multiplayer architecture.

## The workstreams (the lead's plan, 2026-09-13)

| Stream | Brief | First milestone |
|---|---|---|
| Gameplay | [streams/gameplay.md](_agents/streams/gameplay.md) | Playtest-driven: objectives/abilities/anti-snowball, measured with the match runner |
| Look & feel | [streams/look_and_feel.md](_agents/streams/look_and_feel.md) | A `cyberpunk` theme filling every visual slot; HUD restyle |
| Assets | [streams/assets.md](_agents/streams/assets.md) | One AI-generated tank in a test theme + `make assets-check` |
| Netcode | [streams/netcode.md](_agents/streams/netcode.md) | Broker (lobbies + relay), then a deterministic-core spike |
| Garage | [streams/garage.md](_agents/streams/garage.md) | Loadout schema + garage scene producing a playable doctrine |

Setup (git worktrees, shared toolchain), ownership, contracts, and merge invariants:
[`_agents/workstreams.md`](_agents/workstreams.md).

## What changed to make parallel work possible

- `main.gd` split into `game/modes/*` (offline, skirmish, match runner, server, client) + `LaunchFlags`.
- **Visual slots:** all art moved out of gameplay scenes into `game/theme/default/`; `GameTheme` maps slot ids to scenes; `VisualSlot` nodes load them. The simulation hash was identical before and after (`e69acc63a64f319a`).
- Tank replication built in code (`game/network/replication.gd`); the HUD in its own scene (`game/ui/hud.tscn`); the Makefile split into `mk/*.mk`; `tests/baselines/sim_state_hash.txt` + `make sim-baseline`.

## Open decisions for the lead

1. **Netcode direction** (streams/netcode.md): OK to ship casual matches player-hosted through a relay first, while a deterministic-simulation spike decides whether cheat-resistant lockstep is feasible?
2. **Which streams to start first,** and who merges (you, or an integrator agent)?
3. Still open from before: the flamethrower trade-off (now part of the gameplay stream), your son's Godot version and OS.
