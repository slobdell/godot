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

## Product constraints every stream designs for (the lead)

1. **Mobile first** (2026-09-14): *"we eventually want to optimize for a mobile experience, meaning
   we'll be limited to taps, swipes, and button clicks."* Every player action must be reachable
   by tap, drag/swipe, pinch, or an on-screen button. Keyboard and mouse shortcuts are fine as
   extras for desktop and testing, but never the only way. Tap targets are at least ~48 px at
   1080p, and the HUD must stay readable on a phone-sized screen. Verify with touch emulation
   (`input_devices/pointing/emulate_touch_from_mouse`) or `InputEventScreenTouch`/`ScreenDrag`
   events in tests.
2. **The vibe:** a cyberpunk gladiator arena, *Mad Max × Death Race × Blade Runner*: a dark
   atmosphere lit by neon and weapon fire. **Lighting is a core part of the fun**, not polish
   (streams/look_and_feel.md).
3. **Web and phones:** Compatibility renderer, 60 fps on a mid-range phone, one simulation that
   runs headless on a server.

## Autonomous mandate: how a stream agent works without the lead

The lead's kickoff is short on purpose: *"You are the `<stream>` agent. Execute, iterate, and smoke
test toward completion without my input."* Everything else is in the docs. It means:

1. **Orient:** read `CLAUDE.md` → `HANDOFF.md` → `_agents/orientation.md` → this file → your brief. Run `make check` to confirm a green start.
2. **Plan:** turn your brief's directives into an ordered list in its **Status** section (smallest foundation first). Brief directives are the lead's intent. Where they leave a choice open, make the call a good game designer/engineer would, and record it with a one-line reason.
3. **Loop per directive:** build → automated test (a regression test that fails without the change) → `make check` → **smoke test like a player** (launch it, take screenshots at desktop *and* phone aspect, and look at them; drive it through the agent bridge or scripted input; for gameplay, run `tools/match_series.py`) → fix what felt wrong → commit to your branch with a message saying what and why.
4. **Keep going** to the next directive without waiting. Update your brief's Status after each one (done, measured result, decisions, known issues).
5. **Stop and ask the lead only** for: a contract change that another stream must accept, spending money or creating accounts (e.g. asset services), anything destructive outside your worktree, or a directive that turns out to be impossible or self-contradictory as written. Otherwise, decide, document, and continue.
6. **Done** = every directive in the current set meets its acceptance notes, `make check` + `make web-smoke` pass, screenshots were reviewed, the brief's Status is current, and the branch is ready to merge (rebased on `main`). Then write a short merge note: what changed, what to playtest, decisions made, and open questions for the lead.

## Unattended runs (overnight): extra rules when the lead is away

The lead starts all five streams at once with `/goal` and goes to bed. **Nobody will answer
questions until morning.** On top of the mandate above:

1. **Never wait for an answer.** Everything the mandate says to "ask the lead" becomes: write it
   under **Questions for the lead** in your brief's Status, take the most *reversible* reasonable
   option (or skip that item), and keep working on the next one.
2. **Need something from another stream?** Don't edit their paths. Build a small adapter or stub
   inside your own paths, write the request under **Requests to other streams** in your Status, and
   continue. The integrator reconciles in the morning.
3. **Don't merge or rebase on `main` overnight.** `main` won't move until the morning integration. Commit
   to `stream/<name>` after every green step. You may `git push -u origin stream/<name>` as a backup.
   Never push `main`, never force-push, never touch another worktree.
