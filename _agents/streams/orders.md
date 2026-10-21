# Stream: orders (squads look smart and under his control: no flicker, parked squads stay put, squads arrive whole)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 37** (C37.1, C37.4,
> C37.5) and in *Round 36*: R36.11, R36.24, R36.26 and the O2/O4 rulings. Then your round-36 brief
> `streams/archive/round36/orders.md` (its Status is the close-out) and `game_design.md` *Round 36: his answer on parked squads*,
> *Round 36: his answer on mixed squads, and the bar behind every movement change*. **You own:** `game/control/**`,
> `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`; in `game/tactics/element_plan.gd` the
> deploy-step and halt-lay functions; `game/tactics/deploy_passers.gd`. **Grants (C37.5), one guarded seam each, merge note:**
> `ElementSituation.terrain_at` and the halt-shape choice (O1); the ADVANCE from a parked seat in brains' engagement code (O2);
> `cpu_commander.gd`'s screen / support_by_fire seat placement (O5).
> **Model:** FABLE (the lingering "looks dumb" problems). **Machine:** builder0 (C37.1); light runs on either builder.

## The lead's direction (verbatim in game_design.md)

**"the feel of the game needs to have the user perceive that the units are smart and under their control"**; he recalls a scathing
RTS review because the units seemed dumb. **"the general priority is to mitigate vehicle contention with one another."** Parked
squads: **"Stay put and shoot"** (he decides when it moves; if it ever moves to fight, it drives all the way back). Mixed squads:
every vehicle with its own squad, PROVIDED contention is not worse. Packing: keep 9 m between squads.

What he will notice: a squad he has just parked stops switching between two shapes (a crew driving to a point ~15 m off and back);
a squad he parked fights from where it stands; squads he sends together arrive with their own vehicles; CPU squads set up off the
streets other squads use.

## Where things stand

- **The flicker (R36.24, traced R36.26):** the halt shape flips herringbone <-> coil on `ElementSituation.terrain_at(center)` of the
  crews' centroid at a 45 m radius with no hysteresis; as crews move the centroid moves and the shape flips, re-seating the crews.
  Fix options: latch the shape per arrival, read terrain at the anchor (the click), or hysteresis. Size the flicker's base rate first.
- **away_m** (orders' metric) counts goal flips; it should be read against a fixed seat (R36.24).
- **Parked ADVANCE:** 16 of 55 twitchy squads (round 36's probe) were a parked crew advancing to fight (orders' "neither"
  ENGAGEMENT kind).
- **CPU seats (R36.11):** 9 of 11 jam:yielding-to-another-squad deaths were at CPU screen / support_by_fire seats placed on others' paths.
- Tooling on main: the herringbone lab (`make herringbone-lab`), the orders probe and its shots.

## Backlog (in order)

1. **O1 the flicker.** Base rate first (how many arrived squads flip shape, how often, on the probe's cells); then the fix behind a
   switch, a deterministic lab case (a squad straddling a terrain edge), a bar (deciding: flips per arrival; guards: all-in time,
   friendly contacts, far bank, `test_control_scale`'s 3-tick response). Symmetric: a pass ships ON.
2. **O2 parked squads stay put and shoot.** The parked crew fires from its seat; if a rule ever moves it, it returns all the way.
   Bar: advances from parked seats (deciding), kills/deaths of parked squads (guard: not worse beyond noise).
3. **O3 squads arrive whole.** Every vehicle with its own squad unless contention worsens: bar with contention (friendly contacts,
   crossings, all-in time) as the guard at no-worse-than-today, squads arriving short as the deciding line.
4. **O4 away_m against a fixed seat** (tooling; re-read round 36's numbers with it).
5. **O5 CPU seats off paths** (the grant): a seat on another element's route moves aside; bar from R36.11's deaths.
6. **O6 the cover seat call (C37.4)** once cover's `low_cover_seat` is on main: called once when laying a halt seat, behind its own
   switch; until then a stub.
7. **Stretch:** a click right at a bridge mouth seating a crew past the deck; `uncross_paths` on a queued screen.

## How to verify

Tests and lab cases first; `make quick-remote`; one full check per named hash; `make orders-probe-shots` LOOKED at for every cell you
change; series on fresh seeds; every number with commit, machine, workload, n. Smoke like a player: `make skirmish ARENA=locks`,
three squads to one point, then two more down the same street; park a squad and let the CPU come to it. Write in every bar "what he
would see".

## Don't touch

Manoeuvre's paths (movement.gd's drive / traffic blocks), rules' and cover's paths, brains' paths beyond your grants, `native/**`,
`tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Plan (worker, 2026-10-21; start: main 9d325e291, green by the launch check named in HANDOFF)
1. O1: probe columns first (per squad after arrival: halt-shape flips, terrain flips of the crews' centroid, reseats),
   base rate on builder0 (native, light lane) over the 12 street cells x seeds 3621-3626 (already seen); then the fix.
   **Choice: read the terrain at the element's fixed ANCHOR once arrived** (not the moving centroid). Stateless (no new
   Element/Movement field, no native twin needed: terrain_at has none), and in player terms the shape belongs to the spot
   he parked it on. Latch and hysteresis kept as fallbacks if the anchor read still flips. Switch `--halt-terrain=centre`
   = main's rule. Bar filed before any arm number; fresh seeds for the judged read.
2. O2 parked ADVANCE (brains' engagement grant), 3. O3 squads whole, 4. O4 away_m v a fixed seat (tooling; may land with
   O1's columns since both are probe reads), 5. O5 CPU seats off paths, 6. O6 cover seat stub, 7. stretch.
