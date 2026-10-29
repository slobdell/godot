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

### WHERE IT STANDS (2026-10-29 ~13:00 PDT; updated as the bars land)

- **Tip: stream/manoeuvre bdcfb6dcc** (code **dab58b334**; docs after). **Nothing ships ON yet**: backout stays `DEFAULT_OFF`; **Bar B2 FAILS AS FILED** (D1 PASS, D2's deciding line PASS 11 / 11,
  its cost ceiling broken by ONE pose of 48: seed 11187 +6.3 s; the Terminus k-turn guard +2.6 se); the 11187 fix is on the branch
  (0a80c3685, OFF code) but the Terminus excess is not its shape, so **B2b is not filed this round (R45.12)**. **M1 + M2 done** (the corpus re-staged, two rule defects fixed, the look follows the squad's route, the stalled leg); **M3
  done** (native's twin `pair/native-backout-b2v2` 04ce3abe9 EQUAL); **M4 Bar B2 FILED** (R45.4 / R45.8 amendments), frozen at
  `wip/manoeuvre-b2-freeze` **0493977ed** (= stream ce52cba1c + the pair) in `../godot-manoeuvre-b2` and `../godot-manoeuvre-b2x`;
  its full check on builder2 is GREEN (3448 / 0, exited 0, 4 perf / load lines NOT JUDGED; the first attempt died with builder2's 12:51
  preemption, no number seen) and **the series is running since 13:34 PDT**. **M5 Bar S v4 FILED** (the bound + seat-order, 11401-11448), **M6 Bar A6 v4 FILED** (holdway,
  one-sided guard, 11449-11496): both ride B2's frozen tree, queued behind B2's series. Drivers: `~/overnight-manoeuvre/r45/bars_b2_a.sh`
  (builder0 light legs, from b2x), `bars_b2_b.sh` (builder2 legs, from b2), `bars_b2_judge.sh`, `bars_s4.sh`, `bars_a6v4.sh`.
- **Checks:** dab58b334's lab tests 3 / 0 (builder2 heavy folder, library present); 57e02fed5 quick-remote 37 / 1 (the 1 = the stage on
  the folder's OLD library, fixed by dab58b334); 0af772a85 alone builder0 3445 / 1 (native's exec-field table wants the twin: by design,
  the OFF code ships with the twin); 27f00d3f0 (the v1 freeze) builder2 3446 / 1 (native's v1 stage, superseded).
- **What he would notice if B2 passes and backout ships ON:** a War Rig nose-on to a container backs out first and swings the way its
  squad is going (his start: reversing at tick 4, past the box at tick 98 v 144 today); a rig whose back-up is pressed on a squadmate
  gives up within a second instead of standing 4-5 s. **To playtest (after the merge):** `make skirmish` Locks seed 56416 as the
  Gangs, click west from the start; the shots pair `make manoeuvre-start-shots SS_FLAGS=--traffic-on=backout` v none.
- **Merge notes (shared files):** `Makefile` LIGHT_GOALS += `gcp-remote gcp-status gcp-start gcp-stop` (one line; round 45: `make
  gcp-remote` took a laptop heavy slot and queued 20+ min behind two other streams' local lints while `make remote` is light; the
  gcp goals are ssh / gcloud calls, no CPU). Nothing else outside the stream's paths.
- **Questions for the lead:** none blocking. **Requests to other streams:** native (done: the twin); orders / engage: none.
- **Known issues / next:** S v4's wedged guard is the likely miss (+1.7 se on dev; the squad's LAST crew carries the press: the next
  shape is that crew's seat); the one-crew swarm / coil slot ~5 m off his click (engage's relay, R45.2) is a stretch after M4; a
  tick-1 look against a stale `_goal` is closed (brain-order-only final goal).

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

### M3 / M4: the twin and the freeze candidate (2026-10-29 ~11:15 PDT)

- **Native's twin: `pair/native-backout-b2` b2b129f9f** (= 0af772a85 + the C++ stalled leg + `_backout_stall_ticks` + a staged test
  `tests/test_native_drive_backout_stall.gd`); its builder2 native-proof and the default orders probe run on native's side (the
  orchestrator relays the verdict). **main 47a15f434 merged** (native's cold-import watchdog, tools only; the conflict in
  workstreams.md resolved to main's recorded copies of B2 / A6 v4): 79710edca.
- **Freeze candidate: `wip/manoeuvre-b2-freeze` 27f00d3f0** in `../godot-manoeuvre-b2` = stream/manoeuvre 89ff738b9 + the pair. Its gate
  check runs on builder2 (`~/overnight-manoeuvre/r45/check_b2/check-27f00d3f0.log`; a fresh builder2 folder: the watchdog's first
  real cold import). B2's series launches on it once native's verdict reads EQUAL + 60/60 AND the check is green; a different twin
  hash re-cuts the freeze. The check of 0af772a85 alone (dormant-code merge candidate) runs on builder0
  (`~/overnight-manoeuvre/r45/check_0af772a85/check.log`; perf REFUSED by load there: NOT JUDGED).

- **Checks read (~11:45 PDT):** (a) **0af772a85 alone on builder0: 3445 / 1 FAILED** (`make check exited 2`): `test_native_exec_state::
  test_the_table_is_the_scripts_members` wants `_backout_stall_ticks` in `native/src/exec_fields.h` (197 members v 196 fields) — by
  design: the OFF code ships WITH native's twin or not at all; perf NOT JUDGED (the box busy, 2.19x). (b) **27f00d3f0 (the freeze
  candidate) on builder2: 3446 / 1 FAILED**: native's `test_native_drive_backout_stall` — the twin EQUAL (1197 drives, 0 mismatches),
  its own stage assertion `stalls >= 1` failed (0 stalls): it drops a StaticBody3D behind the tail, and a static collider is a
  WallContact, so the leg ends through today's `lead_hit` wall rule before a stall tick can count; the stall rule is for HULLS (no
  WallContact). Told the orchestrator (relayed to native: a parked Tank, not a box). My own stage of it added to
  `tests/test_manoeuvre_backout.gd` (a parked War Rig placed 1 m behind the tail the moment the leg reverses): running on builder2 light.
  **B2's freeze re-cuts on native's corrected pair.**

