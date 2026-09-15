# Workstreams: the current round

> **Round 3, planned 2026-09-15.** How rounds work (roles, lifecycle, the worker contract, the kickoff prompt) is in
> [orchestration.md](orchestration.md): read it first. This file is round 3's streams, ownership, contracts, gates, and
> invariants. Rounds 1–2 are archived in `streams/archive/round1/` and `streams/archive/round2/`.

## Round 3 goal

**Make it fun.** The lead played the round-2 build: *"it's still currently boring and no fun to play … looking like a
military nerd game."* Round 3 rebuilds control (StarCraft-style, desktop first), makes combat feel alive
(arcade-tactical: moving while shooting, dodging, weak spots, devastating tank shells, 25 mm bursts, machine-gun
streams), gives hits real impact, and in parallel fills the arena kit, concepts the three new factions, sets up the
announcer's script engine, and moves builds to builder0. The lead's full verdict: [game_design.md](game_design.md)
*Round 3 direction*.

## Round 3 streams

| Stream | Brief | Outcome |
|---|---|---|
| **control** | [streams/control.md](streams/control.md) | StarCraft-style selection and orders (click, box, groups, right-click, attack-move, queue, follow), instant responsiveness, regrouping, automatic formations, selection panel and order feedback, desktop first |
| **combat** | [streams/combat.md](streams/combat.md) | Weapons rebuilt (tank shells, 25 mm bursts, MG streams), weak spots, arcade driving with momentum and turning circles, artillery deploy, control point default, matchup matrix re-run |
| **ai** | [streams/ai.md](streams/ai.md) | Units that feel alive: circle-strafing, dodging, flanking for weak spots, cover pops, range keeping, wheeled driving; a CPU opponent that maneuvers and uses formations; orders always win |
| **feel** | [streams/feel.md](streams/feel.md) | Impact: weapon and hit effects for the new weapons, camera shake, weak-spot hits, wrecks, weapon and engine sound, order and selection feedback visuals |
| **assets** | [streams/assets.md](streams/assets.md) | Arena kit (stackable 20/40 ft containers, giant ad screens), Meshy concepts and approved 3D for the road gangs, the Law, and the Syndicate, artillery outrigger parts |
| **announcer** | [streams/announcer.md](streams/announcer.md) | Match-event fixtures, the banter director, and transcripts for the lead to review; the ElevenLabs pipeline built and tested **without API calls** |

**Paused:** netcode (relay, lobby, replays, lockstep spike), army and progression (builder, unlocks, match loop), and
faction *gameplay* (factions get concept art only). No stream owns their paths this round; a stream that breaks one of
their tests fixes it minimally and says so in its merge notes.

**Why this split:** each of the lead's complaints is one independent problem with one owner: control (burdensome,
unresponsive), combat (weapons wrong, dead driving), ai (no intent), feel (no impact). Assets and the announcer are
independent of gameplay and keep paid generation behind lead gates. Remote builds were set up by the orchestrator
before launch ([remote_builds.md](remote_builds.md)).

**Checkpoints** (the orchestrator merges these early and tells every stream to `git merge main`):
- **CP1, control's K1 Orders API** (control X1): brains, combat, and feel need the order data and signals.
- **CP2, combat's K2 weapon events and K3 locomotion fields** (combat X1): ai and feel build against them.
Until a checkpoint lands, build against the contract with a stub in your own paths.

## Product constraints every stream designs for (the lead)

1. **Fun first, desktop first** (pillar 5): mouse and keyboard, StarCraft-style. Touch must keep compiling and its
   existing tests pass or be consciously retired with a note; no new touch-only work this round.
2. **Alive and responsive** (pillar 7): orders obey instantly; units move while fighting.
3. **The vibe:** over-the-top converted vehicles in a night gladiator arena ([art_direction.md](art_direction.md)).
4. **Die-hard, no pay-to-win** ([vision.md](vision.md)).
5. **Performance:** 60 fps on a laptop-class integrated GPU with 50 vehicles; the web build still boots.

