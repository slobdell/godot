# Stream: rules (units, combat, match, arenas)

> Read [../game_design.md](../game_design.md), [../workstreams.md](../workstreams.md), and [../balance.md](../balance.md).
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
fire is off (teammates block shots but take no damage). Balance history: [../balance.md](../balance.md).

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
control for each ([../verification.md](../verification.md)).

**R7. The matchup matrix:** a tool (`tools/matchup_matrix.py` or an extension of match_series) that plays
cost-equal unit-vs-unit fights for every pair, both base sides, seeded. It writes a matrix into balance.md. Tune until
the intended counters hold clearly (e.g. the counter wins ≥ 65% cost-equal) and no unit is dominated
(each wins some matchup). Keep the tuning values data-driven.

**R8. Rules defaults with roster v2:** re-measure the control point ("coordination beats individuals" under
shields) and whether ammo resupply adds decisions; recommend defaults in balance.md for the lead.

- **Stretch:** the Burner (flamethrower unit); arena hazards (fire pits, crushing gates) as layout data; ammo
  simplification if R8 says so.

## How to verify

- `make check`, sim baseline updated on purpose.
- Unit tests for every mechanic (arc gating, tracking, penetration, friendly damage, symmetry validation).
- Match series with swap-bases control; the matchup matrix; `make skirmish` screenshots showing the new units.

## Don't touch

`game/ai/` brains and behavior (ai), the UI, camera, and skirmish mode (command), `game/theme/**` and art (art),
`game/garage/` beyond keeping its tests compiling during R1 (army).

## Status

- 2026-09-15: brief written for round 2. Nothing started.
- 2026-09-14 (agent start): oriented; baseline `make check` queued behind other streams.

- **R1 done (commit e8547aa): CHECKPOINT 1 READY for the orchestrator.** `make check` green (295 tests), sim
  baseline unchanged (`e5cf33921713b657`: tank stats are identical). Smoke: `cpu:balanced` vs `cpu:recon_strike` at
  1500 points plays a full 300 s match with all five unit types firing, no errors.

- **R2 (mechanics):** penetration vs per-unit armor thickness replaces per-weapon armor tables
  (`Armor.penetration_multiplier`: 0.5·log2(1.6·pen/armor), clamped 0.05–1.5; the cannon vs the tank reproduces
  round 1's 0.5/1/1.5 exactly); fixed mounts clamp the gun to ±`fire_arc_deg`/2 (`Tank.gun_yaw_toward`,
  `Tank.can_bear_on`); tank turret 110 → 50°/s; shells fly their weapon's range + 5 m; artillery rounds at a
  point no teammate sees scatter 3× (`Match.is_point_spotted`); Lancer beam 55 → 80 m. Tests:
  `tests/test_combat_mechanics.gd` (arc gating, tracking: the tank's gun falls >7.5° behind a scout crossing at
  10 m while the IFV stays within 3°, penetration, range, blind fire). Sim baseline → `a4106d15a8711f5c` (the
  slower tank turret). Two turret-hold tests moved to the IFV (they test the order layer, and the tank's turret
  is now slower than its hull on purpose).

### Plan (in order)
1. R1a `Units` v2 (fixed types, C1) + `Tank` reads it (mount, turret rate, muzzle height; no components).
2. R1b `Doctrine` v2 (C2: `units`, ≤ 5×5, v1 keys rejected), `Match.load_doctrine`/`spawn_tank(unit_id)`, migrate
   `doctrines/`, `Army` archetypes on the roster, garage kept compiling through an adapter at its doctrine
   boundary, tests updated, sim baseline re-recorded. **Checkpoint 1.**
3. R2 mechanics: fixed-mount arc gating, per-weapon shell speed/range, penetration vs armor, autocannon, artillery
   minimum range + team sight, Lancer shield stripping. Unit tests per mechanic.
