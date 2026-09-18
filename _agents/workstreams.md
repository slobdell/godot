# Workstreams: the current round

> **Round 6, planned 2026-09-18.** How rounds work (roles, lifecycle, the worker contract, the kickoff prompt) is in
> [orchestration.md](orchestration.md): read it first. This file is round 6's streams, ownership, contracts, gates and
> invariants. Rounds 1–5 are archived in `streams/archive/round1..5/`.

## Round 6 goal

**Movement you can trust, and a squad that forms up.** The lead played round 5 and stopped at vehicles that get stuck
behind each other, formations that never form, buttons he can't name, a long dead pause after FIGHT, a camera too far
above the fight, empty stands, and weapons that open fire the moment anyone is visible
([game_design.md](game_design.md) *Round 6 direction*). Frame rate is **not** on his list this round — the locked 30 fps
held — so this round spends its budget on behaviour, not on the frame.

The stack the lead described, top to bottom, is the shape of this round:

```
  player order  ──▶  squad: target formation, a slot per unit, form-up ETA     (squad)
                     └─▶ unit: path to my slot, avoid, negotiate, unstick      (nav)
                         └─▶ hull: throttle and turn from a regulated error    (nav, PID)
  read and issued through the task palette, symbols and camera                 (control)
  over terrain that makes ambush and flanking possible                         (arena)
  at ranges where closing is a decision                                        (combat)
  in a place that feels inhabited                                              (feel)
```

## Round 6 streams

| Stream | Brief | Outcome |
|---|---|---|
| **nav** | [streams/nav.md](streams/nav.md) | A horde gets where it is sent: real path planning, local avoidance with peer-to-peer right-of-way, nothing stuck, and one regulated control law (PID) from the wheels up. Proven on a maze. |
| **squad** | [streams/squad.md](streams/squad.md) | A squad order is a *formation* order: a target formation anchored on the destination, a slot per unit, a form-up formula and ETA, and every named task producing the behaviour its name claims |
| **control** | [streams/control.md](streams/control.md) | The squad UX earns every button: military task symbology, nothing the mouse already does, a camera between StarCraft 2 and Twisted Metal, and loading that shows its progress |
| **arena** | [streams/arena.md](streams/arena.md) | Terrain that makes ambush and flanking possible instead of one open brawl, plus the maze arena nav is measured against |
| **combat** | [streams/combat.md](streams/combat.md) | Engagement ranges where seeing an enemy is not the same as opening fire: closing, breaking contact and cover become decisions |
| **feel** | [streams/feel.md](streams/feel.md) | The arena is inhabited: a crowd in the stands that can be seen and heard, and the place reacts to the match |

**Paused:** netcode, the garage and progression loop, new Meshy *models* (88 credits left). ElevenLabs has credits and
feel may use them for crowd beds under the standing text-approval gate.

**Why this split:** the lead's message is one stack with six layers, and each layer fails on its own terms. Getting a
vehicle around another vehicle (nav) is a different craft from deciding where five vehicles should stand (squad), from
naming that task on screen (control), from the ground it happens on (arena), from when a gun is allowed to speak
(combat), from whether the arena feels like a place (feel).

## Checkpoints

- **CP1, nav's Movement API (N1)** — the seam every other stream's movement runs through. nav lands the interface and a
  working default first, before the clever parts, so squad is never coding against a stub.
- **CP2, arena's maze (N3)** — a small data job arena does on day one, because it is nav's acceptance test.
- **CP3, squad's slot contract (N2)** — control's task palette and the CPU commander both read it.
- **CP4, combat's engagement envelope (N5)** — it re-times every fight. It lands **once**, early, and every stream
  re-runs its measurements after; nobody publishes a number that straddles it (round 5 lost days to exactly this).

## Product constraints every stream designs for (the lead)

1. **"Even smarter than StarCraft 2."** The bar is legibility: a unit must look like it knows what it is doing. No unit
   standing still in a fight, no unit stuck behind a friend, no element flip-flopping between drills.
