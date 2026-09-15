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

**R9. Locomotion: wheels drive like cars** (added 2026-09-15 by the lead; [../game_design.md](../game_design.md)
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

## Portability (read [../determinism.md](../determinism.md))

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

- 2026-09-15: brief written for round 2. Nothing started.
