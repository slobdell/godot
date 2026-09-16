# Workstreams: the current round

> **Round 4, planned 2026-09-16.** How rounds work (roles, lifecycle, the worker contract, the kickoff prompt) is in
> [orchestration.md](orchestration.md): read it first. This file is round 4's streams, ownership, contracts, gates, and
> invariants. Rounds 1–3 are archived in `streams/archive/round1..3/`.

## Round 4 goal

**Doctrine, vision, and scale.** The lead played round 3 (*"this is for sure much better"*) and set the direction
([game_design.md](game_design.md) *Round 4 direction*): the camera frames only what your force can see, elements run
real battle drills chosen by their leader, suppression makes those drills bite, armies grow to ~30 a side with
faction-sized rosters, and the audio stops sounding like an Atari.

## Round 4 streams

| Stream | Brief | Outcome |
|---|---|---|
| **control** | [streams/control.md](streams/control.md) | The vision-constrained camera (as close as your force's sight allows), element focus with off-screen markers and alerts, command and readability at 30+ units a side |
| **doctrine** | [streams/doctrine.md](streams/doctrine.md) | Element leaders: movement formations and techniques, battle drills on contact, all from real doctrine, as data; the same library for the CPU and the player (L1) |
| **combat** | [streams/combat.md](streams/combat.md) | Suppression and effective fire (L2), heavies shielding fragile units, cost and effectiveness curves that produce faction-sized armies, faction rosters playable (L3) |
| **ai** | [streams/ai.md](streams/ai.md) | Brains that execute doctrine well, the CPU cost to run 30+ a side, and the tournament harness that measures which drills win (plus the groundwork for offline tactics discovery) |
| **audio** | [streams/audio.md](streams/audio.md) | Cinematic sound effects, the real ElevenLabs announcer run (repetition fixed first), the booth wired into live matches, and the dynamic music pipeline with per-state prompts |

**Paused:** netcode, army and progression (the garage loop), and new Meshy art (88 credits left: the lead tops up
before any new generation). Assets have no stream this round; `game/theme/**` changes are minimal and additive.

**Why this split:** the lead's asks divide cleanly by layer. Control owns what the player sees and does, doctrine owns
the commander layer between orders and brains, combat owns the rules that make formations pay, ai owns the units'
execution and the cost of running many of them, and audio is independent of all of it.

**Checkpoints** (the orchestrator merges early and tells everyone to `git merge main`):
- **CP1, doctrine's L1 element API** (doctrine X1): control and ai both build on it.
- **CP2, combat's L2 suppression fields and L3 roster schema** (combat X1): doctrine, ai, and audio read them.
Until a checkpoint lands, build against the contract with a stub in your own paths.

## Product constraints every stream designs for (the lead)

1. **Fun first, desktop first** (pillar 5): mouse and keyboard. Touch keeps compiling; no new touch work.
2. **Alive and responsive** (pillar 7): orders obey instantly; units move while fighting.
3. **No unearned god view** (round 4): the camera shows what the force can see.
4. **Parity:** anything the CPU can do tactically, the player's elements do automatically.
5. **The vibe** ([art_direction.md](art_direction.md)) and **die-hard, no pay-to-win** ([vision.md](vision.md)).
6. **Performance:** the target is ~30 units a side at 60 fps on this laptop's integrated GPU; measure before assuming.

## Lead gates this round

1. **Announcer generation is approved** (the lead, 2026-09-16: *"we can have an agent go ahead and run the full
   ElevenLabs pipeline"*). Fix the repetition first, run a small pilot, listen, then the full run; log every request and
   its credits. All three voices exist (`JR1`, `corporate2`, `veteran`).
2. **No new Meshy art** without the lead: 88 credits remain and a top-up is pending.
3. **Music tracks:** the lead generates them later in Suno. Build the pipeline and write the per-state prompts
   (`/tmp/music_prompt.md` has the style he already likes); ship with placeholders.
4. **Design pillars**, money, accounts, and anything destructive outside your worktree.

## Who owns what (round 4)

| Path | Owner |
|---|---|
| `game/control/` (selection, groups, the Orders API), `game/ui/` except `widgets/**` and `hud.tscn`, `game/camera/`, `game/controllers/`, `game/modes/{skirmish,offline}_mode.gd`, `mk/command.mk`, `_agents/tactical_map.md` | control |
| `game/tactics/` (new: elements, leaders, doctrine tables, drills), `doctrines/`, `game/ai/doctrine.gd`, `_agents/doctrine.md` (new), `mk/tactics.mk` (new) | doctrine |
| `game/units/`, `game/combat/` except `impact.gd`, `game/match/`, `game/tank/`, `game/arena/` + `arenas/`, `tools/{match_series,matchup_matrix,make_arenas,combat_duel,matchup_search}.py`, `mk/match.mk`, `game/modes/match_runner_mode.gd`, `_agents/balance.md` | combat |
| `game/ai/` except `doctrine.gd` (brains, perception, pathing, cover, fire lanes, matchups, CPU commander), `game/agent/`, `tools/agent.py`, `tools/ai_ladder.py`, `mk/ai.mk`, `tests/ai_scenarios/`, `_agents/{tank_brain,squad_ai_design,unit_ai}.md` | ai |
| `game/announcer/`, `game/audio/` (new: the music director and mixer), `assets/announcer/`, `assets/audio/`, `assets/music/` (new), `game/theme/audio/`, `tools/announcer/`, `tools/audio/` (new), `mk/announcer.mk`, `mk/audio.mk` (new), `tests/announcer/` | audio |
| `game/theme/**` models, props, effects (no stream this round): additive, minimal edits only, listed in merge notes | shared |
| `game/garage/`, `game/progression/`, `game/network/`, `server/`, net modes, `mk/{garage,net}.mk` | **paused**: minimal compatibility fixes only |
| `_agents/game_design.md`, `vision.md`, `roadmap.md`, `workstreams.md`, `orchestration.md`, `HANDOFF.md` | orchestrator (streams propose edits in their Status) |
| **Shared:** `project.godot`, `export_presets.cfg`, `game/main.gd`, `game/main.tscn`, `game/modes/game_mode.gd`, `Makefile`, `mk/core.mk`, `tests/run_tests.gd`, `tools/remote.sh`, `tools/slot.sh`, `CLAUDE.md` | nobody alone: minimal edits, listed in merge notes |

Tests: `test_control_*.gd`, `test_tactics_*.gd`, `test_combat_*.gd`, `test_ai_*.gd`, `test_announcer_*.gd`/`test_audio_*.gd`.

## New contracts (round 4)

| Contract | Owner, where | Consumers |
|---|---|---|
| **L1 Elements and doctrine** (CP1). An `Element` is a cluster of units with a leader: `Elements.form(units, name)`, `Elements.of(unit)`, `element.assign(task)` where a task is `{"verb": "move" \| "attack" \| "screen" \| "support_by_fire" \| "hold", "to"?, "target"?}`; the leader picks a **formation** (`column`, `wedge`, `line`, `echelon_left/right`, `herringbone`) and a **movement technique** (`traveling`, `traveling_overwatch`, `bounding_overwatch`) from doctrine data, and runs **battle drills** on triggers (`react_to_contact`, `near_ambush`, `far_ambush`, `break_contact`, `support_by_fire`, `assault_through`). It issues per-unit orders through control's K1 `Orders` (so brains obey one thing). Read-only for UI: `element.state() -> {formation, technique, drill, reason, slots}` and signal `element_changed(id)`. Doctrine data lives in `doctrines/doctrine_<name>.json` with a `faction` field. | doctrine: `game/tactics/` | control (HUD, task issuing), ai (brains execute; CPU commander assigns tasks), combat (none) |
| **L2 Suppression and effective fire** (CP2). `Tank.suppression` (0–1, decays), raised by near-misses and by rounds passing close; effects: accuracy penalty and a `pinned` state above a threshold. `Match.threat_field(team)` (a cheap grid of incoming-fire density) and `Match.is_beaten_zone(from, to)` for path and target scoring. `projectile_impact` and `weapon_fired` gain `suppression_applied`. | combat: `game/match/`, `game/combat/` | ai (avoid beaten zones, suppress on purpose), doctrine (support-by-fire drills), audio and feel (cues) |
| **L3 Faction rosters** (CP2). `Units.PROFILES` entries carry `faction` (`condemned` \| `gangs` \| `law` \| `syndicate`) and per-faction costs and stats; `Units.roster(faction)`; army JSON and the match runner take `--green-faction=` / `--rust-faction=`; `Army` builds faction armies to a budget. Art slots already exist (K4). | combat: `game/units/` | doctrine (per-faction doctrine ids), ai (matchups), control (faction pick in skirmish), audio (faction lines) |
| **L4 Vision-framed camera.** `RtsCamera.frame_vision(element)` and `Camera.max_zoom_in`; `Match.visible_region(team, units)` (what a set of units can currently see) provided by combat if it needs sim data, else computed by control from sight radii. Off-screen markers and alerts come from control. | control: `game/camera/`, `game/control/` | ai (none), audio (none) |
| **L5 Match mood.** One signal for the announcer, music, crowd and screens: `MatchMood.current() -> {intensity 0..1, state: "lull" \| "skirmish" \| "battle" \| "last_stand" \| "victory" \| "defeat", reasons[]}`, derived from the K5 event stream (contacts, kill rate, losses, control point). | audio: `game/audio/` | announcer (pacing), feel and assets later (crowd, screens) |

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
   d7967d8b36d4417b` is canonical on 2026-09-16; **combat, doctrine, and ai** may change it on purpose, control and
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
make worktree STREAM=control OFFSET=1    # → ../godot-control on branch stream/control
make worktree STREAM=doctrine OFFSET=2
make worktree STREAM=combat OFFSET=3
make worktree STREAM=ai OFFSET=4
make worktree STREAM=audio OFFSET=5
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

