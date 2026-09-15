# Stream: rules (units, combat, match, arenas)

> **Archived 2026-09-15:** round 2 is merged into `main`. This brief and its Status are the record of what the stream did;
> the current round is in [../../../workstreams.md](../../../workstreams.md).

> Read [../game_design.md](../../../game_design.md), [../workstreams.md](../../../workstreams.md), and [../balance.md](../../../balance.md).
> You own `game/units/`, `game/combat/` (except `impact.gd`), `game/match/`, `game/tank/`, `game/arena/` +
> `arenas/` (new), `game/ai/doctrine.gd`, `doctrines/`, `tools/match_series.py`, `mk/match.mk`,
> `game/modes/match_runner_mode.gd`, `_agents/balance.md`. You and art share `_agents/slot_contracts.md`.

## The lead's decisions this stream implements (2026-09-15)

> *"Previously I talked about equipping different weapon systems on tanks, but that's too complicated. We'll
> instead draw inspiration from games like StarCraft where we just have simple units … The units themselves will
> be static throughout gameplay … The idea with different units is like rock-paper-scissors … the scout vehicles
> can have no turret, and they just have a machine gun that shoots straight forward, so they can only shoot at
> what they point at, unlike a tank. A tank turret moves slow so it would have a hard time tracking a scout. So
> we'd want some in between vehicle (think a Bradley or a Stryker) that has the equivalent of 30 mm cannons …
> the laser is awesome, but we'll just move that to a different unit type … Friendly fire should be allowed …
> a player can have up to some finite number of squads (say 5)."*

## Where things stand (round 1)

`Units.PROFILES` v1 has chassis `tank`/`scout`/`artillery` with hardpoints and `COMPONENTS`; `Tank.apply_loadout`
reads it; `Doctrine.parse` validates loadouts; `Army` builds seeded CPU armies; weapons are data (cannon, laser,
machine gun, mortar, flamethrower); shields, ammo, heat, control point, visibility field all exist. Friendly
fire is off (teammates block shots but take no damage). Balance history: [../balance.md](../../../balance.md).

## Backlog (in order; R1 is checkpoint 1: tell the orchestrator when it lands)

**R1. Catalog v2 and army JSON v2** (contracts C1, C2 in workstreams.md).
- Replace chassis + loadouts with fixed unit types: one weapon, `mount` (`turret`/`fixed`), per-unit turret
  turn rate, `muzzle_height`, `role`, `cost`, `unlock_tier`, `good_vs`/`weak_vs`. Remove `COMPONENTS`,
  hardpoints, `validate_loadout`, and heat except on units whose weapon uses it.
- Army JSON v2 (`units` lists in ≤ 5 squads of ≤ 5); migrate every file in `doctrines/`; reject v1 loadout keys
  with a clear error. Update `Army` archetypes (CPU armies) to the new roster.
- Keep `make check` green: update the tests that encoded loadouts (including the garage's, minimally, so the army
  stream can take over), and update the sim baseline with a reason.

**R2. Mechanics that make counters real** (no damage multiplier tables).
- **Fixed-mount weapons** fire only inside `fire_arc_deg` of the hull heading; the vehicle aims by turning.
- **Turret tracking:** turret turn rate vs the target's angular speed decides whether a turret can stay on target.
- **Penetration vs armor facing:** light guns barely scratch heavy frontal armor; everything hurts from behind.
- **Autocannon profile:** fast fire, low penetration, modest range.
- **Artillery:** splash radius, minimum range, needs team sight.
- **Lancer laser:** hitscan, heat-limited, strips shields.

**R3. The starting roster:** scout (fixed forward MG), tank (the dozer), IFV (30 mm, fast turret),
artillery, Lancer. Each unit gets placeholder visual slots `unit.<id>.hull/turret/weapon` that fall back to the
`tank.*` scenes (add the rows to slot_contracts.md). The flamethrower stays in `Weapons` as a future "Burner".

**R4. Friendly fire** (the lead: allowed). Shells, beams, and splash damage teammates. Track friendly damage in
match stats; post an announcer message. Provide `Match.friendlies_in_line_of_fire(shooter, aim_point)` (C4) for
the AI stream, with tests.

**R5. Squads and spawning:** up to 5 squads × 5 units; spawn zones that fit 25 units per side without overlap;
`Match.finished` result fields for progression (C3).