- **The stall rule, re-cut on net progress (~12:30 PDT):** my own stage (`test_manoeuvre_backout`: a parked War Rig placed 1 m behind
  Guns_2's tail the moment its departure leg reverses, GDScript drive, builder2 light) read **0 stalls, max 2 stall ticks** under the
  velocity rule, and the per-tick trace showed why (native's trace of its parked-hull stage said the same): pressed on the hull the
  plant's `real_velocity` flips sign every tick (+2.7 / -2.8 m/s, the contact bounce) while the body moves 0.02 m a tick, so "no
  motion for 15 consecutive ticks" reset every other tick. Now the stall is judged on the CENTRE's net progress: a window opens where
  the hull stands (`_backout_stall_from`, a new Vector3 exec field) and counts ticks while the plant is asked for >= 0.3 m/s in the
  leg's gear; it re-opens on 1.0 m of progress (`BACKOUT_STALL_PROGRESS_M`); 30 ticks (`BACKOUT_STALL_TICKS` = 1 s) without = stalled.
  A free leg from rest covers ~2.2 m in its first second. **Stage read: placed t3, stalled t33, the rig moving its own way again t33,
  1 stall; his start unchanged (ON reverse t4, past the box t98; 3 / 0 tests).** Shoving a squadmate along counts as progress (the
  centre moves); B2's wedged and friendly-contact guards read that. Native re-twins on this hash (two exec fields now:
  `_backout_stall_ticks`, `_backout_stall_from`).

- **Corpus + guard re-read on 57e02fed5 (builder2 light, GDScript drive, ~12:50):** identical rows to dev read 3 (base-stuck 3 / 3 sooner,
  ceiling worst +1.5 s / median -0.07 s PASS, guard poses 6 / 6 ok, 0 stalls anywhere: the rule only acts where a leg is pressed).
  B2's filing sentence on rule (3) amended to the net-progress wording (no number seen on 11149-11196).

- **quick-remote of 57e02fed5 (builder2 heavy folder, ~12:55): 37 / 1, lint 203 scripts parse**; the one failure was my new stall stage
  running on the folder's OLD C++ library (no twin: 0 stalls). **dab58b334** (test only) makes the stage force the GDScript drive (the
  GDScript rule is what it proves; native's `test_native_drive_backout_stall` proves the twin, C45.4): heavy folder, library present,
  **3 / 0** (his start OFF t46 / t144, ON t4 / t98; the stage placed t3, stalled t33, 1 stall). **Native re-twins on dab58b334.**

- **Native's v2 twin EQUAL (relayed ~13:20): `pair/native-backout-b2v2` 04ce3abe9** = dab58b334 + the twin (builder2: his start 1191
  drives / 0 mismatches t4 / t98; the stall twin on a FIXED parked rig 1189 / 0, 1 stall at 30 ticks; default orders probe base v
  backout on the C++ drive 60 / 60 byte-identical; the pair's own tests 4 / 0). **Freeze re-cut: `wip/manoeuvre-b2-freeze` 0493977ed**
  = stream/manoeuvre ce52cba1c + 04ce3abe9; its full check runs on builder2 (`check_b2/check-0493977ed.log`); the series waits for
  its exit line.

- **builder2 preempted ~12:51 PDT** (Spot; "No route to host") during the sync of 0493977ed's check: the check never started. Restarted
  (`gcloud compute instances start`, the gcp-start recipe); the check re-queued. The B2 series is split into two drivers so it runs on
  both builders at once (`bars_b2_a.sh`: builder0 light legs from a second frozen checkout `../godot-manoeuvre-b2x` at 0493977ed;
  `bars_b2_b.sh`: builder2 legs from `../godot-manoeuvre-b2`; `bars_b2_judge.sh` after both), their copy-backs in separate worktrees.

- **GATE GREEN (~13:30 PDT): 0493977ed on builder2, `>> remote: make check exited 0`, 3448 passed / 0 failed, 24 targets passed, 4 NOT
  JUDGED** (perf-judge: not a judging machine; ai-scenarios perf loaded 4.75x; remote-guard-test and web-smoke under load 42-55 on 16
  cores). Perf is judged on builder0 before ON, as filed. **Bar B2's series LAUNCHED 13:34 PDT**: driver A (builder0 light, from
  `../godot-manoeuvre-b2x`): corpus, guard poses, fights, G1 probe; driver B (builder2, from `../godot-manoeuvre-b2`): his start, his
  Gorge replay, workload, group guards. Evidence `~/overnight-manoeuvre/r45/bars_b2/` (meta.txt has each leg's clock); judges by
  `bars_b2_judge.sh` once `A.done` and `B.done` exist.

- **Bar B2, legs as they land (frozen 0493977ed; every number builder2 / builder0 as named; the C++ drive in both arms):**
  - **D1 his start (builder2, 13:37): PASS.** Green_Guns_2 reversing t4 (line < 15), past the box's west end t97 (line < 110); base t44 /
    t140 (does not do both). From the per-tick START_ROW rows of `b2_his_base.log` / `b2_his_bo.log` (600 rows each).
  - Engage's line (his Gorge replay): the first run of both arms FAILED TO START (my driver's recording path `_agents/streams/
    references/...` does not exist; the file is `references/round44/playtest/...`): no rows, rerun queued verbatim with the path fixed
    (`bars_b2_gorge.sh`, after driver B's gorge legs; the bad-path logs kept as `gorge-*.badpath.log`).

  - **D2 the corpus (builder0 light, `godot-manoeuvre-b2x-light`, 13:39; 96 rows, native_drive True): deciding PASS, cost ceiling FAIL
    -> Bar B2 FAILS AS FILED.** Base-stuck poses 11 (floor 8): ON sooner in **11 / 11** (line 80 %), median **-3.03 s** (line -1 s); the
    37 other poses: median -0.13 s (line +1) PASS, **worst +6.3 s (line +3.0) FAIL: seed 11187, pose 10 (crossing crawl +50, route +48,
    nose 0.5 m), base clear t166 -> ON t355; both arms first reverse t28, crept 0.26 m; ON looks 2, k-turns 2, 0 stalls.** One pose of
    48 breaks the every-pose line; no amendment (C45.1). The other legs run on for the record; the orchestrator decides with him
    (lesson 339 / C45.2). The cause of 11187 is being traced (laptop, GDScript drive, the frozen worktree).

  - **Engage's line (rerun, builder2, 13:46): PASS** — his Gorge replay 107 s base v bo, DIVERGENCE 20 / 20 within 3 m both arms, the
    per-crew tables IDENTICAL.
  - **The red flag (C++ t355 v laptop GDScript t273 on 11187): RESOLVED as the machine, not the twin.** The whole block both ways on
    builder2's heavy folder (`~/overnight-manoeuvre/r45/b2_equal/`, 0493977ed): C++ drive v GDScript drive **96 / 96 rows identical**
    (clear tick and first reverse; 11187 ON t355 on both).
  - **Workload guards (builder2 light, 72 paired cells 11149-11172, 0 SCRIPT ERROR; `judge-workload.txt` once judged):** yield+blocked
    crossing -0.9 se / locks -0.1 / terminus -3.4 PASS; k-turn s crossing -0.5 se PASS, locks +1.8 se PASS, **terminus +2.6 se (+1.79 s a
    run) FAIL** (line +2 se); wedged -0.35 s a run PASS; never-arrived -0.5 a run; seated-by-15 -0.6 se PASS. `b1_judge`: other crews'
    reversing ticks -4.0 / +0.5 / -3.3 se PASS, seated +0.2 / -1.4 / +1.9 se PASS; nose-on crews' clear 8 m 248 -> 264 ticks (+1.0 se,
    reported). **B2 as filed: two misses (the 11187 ceiling, the Terminus k-turn guard).** The driver's leg ended "WRAPPER_DONE 127"
    (a shell quirk after the copy; all 144 runs present with START_RUN).
  - **The 11187 fix (uncommitted at this line; GDScript, laptop):** a look that plans nothing is withdrawn; on a tick today's drive
    would have planned it re-runs today's planner on the station (11187: both arms plan the same circle at tick 29 now; ON t207 v OFF
    t166, the rest is the squadmates' own ON drives); on a look-only tick nothing more and `_kturn_check` restored (today's cadence);
    a look-only call that planned nothing waits KTURN_CHECK_TICKS (`_backout_skip_until`, a new exec field). 14 dev poses unchanged
    (3 / 3 sooner, ceiling worst +1.5 s, median 0.00), lab 3 / 0.

  - **Who carries the Terminus k-turn excess (the workload's per-crew rows):** on 7 of 24 seeds (11149 / 11151 / 11157 / 11160 / 11163 /
    11168 / 11171, one deploy shape) **Guns_5, the Resupply Tanker (6.6 m, never looks), 2.5 -> 10.3-11.8 s** (+8 s), the War Rigs
    Guns_2 / Guns_3 +2 s each (their back-ups are k-turns), the Hunters -2 to -5 s; the other 17 seeds within +-1 s a run. Not the
    11187 shape: the rear crew k-turns because the rigs ahead back out toward it. R45.12's removal read (Terminus dev 7001-7012, base v
    frozen bo v bo+fallback, GDScript drive, builder2) decides whether B2b is filed at all (`~/overnight-manoeuvre/r45/terminus/`).
  - **The fix committed: stream/manoeuvre 0a80c3685** (code dab58b334 + the fallback / cadence / skip; one new exec field).

  - **R45.12's three-arm Terminus read (dev 7001-7012, GDScript drive, builder2, `~/overnight-manoeuvre/r45/terminus/`): the fallback
    changes NOTHING on Terminus.** k-turn s a run: base 384.6 pooled -> frozen bo +4.45 (+4.1 se) -> bo+fallback +4.45 (identical rows
    but one crew on 7009). The excess is the rule's own back-ups (the rigs +2 s each) and the Tanker behind them turning to make way
    (+8 s on its deploy shape), not a look pre-empting a plan. The same cells: yield+blocked -4.9 s a run (-1.9 se), never-arrived -0.75
    a run, wedged -0.8 / -1.3 s a run: the squad flows out sooner while its rear crew turns. **B2b is not filed (R45.12); backout stays
    OFF this round; the orchestrator tells him in player terms.** Round 46: the k-turn guard counts the manoeuvre the rule exists to
    make (a filing-design point), and the rear crew's reaction to a rig backing toward it is the next thing to look at.

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

