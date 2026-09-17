# Workstreams: the current round

> **Round 5, planned 2026-09-17.** How rounds work (roles, lifecycle, the worker contract, the kickoff prompt) is in
> [orchestration.md](orchestration.md): read it first. This file is round 5's streams, ownership, contracts, gates and
> invariants. Rounds 1–4 are archived in `streams/archive/round1..4/`.

## Round 5 goal

**Make it playable.** The lead played round 4 and stopped at the frame rate, a camera that frames the enemy, a title
screen that won't click, one flat boring map, vehicles that read as blue lights, and two masses trading fire at long
range ([game_design.md](game_design.md) *Round 5 direction*). Faction art ships this round; the garage and progression
stay paused.

## Round 5 streams

| Stream | Brief | Outcome |
|---|---|---|
| **render** | [streams/render.md](streams/render.md) | 60 fps with 30 a side on the lead's laptop: fewer and better-motivated lights, the per-instance uniform limit gone, detail levels, vehicles that read as vehicles rather than glows, faction art shipping |
| **arena** | [streams/arena.md](streams/arena.md) | Maps as a discipline: several arenas with real tactical shape (lanes, chokepoints, sightline breaks, cover that matters), built from the arena kit that already exists (containers, ad screens, barricades, signs), fairness-validated |
| **control** | [streams/control.md](streams/control.md) | The shell works: the title screen accepts clicks, the camera frames *your* units, the console is clean, subtitles have their own line, the lead's three dials |
| **combat** | [streams/combat.md](streams/combat.md) | Engagement ranges that force maneuver instead of two masses at max range; the gangs' 23%; the duplicated Lancer; suppression follow-ups |
| **ai** | [streams/ai.md](streams/ai.md) | 4 ms per tick at 60 units, the SUPPRESS gate, a pinned enemy actually pulling units out of cover, the tactics ladder, faction behaviour |
| **audio** | [streams/audio.md](streams/audio.md) | Guns that sound dangerous (ElevenLabs sound effects under the transients), faction naming in the booth, music stems |

**Paused:** netcode, the garage and progression loop (the lead: stay on combat feel another round), new Meshy *models*
(88 credits; ElevenLabs has 125k for sound effects).

**Why this split:** the lead's blockers divide by discipline. Frame rate and the look are one problem (render), maps
are their own craft (arena, new this round), the shell bugs are control's, fight shape is combat's, brain cost is ai's,
and guns sounding right is audio's.

**Checkpoints:**
- **CP1, render's performance baseline and light budget** (render X1): every stream needs to know what a frame costs
  before changing it.
- **CP2, arena's layout schema v2** (arena X1): combat builds collision and navigation from it; render dresses it.

## Product constraints every stream designs for (the lead)

1. **60 fps with 30 a side on the lead's laptop** (Intel UHD 620, Compatibility renderer). Frame rate is the blocker
   this round; measure before and after anything you add.
2. **Vehicles read as vehicles**, not as glows. Neon is mood; the machine is the subject.
3. **Maps must give tactics something to work with**: lanes, cover, chokepoints, sightline breaks.
4. **Fun first, desktop first**; orders obey instantly; no unearned god view; CPU and player run the same doctrine.
5. **The vibe** ([art_direction.md](art_direction.md)) and **die-hard, no pay-to-win** ([vision.md](vision.md)).

## Lead gates this round

1. **ElevenLabs sound effects are approved** (125,297 credits left): pilot a few, listen, then the batch; ledger every
   request. The lead's standing note: cinematic exaggeration, and guns should sound dangerous.
2. **No new Meshy models** without the lead (88 credits). Placing and re-dressing existing art is free and expected.
3. **Faction art ships** (the lead, 2026-09-17): desktop presets include `game/theme/factions/*`; the web build stays
   lean, so keep it excluded there and say what the web player sees instead.
4. **Design pillars**, money, accounts, and anything destructive outside your worktree.

## Who owns what (round 5)

