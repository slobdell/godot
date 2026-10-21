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

### REPORT (orders, round 37; updated 2026-10-21 ~09:25 PDT). Every number names its commit, machine, workload, n.
- **O1 the flicker: BUILT, bar recorded on main (441d8951d), pre-series check running.** Base rate (builder0 native,
  20005d611, orders-probe 12 cells x 3621-3626, 285 placed squads): 4 squads flip halt shape after the place window, 18
  flips, 50 reseats; centroid terrain changes 38 (shape flips + lanes <-> dense re-spacings: the deploy re-picks shape AND
  spacing from the situation's terrain every update); at the anchor 0. Fix `--halt-terrain=anchor` (eb102aada, default
  still centre). Lab `test_control_halt_terrain` (laptop GDScript: centre 2 flips, anchor 0). quick-remote eb102aada:
  builder0 120 passed / 0 failed, exited 0. Full check of f4365153f (builder0, native) running; the judged probe runs on
  that hash from a detached side worktree (`~/projects/godot-orders-o1`).
- **O2 parked squads: MEASURING.** Finding (laptop traces, locks 5 click s34): in the no-fight probe a parked crew's
  "ADVANCE" is a crew pushed off its seat by a friend's give-way, then walking back (an idle crew's ADVANCE objective IS
  its station). R37.6: the give-way half is manoeuvre's M5; orders keeps the idle-crew options. Probe `--probe-fight=on`
  (a real CPU army, 120 s after all are in) with `left_by` (option at the moment a crew with no order passes 6 m off its
  placed seat; GIVEWAY apart), `self_off_*`, `lost_after_placed`. builder0 sizing (light, 3 maps x 3 squads x 3621-3626)
  running; design note + grant request to follow.
- **O3 squads whole: BUILT OFF, bar recorded on main.** `--untangle=whole` (092cb34b7); `test_control_untangle_whole`;
  probe `friend_contacts` (physics hull touches). Judged probe after O1's (needs its own green check).
- **O4 away_m v a fixed seat: DONE (tooling).** `away_held_m` (goal unchanged) and `away_seat_m` (placed seat) beside
  away_m. On the base rows (20005d611, 285 squads): away 820.2 m, held 813.8 m, seat 2411.9 m; the flicker's share of
  away_m is small on these cells.
- **O5 CPU seats: MEASURING.** Grant moved (R37.5) to element_commander.gd's screen / support_by_fire point choice and
  `_plan_screen`. `make seat-yield-census` (4daa2d069): laptop locks s1828: 75 give-ways by crews holding CPU seats (67
  screen) to another element's crew, 0 deaths. builder0 sizing queued.
