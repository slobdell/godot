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
| `game/ai/{pathing,steering,combat_motion,order_controller,order_feed}.gd`, new `game/ai/{avoidance,movement,pid,control_gains}.gd`, `game/tank/tank_motion.gd`, `mk/nav.mk` (new), `_agents/navigation.md` (new) — **one exception, granted 2026-09-18:** with no nav session running and two streams holding for CP4, combat made four surgical edits to `order_controller.gd` (an `engagement_lay` member, an `Engagement.is_seen` early-out in `_shootable`, an `envelope` term in the trigger line, and a seconds helper with `lose`/`forget`). Every rule lives in combat's `game/combat/engagement.gd`; the controller only holds state and calls it, and none of the edits touches a path, waypoint or throttle. nav reviews them when it starts and owns the file. The seam combat wants for the `gunnery.gd` split is written into [streams/nav.md](streams/nav.md). | **nav** |
| `game/tactics/**`, `game/ai/{formations,squad,squad_tactics,cpu_commander,tank_brain,directives,utility_curves,brain_variants,element_feed,matchups,difficulty,tactical_query,cover_map,fire_lanes,perception,suppression_feed,incoming_fire,ai_tick_cache,ai_explain_overlay}.gd` (**not** `doctrine.gd`: the army-JSON loader is combat's, C2), `doctrines/`, `game/agent/`, `tools/{agent,ai_ladder}.py`, `mk/{ai,tactics}.mk`, `tests/ai_scenarios/`, `_agents/{tank_brain,squad_ai_design,unit_ai,doctrine}.md` | **squad** |
| `game/control/`, `game/ui/` (HUD, widgets, title screen, loading screen), `game/camera/`, `game/controllers/`, `game/modes/{skirmish,offline,title}_mode.gd`, `mk/command.mk`, `_agents/tactical_map.md` — **one exception, granted 2026-09-18:** squad rewrites `game/control/group_formation.gd` into a thin adapter over N2's `TacticsFormation.slots()`, keeping its public API unchanged, because N2 cannot collapse three formation systems into one while one of them lives behind another stream's wall. control reviews that diff at merge and owns the file again afterwards. **Reviewed and cleared 2026-09-18:** control confirms the shim suits `Orders._resolve_group()` — pacing carried over exactly (`PACE_NEAR` 8 m, `PACE_FLOOR` 0.35, same formula) and seating through `TacticsFormation.place(..., {"policy": "front"})` keeping heavies forward with non-crossing seats; all 141 control formation/orders/group tests pass on the merged tree. No objection — the exception is discharged and the file is control's again. | **control** |
| `game/arena/`, `arenas/`, `tools/make_arenas.py`, `mk/arena.mk`, `_agents/arenas.md` | **arena** |
| `game/units/`, `game/combat/`, `game/match/`, `game/tank/` **except `tank_motion.gd`**, `tools/{match_series,matchup_matrix,combat_duel,matchup_search}.py`, `mk/match.mk`, `game/modes/match_runner_mode.gd`, `_agents/balance.md` | **combat** |
| `game/theme/**` (materials, shaders, effects, props, the crowd's MultiMesh **and its voice**), `game/audio/`, `game/announcer/`, `assets/{announcer,audio,music}/` and art paths, `tools/{assets,announcer,audio}/`, `mk/{fx,assets,announcer,audio}.mk`, `export_presets.cfg` art filters, `_agents/{art_direction,slot_contracts}.md` — **one exception, granted 2026-09-18:** arena edited four lines of `tools/announcer/test_arena_names.py` to skip layouts flagged `"fixture": true`, because its maze is a test fixture that must never get a spoken name (the booth should not name a map nobody plays) or a recorded clip (paid ElevenLabs time behind a lead gate), and it had turned `main`'s check red. feel reviews it at merge and owns the file. | **feel** |
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
| **N7 Objectives are the arena's, not a constant** (added 2026-09-18, arena proposing, combat scheduling). `Match` hard-codes `CONTROL_CENTER := Vector3.ZERO` and `CONTROL_RADIUS := 16.0`, and a layout's `control_point` reaches only the *dressing* — **an arena cannot move its own objective today; the field is decorative.** arena has landed its half: `arenas/` gains `objectives: [{name, position, radius}]` with `Arena.objectives_of()`, validated so off-centre objectives come in **mirrored pairs** (a lone one is owned by whichever base is nearer, preserving the fairness invariant), and a layout with no `objectives` list reports exactly the single central zone `Match` already hard-codes — asserted for every shipped layout. **combat's half is a pure read-through with no behaviour change on any existing arena:** read `Arena.objectives_of(Arena.active)` instead of the two constants, and hold a per-objective owner instead of one scalar. It is combat's to schedule; arena's X3 (objectives off the centre line) is blocked on it *and* on CP4. | arena: `arenas/`, `game/arena/` → combat: `game/match/` | squad (what to take), feel (dressing) |
| **N6 PID as the house control law.** `Pid` (a small, deterministic, tick-based regulator: gains, integral clamp, derivative on measurement, reset) used where there is a continuous error to regulate — slot station-keeping, speed matching, turret lay — and **not** where the problem is discrete choice. Gains live in **data**, per faction, so the lead's idea that factions differ by their gains is reachable: the Syndicate crisp, the gangs loose. Default gains ship stable first; per-faction gains are a stretch. | nav: `game/ai/{pid,control_gains}.gd` | squad (station-keeping), control (camera smoothing), feel (none) |

## Round 8 goal (2026-09-19): the owed algorithms, and the eight things he listed

**The lead: *"it still sucks"*, and *"my expectation was that you would have gotten all this working while I was away."***
**Round 7 merged seventeen branches and did not change his verdict.** Round 8 is the algorithm roster plus his eight
items, and **nothing else**. No instrument work that is not in service of one of them.

**Why the roster slipped, stated plainly so it is not repeated:** round 7 spent its capacity on *merging* and on
*instruments* — six measuring tools were found broken — and the owed algorithms were deferred as too large to land
alongside that. **That was defensible once. It is not defensible twice**, and the four missing algorithms map directly
onto his complaints:

| his complaint | the owed algorithm |
|---|---|
| *"the semi trucks are yawing in place"* | **angular acceleration limit** on the plant |
| trucks turn like tracked vehicles | **Reeds–Shepp** |
| *"stuck behind basic barriers… back and forth indefinitely"* | **flow fields** |
| long routes, repathing every second | **HPA\*** |

| Stream | Round 8 |
|---|---|
| **nav** | **The three motion algorithms, in this order: (1) angular-acceleration limit in `TankMotion.step_in_place` — and a wheeled hull must NOT rotate without translating, which is a class bug, not a semi bug; (2) Reeds–Shepp for car-like hulls; (3) FLOW FIELDS as its own checkpoint.** Flow fields are no longer deferrable — they are the named answer to his loudest complaint |
| **arena** | **A REPRO MAP for the barrier stall, in the configuration he plays.** nav measured blocked-by-terrain to zero in `nav-fight` while he watches it happen in `make skirmish` — **the instrument and the game disagree and the game is right.** Build the barrier that stalls units and make it a probe nav can run |
| **squad** | **Orphaned units: every unit belongs to a squad, and 1–4 selects all of them.** Then **an explicit attack order must override an existing target** — `test_a_move_order_beats_every_brain_state` has no attack sibling and needs one |
| **control** | **The selection side of the orphans**, and whatever makes an ignored order visible: if a unit cannot obey, the HUD must say so rather than leaving him to infer it |
| **feel** | **MAKE THE SEMI HUGE.** 3.14× satisfied the number he gave in round 6 and not the intent, and **he has removed balance as a constraint**. Then the articulated tractor/trailer, which he offered to shelve — **treat it as a stretch** |
| **combat** | **`hull_size` for the semi** (the catalog is combat's, and it is the collision box), and **the balance consequences of a huge semi, which he has explicitly deferred** — measure, do not tune |

**The standing rule for this round: every item is something he named. If a stream wants to do something he did not name,
it asks first.**

## New contracts (round 7)

| Contract | Owner, where | Consumers |
|---|---|---|
| **M4 Arena containment is a predicate, not a scalar** (added 2026-09-19; combat found it, arena owns it). `Arena.contains(point) -> bool` and `Arena.clamp_into(point) -> Vector3`, working for **every** shape including the existing square, so no caller knows what shape the arena is. **Why it exists:** `DRIVABLE_LIMIT` is used as a *square* clamp in six places — three `absf(x) > DRIVABLE_LIMIT or absf(z) > ...` checks in `arena.gd`'s validate, and `clampf` in `orders.gd`, `rts_controls.gd` and `army_layout.gd`. A regular hexagon of circumradius 139.7 m has an **inradius of 121.0**, so its boundary is 139.7 m toward a vertex and 121.0 m toward a flat edge, while **a square clamp at ±136 permits points 192 m from centre on the diagonal** — every one of those call sites would place an obstacle, clamp an order or lay out an army outside the playable arena, and `Arena.validate` would approve it. `DRIVABLE_LIMIT` survives only as the conservative **inscribed** bound: 121.0 − 4.0 clearance = **117**, which is barely different from today's 116. **⚠ Scaling it 116 → 136 in proportion with `ARENA_HALF_SIZE` makes the clamp about three times too permissive, not slightly.** `clamp_into` must document whether it returns the nearest boundary point or the ray-to-centre crossing — they differ sharply near a corner; nearest-boundary is what a player means by *"go as far that way as you can"*. The water and pit footprints belong behind the same predicate: a point inside a pit is not a point a player can be ordered into. | arena: `game/arena/` | **control** (`orders.gd` ✅, `rts_controls.gd` ✅ via `Orders.clamp_to_arena`: the shape inset by a 4 m hull clearance (exactly ±116 on the square), then `Arena.clamp_into` for water and pits; `radar.gd` has no clamp), **arena** (`validate`), **squad** (`army_layout.gd`, `agent_bridge.gd`), **combat** (`match.gd` constants, `visibility_field.gd` ✅, `match_runner_mode.gd` bench spread — still a square clamp, harmless today, **unmigrated**), nav |

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
2. **The sim baseline is recorded ONCE, by the orchestrator, on `main`, after the last simulation-changing merge of
   the round.** No stream records it — not even a stream entitled to move it. **Ruling made 2026-09-18** (combat
   proposed it; the round had three streams each about to record, and every per-stream hash was guaranteed stale):
   - **A per-stream hash is correct on a tree that will not exist by the time anything checks it.** With three
     streams moving the simulation, "whoever merges second re-records" is undefined — nobody can know at record time
     whether they are last.
   - **It fails safe.** A stale committed hash turns `sim-baseline` red on `main`, and *"the simulation broke"* and
     *"the hash is old"* look identical from the outside. That ambiguity cost round 5 a day.
   - **INERTNESS DOES NOT COMPOSE, and this is the deep reason the rule exists** (combat, 2026-09-19). *"'A is inert'
     and 'B is inert' does not give 'A+B is inert', because A can be inert only in the absence of B."* Three streams
     each measuring a green `sim-baseline` on their own branch **predicts nothing about `main` after merge** — each was
     measured against a different baseline, on a different tree, alone. **A hash that differs from what the branches
     implied is not evidence of a defect; it is the expected result of composing changes measured separately.** The
     orchestrator treated one such gap as an anomaly and sent a stream a message implying its correct claim was wrong.
   - **A change can be genuinely inert in BEHAVIOUR and not inert in the HASH.** arena's `_build_perimeter()` generates
     the arena wall from the shape polygon instead of using boxes authored in the scene: geometrically identical walls,
     **different collision bodies created in a different order, which is enough for Jolt.** Expect this from any change
     to how the physics world is *built*, even one that changes nothing about how it behaves.
   - **Nothing local can catch the mistake.** The file is keyed per glibc; the laptop is **2.39** and there is no
     2.39 line, so `sim-baseline` **silently skips locally** — every stream can commit a stale hash and watch a green
     local check.
   A stream whose change moves the simulation says so in its green report — *"the sim baseline moves and is
   deliberately NOT recorded here"* — and the orchestrator records it with `make remote T=sim-baseline-record`
   (twice, confirming it repeats) in a commit that names every change it covers.
   **AMENDED 2026-09-19, after the orchestrator read "after the last simulation-changing merge" as licence to defer
   to round close.** It does not mean that. It means *do not record repeatedly mid-round*, and it silently assumed
   merges arrive **batched at the end of a round**. In round 7 they trickled in across a long round, and the result was
   that **`main` sat red on `sim-baseline` for hours** — so every stream that merged `main` afterwards inherited a
   failure that had nothing to do with its work, could not tell whose it was, and had to ask.
   - **The orchestrator records the baseline in the same working session as any sim-changing merge to `main`** — not at
     round close. One record per *session of merging*, not one per round.
   - **A merge commit that moves the simulation says so in its subject or body.** Then a stream hitting a red
     `sim-baseline` runs `git log main --grep` and answers the question **without a round trip to the orchestrator**.
     Invariant 2 already asks streams to declare it in their green report; the merge commit needs the same declaration.
   - **The rule looked cheap because of a cost asymmetry** (combat's framing): *"the orchestrator who defers pays
     nothing, and the cost lands on every stream that merges `main` afterwards."* **A rule whose cost falls entirely on
     people who did not make the decision will always look cheaper than it is.**
   - **And a stream's red `sim-baseline` may be over-determined, so it is evidence of nothing.** combat's `d21a3d86`
     carried three of its own hash-moving changes (N7's per-objective owner, the designator's effect on *when* units
     fire, and `hull_size` as the collision box), so it would have failed *whether `main` were green or red*. **Only a
     check on `main` itself can establish `main`'s state.** Do not let a stream's failure stand in for that.
   **While the baseline is stale, THREE targets fail and two of them lie about why** (found by combat, 2026-09-18):
   `sim-baseline` says what is actually wrong, but `announcer-record-smoke` announces *"the booth changed the
   simulation"* and `music-smoke` announces *"the soundtrack changed the simulation"* — **both computing exactly the
   same hash `sim-baseline` computed, which is the proof they changed nothing.** They are feel's targets, so a feel
   agent would go hunting in audio code for a bug that does not exist. **If you see either of those messages, check
   whether the three hashes agree before believing the accusation.**
   **The root defect named (combat, 2026-09-19, after both targets PASSED on a current baseline): those two targets ask a
   DIFFERENTIAL question — "does the booth/soundtrack change the simulation?" — and implement it as an ABSOLUTE comparison
   against a shared file.** So they misfire **every time the baseline moves, i.e. once a round by design**, and they have
   been carried in feel's brief as broken for two rounds when nothing was ever wrong with the components. **The fix is to
   make the comparison differential too: run the match twice in one invocation, with and without the subsystem, and
   compare the two hashes to EACH OTHER.** A latent trap rather than a live failure — it blocks nothing. The underlying defect and its fix are in
   [orchestration.md](orchestration.md) lesson 65.
2b. **The old text, for the rules it still carries:** the baseline (`tests/baselines/sim_state_hash.txt`, one hash per glibc version; builder0 canonical) changes
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