**R6. Arena layouts as data** (C5): extract today's arena into `arenas/<name>.json`, build collision and the
mirrored navmesh from it, validate point symmetry, add `--arena=<name>` and `Arena.cover_features()`. Author a
second layout with a different character (e.g. open lanes vs dense cover). Re-run the swap-bases fairness
control for each ([../verification.md](../../../verification.md)).

**R7. The matchup matrix:** a tool (`tools/matchup_matrix.py` or an extension of match_series) that plays
cost-equal unit-vs-unit fights for every pair, both base sides, seeded. It writes a matrix into balance.md. Tune until
the intended counters hold clearly (e.g. the counter wins ≥ 65% cost-equal) and no unit is dominated
(each wins some matchup). Keep the tuning values data-driven.

**R8. Rules defaults with roster v2:** re-measure the control point ("coordination beats individuals" under
shields) and whether ammo resupply adds decisions; recommend defaults in balance.md for the lead.

**R9. Locomotion: wheels drive like cars** (added 2026-09-15 by the lead; [../game_design.md](../../../game_design.md)
*Locomotion*). Today every unit rotates in place at `hull_turn_rate_deg`.
- Catalog: `locomotion` (`tracks` | `wheels`; `hover` and `articulated` reserved) and `min_turn_radius_m` for wheels
  (contract C1).
- A curvature-based kinematic model in `TankMotion` (pure, unit tested, dot/cross math per determinism.md): tracks
  keep today's behavior; wheels get no rotation at standstill, yaw rate from speed and radius, inverted steering in
  reverse.
- Proposed assignment: scout, IFV, artillery, Lancer on wheels; tank on tracks. Re-run the matchup matrix (R7) and
  record how turning radius changes the counters (the fixed-gun scout now aims by driving).
- Tell the ai stream in your Status: `Steering`, pathing, unstick, formations, and peek-and-shoot must handle wheels
  (their A8). Update the sim baseline with a reason.

- **Stretch:** the Burner (flamethrower unit); arena hazards (fire pits, crushing gates) as layout data; ammo
  simplification if R8 says so.

## Portability (read [../determinism.md](../../../determinism.md))

The simulation is deterministic within one build only; lockstep for ranked play needs it identical across builds,
so new mechanics are future porting work. Keep that work cheap:
- fire arcs, turret tracking, and armor facing with dot and cross products, not `atan2`/`angle_to`
- friendly fire as segment-vs-circle, splash as squared distance, cover features (C4) as segments and boxes
- arena layouts (C5) as simple shapes we own, so the integer core can load the same data
- one seam per engine query (line of sight, rays, paths)

Add any new engine dependency to the determinism.md inventory in the same commit.

## How to verify

- `make check`, sim baseline updated on purpose.
- Unit tests for every mechanic (arc gating, tracking, penetration, friendly damage, symmetry validation).
- Match series with swap-bases control; the matchup matrix; `make skirmish` screenshots showing the new units.

## Don't touch

`game/ai/` brains and behavior (ai), the UI, camera, and skirmish mode (command), `game/theme/**` and art (art),
`game/garage/` beyond keeping its tests compiling during R1 (army).

## Status

_Report for the lead and the orchestrator, 2026-09-14 (rules agent, first run). Branch `stream/rules`._

### Done (every item committed with `make check` green)

