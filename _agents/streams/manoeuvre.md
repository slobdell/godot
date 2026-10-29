# Stream: manoeuvre (a War Rig nose-on to a container backs out first, on the poses Bar B1 lost; then S v4 and holdway)

> Read `_agents/orchestration.md` (the worker contract; lesson 339), `_agents/judging.md`, `_agents/workstreams.md` **Round 45**
> (C45.1, C45.3-C45.6). Your last brief: `streams/archive/round44/manoeuvre.md` (Status: Bar B1's tables, the two losing patterns, the
> round-45 notes, the proof takes); R44.7, R44.19, R44.21, R44.24, R44.25 in `workstreams.md`. **You own:** movement's drive / unstick
> / side-step / avoidance / yield / backout (`game/ai/movement.gd` but the planner seam), `game/ai/traffic.gd`,
> `game/tactics/tactics_formation.gd`'s `pitch` / `hull_floor` / `offsets_at` / `fit_to_corridor` / seat bound / shape latch,
> `game/tactics/element_plan.gd`'s `grouped()` and converge, `tests/manoeuvre/**`, `tests/traffic/**`, `tests/test_manoeuvre*.gd`,
> `tests/test_traffic*.gd`, `tests/test_formation*.gd`, `mk/manoeuvre.mk`. **NOT** `game/tactics/element.gd` this round (engage's; ask
> through the orchestrator) nor `game/control/**` (orders). **Model:** Fable. **Machine:** builder0 light lane; builder2 for a bar
> series. **Seeds:** 11149-11196 (Bar B2), 11401-11448 (Bar S v4), 11449-11496 (reserve, A6 v4).

## The lead's direction (2026-10-28, verbatim; still open)

"The tanks start behind a shipping container. One of the tanks moved forward right away only to get stuck right away before
recognizing it needed to back up. In that case it should have been obvious to the tank that they should have backed up first to create
clearance."

His round-44 playtest (Gorge) did not repeat the container, but the bar is "units must look smart" (memory) and lesson 339 applies:
backout has failed one bar (B1) with every guard green. Ship it ON this round if B2 passes.

## Where things stand (main at launch: 972e4bb57, code a93271a66 GREEN builder0 3446/0, see HANDOFF)

- **Backout** (`--traffic-on=backout`, with parkedpass), OFF; C++ twin r3 EQUAL (R44.24). Bar B1 (R44.25, frozen 9111520bf,
  11101-11148): D1 his start PASS (Guns_2 reverses t4 v t44); D2 corpus FAIL 71 % v 80 % (21 base-stuck poses); every guard PASS.
  Losing poses: **13** (crossing, alone, +55 deg, nose 0.0 m: `looks 0`, the look never fires, arms identical) and the **crossing
  crawl 10 / 6** (+50 / +60 deg, a squadmate crawling ahead: the back-up lands, then a second k-turn, +1.7 to +5.3 s).
