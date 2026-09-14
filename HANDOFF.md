# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** Then, if you're a workstream
> agent, [`_agents/workstreams.md`](_agents/workstreams.md) and your brief in `_agents/streams/`.

_Last updated: 2026-09-14. **Five stream agents are set up to run overnight without the lead** (see below)._

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
*Autonomous mandate*). **Art direction source of truth: [`_agents/art_direction.md`](_agents/art_direction.md)** (the "Death Race prison dozer" north star, chosen by the lead 2026-09-14). **Standing product constraints:** mobile first (taps, swipes, buttons), and a
dark neon cyberpunk arena where lighting is part of the fun.

Setup (git worktrees, shared toolchain), ownership, contracts, and merge invariants:
[`_agents/workstreams.md`](_agents/workstreams.md).

## Overnight run (2026-09-14): five agents, no lead input

Each stream's brief now ends with an **Overnight backlog** (more than a night's work, ordered, with
stretch items). Rules for unattended work are in workstreams.md → *Unattended runs*. Landed on
main first so streams don't block each other: the machine-wide heavy-run limiter (`tools/slot.sh`),
the `fx.shell` visual slot, the unit catalog v0 (`game/units/units.gd`), and `--player=<path>` for garage armies.

**Start each agent** in its worktree (`cd ~/projects/godot-<stream> && claude`) with this goal. It's
the same text for all five; the agent works out its stream from its folder:

> /goal You are a Tank Squad workstream agent. Your stream is determined by your working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>` (one of gameplay, look_and_feel, assets, netcode, garage). Run `pwd` and `git branch --show-current` to confirm them, and stop if they disagree. I'm asleep: you will get NO input from me until morning, so never stop to wait for an answer. Read CLAUDE.md, HANDOFF.md, `_agents/orientation.md`, `_agents/workstreams.md` (especially *Autonomous mandate* and *Unattended runs*), then `_agents/streams/<stream>.md`. Work through its **Overnight backlog** top to bottom, then its stretch items: build, test, `make check`, smoke test and look at your screenshots, and commit every green step. Done when every backlog item is complete or written up as blocked, `make check` passes on your last commit, and the brief's Status section holds the morning report.

**Morning integration** (the orchestrator session in `~/projects/godot`): read each Status report,
merge streams one at a time in the order netcode → assets → garage → gameplay → look_and_feel
(smallest shared surface first; gameplay and look & feel touch the most), running `make check`
after each merge, then playtest `make skirmish` with the lead.

## What changed to make parallel work possible

- `main.gd` split into `game/modes/*` (offline, skirmish, match runner, server, client) + `LaunchFlags`.
- **Visual slots:** all art moved out of gameplay scenes into `game/theme/default/`; `GameTheme` maps slot ids to scenes; `VisualSlot` nodes load them. The simulation hash was identical before and after (`e69acc63a64f319a`).
- Tank replication built in code (`game/network/replication.gd`); the HUD in its own scene (`game/ui/hud.tscn`); the Makefile split into `mk/*.mk`; `tests/baselines/sim_state_hash.txt` + `make sim-baseline`.

## Open decisions for the lead

1. **Netcode direction** (streams/netcode.md): OK to ship casual matches player-hosted through a relay first, while a deterministic-simulation spike decides whether cheat-resistant lockstep is feasible?
2. **Netcode:** the overnight agent assumes the recommended plan (casual relay first, deterministic spike in parallel). Confirm or redirect in the morning.
3. Still open from before: the flamethrower trade-off (now part of the gameplay stream), your son's Godot version and OS.