2. **A locked 30 fps at 1080p with 30 a side** (the lead's round-5 sign-off), and a 720p 60 fps option. Anything added
   this round is measured against it; the simulation tick is 30 Hz.
3. **Orders obey instantly**: the K1 response guarantee is **100 ms of wall clock**, asserted in milliseconds.
4. **The player's units hold until ordered** (round-5 ruling). An army that moves without being told is not an army.
5. **Fun first, desktop first; no unearned god view; CPU and player run the same doctrine.**
6. **The vibe** ([art_direction.md](art_direction.md)) and **die-hard, no pay-to-win** ([vision.md](vision.md)).

## Lead gates this round

1. **The camera look is the lead's call.** control puts a page of screenshots (pitch × height × FOV, the same moment of
   the same fight) in front of him rather than guessing at "between StarCraft 2 and Twisted Metal".
2. **Paid generation:** no new Meshy models (88 credits). ElevenLabs crowd beds need the usual text approval, and a
   cheap pilot before any batch (lesson 19).
3. **Design pillars**, money, accounts, and anything destructive outside your worktree.

## Who owns what (round 6)

| Path | Owner |
|---|---|
| `game/ai/{pathing,steering,combat_motion,order_controller,order_feed}.gd`, new `game/ai/{avoidance,movement,pid,control_gains}.gd`, `game/tank/tank_motion.gd`, `mk/nav.mk` (new), `_agents/navigation.md` (new) | **nav** |
| `game/tactics/**`, `game/ai/{formations,squad,squad_tactics,cpu_commander,tank_brain,directives,utility_curves,brain_variants,element_feed,matchups,difficulty,tactical_query,cover_map,fire_lanes,perception,suppression_feed,incoming_fire,ai_tick_cache,ai_explain_overlay}.gd` (**not** `doctrine.gd`: the army-JSON loader is combat's, C2), `doctrines/`, `game/agent/`, `tools/{agent,ai_ladder}.py`, `mk/{ai,tactics}.mk`, `tests/ai_scenarios/`, `_agents/{tank_brain,squad_ai_design,unit_ai,doctrine}.md` | **squad** |
| `game/control/`, `game/ui/` (HUD, widgets, title screen, loading screen), `game/camera/`, `game/controllers/`, `game/modes/{skirmish,offline,title}_mode.gd`, `mk/command.mk`, `_agents/tactical_map.md` — **one exception, granted 2026-09-18:** squad rewrites `game/control/group_formation.gd` into a thin adapter over N2's `TacticsFormation.slots()`, keeping its public API unchanged, because N2 cannot collapse three formation systems into one while one of them lives behind another stream's wall. control reviews that diff at merge and owns the file again afterwards. | **control** |
| `game/arena/`, `arenas/`, `tools/make_arenas.py`, `mk/arena.mk`, `_agents/arenas.md` | **arena** |
| `game/units/`, `game/combat/`, `game/match/`, `game/tank/` **except `tank_motion.gd`**, `tools/{match_series,matchup_matrix,combat_duel,matchup_search}.py`, `mk/match.mk`, `game/modes/match_runner_mode.gd`, `_agents/balance.md` | **combat** |
| `game/theme/**` (materials, shaders, effects, props, the crowd's MultiMesh **and its voice**), `game/audio/`, `game/announcer/`, `assets/{announcer,audio,music}/` and art paths, `tools/{assets,announcer,audio}/`, `mk/{fx,assets,announcer,audio}.mk`, `export_presets.cfg` art filters, `_agents/{art_direction,slot_contracts}.md` | **feel** |
| `game/garage/`, `game/progression/`, `game/network/`, `server/`, net modes, `mk/{garage,net}.mk` | **paused**: minimal compatibility fixes only |
| `_agents/game_design.md`, `vision.md`, `roadmap.md`, `workstreams.md`, `orchestration.md`, `backups.md`, `HANDOFF.md` | orchestrator |
| **Shared:** `project.godot`, `game/main.gd`, `game/main.tscn`, `game/modes/game_mode.gd`, `Makefile`, `mk/core.mk`, `tests/run_tests.gd`, `tools/{remote,slot,backup_assets}.sh`, `CLAUDE.md` | nobody alone: minimal edits, listed in merge notes |

`game/theme/audio/` and `engine_system.gd` stay with the sound owner, which is **feel** this round (round 5's audio
stream folds into it; round 5's render stream folds into it too — the frame-rate work is done and the remaining
presentation job is the arena as a place).

## New contracts (round 6)

| Contract | Owner, where | Consumers |
|---|---|---|
| **N1 Movement API** (CP1). One seam between *where a unit is told to be* and *how it gets there*. `Movement.request(unit, to: Vector3, opts) -> void` where `opts` may carry `{"arrive_radius", "facing", "pace", "priority"}`; `Movement.state(unit) -> {"phase": "pathing" \| "driving" \| "yielding" \| "blocked" \| "arrived", "eta_s", "remaining_m", "path_points", "blocked_by"}`; `Movement.eta(unit, to) -> float` (the lead's "estimate the position and time at which a unit would converge"); `Movement.cancel(unit)`. Guarantees nav owes every consumer: a unit given a reachable destination **arrives or reports `blocked` with a reason** — it never stands still silently, and never remains stuck. Local avoidance and right-of-way are always on; no consumer opts in. | nav: `game/ai/movement.gd` | squad (slots), control (orders, markers), combat (none), arena (none) |
| **N2 Slot contract** (CP3). A squad/element order is a formation order. `TacticsFormation.slots(element, anchor, heading, count) -> [{"unit", "to", "facing", "role"}]`, recomputed as the anchor moves; assignment **minimises crossing** (a unit keeps its relative place) and is stable tick to tick; `element.form_up_eta() -> float` from N1's ETAs; the group paces to its slowest member (`Orders.pace_factor`). The two formation systems that exist today (`game/ai/formations.gd`, squad-level, 5 slots; `game/tactics/tactics_formation.gd`, element-level) become **one**. | squad: `game/tactics/`, `game/ai/formations.gd` | control (palette, markers), nav (consumes slot targets), combat (none) |
| **N3 Maze arena** (CP2, day one). `arenas/maze.json` — a quasi-maze the lead asked for by name, built from the existing kit, point-symmetric like every arena, with a start zone and a far objective and gaps a horde must file through. Plus `make nav-maze`, a headless run that sends N units across it and reports how many arrive, when, and how many were ever stuck. It is nav's acceptance test, not a shipping map. | arena: `arenas/`, `mk/arena.mk` | nav (acceptance), squad (form-up under constraint) |
| **N4 Task palette and symbology.** The final task vocabulary, one row per task: the verb (`ElementTask.VERBS`), its **military symbol** (APP-6 / MIL-STD-2525 tactical task graphic), its hotkey, one line of player-facing text, and the behaviour the player is entitled to see. A verb may only appear in the palette when squad can demonstrate its behaviour; a verb the mouse already expresses (`move`, `follow`, `attack`) gets **no button**. control owns the table and draws the symbols; squad owns the behaviour behind each row. | control + squad, table in `_agents/tactical_map.md` | all |
| **N5 Engagement envelope** (CP4). Per-weapon *effective* range, acquisition range and the rule that decides when a unit opens fire, such that seeing an enemy is not the same as shooting at it. Lands once, early, with the before/after measured on the configuration players actually get. | combat: `game/combat/`, `game/units/`, `game/match/` | all (every measurement re-runs after it) |
| **N6 PID as the house control law.** `Pid` (a small, deterministic, tick-based regulator: gains, integral clamp, derivative on measurement, reset) used where there is a continuous error to regulate — slot station-keeping, speed matching, turret lay — and **not** where the problem is discrete choice. Gains live in **data**, per faction, so the lead's idea that factions differ by their gains is reachable: the Syndicate crisp, the gangs loose. Default gains ship stable first; per-faction gains are a stretch. | nav: `game/ai/{pid,control_gains}.gd` | squad (station-keeping), control (camera smoothing), feel (none) |

## Round 5's contracts (still in force)

| Contract | Owner, where | Consumers |
|---|---|---|
| **M1 Performance budget.** `make perf-scene` reports frame time, draw calls, primitives and real-light count for a 30-a-side battle; the written budget is in `_agents/streams/references/fx_tricks.md`. The target is the lead's: **a locked 30 fps at 1080p with 30 a side**, plus a 720p 60 fps option. | feel | all |
| **M2 Arena layout v2.** `arenas/<name>.json` with the arena kit: `props` (`container_20`/`container_40` with `stack`, `ad_screen`, `barricade`, `sign`, `wreck`), lanes and cover annotations for the AI, per-arena spawn zones sized for 30+ a side, validated point-symmetric; `--arena=<name>`. | arena | combat (collision, nav), nav (navigation), feel (props), squad (cover, lanes) |
| **M3 Team identity without glare.** Vehicles read as vehicles at play distance; team accent is a hint. Settled by the lead: **rim tint is enough**, no per-team hull paint. | feel + control | all |

## Round 4's contracts (still in force)

| Contract | Owner, where | Consumers |
|---|---|---|
| **L1 Elements and doctrine.** *Sharp edge (control, 2026-09-16): an element with no task still runs its SOP, so forming one before it has a task makes its leader fight the player for the wheel. Form lazily, on the first task.* An `Element` is a cluster of units with a leader: `Elements.form(units, name)`, `Elements.of(unit)`, `element.assign(task)` where a task is `{"verb": "move" \| "attack" \| "screen" \| "support_by_fire" \| "hold", "to"?, "target"?}`; the leader picks a **formation** (`column`, `wedge`, `line`, `echelon_left/right`, `herringbone`) and a **movement technique** (`traveling`, `traveling_overwatch`, `bounding_overwatch`) from doctrine data, and runs **battle drills** on triggers (`react_to_contact`, `near_ambush`, `far_ambush`, `break_contact`, `support_by_fire`, `assault_through`). It issues per-unit orders through control's K1 `Orders`. Read-only for UI: `element.state() -> {formation, technique, drill, reason, slots}` and signal `element_changed(id)`. Doctrine data lives in `doctrines/doctrine_<name>.json` with a `faction` field. **Round 6 puts this contract on trial: the verbs must do what they say (N4), and the formations must actually form (N2).** | squad: `game/tactics/` | control (HUD, task issuing), nav (executes), combat |
| **L2 Suppression and effective fire.** `Tank.suppression` (0–1, decays), raised by near-misses and rounds passing close; accuracy penalty and a `pinned` state above a threshold. `Match.threat_field(team)`, `Match.is_beaten_zone(team, from, to)`, `Match.threat_along(team, from, to)`, `Match.shot_spread(weapon, moving, suppression)`, `Weapons.suppression(weapon)`, `Tank.suppression`/`is_pinned()`/`suppress()`. `projectile_impact` and `weapon_fired` carry `suppression_applied`. | combat | squad, feel |
| **L3 Faction rosters.** `Units.PROFILES` entries carry `faction` (`condemned` \| `gangs` \| `law` \| `syndicate`), per-faction costs and stats; `Units.roster(faction)`; `--green-faction=` / `--rust-faction=`; `Army` builds faction armies to a budget. | combat: `game/units/` | squad, control, feel, nav (per-faction gains, N6) |
| **L4 Vision-framed camera.** `RtsCamera.frame_vision(element)`, `Camera.max_zoom_in`, `Match.visible_region(team, units)`. Off-screen markers and alerts come from control. | control | — |
| **L5 Match mood.** `MatchMood.current() -> {intensity 0..1, state: "lull" \| "skirmish" \| "battle" \| "last_stand" \| "victory" \| "defeat", reasons[]}` from the K5 event stream. | feel: `game/audio/` | announcer, crowd, screens |

## Standing contracts (from rounds 2–3, still in force)

| Contract | Owner, where | Consumers |
|---|---|---|
| **K1 Orders API** (control). `UnitCommand` = `{"units": [names], "verb": "move" \| "attack" \| "attack_move" \| "follow" \| "hold" \| "stop", "to"?, "target"?, "queue": bool, "formation"?, "source"?: "player" \| "element" \| "", "facing"?: [x, z]}`. **The response guarantee is 100 ms of wall-clock time, not a tick count** — at 30 Hz that is exactly 3 ticks with nothing spare, so 30 Hz is the floor for the simulation rate. `Match.orders` holds `Orders`: `issue`, `current(unit)`, `queue(unit)`, `complete(unit)`, signal `order_changed(unit)`, plus `pace_factor` and `station` for group moves. | control: `game/control/` | nav (executes), squad (elements issue), combat, feel (markers) |
| **K2 Weapon events** (combat). `Weapons.PROFILES` fire model fields; `Match.weapon_fired(event)`, `Match.projectile_impact(event)` (faces, `weak_spot`, `suppression_applied`), `Match.incoming_projectiles(unit)`. | combat | squad (dodging, weak spots), feel (effects) |
| **K3 Locomotion** (combat). `locomotion` (`tracks` \| `wheels`), `min_turn_radius_m`, acceleration, braking, `lateral_grip`; `TankMotion.predict/state_for/step`. **`tank_motion.gd` moves to nav for round 6** (it is the plant the controller regulates); its data fields stay combat's. | combat (data) + nav (motion) | nav, control, squad |
| **K4 Faction art slots** (feel). `unit.<faction>.<role>.hull/turret/weapon`; `make vehicle-gallery FACTION=<id>`. | feel: `game/theme/factions/` | combat (rosters) |
| **K5 Match events for the announcer** (feel). JSON-line events from fixtures or `Match`; `element_formation` and `element_drill` carry the table's reason. | feel: `game/announcer/` | squad (publishes), combat (adapter) |
| **C1 Unit catalog v2.** `Units.PROFILES[id]` = `display_name`, `role`, `blurb`, `cost`, `unlock_tier`, `hull_size`, `max_health`, `max_shield`, `shield_recharge_delay`, `shield_recharge_rate`, `max_forward_speed`, `max_reverse_speed`, `hull_turn_rate_deg`, `sight_radius`, `weapon`, `mount`, `turret_turn_rate_deg`, `fire_arc_deg`, `muzzle_height`, optional `heat_capacity`/`heat_dissipation`, `good_vs`/`weak_vs`, `armor` `{front, side, rear}`, `locomotion`, `min_turn_radius_m`, optional `faction`. Weapons carry `penetration` and `splash_radius`. | combat: `game/units/units.gd`, `game/combat/weapons.gd` | all |
| **C2 Army JSON v2.** `{"name", "squads": [{"name", "formation"?, "directive"?, "units": [{"unit": id, "paint"?, "directive"?}]}]}`; ≤ 5 squads, ≤ 5 units per squad; cost ≤ the match budget. | combat + squad | garage (paused), skirmish, match runner |
| **C3 Match result for progression.** `Match.finished(result)` includes `winner`, `reason`, per-team `units_lost`/`units_left`, kills by unit type, `duration_seconds`, `budget`. | combat | control (results), progression (paused) |
| **C4 Combat queries for AI.** `Match.friendlies_in_line_of_fire(shooter, aim_point)`, `Arena.cover_features()`, `Tank.mount`/`fire_arc_deg`/`turret_turn_rate`/`muzzle_height`, `Tank.can_bear_on(point)`, `Arena.hazards()`, `Units.armor(unit, face)`, `Match.armor_multiplier(weapon, unit, face)`. | combat | squad, nav |
| **C5 Arena layouts.** `arenas/<name>.json` = `{name, half_size, obstacles: [{type, position, rotation_deg, size?}], spawns: {green, rust}, control_point?, hazards?}`, validated point-symmetric; `--arena=<name>`; obstacle `type` maps to visual slot `prop.<type>`; `arena.dressing.setup(layout)`. | arena | feel (props), squad (cover), nav (navigation), control (radar outline) |
| **C6 Visual slots**, including per-unit ids `unit.<id>.hull/turret/weapon`; `set_team_color`, `set_paint`, `set_shield`, `set_heat`, `set_firing`, `setup`. | feel: [slot_contracts.md](slot_contracts.md) | all |
| **C7 Command API.** `SquadCommand` `{squad, verb, to, facing, formation, commander}`; `Formations.offsets(formation, count)`; `TacticalMap.command_issued`, `squad_selected(squad_key)`; `RtsCamera.follow(target)` / `focus_on(point)` / `frame(points)`. | control, squad | agent bridge |
| **C8 Progression profile.** `user://profile.json`; `Progression.BUDGET_TIERS`; `Progression.award(report, team, tier)`. | paused | — |
| **HUD messages:** `Hud.post_message(text, severity)` → cyber banners | control posts; feel renders | everyone |
| **Visibility / radar data:** `VisibilityField`, `Match.is_visible_to`, `Match.intel`, `Radar.blips()`, slot `fx.fog_of_war` | combat (field), control (radar) | feel (skin) |
| **Launch flags and console markers** (`TANK_SQUAD_*`, `MATCH_RESULT`, `GARAGE_FIGHT`, …) | each mode's owner; list in `game/main.gd` header | smoke tests, `match_series.py` |

## Invariants every stream must keep

1. **`make remote T=check` passes before merging** (lint, tests, network + relay + lobby smoke, combat, match,
   determinism, sim baseline, garage smoke). Paused areas keep their tests green.
2. **The sim baseline** (`tests/baselines/sim_state_hash.txt`, one hash per glibc version; builder0 canonical) changes
   only on purpose, recorded with `make remote T=sim-baseline-record`, in the same commit as the reason.
   **Round 6: nav, squad and combat will move it** (movement and ranges are the simulation); control, arena and feel
   must not.
3. The web build still boots (`make remote T=web-smoke`) and the server still exports. Visual slots load headless.
4. Fairness: arena, spawn, or navigation changes re-run the swap-bases control ([verification.md](verification.md)).
5. Docs move with code: your brief's Status and any stale `_agents/` doc, in the same merge.
6. **Design follows [game_design.md](game_design.md)**; propose changes with evidence in your Status.
7. **Portable simulation code** (combat, nav, squad, control's order execution): [determinism.md](determinism.md)
   guidelines, and add new engine dependencies to its inventory. **Decisions must never read the wall clock** — a PID's
   `dt` is the fixed tick, not a frame delta.
8. **Heavy runs go to builder0** (`make remote T=…`, [remote_builds.md](remote_builds.md)); this laptop is for editing.
9. **Every number carries its commit, its machine, its workload and its sample size** (orchestration.md lesson 10).
   Nobody publishes a number measured across CP4.

## How to set up parallel copies: git worktrees, not folder copies

Copies drift and can't merge back cleanly. **Worktrees** are extra checkouts of the *same* repository, each on its own
branch. One command creates an isolated one:

```bash
cd ~/projects/godot                       # the main checkout, on main: the orchestrator's home
make worktree STREAM=nav     OFFSET=1     # → ../godot-nav on branch stream/nav
make worktree STREAM=squad   OFFSET=2
make worktree STREAM=control OFFSET=3
make worktree STREAM=arena   OFFSET=4
make worktree STREAM=combat  OFFSET=5
make worktree STREAM=feel    OFFSET=6
make worktrees                            # status of all of them
```

What `tools/worktree.sh` isolates:

| Shared resource | Collision risk | Isolation |
|---|---|---|
| Files and branch | agents overwrite each other | separate folder + `stream/<name>` branch |
| Network ports (servers, smoke tests, agent bridge) | two `make check`s fight over 9181/8061/8765 | `local.mk`: every port + `10 × OFFSET` |
| CPU (match series) | 6 agents × parallel matches thrash | `local.mk`: `JOBS := 2` |
| Godot `user://` (saves, logs) | garage saves / logs collide | `override.cfg`: `tank_squad_<stream>` user dir |
| `.godot/` import cache | a stale cache for another branch | per worktree (not shared) |
| `.tools/` Godot toolchain (300 MB) | none (read-only use) | shared by symlink |

## Running the agents

1. One terminal per stream: `cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`, then the `/goal`
   prompt from `HANDOFF.md` (the same text for every stream; the agent reads its stream from its folder).
2. Agents commit to their own branch as they go (they may `git push -u origin stream/<stream>` for backup).
3. **The orchestrator** reviews and integrates; after every merge, the other streams `git merge main`.
4. When a stream is finished: `make worktree-remove STREAM=<name>` (refuses with uncommitted work; keeps the branch).

**Git facts that bite with worktrees:**
- A branch can be checked out in only ONE worktree. Don't `git checkout main` inside a stream worktree.
- `git stash`, hooks, and `git config` are **shared** across worktrees. Prefer WIP commits on the stream branch.
- Deleting a worktree folder by hand leaves stale metadata; use `make worktree-remove` (or `git worktree prune`).