| Item | Commit | What it is | Measured |
|---|---|---|---|
| **R1** catalog v2 + army JSON v2 | e8547aa | `Units.PROFILES`: scout, tank, IFV, artillery, Lancer (C1); `Doctrine` v2 (`units`, ≤ 5 × 5, v1 keys rejected with a fix-it message, C2); every doctrine migrated; CPU archetypes on the roster; garage kept working through an adapter | **CHECKPOINT 1 READY.** Sim baseline unchanged |
| **R2** counters from mechanics | 0592458 | penetration vs per-unit armor thickness (no damage table); fixed-mount arcs (`Tank.can_bear_on`); tank turret 50°/s; per-weapon shell range; blind artillery scatters 3×; autocannon | tank's gun falls > 7.5° behind a scout crossing at 10 m, IFV stays within 3° |
| **R3** roster + art slots | (R1, R2) | `unit.<id>.hull/turret/weapon` with fallbacks in `Tank`; slot_contracts.md rows | skirmish screenshots, desktop + phone |
| **R4** friendly fire | 28c09cc | shells, beams, bursts, flames hurt teammates; stats; announcer; `Match.friendlies_in_line_of_fire` (C4) | brains: 0.25–0.4 friendly kills per 5v5 match; legacy bots ~2 per team |
| **R5** 25 units a side + C3 | a88db9e | 9 × 3 spawn grid; `units_lost/left`, `kills_by_unit`, `losses_by_unit`, `duration_seconds`, `budget`, `army_cost` in `Match.finished` | 5 × 5 per side spawns clear of each other and of cover |
| **R6** arenas as data (C5) | 6fb62db | `arenas/foundry.json` (round 1's map), `arenas/scrapyard.json` (dense cover); `Arena` validates symmetry, builds collision + mirrored navmesh, `cover_features()`, `--arena=` | fairness (brains, 60 matches each): foundry south 47%, scrapyard south 53% |
| **R7** matchup matrix | e9ac208 | `make matchups` (tools/matchup_matrix.py: `--tune --escort --focus --balance`); 9 tuning experiments | tank > IFV > Lancer > tank; IFV > scout; scout > artillery 92%; every unit wins a matchup (artillery with a spotter). Matrix in balance.md |
| **R8** rules defaults | dd03ca5 | control point re-measured; direct-fire guns unlimited (mortar keeps 24) | coordination 0/32 without control, 15/32 with it; unlimited ammo changed no outcome |
| Stretch: Burner, fire pits | 268b117 | `burner` unit (tier 2, flamethrower, archetype `brawl`); layout `hazards` (fire pits, symmetric, either team) and `arenas/furnace.json`; `Arena.hazards()`; `tools/make_arenas.py` | Burner beats IFV 67% / artillery 83%, loses to tank / Lancer |

Sim baseline history (each change on purpose): `e5cf33921713b657` → `a4106d15a8711f5c` (slow tank turret) →
`698d9058af076a38` (friendly fire) → `3fb60602d435d1c2` (spawn jitter).

### Decisions (with reasons)
- **Unit ids** `scout`, `tank`, `ifv`, `artillery`, `lancer` (+ `burner`); weapon ids kept (`cannon`, `laser`,
  `machine_gun`, `mortar`, `flamethrower`) plus `autocannon`, so saves, AI checks, and art slots keep meaning.
- **Starters (tier 0):** scout, tank, IFV (the three the lead named); artillery and Lancer tier 1; Burner tier 2.
  The army stream owns what a tier costs.
- **Army JSON v2 requires `unit` on every entry** (no silent default) and rejects `tanks`, `weapon`, `weapons`,
  `components` with a message naming the fix. Unknown extra keys (`note`) stay allowed.
- **Armor is per-unit thickness** `{front, side, rear}` (an addition to C1); damage through it is
  `clamp(0.5·log2(1.6·penetration/armor), 0.05, 1.5)`, chosen so the cannon vs the tank reproduces round 1's
  0.5/1/1.5 exactly (sim baseline unchanged by R2's armor change).
- **`muzzle_height` stays ≥ 0.1 m under the shortest hull top** (tested): rounds fly flat, so a taller muzzle
  would shoot over scouts.
- **Doctrine files keep their names** (`flame_rush.json` is "Hunter Rush", IFVs): the garage lists them by name.
- **Garage adapter, not a rewrite:** v2 at the file boundary (`Loadout.from_doctrine/to_doctrine`), `workhorse()` →
  tank; tests of removed features deleted; the army stream owns the rebuild.
- **Arena `half_size` stays 120** (radar, fog, perimeter are sized for it); obstacles and spawns are data.
- **Matchup verdicts:** elimination decides; a timeout goes to the side with more army value left. Artillery is
  also measured with a scout escort, since alone it is blind by design.
- **Ammo simplified** (the brief allowed it after R8): direct-fire guns never run out; the mortar keeps 24 rounds;
  base repair stays.
- **Fire pits aren't in a default layout:** the brains don't avoid them yet and they're invisible until art.

### Questions for the lead (answered 2026-09-14)
1. **Control point as the default rule?** The lead: *"sure, I agree with you."* Decided: default on. Skirmish
   (command) and game_design.md (orchestrator) should flip it; the match runner keeps `--control` for experiments.
2. **Finite ammo only on artillery?** The lead: *"yes that's ok for now."* Kept as applied.
3. **Scouts: fighters or spotters?** The lead: *"scouts should be spotters more than fighters, but there will be
   cases where its machine gun is useful."* Decided: spotting stays the scout's main job (the brain's standoff is
   right); the matrix bar no longer expects scouts to beat Lancers or tanks head-on. Their gun matters for
   opportunistic kills (exposed rears, artillery, finishing wrecked units). game_design.md's roster table should
   say so (orchestrator).

### Requests to other streams
- **ai:** (1) **scouts:** matchup targeting and fixed-mount strafing runs (turn the hull while moving;
  `Tank.can_bear_on`, `mount`, `fire_arc_deg`). A minimal rules hook in `order_controller.gd` (marked) only turns a
  *halted* fixed-mount unit onto its target. (2) Use `Match.friendlies_in_line_of_fire(shooter, aim_point)` before
  firing (friendly damage ~650 points per foundry match, ~1,200 on scrapyard). (3) `tank_brain.gd`/`cpu_commander.gd`
  read `role` now (`me["class"]` is fed from it); intel contacts carry `unit` and `role`. (4) The tank turret is
  50°/s on purpose: turn the hull to track fast targets. (5) `Units.armor(unit, face)` and
  `Match.armor_multiplier(weapon, unit, face)` say whether a shot is worth it. (6) `Arena.cover_features()` and
  `Arena.hazards()` for cover and routing. (7) Legacy `BotController` shoots through teammates. (8) Re-run
  `make matchups` after brain changes: the matrix is only as good as the brains.
- **art:** slots `weapon.autocannon`, `unit.<id>.hull/turret/weapon` (ids incl. `burner`), `prop.fire_pit`
  (`setup(hazard)`), and optional `arena.dressing.setup(layout)` (slot_contracts.md). Until then the IFV draws
  the cannon, the Lancer the laser, and fire pits are invisible.
- **army:** garage adapter as above; `Doctrine.MAX_SQUADS` 5, `MAX_SQUAD_UNITS` 5, `MAX_UNITS` 25; unit cards from
  `display_name`, `blurb`, `cost`, `unlock_tier`, `role`, `good_vs`/`weak_vs`; `Match.finished` C3 fields for
  credits. The CPU `armor` archetype beats `balanced` 26 : 6 (scouts and artillery don't fight): a preset note.
- **command:** `player_default.json` is tank, tank, IFV + IFV, scout (810 pts, 5 units). Skirmish should set
  `game_match.budget` (C3) and may pass `--arena`; the radar outline already reads layout obstacles.
- **orchestrator:** fold into workstreams.md contracts: C1 + `armor`, role `burner`; C4 + `Tank.can_bear_on`,
  `Arena.hazards()`; C5 + optional `hazards`. HANDOFF: new make targets `make matchups`; flag `--arena=`.

### Known issues
- Scouts beat nothing but artillery head-on; the lead wants them as spotters first, so that is acceptable. Samples are 12 per pair (±14 points).
- Networked clients build the default arena unless given `--arena` too (netcode paused).
- Background `make check` runs launched by an agent were killed three times by the session's memory guard while
  queued for a slot; detaching with `setsid nohup … &` and watching the log worked. (Proposed trip-up.)

### What to playtest
- `make skirmish ENEMY=cpu:balanced SEED=3`: the mixed roster (your squads: 2 tanks + IFV, IFV + scout).
- `make skirmish ENEMY=cpu:brawl CONTROL=1`: Burners rushing, with the control point on.
- Arenas (`make skirmish` has no arena knob yet; command owns it):
  `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . -- --skirmish --enemy=cpu:balanced --arena=scrapyard`
  (dense cover), or `--arena=furnace` (fire pits, invisible until art).
- Watch friendly fire: the HUD says "Friendly fire: Alpha 1 hit Alpha 2".

### Next steps
1. After checkpoint 1 merges and the ai stream's brains land: re-run `make matchups BALANCE=1` (judge scouts as spotters, per the lead).
2. Measure the Burner and furnace in CPU-army series once brains route around hazards.
3. Arena hazards beyond fire pits (the brief's crushing gates need moving collision and nav updates: not started).
