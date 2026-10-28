# Stream: manoeuvre (a War Rig nose-on to a container backs out first; his one-squad order lands at his click)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 44** (C44.1, CP44.0,
> C44.3, C44.4, C44.5). Your round-43 brief: `streams/archive/round43/manoeuvre.md` (Status: Bar S / S v2 tables, the read after the
> numbers, the R43.34 candidate and its proof takes 1-4); R43.31 / R43.34 / R43.42 in `workstreams.md`. **You own:** movement's drive /
> unstick / side-step / avoidance / yield (`game/ai/movement.gd` but the planner seam), `game/ai/traffic.gd`,
> `game/tactics/tactics_formation.gd`'s `pitch` / `hull_floor` / `offsets_at` / `fit_to_corridor` / seat bound / shape latch,
> `game/tactics/element_plan.gd`'s `grouped()` and converge, `game/tactics/element.gd` (as the candidate), `tests/manoeuvre/**`,
> `tests/traffic/**`, `tests/test_manoeuvre*.gd`, `tests/test_traffic*.gd`, `tests/test_formation*.gd`, `mk/manoeuvre.mk`. **NOT**
> `game/control/**` (orders'; the `group` key arrives through CP44.0). **Model:** Fable. **Machine:** builder0 light lane; builder2
> for a bar series. **Seeds:** 10901-10948 (bar), 10949-10996 (reserve).

## The lead's direction (2026-10-28, verbatim; the full note in `game_design.md` *His playtest after round 43*)

"I once again told squad 1 to go to the west side of the map. These were the gang tanks. The tanks start behind a shipping container.
One of the tanks moved forward right away only to get stuck right away before recognizing it needed to back up. In that case it should
have been obvious to the tank that they should have backed up first to create clearance. I played again to try to reproduce and I
didn't seem to have the same problem."

"Units must look smart" (memory): a tank that drives its nose into a box it could see is the opposite.

## Where things stand (main at launch: dbf0bf637, see HANDOFF)

- **His case** (`references/round43/playtest/2026-10-28T08-15-42-locks.jsonl`, Locks, seed 56416, Gangs, laptop, native ON): his first
  order (tick 0) sent the Guns west; Green_Guns_2 at (-42, 90) read `driving` for 4 s (ticks 0-120) moving under 2 m, then left;
  Guns_3 yielded 3 s to Hunters_1. Native's replay (`make replay-match`) reproduced his round-42 match bit-exact; run it on this one.
- **Built in round 43, all OFF (R43.42):** the seat bound (`--seat-bound=on`), the shape latch (`--shape-latch=on`), the first-tick
  k-turn for a station a hull's length off the crew (`--converge-on-crew=on`, R43.14), `--traffic-on=kturngoal` (native twin
  b2dea555a), `--traffic-on=parkaside` (twin 5b5a2c365). Bar S v2: D1 +13.8 se, D2 -2.4 se, never-arrived -37 %, but FAILED on
  Locks' per-arena give-way guard (+2.4 se; five crews converging on seats within 37 m give way to each other, +4.1 s a run) and G5
  (+3.8 s a run on his 5-squad order, parkaside's seats-beside on a group click).
- **The R43.34 candidate** `wip/manoeuvre-scope-g1` e883fc4eb (off 04ddbcabb, before main's merge of the ship and native's twins):
  `ElementPlan.grouped(task)` scopes the five rules to a squad on its own order; a grouped squad drives as today. Proof take 4: G1
  v9 probe 60 / 60 byte-identical, tests 581 / 0. The two `rts_controls.gd` lines and the KEYS entry land through orders (CP44.0).

## Backlog (in order)

1. **M1 rebase the scoping onto main.** Everything of `wip/manoeuvre-scope-g1` but `game/control/**` and `element_task.gd`'s KEYS
   (orders' CP44.0; until it merges, apply those three lines locally uncommitted to test, or wait; `git merge main` when the
   orchestrator says CP44.0 is in). Re-run proof take 4 on the rebased tree: the G1 probe byte-identical with all switches ON.
2. **M2 his container moment.** Replay 08-15 to tick 120: does Guns_2 nose in on main, and does `converge-on-crew` + `kturngoal`
   (scoped) back it out first? If not, trace why its first leg points into the box (the station a hull's length ahead? the seam's plan
   ignoring the container as a static obstacle?) and fix the k-turn so a crew whose first leg is blocked within a hull length starts
   in reverse. Show it as a before/after trace and a screenshot pair (look at them). Note he could not reproduce it on his second
   match: say what differed.
3. **M3 the Locks give-way (Bar S v2's failed guard).** Five crews of one squad converging on seats within 37 m yield to each other on
   the way in. Two shapes are on file in the archived Status; pick by removal on dev seeds, build behind a switch.
4. **M4 Bar S v3**, filed in *Bars (round 44)* BEFORE any number on 10901-10948: the scoped bound + converge + kturngoal + parkaside
   (+ M2's k-turn, + M3), deciding lines D1/D2 as v2, the Locks give-way line and G5 named as the risks, the G1 group probe as a guard
   (C44.3), fights (deaths, friendly contacts), native twins in the tree (C44.4). Ships ON with `=off` escapes when it passes.
5. **M5 his acceptance read:** the shipped tree on both his recordings' first orders (the 08-15 container, the 08-21 first order).
6. **Stretch:** the bridge drill crew's own cause (R43.38); the street hold on a bar decided on side jam_s (A6 v2's z -5.2, R43.21;
   `game/ai/traffic.gd` is yours; engage's archived Status has the candidate).

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>`); `make manoeuvre-start-trace`; `make replay-match RECORDING=...`;
the Bar S judge (`tools/judge/`); screenshots of the container start before/after, looked at. Every number with its commit and machine.

## Don't touch

`game/control/**` (orders), `native/**` (ask native for twins), the planner (trace lines only), `game/camera/**`, `game/match/**`,
element_plan's engagement and settle functions, `tests/baselines/**`.

## Waiting on the lead

Nothing at launch.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Session start 2026-10-28 ~09:20 PDT (Fable, `godot-manoeuvre-c0`). Starting commit 711f3e94f = main at launch (code dbf0bf637 GREEN
builder0, 3420/0; no baseline check re-run, per the contract). Orchestrator session: `godot-b8`. CP44.0 not yet merged at start.**

### Plan (smallest foundation first; the brief's order kept)

1. **M1** rebase the R43.34 scoping (done: 1354362f8, below); proof take 5 = the G1 v9 probe byte-identical base v all-ON on the rebased
   tree (running, builder2 light); re-proved on the merged tree once CP44.0 lands (`git merge main`).
2. **M2** his container moment: the 08-15 start rebuilt on builder0 (native ON) in three arms (base / converge+kturngoal / all), the
   Guns traced per tick; read why Guns_2's first leg points into the box; fix the k-turn so a first leg blocked within a hull length
   starts in reverse; before/after trace + screenshot pair.
3. **M3** the Locks give-way: pick by removal between (a) seats dealt in arrival order along the approach and (b) a squadmate's
   give-way deferred until the seat ahead is taken, on dev seeds; build the winner behind a switch.
4. **M4** Bar S v3 FILED before any 10901-10948 number; gate check on the frozen tree; series on builder2.
5. **M5** his acceptance read on both recordings' first orders. Stretch: R43.38, the street hold on side jam_s.

Decisions so far: the CP44.0 lines (orders') are applied locally UNCOMMITTED for testing only (the brief's option), never committed here.

### M1: the scoping rebased (2026-10-28 ~09:30 PDT)

- **1354362f8** = everything of `wip/manoeuvre-scope-g1` e883fc4eb but `game/control/rts_controls.gd` and `ElementTask.KEYS` (CP44.0).
  The patch applied three-way without conflict onto 711f3e94f. The scope test's `before_each` / `after_each` (hooks the runner now
  fails, N6) became `teardown()`; its validator line on `group` waits for CP44.0 (orders' test pins the key).
- Laptop, 1354362f8 + the two CP44.0 files uncommitted: `make test FILTER=` the five rule files + group_scope + element_task =
  **28 passed / 0 failed**.
- **Proof take 5 PASSED (builder2 light, native ON, 1354362f8 + the two CP44.0 files uncommitted, 09:30-09:41 PDT,
  `~/overnight-manoeuvre/r44/m1/proof5.txt`, `rows.jsonl`):** tests 591 / 0 (the five rule files, group_scope, element_task, every
  `control_` file); the G1 v9 probe (locks / crossing / terminus x 5 squads x click x 7001-7004) base (`--shape-latch=off`) v scoped
  (`--seat-bound=on --converge-on-crew=on --traffic-on=kturngoal --traffic-on=parkaside`) **60 / 60 rows byte-identical**. M1 stands;
  re-proved on the merged tree once CP44.0 is in.

### M2: his container moment, the cause (2026-10-28 ~09:45 PDT; builder0, native ON, 1354362f8, `~/overnight-manoeuvre/r44/m2/`)

- **The rebuild is faithful:** `make manoeuvre-start-trace ST_RECORDING=<his 08-15> ST_CREWS=Guns` puts Guns_2 within 0.1-1.5 m of his
  census for the first 4 s (START_GAP), every Guns crew within 1.5 m to 3 s.
- **What happens (base = main; identical row for row in the `--converge-on-crew=on --traffic-on=kturngoal` arm AND in the all-four
  arm for Guns_2's first 130 ticks: none of round 43's rules touches it):** Green_Guns_2 (War Rig, 14 m, 12 m turning circle) at
  (-42.1, 90) faces south; ArenaKit `container_20` at (-42, 80) (6.06 x 2.44 m, long axis x) has its north face 1.8 m past the nose;
  his click is 87 m WSW and the squad's route leaves 35 deg right, round the box's west end (x -45). Ticks 1-27: the transit's
  converging station starts ON the crew and creeps 1-2 m ahead (goal (-42.7, 89.2), (-43.5, 88.4), once 1.4 m BEHIND); the k-turn
  planner sees a steering point a metre off the nose (nothing to turn for) and the rig creeps 0.6 m forward at 0.4-1.4 m/s. Tick 28:
  the station jumps 9.6 m west, 70 deg off the nose, inside the turning circle; tick 30: the circle plan (back 4.0 m, away 7.5 m: the
  right answer); ticks 31-48 lost braking the creep's roll; ticks 49-70 it backs 2 m at 2.8 m/s; tick 70 a reseat moves the goal to
  13 deg off the nose and the leg is cut; tick 85 it rolls forward and clears the box's west end at tick ~142 by ~0.6 m. In his eyes:
  moved forward right away, stuck, then backed up: 3.3 s in front of a box it could see at tick 1.
- **His second match (08-21):** the same spot (-42.1, 90) held Green_Guns_4 (a War Rig too, all five Guns 420 hp); his click was
  (-85.7, 52.6); that rig stood for 150 ticks (5 s) before moving: the same thing, LONGER, unnoticed (the camera was elsewhere).
  Nothing differed in the mechanism; the roster order and the click did.
- **The fix, BUILT and committed: e0a746667 (`--traffic-on=backout`, DEFAULT_OFF).** His real start rebuilt under it (builder0, native
  base v the rule on the GDScript drive (the chain gate; the two drives are row-identical over all 3000 rows of his 20 s start at
  1354362f8, builder0), `start_trace_bo3.log`): the look at tick 1 (departure point (-52.7, 79.1), 15 m, 44 deg off the nose, inside
  the circle), the circle plan "back 2.0 m, away 3.5 m" at tick 1, reversing by tick 2 (-1.2 m/s at tick 6, -2.8 at 16), 2 m back by
  tick 31 with the nose 10 deg west, rolling forward at tick 36, 6 m/s by tick 61, **past the box's west end at tick 91 (main: 142)**.
  No creep: 0.0 m forward before the reverse (main 0.6 m). The squad (20 s window, arrival s): Guns_1 18.9 -> 14.3, Guns_2 8.4 ->
  8.9, Guns_3 never (20.0) -> 10.8, Guns_4 7.6 -> 7.7, Guns_5 9.9 -> 13.3; k-turn s Guns_2 1.3 -> 1.9. One start, one seed: a read,
  not a number; Bar S v3 decides.
- **The lab test** `tests/test_manoeuvre_backout.gd` (his five Guns at the header's spawns on Locks, the Gangs table, an element's
  move to his click; a rig ALONE reverses straight under M1's `behind` rule and never shows the creep, so the squad is staged):
  OFF: forward at t12, reverse t46, crept 0.62 m, past the box t144; ON: reverse t10, crept 0.0 m, forward t36, past the box t99
  (builder2 light, e0a746667's code: 2 passed / 0 failed).
- **Three things had to change, all behind the switch (OFF = today byte for byte):** (1) the look happens while the hull still sits
  "arrived" on the station (today the planner is only called when steering wants to drive); (2) the k-turn decision is made against the
  departure point instead of the station; (3) the station PID (Movement._keep_station, a station within 14 m moving >= 0.5 m/s) is kept
  off a planned leg: it wrote the throttle after the leg and the hull rocked +-1.5 m/s on the spot for 80 ticks (bo2 trace). (3) is a
  bug for ANY k-turn planned near a moving station; it is gated for C44.4 and the native twin should carry it.
- **Native twin needed before ON (C44.4):** `Movement._backout_due`, `_backout_departure`, `_backout_final_goal`, the waypoint swap at
  the top of `_planned_reverse`'s look, `BACKOUT_MIN_ERROR_DEG` as the gate, `_backout_leg`'s continuation at the call site, the station
  PID gate; new members `_backout_goal/_tick/_point/_from/_leg` (exec_fields). Requested through the orchestrator.
- **Dev read with backout in the round-43 set (Locks dev 7001-7012, 12 paired cells, builder2, e0a746667, `make manoeuvre-bar-s`,
  `~/overnight-manoeuvre/r44/m3/dev1_logs`; never a bar):** base v `all` (bound + converge + kturngoal + parkaside) v `allbo` (all +
  backout). D1 seated within the bound by 15 s: 53 -> 88 (+4.6 se) -> 83 (+6.3 se); Locks yield+blocked +0.3 se both (v2's failing
  line passes on this block); k-turn s 106 -> 43 (-3.0 se) -> 83 (-1.2 se). Per squad (s a run): Guns (squad 1) yield 4.0 / 2.6 / 2.8,
  blocked 5.2 / 4.7 / 4.1, wedged 3.9 / 3.7 / 2.9, k-turn 4.1 / 0.7 / 3.8, within the bound 19 / 35 / 30 of 50; Hunters (squad 2)
  yield 1.0 / 2.0 / 4.8, wedged 1.8 / 5.1 / 6.2. **Read:** (a) the Locks cost of the bound is the SECOND squad through the first's
  zone (wedged, yields), not the first squad's own crews; (b) backout as first built over-triggered: every rig whose route left
  ~40 deg off got the circle plan's back-up on open ground (the departure vertex 15 m out lies inside a 12 m turning circle whatever
  is around): Guns k-turn 0.7 -> 3.8 s a run. **Changed (uncommitted, re-reading):** a departure look skips the circle plan; only the
  swept arc decides (a back-up when the forward swing toward the route would hit something within 5 m): his box still hits, open
  ground does not.
- **Iterations after the dev reads (all uncommitted on top of e0a746667 until the re-read lands; `~/overnight-manoeuvre/r44/m2/`,
  `m3/dev2_logs`, `dev3_logs`):** (i) the circle plan skipped for a departure look: Guns k-turn 3.8 -> 3.4 s a run, but with the
  departure vertex inside the circle the plan had no away leg and the drive crept back toward the station and scraped the box
  (backout alone: wedged 3.9 -> 8.5 s a run, dev2). (ii) The look made toward a FAR point (60 m) along the way the route leaves (an
  away leg aligns with it), the gate 40 deg (today's k-turn gate is 45; his departure is 44), kturngoal's goal-moved end kept off a
  backout leg, and a run-clear check behind: on his start the check counted Guns_4 fifteen metres behind-left as in the way
  (Manoeuvre._hull_hit's disc is a hull's half-length wide), the look never fired, and my call-site hook still ran TODAY's planner
  on a station 1.4 m behind the rig: a 3 m left-turning back-up and a 13 s arrival (bo5; dev3 `bo` alone: wedged +6.3 s a run,
  never-arrived 13 -> 22). (iii) Restructured (current): the hook calls the planner only when the departure look WILL apply
  (`_backout_look`: near rest, station within a hull's length, not grouped, within the window, the route leaving >= 40 deg off,
  2 m of straight run behind clear of hulls), and the single back-up search stops at any hull (`departure_look` adds
  Manoeuvre._hull_hit to its navmesh test). Re-reading on his start (bo6) and Locks dev (dev4).
- **(iv) NOSE-ON (current, the keeper):** back to the circle-plan look at the route's vertex (bo3's shape: back 2.0 m, away 3.5 m,
  past the box at tick ~91 on his start; bo7 / bo8) with the restructured hook, the hull checks in both back-up searches, the 40 deg
  gate, 2 m of clear run behind, AND the lead's own condition: the straight run past the nose blocked within 4 m (`_free_run`; his box
  1.8 m). Locks dev 7001-7012 (dev6, builder2): **backout alone v base: D1 53 -> 55, yield+blocked +1.0 se, k-turn +1.4 se, wedged
  +0.8 s a run, never 13 -> 15: neutral on an open deploy row** (the versions without the nose test: wedged +5 s a run, never 13 ->
  28, yield+blocked up to +5.6 se); **the round-43 four + backout: D1 +5.9 se PASS, Locks yield+blocked -0.4 se PASS, k-turn -1.6 se,
  wedged +4.8 s a run (the bound's second-squad cost, Hunters 1.8 -> 4.3 s), never 13 -> 13.** Lab test (builder0 light): OFF forward
  t12 / reverse t46 / crept 0.62 m / past the box t144; ON reverse t11 / crept 0.0 / past the box t102: PASS.
- **parkedpass lab test (builder0 light):** ON: 6 refusals with a lane, 1 pass, the rigs moved 0.0 m (OFF: the rig backed 9.0 m);
  the truck arrives t324 v t232 OFF: the pass costs the passer ~3 s round a 14 m rig; the rule buys the parked squad's stillness.
  Test line relaxed to four seconds with that reason; the squad-level net is the bar's. Locks dev arm with parkedpass running (dev7).
- **Screenshots:** `make manoeuvre-start-shots` (tests/manoeuvre/start_shot.gd: the faithful replay in a window, the RTS camera
  focused on SS_FOLLOW every tick; `follow()` is overridden by the skirmish's own framing) -> `~/overnight-manoeuvre/r44/m2/shots3/`
  (base) and shots4 (base + the current rule), t15/45/75/105/135. The base frames show Guns_2 nose-on to the brown container; the
  pair is read once shots4 lands.
- **M3 built (uncommitted, test queued): `--traffic-on=parkedpass`.** Bar S v2's Locks logs (24 cells, `~/overnight-manoeuvre/r43/
  bars_v2/deciding`) read per squad: the Guns' yield s 51 -> 92 and the Hunters' 36 -> 60 over 24 runs, the Guns' blocked 86 -> 71;
  the yields are the SECOND squad driving into the first's compact zone (a parked rig backs 6 m for a Hunter, `back(6)`, then asks
  the squadmate behind it to back too: seeds 10703/04/11/13/16/19 all +8.6 s), not the first squad's five crews converging (the
  squadmate-to-squadmate yields on Locks dev FELL under the bound, 21 -> 14 of 12 seeds). Rule: a crew that has arrived and stands
  (not under way, its element arrived or none), asked by another squad's crew with a lane past it (T7's `_pass_lane`), refuses with
  the offer and the asker passes beside it; no lane = today's give-way; never for a squadmate. In `Movement.ask()`; counter
  `parkedpass_refusals`; ON runs the GDScript yield (native_yield off). Test `tests/test_manoeuvre_parkedpass.gd` (two rigs abreast,
  a gun truck sent through the right one with open ground to its right). The brief's two shapes (seats in arrival order; a
  squadmate's give-way deferred) are not what the logs show: not built.
- **The fix as first built (`--traffic-on=backout`, superseded above):** at an order's start, a hull near rest whose steering point is within its
  own length makes the k-turn decision against the DEPARTURE POINT (the first point of its own navmesh route to its FINAL seat at
  least a hull's length away) when that is >= 25 deg off the nose; the decision machinery is today's (circle plan / arc sweep /
  reverse search). Scoped off grouped squads (C44.3). Untwinned: ON runs the GDScript drive (chain gate); native asked for a twin
  once the numbers are read. Test `tests/test_manoeuvre_backout.gd` (his geometry in the lab: Locks, a War Rig at his spawn, an
  element's move to his click).