- **O6 cover seat: SEAM DONE, OFF** (`--cover-seat=on`, 5fbee5103): cover's real signature; null until cover's API is on
  main (cover: low cover is scarce on today's maps, so it will rarely fire).

### Bars (filed here; the orchestrator records them on main)
- **O1 HALT_TERRAIN=anchor (orders, C37.5; filed 2026-10-21 ~09:10 PDT before any arm number).** What he would see: a squad he
  has parked keeps one shape; no crew drives to a point ~15 m off and back while the squad sits. The fix: an ARRIVED element
  reads `ElementSituation.terrain_at` at its anchor (fixed), not its crews' centroid (`--halt-terrain=centre|anchor`; GDScript
  only, terrain_at has no native twin). **Base rate (sizing, seen; builder0 native, 20005d611, orders-probe 12 street cells x
  seeds 3621-3626, 285 placed squads):** 4 squads flip halt shape after the place window (18 flips, 50 reseats; locks 3 x 3,
  terminus 5 x 1), centroid terrain changes 38 (shape flips + lanes <-> dense re-spacings), anchor terrain changes 0. Lab:
  `test_control_halt_terrain` (locks, open spot 4 m off a lanes edge, the squad nudged across 6 times: centre 2 flips, anchor 0;
  laptop GDScript). **Judged probe:** `make native orders-probe`, arms `main:` v `anchor:--halt-terrain=anchor`, the 12 cells,
  FRESH seeds 3701-3712 (n 12 a cell), builder0, on a hash whose full check is green. **Counter:** base relays >= 10 (else
  "no workload") and the arms' rows differ somewhere. **Deciding:** `relays` (an update where the halt's shape or the terrain
  the element reads changed, after the place window, within one task) summed over all placed squads: arm <= 25 % of base, and
  shape flips arm <= 1. **Guards (each cell, medians as R36.6's):** all-in <= base x 1.2 + 3 s and no more never-in seeds;
  twitch worst <= base + 3 m; end foreign min >= base - 3 m; crossed (far bank) no higher; `test_control_scale`'s 3-tick
  response (in check). **CPU guard (the read is symmetric: CPU elements halt too):** `make native traffic-census`, its 3
  default cases x seeds 3701-3706 (18 CPU v CPU fights an arm), `TRAFFIC_FLAGS=--halt-terrain=anchor` v none: friendly
  contacts arm <= base x 1.1 + 5, stuck s arm <= base x 1.2 + 10, outcomes reported. **A pass ships ON** (default "anchor",
  `--halt-terrain=centre` keeps main's), sim-baseline maps that move attributed with the switch OFF.
  (Recorded on main 441d8951d by the orchestrator.)
- **O1 addendum (R37.9; filed 2026-10-21 before any judged O1 number): a SECOND deciding workload, the fight probe.**
  Sizing (seen; builder0 native light, 3e43c4a24, `--probe-fight=on --probe-budget=1500`, locks/crossing/terminus x 3
  squads x click x 3621-3626, 18 fights, 51 placed squads): 175 halt-shape flips, 446 re-lays, 27 squads re-laying.
  **Judged fight read:** arms `fight:--probe-fight=on,--probe-budget=1500` v `fightanchor:--probe-fight=on,--probe-budget=1500,
  --halt-terrain=anchor`, the same 9 cells, FRESH seeds 3731-3742 (36 fights an arm), builder0, on a green-checked hash
  that has the fight mode (>= 092cb34b7; f4365153f does not). **Deciding:** relays summed arm <= 25 % of base and shape
  flips arm <= 25 % of base. **Guards (fights are not deterministic across arms once seats differ: read as per-fight
  totals):** his kills a fight and his losses a fight each within base +/- 1.645 se (se from the base arm's per-fight sd,
  n 36), the CPU's losses likewise. The no-fight read (f4365153f, seeds 3701-3712, + the census) stands as filed. O1
  ships only when BOTH pass.
- **O2 PARKED_HOLD (orders, R37.9; filed 2026-10-21 before any arm number; code ef6b17ea9, OFF).** What he would see: a
  squad he parked stays where he put it and shoots from there; a crew that is pushed or pulls back drives all the way back
  onto its spot. The change (tank_brain.gd `_order_move`, his idle crews at their post only): a move of the crew's own
  option ending more than 4 m from its post is refused (it holds and faces the threat); RETREAT is kept (his question is
  open); a crew more than 3 m off its post with nothing else to do drives back onto it (1.5 m). **Sizing (seen; builder0
  native light, 3e43c4a24, the fight probe, 18 fights):** own-option leaves 34 (1.89 a fight). **Judged probe:** `make
  native orders-probe`, arms `fight:--probe-fight=on,--probe-budget=1500` v `parked:` the same + `--parked-hold=on`,
  locks/crossing/terminus x 3 squads x click, FRESH seeds 3743-3754 (36 fights an arm), builder0, on a green-checked
  hash. **Counter:** `parked_refused` > 0 on the arm. **Deciding:** own-option leaves (`left_by` minus GIVEWAY and MOVE,
  RETREAT kept in the count) a fight, arm <= 25 % of base (RETREAT stays allowed, so 10 % is not reachable if retreats
  are a fifth of today's leaves: 4 of 34). **Reported:** RETREAT leaves alone; survivors that left and are back within 3 m
  at the end. **Guards (per-fight totals):** his kills a fight and his losses a fight each within base +/- 1.645 se (se
  from the base arm's per-fight sd, n 36); the CPU's losses likewise. **A pass ships ON** (default on,
  `--parked-hold=off` keeps today's), his crews only.
- **O3 UNTANGLE_WHOLE (orders, C37.5; filed 2026-10-21 ~10:10 PDT before any O3 number; code 092cb34b7, OFF).** What he
  would see: squads he sends together arrive each with its own vehicles (no squad one vehicle short, no stranger in it),
  and they do not bump each other more than today. The change: where today's untangle re-deals vehicles between squads
  whose drives cross, the crossing squads swap whole PLACES (fewest crossing drive pairs, then least driving); each keeps
  its element. **Base rate (seen):** 25 of 287 squads had a crew re-dealt (builder0 native, 55c973cd4, round 36's 12 cells x
  3621-3626). **Judged probe:** `make native orders-probe`, arms `main:` v `whole:--untangle=whole`, the 12 cells, FRESH
  seeds 3713-3724 (n 12 a cell), builder0, on a hash whose full check is green. **Counter:** `swapped_whole` > 0 on the
  whole arm and the arms' rows differ. **Deciding:** squads arriving short (`redealt` > 0) summed: arm 0 and base >= 10
  (else "no workload"). **Guards (his priority, contention, at no-worse-than-today):** friendly contacts summed over all
  runs (`friend_contacts`, physics hull touches between his vehicles) arm <= base x 1.1 + 5, and the same for
  `friend_contacts_foreign` (different squads); per cell medians: all-in <= base x 1.2 + 3 s and no more never-in seeds,
  twitch worst <= base + 3 m, end foreign min >= base - 3 m, crossed (far bank) no higher; `whole_still_crossed` reported.
  `test_control_untangle*` and `test_control_scale` in check. **A pass ships ON** (default whole, `--untangle=deal` keeps
  today's); the player's path only (CPU elements are not untangled), so no CPU guard. If contacts fail, re-dealing stays
  (his answer).

### Plan (worker, 2026-10-21; start: main 9d325e291, green by the launch check named in HANDOFF)
1. O1: probe columns first (per squad after arrival: halt-shape flips, terrain flips of the crews' centroid, reseats),
   base rate on builder0 (native, light lane) over the 12 street cells x seeds 3621-3626 (already seen); then the fix.
   **Choice: read the terrain at the element's fixed ANCHOR once arrived** (not the moving centroid). Stateless (no new
   Element/Movement field, no native twin needed: terrain_at has none), and in player terms the shape belongs to the spot
   he parked it on. Latch and hysteresis kept as fallbacks if the anchor read still flips. Switch `--halt-terrain=centre`
   = main's rule. Bar filed before any arm number; fresh seeds for the judged read.
2. O2 parked ADVANCE (brains' engagement grant), 3. O3 squads whole, 4. O4 away_m v a fixed seat (tooling; may land with
   O1's columns since both are probe reads), 5. O5 CPU seats off paths, 6. O6 cover seat stub, 7. stretch.