4. R3 roster rows + `unit.<id>.*` slot fallbacks (slot_contracts.md).
5. R4 friendly fire + `friendlies_in_line_of_fire` (C4) + stats/announcer.
6. R5 25-unit spawn zones + C3 result fields.
7. R6 arenas as JSON (C5), `--arena`, `cover_features()`, second layout, swap-bases control.
8. R7 matchup matrix tool + tuning. 9. R8 control point / ammo re-measure. Then stretch.

### Decisions (with reasons)
- **Unit ids** `scout`, `tank`, `ifv`, `artillery`, `lancer`; old ids kept so saves, AI checks, and art slots keep
  meaning. **Weapon ids** kept (`cannon`, `laser`, `machine_gun`, `mortar`, `flamethrower`) plus `autocannon`.
- **Starters (unlock_tier 0):** scout, tank, IFV (the three the lead named); artillery and Lancer are tier 1.
  The army stream owns what a tier costs.
- **Army JSON v2 requires `unit` on every entry** (no silent "tank" default) and rejects `tanks`, `weapon`,
  `weapons`, `components` with a message naming the fix. Unknown extra keys (e.g. `note`) stay allowed.
- **Units carry `armor {front, side, rear}` thickness** (an addition to C1): penetration needs something to beat.
- **`muzzle_height` must stay ≥ 0.1 m below the shortest hull top** (a test enforces it): rounds fly flat.
- **Doctrine files keep their names** (`flame_rush.json` is now "Hunter Rush" with IFVs) because the garage lists
  them by file name; flamethrower doctrines became IFVs and laser doctrines became Lancers.
- **Garage kept working through an adapter** in `Loadout.from_doctrine/to_doctrine` (v2 at the file boundary,
  v1 `tanks` inside), `GarageCatalog.workhorse()` → tank, the turntable reads the unit's fixed weapon. Tests
  for removed features (mounting a weapon in the game catalog, flamer presets on the game catalog) were deleted;
  hand-made-catalog garage tests are untouched. The army stream owns the real rebuild.
- **Per-unit art slots** `unit.<id>.hull/turret/weapon` fall back to `tank.*` / `weapon.<id>` / `weapon.cannon`
  inside `Tank` (rules' path), so a theme without `weapon.autocannon` still draws something.

### Requests to other streams
- **ai:** (1) fixed-mount units (the scout) must aim with the hull. `OrderController` has a minimal rules hook that
  turns a *halted* fixed-mount unit onto its target (`order_controller.gd`, marked); the real behavior (strafing
  runs, turning while moving) is yours. Query `Tank.can_bear_on(point)`, `Tank.mount`, `Tank.fire_arc_deg`.
  (2) `tank_brain.gd`/`cpu_commander.gd` read `Units.PROFILES[...]["role"]` now (the brain's `me["class"]` key is
  unchanged, fed from `role`). (3) Intel contacts gain `unit` and `role`. (4) The tank's turret is 50°/s (the lead's
  "slow turret"): brains that expect a tank to track fast targets should turn the hull too. (5) `Units.armor(unit,
  face)` and `Match.armor_multiplier(weapon, unit, face)` tell a brain whether a shot is worth taking.
- **art:** new slot `weapon.autocannon` (IFV), per-unit slots `unit.<id>.hull/turret/weapon` (rows in
  slot_contracts.md). Until they exist the IFV draws `weapon.cannon` and the Lancer `weapon.laser`.
- **army:** the garage runs on catalog v2 through an adapter in `Loadout.from_doctrine/to_doctrine`; `Doctrine.MAX_SQUADS`
  is 5, `MAX_SQUAD_UNITS` 5, `MAX_UNITS` 25 (`MAX_TANKS` is gone). Unit cards: `display_name`, `blurb`, `cost`,
  `unlock_tier`, `role`, `good_vs`/`weak_vs`.
- **command:** `player_default.json` is now tank, tank, IFV (Alpha) + IFV, scout (Bravo), 810 points, still 5 units.

### Questions for the lead
- None blocking yet.
