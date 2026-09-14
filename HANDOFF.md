# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** Then, if you're a workstream
> agent, [`_agents/workstreams.md`](_agents/workstreams.md) and your brief in `_agents/streams/`.

_Last updated: 2026-09-14. The repo is prepared for **parallel workstreams**; gameplay and look & feel have concrete directives from the lead._

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
| Gameplay | [streams/gameplay.md](_agents/streams/gameplay.md) | Directive set 1: touch-first input, line-of-sight fog of war, radar, responsive commands, RTS 3D camera, turrets that fight while moving, Halo-style shields, finite ammo + lasers with heat. Next: budgeted army (scouts/tanks/artillery) |
| Look & feel | [streams/look_and_feel.md](_agents/streams/look_and_feel.md) | L0 FX lab: prove efficient lighting tricks with `make fx-bench` (streams/references/fx_tricks.md); port the mavlink-hud cyberpunk HUD (CyberFrame, CyberBanner, Conductors) via `Hud.post_message`; then a dark `cyberpunk` theme where weapon fire, lasers, and neon obstacles light the arena |
| Assets | [streams/assets.md](_agents/streams/assets.md) | One AI-generated tank in a test theme + `make assets-check` |
| Netcode | [streams/netcode.md](_agents/streams/netcode.md) | Broker (lobbies + relay), then a deterministic-core spike |
| Garage | [streams/garage.md](_agents/streams/garage.md) | Loadout schema + garage scene producing a playable doctrine |

**Kickoff for any stream agent** (in its worktree): *"You are the `<stream>` agent. Execute, iterate,
and smoke test toward completion without my input."* The docs carry the rest (workstreams.md →
*Autonomous mandate*). **Standing product constraints:** mobile first (taps, swipes, buttons), and a
dark neon cyberpunk arena where lighting is part of the fun.

Setup (git worktrees, shared toolchain), ownership, contracts, and merge invariants:
[`_agents/workstreams.md`](_agents/workstreams.md).

## What changed to make parallel work possible

- `main.gd` split into `game/modes/*` (offline, skirmish, match runner, server, client) + `LaunchFlags`.
- **Visual slots:** all art moved out of gameplay scenes into `game/theme/default/`; `GameTheme` maps slot ids to scenes; `VisualSlot` nodes load them. The simulation hash was identical before and after (`e69acc63a64f319a`).
- Tank replication built in code (`game/network/replication.gd`); the HUD in its own scene (`game/ui/hud.tscn`); the Makefile split into `mk/*.mk`; `tests/baselines/sim_state_hash.txt` + `make sim-baseline`.

## Open decisions for the lead

1. **Netcode direction** (streams/netcode.md): OK to ship casual matches player-hosted through a relay first, while a deterministic-simulation spike decides whether cheat-resistant lockstep is feasible?
2. **Starting streams:** gameplay and look & feel are ready (`make worktree STREAM=gameplay OFFSET=1`, `make worktree STREAM=look_and_feel OFFSET=2`). Who merges: you, or an integrator agent?
3. Still open from before: the flamethrower trade-off (now part of the gameplay stream), your son's Godot version and OS.