- **S v3** (seat bound + converge + kturngoal + parkaside, scoped to a squad's own order) FAILED its wedged guard (R44.7). **A6 v3
  holdway** FAILED its head-on guard (R44.19). All OFF.
- Evidence: `_agents/streams/references/round44/manoeuvre/`, `~/overnight-manoeuvre/r44/` on the laptop.

## Backlog (in order)

1. **M1 pose 13: why the look never fires.** `--turn-trace` on the dev pose: which gate (steering point within a hull's length,
   |speed| < circle speed, the window) refuses; fix on the dev pose only; tests first.
2. **M2 the crossing crawl (poses 10 / 6).** The back-up then a second k-turn: the departure vertex it backs out against is not the
   vertex the drive then wants. Back out against the vertex the drive will take (or re-read it after the back-up); dev poses only.
3. **M3 native twin** of M1 + M2 (message the orchestrator; native cuts it, C45.4), proved EQUAL + the default orders probe 60/60.
4. **M4 Bar B2**, filed BEFORE any number on 11149-11196: B1's shape (it was sound: floor met, guards green), D2's 80 % line
   unchanged; add orders' G2 places and engage's authority probe as guards (C45.3). Ships ON with `--traffic-on=backout` the default
   and `--traffic-off=backout` the escape the minute it passes; message the orchestrator the green hash.
5. **M5 S v4** on 11401-11448: S v3's wedged guard failure traced by removal first; file before numbers.
6. **M6 A6 v4 holdway** with a one-sided head-on guard (the round-44 note), reserve block.
7. **Stretch:** backout on grouped squads (after orders' G2 lands; C45.3); the two-squad press design note (archived Status).

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>`); `make manoeuvre-start-trace`; `make replay-match RECORDING=...` on
his round-43 container recordings (`references/round43/playtest/2026-10-28T08-15-42-locks.jsonl`); the B1 judge; before/after shots
of each pose, looked at. Every number with its commit and machine.

## Don't touch

`game/control/**` (orders), `game/tactics/element.gd`, `drills.gd` and element_plan's engagement functions (engage), `native/**`, the
planner (trace lines only), `game/camera/**`, `game/match/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing at launch.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Session start 2026-10-29 ~09:50 PDT (Fable, `godot-manoeuvre-68`). Starting commit 8d59b2bdf = main at launch (code a93271a66 GREEN
builder0 3446/0; no baseline check re-run, per the contract). Orchestrator session: `godot-b8`. builder0 has NO godot-manoeuvre folder
(a cold import on the first remote run: watched); builder2 (up at launch) has `godot-manoeuvre` + `-light` warm.**

### Plan (smallest foundation first; the brief's order kept)

1. **M1** pose 13: trace the look's gates on the dev pose (local GDScript drive, `NOSED_POSES=13 NOSED_TRACE=on`, new dev-only env
   switches in the corpus test); fix on the dev pose; audit every dev pose's staging the same way.
2. **M2** the crossing crawl (poses 10 / 6): trace the second k-turn ON; back out against the vertex the drive then takes.
3. **M3** native twin request to the orchestrator (C45.4) the hour M1 + M2 are committed; EQUAL + the default orders probe 60/60.
4. **M4** Bar B2 FILED before any number on 11149-11196 (B1's shape; orders' G2 places and engage's authority probe as guards, C45.3);
   gate check on the frozen tree; series on builder2.
5. **M5** S v4 (11401-11448): S v3's wedged guard traced by removal first. **M6** A6 v4 (reserve). Stretch: backout on grouped squads.

### M1 (2026-10-29 ~10:40 PDT): pose 13 never looked because it stood INSIDE A BUILDING; six of the 14 poses were mis-staged

- **Cause (laptop, GDScript drive, 8d59b2bdf + the test's new `NOSED_POSES=13 NOSED_TRACE=on` dev switches):** pose 13's rig spot
  (24.9, 21.2) lies inside the Crossing's 40 m city block at (34, 33) (x 14-54, z 13-53): 11.18 m off the navmesh, nose 6.13 m off,
  the route's first point 15.8 m away (the look's "steering point within a hull's length" gate refuses), pinned by the building
  (`touch true` from tick 3, `speed()` climbing to 11.9 m/s while it stood). Not a container pose at all.
- **The audit of all 14 dev poses** (`NOSED_SETUP` rows: the spot's and nose's distance to the mesh, the route's first points; then
  `tests/manoeuvre/stage_check.py`, a hexagon / water / prop-overlap checker): **5 / 6** (Locks (-120, 16)): the hexagon wall 0.7 m
  behind the tail ("circle plan refused: blocked behind at 0.5 m" in every look; pose 6's squadmates outside the arena); **7**
  (Crossing (0, 40) crawl): the rear squadmates on the container at (8, 64); **11 / 12** (Crossing (30, 4) side -1): in the far water
  channel, 11.08 m off the mesh; **13** as above. So **10 of Bar B1's 21 "base-stuck" poses (13 x3, 5 x4, 6 x3) could not be won by any
  back-up**, and B1's 71 % was read on a corpus where a third of the deciding poses were impossible.
- **The crawl shape overstated his deploy:** all four squadmates were staged as 14 m War Rigs, which puts a squadmate's nose 1.0 m off
  the lead rig's tail; his deploy had Guns_4 (Gun Truck, 3.44 m) and Guns_5 (Tanker, 6.58 m) there, gaps 6.3 / 4.7 m. Pose 10 ON
  (crawl +50): the look fired at tick 1, the circle plan said back 5.5 m, the rig backed 0.5 m onto the squadmate and stood until
  the leg's timeout (~5 s; `MANOEUVRE_TRACE leg ... backed 0.51 ... real 0.00` from f 3850 to f 3980+): that is B1's "back-up then a
  second k-turn" on 10 / 6 (+1.7 to +5.3 s).
- **Two rule defects under it, fixed behind `--traffic-on=backout` (OFF byte for byte):** (a) the look's "2 m clear behind" and the
  plan's hull test used `Manoeuvre._hull_hit`'s centre disc (half this hull's length beyond the half-widths): it sees a hull beside,
  never a 14 m hull straight behind until the centres are ~7 m apart, so a nose 1 m off the tail read clear. Now
  `Movement._departure_hull_hit` tests ORIENTED BOXES (`_box_gap`, the separating-axis gap, hit when within HULL_MARGIN_M and
  nearer than the start pose). (b) a departure leg that does not move its way (real motion < 0.1 m/s while asked for >= 0.3 m/s)
  for 0.5 s ends as `stalled` (counter `backout_stalls`, new per-crew `_backout_stall_ticks`: an exec field for native's twin)
  instead of standing to its timeout. (b) touches the leg driver native runs in C++: M3.
- **The corpus re-staged (test only):** poses 5 -> Locks (24, 80) alone -40; 6 -> Locks (24, 80) crawl +60; 7 -> Crossing (42, 80)
  crawl +45; 11 / 12 -> Crossing (58, 60) alone -45 / crawl -30; 13 -> Crossing (92, 50) alone +35 (+55 put the order in the water);
  the crawl squadmates' hulls = his deploy; `ON_MESH_M` assertion (every rig of a pose within 0.5 m of the mesh) in `_run`;
  `NOSED_SETUP_ONLY=on` prints the geometry of all 14 in 75 s (laptop). All 14: spot 0.00 m off the mesh, nose 0.28-0.56 m
  into the box's clearance band. **Bar B2 names this corpus change in its filing (C45.1: the deciding workload changed before any
  B2 number; B1's floor / lines unchanged).**
- Stretch note from engage via the orchestrator (R45.2): a one-crew squad's swarm / coil slot sits ~5 m off his click
  (`tactics_formation.offsets_at`); after M4, not before.

### Dev reads of the re-staged corpus with the fixes (builder2 light, `godot-manoeuvre-light`, GDScript drive, `NOSED_TRACE=on`; never a bar)

- **Dev read 1 (uncommitted tree = 8d59b2bdf + the fixes, box margin 1.0 m, ~17:25 builder2 clock):** `make remote` (REMOTE_HOST
  builder2, light) `test FILTER=test_manoeuvre_ NOSED_CORPUS=on NOSED_GDSCRIPT=on NATIVE=off`: **78 passed / 0 failed**, no SCRIPT
  ERROR (every test_manoeuvre_* file + the corpus). His start (the lab stage, GDScript drive): OFF forward t12 / reverse t46 / crept
  0.62 m / past the box t144; **ON reverse t4 / crept 0.0 / past the box t97** (round 44: t99-102). The 14 dev poses (unjittered):
  base-stuck 3 (poses 5, 8, 10), ON sooner in 3 / 3 (-3.0, -3.9, -3.9 s; pose 10 = the crossing crawl B1 lost: clear t360 -> t243,
  reverse t49 -> t4, no stall); the other 11: median +0.03 s, worst **+3.4 s on pose 7** (FAILS the +3 s ceiling). Read of pose 7 ON:
  (i) the look fired on TICK 1, before the element's order had reached the crew, against the mover's stale `_goal` (0, -90) (the lab's
  standing default), planned a 2.5 m back + 1 m forward fill toward it, and the leg ran to its end under the real order; (ii) the
  single search had refused 1.5 m back for the squadmate 1.7 m beside (the 1.0 m box margin: the tail swings 0.85 m at 1.5 m back),
  and the back-and-fill fallback then planned 2.5 m of it (the fill's steps did not test the departure hulls). Poses 0 / 10 / 12 also
  read "blocked behind at 1.5 m (hull)" from the squadmate beside. **Changed (dev read 2 running):** `_backout_final_goal` reads a
  brain's order only (no `_goal` stand-in); the fill's steps test `_departure_hull_hit`; the box margin is `BACKOUT_HULL_GAP_M` 0.5 m
  (half a metre of air between footprints; 1.0 was the disc's allowance).

- **Dev read 2 (the three refinements; builder2 light ~17:55):** 78 / 0 again; his start ON reverse t4 / past the box **t93** (OFF t144).
  Pose 10 (the crossing crawl B1 lost): **clear t360 -> t95 (-8.8 s)**, no stall needed (the box test saw the squadmate, the circle
  plan backed 1.5 m, away 2.5 m). Base-stuck 3 / 3 sooner (median -3.9 s). Cost ceiling still FAILS on **pose 7 (+3.4 s)**, pose 0
  +1.6 s: the trace shows the brief's M2 hypothesis exactly: the look aligned the rig toward its OWN route's first vertex (east round
  the box, err -38) while the squad's STATION then rode the element's transit route round the box's WEST end (steer (29, 74), err
  +52), so a second k-turn followed. **Changed (dev read 3 running):** `_backout_departure` reads the element's transit route
  (`Element.transit["route"]` from the anchor's `s` on; the first point a hull's length from the crew) when the squad is in transit;
  a crew without one (alone, or arrived) reads its own path as before. GDScript only (the look is a callback from the C++ drive).

- **Dev read 3 (builder2 light ~18:20; = commit 0af772a85):** 78 / 0; his start ON reverse t4 / past the box **t98** (OFF t144). The
  14 dev poses: base-stuck 3 (5, 8, 10), **ON sooner in 3 / 3 (-3.0, -3.9, -8.8 s)**; the other 11: **worst +1.5 s (pose 11), median
  -0.07 s: the cost ceiling PASSES**; pose 7 -0.1 s (the look now reads the squad's route west, err +66, the single search is blocked
  by the squadmate beside at 2.0 m, no plan: the base's own drive, t99 v t101); pose 0 +0.2 s; stalls 0 everywhere (the box test
  refuses before a leg can stall). Unjittered dev poses, GDScript drive: a read, not a number; Bar B2 decides on 11149-11196.
- **Committed: 0af772a85** (code, tests, the B2 filing). `make quick-remote` (REMOTE_HOST builder2, QUICK_BASE 8d59b2bdf) running; the
  native twin tests in it read against builder2's round-44 library (UNEQUAL expected until M3). Twin spec sent to the orchestrator.

- **Guard poses dev read (0af772a85, builder2 light ~18:40, `NOSED_GUARD=on`, GDScript drive):** the six round-44 stagings kept verbatim:
  every pose ok (ON v OFF clear +0.0 / +0.3 / -0.6 / +0.0 / +0.0 / +0.0 s; wall ticks +1 / -36 / +11 / 0 / +4 / 0; looks fire on four
  of them, no plan survives the hull / navmesh tests, stalls 0): **G PASS 6 / 6** on the dev poses (D3's line: <= +1.0 s, <= +15 ticks).

### M5 (S v4): S v3's wedged guard traced by removal (builder2 heavy folder, 0af772a85, round-44 library, Locks 7001-7012, 12 paired runs an arm)

- **Removal read 1** (`~/overnight-manoeuvre/r45/s4/removal1/`, `make manoeuvre-bar-s`, each round-43 rule ALONE v base `--shape-latch=off`):
  | arm | D1 seated within the bound by 15 s | yield+blocked s a run | k-turn s a run | **wedged s a run** |
  |---|---|---|---|---|
  | latch (`--shape-latch=on`) | 53 -> 40 (-2.9 se) | +0.2 (+0.5 se) | +0.0 | -0.3 (se 0.55) |
  | bound (`--seat-bound=on`) | **53 -> 83 (+4.4 se)** | +1.6 (+0.6 se) | **-5.4 (-2.8 se)** | **+5.6 (se 2.38, +2.4 se)** |
  | converge (`--converge-on-crew=on`) | 53 -> 52 | +0.1 | +0.1 | +0.5 (se 0.41) |
  | kturngoal (`--traffic-on=kturngoal`) | 53 -> 45 (-2.2 se) | +3.5 (+1.8 se) | +0.3 | **+4.3 (se 1.99, +2.1 se)** |
  | parkaside (`--traffic-on=parkaside`) | 53 -> 54 | -0.5 | +0.2 | +0.9 (se 0.70) |
  **Read:** the wedging S v3 failed on (Locks +9.2 s a run) is the BOUND's press (+5.6) plus KTURNGOAL (+4.3), near-additive; the latch
  costs D1 alone; converge and parkaside are neutral here. The bound is the only rule that delivers his settle (D1). S v4's shape:
  the bound WITHOUT kturngoal, with the press fix (round 44's `--seat-order=on`, seats dealt in arrival order) read next.

- **Removal read 2** (`removal2/`, the bound with the press fix / latch / converge; same cells, 488a10f8d = 0af772a85's code):
  | arm | D1 seated by 15 s | k-turn s a run | never-arrived (pooled) | **wedged s a run** |
  |---|---|---|---|---|
  | bound | 53 -> 83 (+4.4 se) | -5.4 | 13 -> 17 | +5.6 (se 2.4) |
  | bound + seat-order | 53 -> 83 (+3.5 se) | -3.7 | 13 -> 16 | **+3.5 (se 2.0, +1.7 se)** |
  | bound + seat-order + latch | 53 -> 83 (+4.2 se) | -3.4 | 13 -> 20 | +3.1 (se 2.1) |
  | bound + latch | 53 -> 82 (+3.8 se) | -5.1 | 13 -> 14 | +6.5 (se 2.4) |
  | bound + converge | **53 -> 91 (+5.1 se)** | -4.9 | 13 -> 13 | +5.2 (se 2.1) |
  | bound + seat-order + converge | 53 -> 78 (+3.4 se) | -2.2 | 13 -> 19 | +6.7 (se 2.7) |
  **Read:** seat-order takes ~2 s a run off the bound's press but does not remove it (+3.5 s, +1.7 se on 12 dev runs: a fresh 24-seed
  block could read either side of the +2 se guard); the latch and converge add nothing the bar needs. **Decision for S v4:** ONE
  arm = `--seat-bound=on --seat-order=on` (latch off, no kturngoal, no converge, no parkaside), filed with the wedged guard as S v3's
  (ARM <= BASE + 2 se per arena) and the risk named; if it fails, the press needs the second shape (a squadmate's give-way deferred
  until the seat ahead is taken), not another switch mix. Filed after B2's freeze (same tree).

Decisions so far: dev reads run on the laptop's GDScript drive under `flock /tmp/tank-squad-laptop-godot.lock` (one pose pair ~1 min;
nothing of the lead's runs while he is away); every judged number comes from a builder.

