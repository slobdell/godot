# Workstreams: Working in Parallel

> Written 2026-09-13 when the project lead decided to run several agents at once, each on
> an independent problem. **Read this, then your stream's brief in `_agents/streams/`.**

## The streams

| Stream | Brief | Goal | Can start |
|---|---|---|---|
| **Gameplay** | [streams/gameplay.md](streams/gameplay.md) | Make squad-vs-squad actually fun | now |
| **Look & feel** | [streams/look_and_feel.md](streams/look_and_feel.md) | Cyberpunk gladiator arena: Mad Max × Death Race × Blade Runner | now |
| **Assets** | [streams/assets.md](streams/assets.md) | Pipeline for AI-generated 3D models into visual slots | now (slot contracts exist) |
| **Netcode** | [streams/netcode.md](streams/netcode.md) | Production multiplayer without paying for game compute | now (starts with a decision spike) |
| **Garage** | [streams/garage.md](streams/garage.md) | Pre-match equipping / squad building | data model now; art after look & feel v1 |

## How to set up parallel copies: git worktrees, not folder copies

Copies drift and can't merge back cleanly. Worktrees share one repository, and each has its own branch:

```bash
cd ~/projects/godot
git worktree add ../godot-gameplay -b stream/gameplay
git worktree add ../godot-look     -b stream/look-and-feel
git worktree add ../godot-assets   -b stream/assets
git worktree add ../godot-netcode  -b stream/netcode
git worktree add ../godot-garage   -b stream/garage
# In each worktree: share the 300 MB toolchain instead of re-downloading it
ln -s ~/projects/godot/.tools ../godot-gameplay/.tools   # (repeat per worktree)
cd ../godot-gameplay && make import && make check
```

Start one agent per worktree and tell it: *"You are the <stream> workstream. Read CLAUDE.md,
then `_agents/workstreams.md` and `_agents/streams/<stream>.md`."*

**Merging:** each stream merges into `main` when `make check` passes on the rebased branch.
Rebase on `main` often (at least after any other stream merges). The lead (or one integrating
agent) does the merges.

## Who owns what

Owning a path means you may change it freely. Anything else, change only through the
stream that owns it, or through a contract change (below).

| Path | Owner |
|---|---|
| `game/match/` (rules, spawning, damage, intel, squads registry) | gameplay |
| `game/ai/` (brains, orders, squads, formations, directives, doctrine) | gameplay |
| `game/combat/weapons.gd`, `armor.gd`, `ballistics.gd`, `shell.gd` | gameplay |
| `game/combat/impact.gd` (the hit VFX) | look & feel (candidate to become an `fx.impact` slot) |
| `game/tank/tank.gd`, `tank_command.gd`, `tank_motion.gd`; `tank.tscn` structure | gameplay (netcode owns the `sync_*` properties' meaning) |
| `game/arena/` (collision layout, navigation, `arena.gd`) | gameplay |
| `game/ui/tactical_map.gd` (behavior), `game/modes/{offline,skirmish,match_runner}_mode.gd` | gameplay |
| `doctrines/` | gameplay (garage adds player loadout files) |
| `game/theme/**` (all art, the slot registry, team colors, UI palette) | look & feel |
| `game/ui/hud.tscn` (HUD layout/styling) | look & feel (`hud.gd` text logic: gameplay) |
| `assets/`, `tools/assets/`, `game/theme/*/generated/` | assets |
| `game/network/`, `game/modes/{server,client}_mode.gd`, `tools/serve_web.py`, `tests/net/`, `mk/net.mk` | netcode |
| `game/agent/`, `tools/agent.py` | gameplay (it's a player of the game) |
| `game/garage/` (new), `mk/garage.mk` (new) | garage |
| `mk/<area>.mk` | the stream named in the file's header |
| **Shared:** `project.godot`, `export_presets.cfg`, `game/main.gd`, `game/main.tscn`, `Makefile`, `mk/core.mk`, `tests/run_tests.gd`, `CLAUDE.md` | nobody alone: keep edits minimal and mention them in your merge notes |

## Contracts between streams

Changing one of these requires updating this section and telling the other streams (the lead relays).

| Contract | Defined in | Consumers |
|---|---|---|
| **Visual slots**: slot ids, orientation/size/origin, optional methods `set_team_color`, `setup`, `set_firing` | `game/theme/game_theme.gd`, `game/theme/visual_slot.gd`, [streams/assets.md § Slot contracts](streams/assets.md#slot-contracts) | gameplay places slots; look & feel and assets fill them |
| **SquadCommand**: `{squad, verb, to, facing, formation, commander}` | `game/ai/squad.gd` | tactical map, CPU, agent, netcode (sent over the wire) |
| **Doctrine / loadout JSON** | `game/ai/doctrine.gd`, `game/ai/directives.gd` | gameplay, garage (produces), match runner |
| **Simulation entry points**: `Match.command_squad()`, `Tank.command`, `Match.load_doctrine()`, `Match.finished`, `Match.state_hash()` | `game/match/match.gd` | netcode (what goes over the wire), garage, modes |
| **Replicated tank state** (`sync_*`) | `game/network/replication.gd` + `tank.gd` | netcode, gameplay |
| **Launch flags** | `game/main.gd` header, `game/modes/*` | everyone (Makefile targets, smoke tests) |
| **Console markers** `TANK_SQUAD_*`, `MATCH_RESULT` | `game/main.gd`, `match_runner_mode.gd` | smoke tests, `tools/match_series.py` |

## Invariants every stream must keep

1. `make check` passes before merging (lint, tests, network, combat, match, determinism).
2. **Art never changes the simulation.** `make sim-baseline` (part of `make check`) replays a seeded match and compares its `state_hash` to `tests/baselines/sim_state_hash.txt` (`e69acc63a64f319a` on 2026-09-13). Look & feel, assets, garage, and netcode must leave it unchanged. Gameplay changes it on purpose and updates the file in the same commit, saying why.
3. The web build still boots (`make web-smoke`) and the dedicated server still exports (`make export-server`). Visual slots must load on a headless server.
4. Fairness: any change to the arena, spawns, or navigation re-runs the swap-bases control (verification.md).
5. Docs move with code: update your stream brief's **Status** section and any stale `_agents/` doc in the same merge.