| Path | Owner |
|---|---|
| `game/theme/**` **except `game/theme/audio/`** (materials, shaders, effects, models, props, galleries; the crowd's MultiMesh and animation stay here, its voice does not), `assets/` art paths, `tools/assets/`, `mk/{fx,assets}.mk`, `export_presets.cfg` art filters, `_agents/{art_direction,slot_contracts}.md`, `_agents/streams/references/fx_tricks.md` | render |
| `game/arena/`, `arenas/`, `tools/make_arenas.py`, `mk/arena.mk` (new), `_agents/arenas.md` (new) | arena |
| `game/control/`, `game/ui/` (including `hud.tscn`, widgets and the title screen), `game/camera/`, `game/controllers/`, `game/modes/{skirmish,offline,title}_mode.gd`, `mk/command.mk`, `_agents/tactical_map.md` | control |
| `game/units/`, `game/combat/`, `game/match/`, `game/tank/`, `tools/{match_series,matchup_matrix,combat_duel,matchup_search}.py`, `mk/match.mk`, `game/modes/match_runner_mode.gd`, `_agents/balance.md` | combat |
| `game/ai/` except `doctrine.gd`, `game/tactics/` and `doctrines/` (doctrine had no stream this round: ai inherits it), `game/agent/`, `tools/{agent,ai_ladder}.py`, `mk/{ai,tactics}.mk`, `_agents/{tank_brain,squad_ai_design,unit_ai,doctrine}.md`, `tests/ai_scenarios/` | ai |
| `game/announcer/`, `game/audio/`, `game/theme/audio/` (`SfxSystem`, gunfire loops, `make_sfx.gd`; **plus `engine_system.gd` and the crowd's voice, moved here 2026-09-17**: anything that only makes sound belongs to audio), `assets/{announcer,audio,music}/`, `tools/{announcer,audio}/`, `mk/{announcer,audio}.mk`, `tests/announcer/` | audio |
| `game/garage/`, `game/progression/`, `game/network/`, `server/`, net modes, `mk/{garage,net}.mk` | **paused**: minimal compatibility fixes only |
| `_agents/game_design.md`, `vision.md`, `roadmap.md`, `workstreams.md`, `orchestration.md`, `backups.md`, `HANDOFF.md` | orchestrator |
| **Shared:** `project.godot`, `game/main.gd`, `game/main.tscn`, `game/modes/game_mode.gd`, `Makefile`, `mk/core.mk`, `tests/run_tests.gd`, `tools/{remote,slot,backup_assets}.sh`, `CLAUDE.md` | nobody alone: minimal edits, listed in merge notes |

## New contracts (round 5)

| Contract | Owner, where | Consumers |
|---|---|---|
| **M1 Performance budget** (CP1). `make perf-scene` reports frame time, draw calls, primitives and real-light count for a 30-a-side battle on this laptop's GPU class, and a written budget in `fx_tricks.md`: what a frame may spend, how many real lights exist at once, and what every stream must stay inside. Render owns the number; everyone else keeps to it. | render | all |
| **M2 Arena layout v2** (CP2). `arenas/<name>.json` grows the arena kit: `props` (`container_20`/`container_40` with `stack`, `ad_screen`, `barricade`, `sign`, `wreck`), lanes and cover annotations for the AI, and per-arena spawn zones sized for 30+ a side. Validated point-symmetric; `--arena=<name>`. Arena owns the data and the validator; combat builds collision and navigation; render dresses the props. | arena: `arenas/`, `game/arena/` | combat (collision, nav, spawns), render (props), ai (cover, lanes) |
| **M3 Team identity without glare.** Vehicles must read as vehicles at play distance: team accent is a *hint*, not the subject. Render owns the look (a smaller emissive area, a rim or trim, per-team paint), control keeps selection marks distinct from it, and both hold at 30 a side. | render + control | all |

## Round 4's contracts (still in force)

| Contract | Owner, where | Consumers |
|---|---|---|
| **L1 Elements and doctrine** (CP1). *Sharp edge (control, 2026-09-16): an element with no task still runs its SOP, so forming one before it has a task makes its leader fight the player for the wheel. Form lazily, on the first task.*  An `Element` is a cluster of units with a leader: `Elements.form(units, name)`, `Elements.of(unit)`, `element.assign(task)` where a task is `{"verb": "move" \| "attack" \| "screen" \| "support_by_fire" \| "hold", "to"?, "target"?}`; the leader picks a **formation** (`column`, `wedge`, `line`, `echelon_left/right`, `herringbone`) and a **movement technique** (`traveling`, `traveling_overwatch`, `bounding_overwatch`) from doctrine data, and runs **battle drills** on triggers (`react_to_contact`, `near_ambush`, `far_ambush`, `break_contact`, `support_by_fire`, `assault_through`). It issues per-unit orders through control's K1 `Orders` (so brains obey one thing). Read-only for UI: `element.state() -> {formation, technique, drill, reason, slots}` and signal `element_changed(id)`. Doctrine data lives in `doctrines/doctrine_<name>.json` with a `faction` field. | doctrine: `game/tactics/` | control (HUD, task issuing), ai (brains execute; CPU commander assigns tasks), combat (none) |
| **L2 Suppression and effective fire** (CP2). `Tank.suppression` (0–1, decays), raised by near-misses and by rounds passing close; effects: accuracy penalty and a `pinned` state above a threshold. `Match.threat_field(team)` (the fire coming at that team: `at`, `peak_along`, `mean_along`, `hot_cells`), `Match.is_beaten_zone(team, from, to)` (**team added at implementation**: a beaten zone needs to know whose fire), `Match.threat_along(team, from, to)`, `Match.shot_spread(weapon, moving, suppression)`, `Weapons.suppression(weapon)`, `Tank.suppression`/`is_pinned()`/`suppress()`. `projectile_impact` and `weapon_fired` gain `suppression_applied`. | combat: `game/match/`, `game/combat/` | ai (avoid beaten zones, suppress on purpose), doctrine (support-by-fire drills), audio and feel (cues) |
| **L3 Faction rosters** (CP2). `Units.PROFILES` entries carry `faction` (`condemned` \| `gangs` \| `law` \| `syndicate`) and per-faction costs and stats; `Units.roster(faction)`; army JSON and the match runner take `--green-faction=` / `--rust-faction=`; `Army` builds faction armies to a budget. Art slots already exist (K4). | combat: `game/units/` | doctrine (per-faction doctrine ids), ai (matchups), control (faction pick in skirmish), audio (faction lines) |
| **L4 Vision-framed camera.** `RtsCamera.frame_vision(element)` and `Camera.max_zoom_in`; `Match.visible_region(team, units)` (what a set of units can currently see) provided by combat if it needs sim data, else computed by control from sight radii. Off-screen markers and alerts come from control. | control: `game/camera/`, `game/control/` | ai (none), audio (none) |
| **L5 Match mood.** One signal for the announcer, music, crowd and screens: `MatchMood.current() -> {intensity 0..1, state: "lull" \| "skirmish" \| "battle" \| "last_stand" \| "victory" \| "defeat", reasons[]}`, derived from the K5 event stream (contacts, kill rate, losses, control point). | audio: `game/audio/` | announcer (pacing), feel and assets later (crowd, screens) |

## Standing contracts (from round 2, still in force)

| Contract | Owner, where | Consumers |
|---|---|---|
| **K1 Orders API** (round 3, control). `UnitCommand` = `{"units": [names], "verb": "move" \| "attack" \| "attack_move" \| "follow" \| "hold" \| "stop", "to"?, "target"?, "queue": bool, "formation"?, "source"?: "player" \| "element" \| "", "facing"?: [x, z]}` (`facing` added 2026-09-17 by control: `move`, `attack_move` and `hold` only, zero or NaN rejected; it lands on each unit's order as `order["facing"]` and becomes `Orders.station(unit)["heading"]` when the order completes, while the group still travels and lays out slots toward `to`) (`source` added 2026-09-16: the 3-tick response guarantee is about what the *player* asked for, so an element's own slot orders aren't timed against it). `Match.orders` holds `Orders`: `issue`, `current(unit)`, `queue(unit)`, `complete(unit)`, signal `order_changed(unit)`, plus `pace_factor` and `station` for group moves. | control: `game/control/` | ai (brains execute), doctrine (elements issue), combat (the field), feel (markers) |
| **K2 Weapon events** (round 3, combat). `Weapons.PROFILES` fire model fields; `Match.weapon_fired(event)` and `Match.projectile_impact(event)` (faces, `weak_spot`, `suppression_applied`), `Match.incoming_projectiles(unit)`. | combat: `game/combat/`, `game/match/` | ai (dodging, weak spots), feel and audio (effects) |
| **K3 Locomotion** (round 3, combat). `locomotion` (`tracks` \| `wheels`), `min_turn_radius_m`, acceleration, braking, `lateral_grip`; `TankMotion.predict/state_for/step`. | combat: `game/units/`, `game/tank/` | ai, control, doctrine (element movement) |
| **K4 Faction art slots** (round 3, assets). `unit.<faction>.<role>.hull/turret/weapon`; `make vehicle-gallery FACTION=<id>`. Gallery-only until factions play. | assets: `game/theme/factions/` | combat (rosters) |
| **K5 Match events for the announcer** (round 3, audio). JSON-line events from fixtures or `Match`; doctrine adds `element_formation` and `element_drill` carrying the table's reason. | audio: `game/announcer/`, `tools/announcer/` | doctrine (publishes), combat (adapter) |
| **C1 Unit catalog v2** (replaces v1 loadouts). `Units.PROFILES[id]` = `display_name`, `role` (`scout`/`tank`/`ifv`/`artillery`/`lancer`/`burner`, extensible), `blurb`, `cost`, `unlock_tier` (0 = starter), `hull_size` [w, h, l], `max_health`, `max_shield`, `shield_recharge_delay`, `shield_recharge_rate`, `max_forward_speed`, `max_reverse_speed`, `hull_turn_rate_deg`, `sight_radius`, `weapon` (a `Weapons.PROFILES` id), `mount` (`turret` or `fixed`), `turret_turn_rate_deg` (turret mounts), `fire_arc_deg` (fixed mounts), `muzzle_height`, optional `heat_capacity`/`heat_dissipation`, `good_vs`/`weak_vs` (role lists: design intent for AI hints and the army UI; mechanics decide real outcomes). Weapons gain `penetration` and `splash_radius`. No components, no hardpoints. `armor` `{front, side, rear}` thickness per unit (added by rules, round 2; damage through it follows `Armor.penetration_multiplier`). `locomotion` (`tracks` | `wheels`; `hover`, `articulated` reserved) and `min_turn_radius_m` for wheels (added 2026-09-15, rules R9). Optional `faction` (default `condemned`; added 2026-09-15 for future factions, rules adds it after checkpoint 1). | rules: `game/units/units.gd`, `game/combat/weapons.gd` | ai, army, art, command (unit cards, icons) |
| **C2 Army JSON v2** (doctrine files, garage saves): `{"name", "squads": [{"name", "formation"?, "directive"?, "units": [{"unit": id, "paint"?: "#rrggbb", "directive"?}]}]}`; ≤ 5 squads, ≤ 5 units per squad; cost ≤ the match budget. Rules migrates `doctrines/` and rejects v1 loadout keys with a clear error. | rules: `game/ai/doctrine.gd`, `game/units/` | army (produces), skirmish/match runner (load), ai (squads) |
| **C3 Match result for progression:** `Match.finished(result)` includes `winner`, `reason`, per-team `units_lost`/`units_left`, kills by unit type, `duration_seconds`, `budget`. | rules: `game/match/match.gd` | army (credits), command (results display) |
| **C4 Combat queries for AI:** (all new) `Match.friendlies_in_line_of_fire(shooter: Tank, aim_point: Vector3) -> Array` (direct fire, and splash for arcs), `Arena.cover_features() -> Array` of `{position, size, rotation, height, type}`, `Tank` exposes `mount`, `fire_arc_deg`, `turret_turn_rate`, `muzzle_height`; `Tank.can_bear_on(point)`, `Arena.hazards()`, `Units.armor(unit, face)`, `Match.armor_multiplier(weapon, unit, face)` (added round 2). | rules | ai |
| **C5 Arena layouts:** `arenas/<name>.json` = `{name, half_size, obstacles: [{type, position [x, z], rotation_deg, size?}], spawns: {green: [...], rust: [...]}, control_point?, hazards?}` (hazards: symmetric fire pits, round 2), validated point-symmetric; `--arena=<name>`. Obstacle `type` maps to visual slot `prop.<type>`; `arena.dressing` gets `setup(layout)` so stands and crowds fit the arena. | rules (data, collision, nav) | art (props, dressing), ai (cover), command (radar outline) |
| **C6 Visual slots**, including per-unit ids `unit.<id>.hull/turret/weapon` (fall back to `tank.*`/`weapon.*`), `set_team_color` = team accent, `set_paint` = cosmetic, `set_shield`, `set_heat`, `set_firing`, `setup` | rules + art: [slot_contracts.md](slot_contracts.md), `game/theme/game_theme.gd` | art fills; rules places |
| **C7 Command API:** `SquadCommand` `{squad, verb, to, facing, formation, commander}` (unchanged); `Formations.offsets(formation, count)` (exists) for icons (ai keeps it stable); `TacticalMap.command_issued` (exists) plus a new selection signal `squad_selected(squad_key)`; camera: `RtsCamera.follow(target)` / `focus_on(point)` (exist) plus a new `frame(points: Array)` | command (UI and camera), ai (squad and formations) | ai, army (squad names), agent bridge |
| **C8 Progression profile:** `user://profile.json` = `{schema, credits, unlocked_units [ids], budget_tier, wins, losses}` plus additive `draws`, `last_award`, `completed_challenges` (army, 2026-09-15); `Progression.BUDGET_TIERS` = `[{tier, budget, unlock_credits, name}]`; `Progression.award(report, team, tier) -> credits` (report = `MatchReport.build(result)`, C3 fields) | army: `game/progression/` | command (results screen shows credits), skirmish (budget) |
| **HUD messages:** `Hud.post_message(text, severity)` → cyber banners | command posts; art renders | everyone |
| **Visibility / radar data:** `VisibilityField`, `Match.is_visible_to`, `Match.intel`, `Radar.blips()`, `GameTheme.ui["radar_frame"]`, slot `fx.fog_of_war` (defined in round 1) | rules (field), command (radar) | art (skin) |
| **Launch flags and console markers** (`TANK_SQUAD_*`, `MATCH_RESULT`, `GARAGE_FIGHT`, …) | each mode's owner; list in `game/main.gd` header | smoke tests, match_series.py |

C7 (`SquadCommand`) remains for doctrines and the CPU commander; player control moves to K1.

## Invariants every stream must keep

1. **`make remote T=check` passes before merging** (lint, tests, network + relay + lobby smoke, combat, match,
   determinism, sim baseline, garage smoke). Paused areas keep their tests green.
2. **The sim baseline** (`tests/baselines/sim_state_hash.txt`: one hash per glibc version; builder0's `glibc-2.43
   7b1bb7c20063e5a0` is canonical on 2026-09-17 (combat's floating motion mode moved it); **combat, doctrine, and ai** may change it on purpose, control and
   audio must not) changes only on purpose (record with `make remote T=sim-baseline-record`,
   copy `build/sim_state_hash.txt` over the file, which drops other machines' stale lines), by **combat** and **ai** (and control if order execution changes a doctrine match), updated in the same
   commit with the reason. Feel, assets, and announcer never change it.
3. The web build still boots (`make remote T=web-smoke`) and the server still exports. Visual slots load headless.
4. Fairness: arena, spawn, or navigation changes re-run the swap-bases control (verification.md).
5. Docs move with code: your brief's Status and any stale `_agents/` doc, in the same merge.
6. **Design follows [game_design.md](game_design.md)**; propose changes with evidence in your Status.
7. **Portable simulation code** (combat, ai, control's order execution): [determinism.md](determinism.md) guidelines,
   and add new engine dependencies to its inventory.
8. **Heavy runs go to builder0** (`make remote T=…`, [remote_builds.md](remote_builds.md)); this laptop is for editing.

## How to set up parallel copies: git worktrees, not folder copies

Copies drift and can't merge back cleanly. **Worktrees** are extra checkouts of the *same*
repository, each on its own branch. One command creates an isolated one:

```bash
cd ~/projects/godot                       # the main checkout, on main: the orchestrator's home
make worktree STREAM=render OFFSET=1     # → ../godot-render on branch stream/render
make worktree STREAM=arena OFFSET=2
make worktree STREAM=control OFFSET=3
make worktree STREAM=combat OFFSET=4
make worktree STREAM=ai OFFSET=5
make worktree STREAM=audio OFFSET=6
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

1. One terminal per stream: `cd ~/projects/godot-<stream> && claude`, then the `/goal` prompt from `HANDOFF.md` (the same text for every stream; the agent reads its stream from its folder).
2. Agents commit to their own branch as they go (they may `git push -u origin stream/<stream>` for backup).
3. **The orchestrator** (a Claude session in the main checkout, or the lead) reviews and integrates:
   ```bash
   make worktrees                                   # who's dirty, who's ahead of main
   git log --oneline main..stream/rules          # what a stream did
   git diff main...stream/rules --stat           # what it touched: stay inside owned paths?
   (cd ../godot-rules && git merge main && make check)   # rebased branch must be green
   git merge --no-ff stream/rules                    # in the main checkout
   make check && git push
   ```
4. **After every merge, tell the other streams to `git merge main`** so conflicts surface early and small. (Prefer merge over rebase once a branch is pushed.)
5. When a stream is finished: `make worktree-remove STREAM=<name>` (refuses with uncommitted work; keeps the branch).

**Git facts that bite with worktrees:**
- A branch can be checked out in only ONE worktree. Don't `git checkout main` inside a stream worktree; the orchestrator's checkout owns `main`.
- `git stash`, hooks, and `git config` are **shared** across worktrees: a stash made in one shows up in all. Prefer WIP commits on the stream branch.
- Deleting a worktree folder by hand leaves stale metadata; use `make worktree-remove` (or `git worktree prune`).