## Lead gates this round

1. **Meshy concepts (assets):** every new model's concepts go on the tap-to-approve review page
   (`make art-review-page`, references/concept_review.md) before any image-to-3D. Batch reviews: roster options per
   faction on one page.
2. **Announcer text (announcer):** **no ElevenLabs calls this round**, not even a pilot. The lead reviews generated
   transcripts first (*"I'd prefer not to run the ingestion yet because I'll want to review what the generated text is
   for our potential conversations"*).
3. **Design pillars** and anything that spends money, creates accounts, or is destructive outside your worktree.

## Who owns what (round 3)

| Path | Owner |
|---|---|
| `game/control/` (new: selection, control groups, the Orders API, group moves, automatic formation slots, regrouping), `game/ui/` except `widgets/**` and `hud.tscn`, `game/camera/`, `game/controllers/`, `game/modes/{skirmish,offline}_mode.gd`, `mk/command.mk`, `_agents/tactical_map.md` (becomes the controls doc) | control |
| `game/units/`, `game/combat/` except `impact.gd`, `game/match/`, `game/tank/`, `game/arena/` + `arenas/`, `game/ai/doctrine.gd`, `doctrines/`, `tools/match_series.py`, `tools/matchup_matrix.py`, `tools/make_arenas.py`, `mk/match.mk`, `game/modes/match_runner_mode.gd`, `_agents/balance.md` | combat |
| `game/ai/` except `doctrine.gd` (brains, order execution inside brains, squads, formations geometry, perception, pathing, CPU commander, cover, fire lanes, matchups), `game/agent/`, `tools/agent.py`, `tools/ai_ladder.py`, `mk/ai.mk`, `tests/ai_scenarios/`, `_agents/{tank_brain,squad_ai_design,unit_ai}.md` | ai |
| `game/theme/fx/**`, `game/theme/audio/`, `assets/audio/`, `game/combat/impact.gd`, the weapon, shell, beam, and tracer effect scenes and scripts in `game/theme/cyberpunk/` (`fx_*`, `tracer_shell.gd`, `laser_beam.gd`), `game/ui/widgets/**`, `game/ui/hud.tscn`, `mk/fx.mk`, `_agents/streams/references/fx_tricks.md` | feel |
| Models, props, dressing, and galleries in `game/theme/**` not listed for feel (`roster/`, `arena_kit/`, `prison_dozer/`, `gallery/`, new `factions/`, cyberpunk vehicle and prop parts), `assets/**` except `assets/audio/` and `assets/announcer/`, `tools/assets/`, `mk/assets.mk`, `_agents/art_direction.md`, `_agents/streams/references/{asset_*,concept_review}.md` | assets |
| `game/announcer/`, `assets/announcer/`, `tools/announcer/`, `tests/announcer/`, `mk/announcer.mk` (all new) | announcer |
| `game/theme/game_theme.gd` (the slot table), `_agents/slot_contracts.md` | combat + feel + assets (additive edits only) |
| `game/network/`, `server/`, net modes, `tests/net/`, `mk/net.mk`; `game/garage/`, `game/progression/`, `game/modes/garage_mode.gd`, `mk/garage.mk` | **paused**: minimal compatibility fixes only |
| `_agents/game_design.md`, `vision.md`, `roadmap.md`, `workstreams.md`, `orchestration.md`, `HANDOFF.md` | orchestrator (streams propose edits in their Status) |
| **Shared:** `project.godot`, `export_presets.cfg`, `game/main.gd`, `game/main.tscn`, `game/modes/game_mode.gd`, `Makefile`, `mk/core.mk`, `tests/run_tests.gd`, `tools/remote.sh`, `tools/slot.sh`, `CLAUDE.md` | nobody alone: minimal edits, listed in merge notes |

Tests: `test_control_*.gd`, `test_combat_*.gd` (and existing rules tests), `test_ai_*.gd`, `test_fx_*.gd`,
`test_assets_*.gd`/`test_theme_*.gd`, `test_announcer_*.gd`.

## New contracts (round 3)

Changing one requires updating this section, and the owning stream announcing it in its Status.

| Contract | Owner, where | Consumers |
|---|---|---|
| **K1 Orders API** (CP1). `UnitCommand` data (serializable, for the CPU, the agent bridge, replays, and a future LLM): `{"units": [names], "verb": "move" \| "attack" \| "attack_move" \| "follow" \| "hold" \| "stop", "to"?: [x, z], "target"?: name, "queue": bool, "formation"?: "auto" \| name}`. `Orders` (one per match, reachable as `Match.orders`; combat adds that one field): `issue(command) -> String` (error or ""), `current(unit_name) -> Dictionary` (the active order with its formation slot offset and `issued_tick`), `queue(unit_name) -> Array`, signal `order_changed(unit_name)`, `complete(unit_name)`. **Response guarantee:** a brain receiving `order_changed` starts executing the new order within **3 ticks**, whatever it was doing; tests in both streams. `SquadCommand` (C7) stays for doctrines and the CPU until ai migrates them. | control: `game/control/orders.gd`, `unit_command.gd` | ai (brains execute orders), combat (`Match.orders` field), feel (order markers), announcer (later) |
| **K2 Weapon profile v3 and weapon events** (CP2). `Weapons.PROFILES[id]` adds `fire_model` (`shell` \| `burst` \| `stream` \| `beam` \| `arc`), `reload_s`, `burst_count`, `burst_interval_s`, `projectile_speed_mps` (0 = hitscan), `spread_deg`, `damage`, `penetration`, `splash_radius`. Signals on `Match`: `weapon_fired(event)` `{tick, shooter, weapon, fire_model, muzzle [x,y,z], direction [x,y,z], projectile_id}` and `projectile_impact(event)` `{tick, projectile_id, position, normal, target?, face?: "front"\|"side"\|"rear", weak_spot: bool, damage, killed: bool}`. `Match.incoming_projectiles(unit) -> Array` of `{position, velocity, eta_ticks, damage_estimate}` for dodging. | combat: `game/combat/weapons.gd`, `game/match/match.gd` | ai (range, dodging, weak spots), feel (effects and sound), announcer (events) |
| **K3 Locomotion** (CP2). Unit catalog adds `locomotion` (`tracks` \| `wheels`; `hover`, `articulated` reserved), `min_turn_radius_m`, `acceleration_mps2`, `braking_mps2`, `lateral_grip` (0–1, lower drifts); `TankMotion.predict(state, throttle, turn, ticks) -> Array` of poses (pure), so ai plans maneuvers and control previews paths. | combat: `game/units/units.gd`, `game/tank/tank_motion.gd` | ai, control, feel (tire and track effects) |
| **K4 Faction art slots.** Faction ids `condemned` (today's roster), `gangs`, `law`, `syndicate`; models fill `unit.<faction>.<role>.hull/turret/weapon` and show in `make vehicle-gallery FACTION=<id>`. Gallery only this round: no gameplay units. | assets: `game/theme/factions/` | combat (a later round) |
| **K5 Match events for the announcer** (C9 in streams/announcer.md): JSON lines, fixtures now; an adapter from K2 and `Match` signals later. | announcer | combat (adapter, later round) |

## Standing contracts (from round 2, still in force)

| Contract | Owner, where | Consumers |
|---|---|---|
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
   c9cfbb1a221f5c94` is canonical on 2026-09-15) changes only on purpose (record with `make remote T=sim-baseline-record`,
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
make worktree STREAM=control OFFSET=1    # → ../godot-control on branch stream/control
make worktree STREAM=combat OFFSET=2
make worktree STREAM=ai OFFSET=3
make worktree STREAM=feel OFFSET=4
make worktree STREAM=assets OFFSET=5
make worktree STREAM=announcer OFFSET=6
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