- **Who carries the bound's press (removal read 2, bound + seat-order, Locks dev, `s_judge.py --cells` now prints wedged per run
  with the crews over 1 s):** one or two crews a run, not the squad: **Guns_5 (the Resupply Tanker, 6.6 m, the squad's last crew) 7 s on
  seeds 7001 / 7002 / 7004 / 7010**, Battery_4 / Battery_5 7-10 s on 7003 / 7006, Guns2_2 10 s on 7011; the War Rigs 2-3 s. Read: the
  slowest, longest-arriving crew converges on a bound the other four already fill and wedges against them. If S v4 misses its wedged
  guard, the press fix is for the LAST crew's seat (dealt outside the filled bound, or its give-way deferred until the seat ahead is
  taken: the archived "second shape"), not a wider switch mix. The orchestrator's watch item (a D1 pass with a wedged miss) is the
  likely failure shape; the per-run rows are in the judge's `--cells` output for the bar.

- **Design note for the press (if S v4 misses its wedged guard; for round 46 or an S v5 after B2):** the dev rows say the bound's
  wedged seconds sit on the squad's LAST crew (the 6.6 m Tanker, Guns_5: 7 s a run on 4 of 12 Locks seeds; the Battery's rear crews
  7-10 s): the crew arriving last converges on a bound (1.5 hull lengths of the longest hull, `SEAT_BOUND_HULLS`, floor 18 m) the four
  others already fill, and wedges between them and the box/wall of the yard. Two shapes, in order of least machinery: (a) **the last
  seat is dealt outside the filled bound**: `TacticsFormation.place` / `seat()` keeps the bound for the first `count - 1` seats and
  lets the last-arriving crew (by `transit_starts` order, or the longest route) take today's unbounded seat (its own slot of the
  nominal shape): the squad still reads as settled (four of five within the bound) and the tanker parks at the back, where he would
  put it; (b) **a squadmate's give-way deferred until the seat ahead is taken** (`Movement.ask()`: a crew converging on its seat does
  not back for a squadmate whose seat is still empty; the asker waits its turn): more code, touches the yield rules (traffic.gd,
  mine). Dev read first on Locks 7001-7012 with `s_judge --cells` (the per-crew wedged rows name the carrier), then a Bar S v5 on the
  reserve block. Neither is built this round unless S v4 fails before the series window closes.
- **Design note, the two-squad press (stretch, carried from round 44):** the second squad driving into the first's compact zone
  (Locks: the Hunters through the Guns' bound; `parkedpass` was built for it, OFF, S v3's parkedpass arm never read alone). With the
  bound ON the first squad's zone is 37 m instead of 58, so the second squad's path through it is the new cost; the read to do first:
  `manoeuvre-bar-s` Locks with `--seat-bound=on --seat-order=on` v the same + `--traffic-on=parkedpass`, per-squad yield / wedged
  (the archived Status's per-squad table), before any rule.

Decisions so far: dev reads run on the laptop's GDScript drive under `flock /tmp/tank-squad-laptop-godot.lock` (one pose pair ~1 min;
nothing of the lead's runs while he is away); every judged number comes from a builder.