4. **The machine is shared and small** (8 cores, 7.6 GB RAM, ~9 GB free disk on 2026-09-14):
   - Heavy runs queue through `tools/slot.sh` automatically via `make` (orientation trip-up #37). Wrap any Godot/Chrome/match-series run you start outside make.
   - At most **one** long-running background process of yours at a time (a server, an agent client). Stop it by PID when done; never `pkill -f` a pattern (trip-up #19). Never kill processes you didn't start.
   - Disk: check `df -h .` before downloading. Keep each stream's downloads under **500 MB**. No local ML models or large Docker images. Delete stale `build/` outputs you created.
5. **No money, accounts, or secrets.** No sign-ups, paid APIs, or keys. Anything that needs one gets scaffolded and documented so the lead can switch it on later.
6. **Time-box.** If one item fights you for ~90 minutes without progress, write down what you learned and what you'd try next, then move on.
7. **The backlog is deliberately longer than one night.** Finishing an item isn't a reason to stop; take the next one, then the stretch items. Stop only when the backlog is done or you're truly blocked on everything left.
8. **Shared files** (`project.godot`, `game/main.gd`, `main.tscn`, `game/modes/game_mode.gd`, root `Makefile`, `mk/core.mk`): additive, minimal edits only, listed in your merge notes. Prefer adding UI and nodes from code in your own paths over editing shared scenes.
9. **Leave a morning report.** Keep your brief's **Status** current as you go (a crash mustn't lose it). It needs: done (with measurements), decisions + reasons, questions for the lead, requests to other streams, known issues, what to playtest (exact `make` commands), and the next steps.

## How to set up parallel copies: git worktrees, not folder copies

Copies drift and can't merge back cleanly. **Worktrees** are extra checkouts of the *same*
repository, each on its own branch. One command creates an isolated one:

```bash
cd ~/projects/godot                       # the main checkout, on main: the orchestrator's home
make worktree STREAM=gameplay OFFSET=1    # → ../godot-gameplay on branch stream/gameplay
make worktree STREAM=look_and_feel OFFSET=2
make worktree STREAM=assets OFFSET=3
make worktree STREAM=netcode OFFSET=4
make worktree STREAM=garage OFFSET=5
make worktrees                            # status of all of them
```

What `tools/worktree.sh` isolates (verified 2026-09-14: two worktrees ran `net-smoke` + `combat-smoke`
at the same moment, both passed, on ports 9261 and 9271):

| Shared resource | Collision risk | Isolation |
|---|---|---|
| Files and branch | agents overwrite each other | separate folder + `stream/<name>` branch |
| Network ports (servers, smoke tests, agent bridge) | two `make check`s fight over 9181/8061/8765 | `local.mk`: every port + `10 × OFFSET` |
| CPU (match series) | 5 agents × parallel matches thrash | `local.mk`: `JOBS := 2` |
| Godot `user://` (saves, logs) | garage saves / logs collide | `override.cfg`: `tank_squad_<stream>` user dir |
| `.godot/` import cache | a stale cache for another branch | per worktree (not shared) |
| `.tools/` Godot toolchain (300 MB) | none (read-only use) | shared by symlink |

## Running the agents

1. One terminal per stream: `cd ~/projects/godot-<stream> && claude`, then: *"You are the `<stream>` agent. Execute, iterate, and smoke test toward completion without my input."* (The docs, starting from `CLAUDE.md`, carry the rest; see *Autonomous mandate* above.)
2. Agents commit to their own branch as they go (they may `git push -u origin stream/<stream>` for backup).
3. **The orchestrator** (a Claude session in the main checkout, or the lead) reviews and integrates:
   ```bash
   make worktrees                                   # who's dirty, who's ahead of main
   git log --oneline main..stream/gameplay          # what a stream did
   git diff main...stream/gameplay --stat           # what it touched: stay inside owned paths?
   (cd ../godot-gameplay && git rebase main && make check)   # rebased branch must be green
   git merge --no-ff stream/gameplay                 # in the main checkout
   make check && git push
   ```
4. **After every merge, tell the other streams to `git rebase main`** (or merge main) so conflicts surface early and small.
5. When a stream is finished: `make worktree-remove STREAM=<name>` (refuses with uncommitted work; keeps the branch).

**Git facts that bite with worktrees:**
- A branch can be checked out in only ONE worktree. Don't `git checkout main` inside a stream worktree; the orchestrator's checkout owns `main`.
- `git stash`, hooks, and `git config` are **shared** across worktrees: a stash made in one shows up in all. Prefer WIP commits on the stream branch.
- Deleting a worktree folder by hand leaves stale metadata; use `make worktree-remove` (or `git worktree prune`).

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
| `game/ui/tactical_map.gd` (behavior), `game/ui/radar*` (new), `game/camera/`, `game/modes/{offline,skirmish,match_runner}_mode.gd` | gameplay |
| `game/ui/widgets/**` (new: CyberFrame, CyberBanner, Conductors, reusable HUD components) | look & feel |
| `game/units/` (unit catalog, schema v0 landed 2026-09-14) | gameplay |
| `doctrines/` | gameplay (garage adds player loadout files) |
| `game/theme/**` (all art, the slot registry, team colors, UI palette, `game/theme/fx/` effect systems), `mk/fx.mk` (new: `fx-bench`) | look & feel |
| `game/ui/hud.tscn` (HUD layout/styling) | look & feel (`hud.gd` text logic: gameplay) |
| `assets/`, `tools/assets/`, `game/theme/*/generated/` | assets |
| `game/network/` (incl. `ui/` lobby + room badge, `detcore/`), `game/modes/{server,client,host,lobby,det_spike}_mode.gd`, `server/broker/`, `tools/serve_web.py`, `tests/net/`, `mk/net.mk` | netcode |
| `game/agent/`, `tools/agent.py` | gameplay (it's a player of the game) |
| `game/garage/` (new), `mk/garage.mk` (new) | garage |
| `mk/<area>.mk` | the stream named in the file's header |
| **Shared:** `project.godot`, `export_presets.cfg`, `game/main.gd`, `game/main.tscn`, `Makefile`, `mk/core.mk`, `tests/run_tests.gd`, `CLAUDE.md` | nobody alone: keep edits minimal and mention them in your merge notes |

## Contracts between streams

Changing one of these requires updating this section and telling the other streams (the lead relays).

| Contract | Defined in | Consumers |
|---|---|---|
| **Visual slots**: slot ids, orientation/size/origin, optional methods `set_team_color`, `setup`, `set_firing` (`fx.shell` landed 2026-09-14; planned: `weapon.laser`, `fx.laser_beam`, `set_heat(ratio)`, `set_shield(ratio)`; see streams/assets.md) | `game/theme/game_theme.gd`, `game/theme/visual_slot.gd`, [streams/assets.md § Slot contracts](streams/assets.md#slot-contracts) | gameplay places slots; look & feel and assets fill them |
| **SquadCommand**: `{squad, verb, to, facing, formation, commander}` | `game/ai/squad.gd` | tactical map, CPU, agent, netcode (sent over the wire) |
| **Doctrine / loadout JSON** | `game/ai/doctrine.gd`, `game/ai/directives.gd` | gameplay, garage (produces), match runner |
| **Simulation entry points**: `Match.command_squad()`, `Tank.command`, `Match.load_doctrine()`, `Match.finished`, `Match.state_hash()` | `game/match/match.gd` | netcode (what goes over the wire), garage, modes |
| **Replicated tank state** (`sync_*`; gameplay adds `sync_shield` (G6), `sync_ammo`, `sync_heat` (G7)) | `game/network/replication.gd` + `tank.gd` | netcode, gameplay |
| **Launch flags** (netcode added `--host`, `--join`, `--relay`, `--lobby`, `--record`, `--replay`, `--player-key`, `--det-spike`, `--relay-latency/-jitter` on 2026-09-14) | `game/main.gd` header, `game/modes/*` | everyone (Makefile targets, smoke tests) |
| **Console markers** `TANK_SQUAD_*`, `MATCH_RESULT` (netcode: `TANK_SQUAD_ROOM`, `TANK_SQUAD_RELAY`, `TANK_SQUAD_HOST_STATS`, `NET_CHECK`, `NET_MEASURE`, `DET_SPIKE_*`, `DET_REPLAY`) | `game/main.gd`, `match_runner_mode.gd`, `game/modes/{host,client,det_spike}_mode.gd` | smoke tests, `tools/match_series.py`, `mk/net.mk` |
| **HUD messages**: `Hud.post_message(text: String, severity: int)` with `Hud.INFO` / `WARNING` / `ERROR` | `game/ui/hud.gd` (stub: a plain label) | gameplay posts (orders, losses, results); look & feel renders (banners) |
| **Visibility / radar data**: the team's visibility field (visible now / seen / unseen), units, contacts, destinations; radar frame styling hook | gameplay defines when building G1/G2 (streams/gameplay.md), then records the API here | gameplay's radar widget; look & feel skins it |
| **Unit catalog** (classes, costs, stats, hardpoints, component slots, budget) | `game/units/units.gd` (schema v0: `tank` only, not yet read by the simulation); gameplay grows it in directive set 2 | garage (UI), doctrine files |
| **Loadout fields in doctrine JSON** (per tank: `unit`, `weapons` by hardpoint, `components`, `paint`) | proposed 2026-09-14; the garage stream writes them (today's `Doctrine.parse` ignores unknown keys, so files stay loadable), and gameplay starts reading them when classes land | garage (produces), gameplay (consumes) |

## Invariants every stream must keep

1. `make check` passes before merging (lint, tests, network, combat, match, determinism).
2. **Art never changes the simulation.** `make sim-baseline` (part of `make check`) replays a seeded match and compares its `state_hash` to `tests/baselines/sim_state_hash.txt` (`e69acc63a64f319a` on 2026-09-13). Look & feel, assets, garage, and netcode must leave it unchanged. Gameplay changes it on purpose and updates the file in the same commit, saying why.
3. The web build still boots (`make web-smoke`) and the dedicated server still exports (`make export-server`). Visual slots must load on a headless server.
4. Fairness: any change to the arena, spawns, or navigation re-runs the swap-bases control (verification.md).
5. Docs move with code: update your stream brief's **Status** section and any stale `_agents/` doc in the same merge.
