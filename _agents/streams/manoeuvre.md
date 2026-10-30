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

### WHERE IT STANDS (2026-10-29 ~21:30 PDT; backout shipped ON (R45.26); Bar S v5 FAILED as filed; holdway parked with its cause)

- **main carries the stream's OFF code: 5d4b3fa82 merged as main 9203851ec** (its builder0 main check owed by the orchestrator, perf
  judged there). Proof: builder2 check exited 0 / 3456 / 0 / sim-baseline unmoved; the default orders probe on a clean checkout of exactly
  5d4b3fa82 v main e6e926160, same machine: 60 / 60 byte-identical.
- **Bar B3 (backout, his ask) frozen at 26b1425e7** = `pair/native-backout-b3` (native's proof branch IS this hash: no C++ change for the
  room-behind gate); native-proof `--traffic-on=backout` EQUAL (4a04ea921011cd9a, builder2, before the crash); the twin tests and the
  default probe re-run on builder2 (builder2 restarted). Its full check runs on builder2 (`check_b3/check-26b1425e7.log`). **GO (the
  orchestrator, no further word needed): the series launches when native's lines land EQUAL + 60 / 60 AND the check reads exited 0**;
  drivers `bars_b3_a.sh` (builder0 light, from `../godot-manoeuvre-b3x`) + `bars_b3_b.sh` (builder2, from `../godot-manoeuvre-b3`),
  then `bars_b3_judge.sh`. **LAUNCHED ~19:20 PDT**: the check read `exited 0`, 25 passed, 3 NOT JUDGED (perf), sim-baseline unmoved;
  native EQUAL (4a04ea921011cd9a), twins 34 / 0, default probe 60 / 60 on 26b1425e7. Evidence `~/overnight-manoeuvre/r45/bars_b3/`.
- **Bar B3, legs as they land (19:00 PDT):** **D1 PASS** (t4 / t97 v t44 / t140). **D2 (builder0 light, 98 rows): deciding FAILS AS FILED,
  12 base-stuck poses, ON sooner in 9 (75 % v 80 %)**, median -2.78 s PASS, ceiling worst +1.3 s / median -0.52 PASS, the named 11187
  cell +0.8 s PASS. The three not won are one shape, pose 10 (crossing crawl +50), seeds 11711 / 11725 / 11739, **exact ties** (t360 ->
  t360, t360 -> t360, t187 -> t187): the look's back-up is blocked at 2 m by the squadmate 1.7 m beside, it withdraws, today's planner
  runs to the same plan; B2 had read those cells a little sooner by the pre-fallback look's accident. The 80 % line counts a tie as a
  loss. **Engage's line PASS** (the Gorge tables identical base v bo; the replay itself reads FAIL v his recording in both arms since
  main's E2 — engage's). Guard poses, workload, group, fights, G1 probe still running.
- **D3 guard poses (builder0 light, 24): PASS, 0 worse** (the no-room line and pose 2's ceiling line). **R45.23:** B3 FAILS AS FILED on D2's
  share; if EVERY remaining line passes, backout ships ON after a quiet builder0 perf read of the merge; if any fails it stays OFF. The
  ship candidate is prepared: `wip/manoeuvre-backout-on` **466d96191** in `../godot-manoeuvre-on` = 26b1425e7 + `backout` out of
  `Traffic.DEFAULT_OFF` + `test_manoeuvre_backout`'s default test flipped (2 files, 5 / 4 lines; nothing else); its check waits on the legs.
- **Workload guards (builder2 light, 72 paired cells, 0 SCRIPT ERROR): every B3 line PASSES.** Per arena (crossing / locks / terminus):
  yield+blocked -0.0 / +1.7 / -2.8 se; wedged +1.1 / -0.2 / -1.3 se; **the squad's time to clear its start +0.7 / +1.1 / -1.5 se** (the
  replacement guard); other crews' reversing ticks -4.7 / +1.8 / -3.2 se; other crews seated +2.0 / +1.0 / +1.3 se; pooled never-arrived
  -0.375 a run (-3.3 se); D1-seated-by-15 s +1.3 se. **REPORTED (not a line, the named risk):** k-turn s -0.1 / +1.5 / **+3.7 se** (Terminus
  +3.3 s a run, the same shape B2 read at +2.6 se). s_judge's own D1 / D2 and b1_judge's D2 are Bar S / B1 deciding lines, not B3's.
  **Group guards (builder2 light, 48 paired): PASS, identical arms** (G5 / G6 / G7, 0 se). **Fights G1-G4 (builder0 light, 18 fights an arm): PASS** (give-way deaths 49 -> 47, stuck deaths 120 -> 116, contacts -2.0 %, kill share moved 0.004). **G1 corridor (builder0 light): PASS** (ORDERS_PROBE_SQUAD 180 / 180 byte-identical, g1v8 lines identical both arms). No SCRIPT
  ERROR in any leg. **B3 COMPLETE 19:45 PDT: FAIL as filed on D2's share alone; every other line PASSES -> per R45.23 backout ships ON
  after the orchestrator's quiet builder0 perf read of the candidate `wip/manoeuvre-backout-on` 466d96191** (table + candidate sent to
  the orchestrator 19:50). Full table: `references/round45/manoeuvre/barsb3-builder0+builder2-26b1425e7/README.md`.
- **R45.26: backout SHIPPED ON, main a5508847c** (the orchestrator merged 466d96191; sim-baseline re-record + builder0 main check theirs).
  His round-43 ask. Worktrees -b2/-b2x/-mc/-mainref/-on/-b3/-b3x removed (branches kept; laptop disk 95 -> 89 pct).
- **S v5, the Terminus dev read 4 (builder0 heavy, bad080397, dev seeds 7001-7012, base v s4 v s5): s5 wedged +8.0 s a run (s4 -3.8),
  never-arrived +1.4 a run (s4 -0.75), D1 +0.6 se (s4 +2.2 se): NOT clean.** Two causes read in the logs, both in the rear-crew term:
  (1) **the two rear crews of every start layout stand ABREAST** (0.0-0.2 m apart in depth on Locks, Terminus and Crossing alike), so
  "the rear-most crew" was a float tie; on Terminus 7001 / 7002 / 7004 / 7010 it fell to the WEST crew while the deep seat sits 20 m
  east -> it crossed its squadmate's path, the squadmate was sent to the far west seat across its own, and the squad jammed in its start
  zone (wedged 17 -> 44 s; Locks' tie happened to fall the right way on all 12 seeds); (2) **the holder changed as the crews moved**
  (7007 / 7008 / 7012: at t44 the holder had driven 4 m ahead of its abreast squadmate, the deep seat passed to the squadmate, its
  station swung 25 m east across the old holder's, both lingered; wedged 23 -> 42 s). Fixes (tests 11 / 11, laptop): **0a0b822ae** the
  rear crew is the laterally nearest of the rear crews within `SEAT_LAST_REAR_TIE_M` 4 m (abreast = a tie, a column = a column);
  **ca8e71aba** the deep seat's holder keeps it while the order stands (`previous`), a fresh order reads anew. **Dev read 5 running**
  (builder0 heavy, `s5/dev5.sh`, three arenas 7001-7012, base v s4 v s5 at 0a0b822ae = the tie fix alone); dev read 6 with both follows.
  A bar only on a clean three-arena read. **Dev read 5 (tie fix alone, 0a0b822ae, builder0 heavy):** Terminus wedged +8.0 -> +0.1 s a
  run, but yield + blocked Crossing +10.7 (+2.2 se) / Locks +2.3 (+2.1 se): NOT clean. **Dev read 6 (both fixes, 1a9d053e8, builder0
  heavy, 36 paired runs an arm): CLEAN on every S line** -- D1 +5.8 se (s4 +4.4); wedged Locks +0.9 s a run (+0.6 se; s4 +3.5 / +1.7 se),
  Terminus -1.2 (-0.2 se), Crossing -6.6 (-3.4 se); yield + blocked Crossing +6.3 (+1.7 se), Locks +2.0 (+1.4 se), Terminus -7.1
  (-1.7 se); k-turn s better on all three; never-arrived +0.0. The two risks (Crossing / Locks yield + blocked) named in the filing.
  **Bar S v5 FILED (workstreams.md) on 11751-11798. Frozen tree fc639d7e0** (= the code tip: both seat fixes + holdway's verdict fix):
  its check on builder2 `>> remote: make check exited 0`, 27 targets, 26 passed, 2 NOT JUDGED (perf lines: not a judging machine),
  sim-baseline unmoved (`check_tip2/check-fc639d7e0.log`). **Series LAUNCHED 21:05 PDT** from `../godot-manoeuvre-s5`, every leg on
  builder0 light at J=4 (R45: builder2 is orders' G2 series; builder0 holds one series after its 19:52 OOM), driver `bars_s5.sh`,
  evidence `~/overnight-manoeuvre/r45/bars_s5/`. **Ship candidate prepared** (used only if D1 and every guard pass): `wip/manoeuvre-s5-on`
  **6ec15dff0** in `../godot-manoeuvre-s5on` = fc639d7e0 + SEAT_BOUND / SEAT_ORDER / SEAT_LAST_OPEN default ON (`--seat-bound=off`,
  `--seat-order=off`, `--seat-last=bound` the escapes) + the three default tests flipped + two bound-geometry tests pinning the open
  seat off (3 files, 12 / 8 lines; seat tests 13 / 13 laptop). **MOOT: Bar S v5 FAILS AS FILED (workload landed 21:18 PDT, 72 paired
  cells, 0 SCRIPT ERROR):** D1 PASS wide (220 -> 329, **+8.4 se**); guards: Crossing yield + blocked **+9.85 s a run (+4.1 se)** FAIL,
  Crossing k-turn +2.1 se FAIL, **Locks wedged +3.37 s a run (+3.2 se)** FAIL (S v4's +6.4 halved, not cleared); Locks yield + blocked
  +2.0 se (at the line), Terminus clean (k-turn -9.2 se), never-arrived -0.33 a run. Cause read on Crossing 11751: the Battery yields to
  ITSELF in its start zone (Battery_3 <-> Battery_1, Battery_4 <-> Battery_5 mutual yields, ~45 crew-ticks a pair; base: none): the
  open last seat and the rear-crew term deal the two-row layout seats whose paths cross. **The seat rules stay OFF; the candidate
  worktree removed (branch kept).** The remaining legs (group, fights, G1 probe) finish on builder0 light for the record. Evidence
  `references/round45/manoeuvre/barss5-builder0-fc639d7e0/README.md`. Round 46 (named there): the rear-crew term must respect the
  lateral order of the rest of the squad, or the open seat goes on the squad's line of advance, not the shape's deepest slot.
- **holdway (A6 v4 FAILED on contacts_far): the cause read on seed 11466 (laptop, trace):** under holdway the street verdict's "time to the
  middle" ran along each crew's ORDERED way; a crew of A ordered to a seat BESIDE it (west, at the order's first ticks) read 1.2 s to a
  middle 60 m away, became A's lead, and A (the squad in the open) was told to come on; B waited 85 s while A's far crews came through
  (32 contacts at the mouth). Across A6 v4's 12 head-on seeds the verdict flipped to B on 4 (11450 / 11462 / 11466 / 11472) and the
  three locks_lock seeds where B waits in both arms read more far contacts too. **Fix fc639d7e0** (tests 10 / 10, 158 traffic + engage
  tests green, laptop; the new test fails without it): under holdway the time to the middle, and the lead's direction for the street
  test, run along the SQUAD'S way; OFF unchanged. **Re-read of 11466 with the fix: a genuine near-tie** (B 6.6 s v A 6.7 s to the
  middle, both leads reading "open"), decided by the group-id tie-break -> B still waits on this seed. The sideways-way bug was real; the
  remaining flips are the verdict's coin toss between two squads 32 m from the middle at the first tick, which no holdway code decides.
  **holdway dev read 1 (builder0 light, fc639d7e0, A6 v4's 24 seeds both arms; `a6v5/dev1/table.txt`): contacts_far 9 -> 60, +2.12 a run
  (se 1.38, z 1.54; A6 v4 read +2.54 / z 1.81 on the same seeds)**: the fix mends two of the four verdict flips (11450, 11462: A waits
  again, 0 far contacts), 11472 still flips (0 far contacts), 11466 still flips by the near-tie (32); and the three locks_lock seeds
  where B waits in BOTH arms read more far contacts under holdway (11458 3 -> 8, 11460 6 -> 15, 11464 0 -> 5): an excess the verdict
  does not explain. **Read on 11460 (laptop, trace; terminus_west, B waits in both arms, far contacts 3 -> 19):** the wait's spots are
  laid across the waiter's squad WAY at the mouth, and under holdway that way is the mean of the crews' ORDERED ways, which at the
  order's first ticks includes crews driving to stations beside them: the way tilts 7 deg ((-0.03, 1.0) -> (-0.12, 0.99)), the spot
  line tilts with it and the spots are dealt to other crews (three of five east of the street's line instead of two, one at x -45.9),
  and A's far crews, coming down the street 10-25 s later, brush more of B's held crews. Same mechanism as the verdict flip: a crew's
  "ordered way" is its STATION's direction, not its squad's route. Everything the rule is for still passes wide (side jam -8.5 s a run,
  off_arrive -6.1 s, held_on -30.8 s, far_arrive -6.3 s). **holdway stays OFF; round 46 (named here):** define the ordered way as the
  squad's route direction at the crew (Element.transit route tangent, as backout's look follows it), not the crew's next station;
  a tie rule for the coin-toss verdicts (the squad whose lead is nearer the street's inside waits); then a bar on fresh seeds.
- **Then:** holdway's head-on release last; shortfwd parked (OFF) with the edge note. The earlier report block (the three round-45 bars,
  each failing as filed with his line passing) follows unchanged.

### The round's report as of ~16:05 PDT (B2 / S v4 / A6 v4 failed as filed) -- SUPERSEDED above: B3 read 19:45, backout SHIPPED ON (R45.26); S v5 read 21:18, FAILED as filed; holdway parked with its cause

- **(As of 16:05:) Nothing ships ON from this stream in round 45.** Three bars were filed and read on fresh seeds; all three FAIL as filed, each with
  the line he would feel passing and a guard missing: **B2** (backout, his container ask): his own start PASSES (Guns_2 reverses at tick 4
  and is round the box at tick 97, today at 44 / 140) and the deciding corpus PASSES (11 base-stuck poses, ON sooner in 11 / 11, median
  -3.0 s), but one pose of 48 was 6.3 s slower (fixed on the branch), Terminus k-turn seconds +2.6 se (the rule's own back-ups and the
  tanker behind the rigs turning to make way), and 4 of 24 impossible-staging guard poses leaned harder on their wall. **S v4** (the
  seat bound, his round-43 settle): seated within the bound by 15 s 219 -> 362 (+8.6 se), but Locks wedged +6.4 s a run (+4.4 se: the
  squad's last two crews pressing into a filled bound) and the fight kill share moved 0.049. **A6 v4** (holdway, the street jam): the
  side-street jam 397 -> 48 crew-seconds (-5.6 se) but the released crews brush the passer at the mouth +2.5 contacts a run (line +2.3).
  **Merge candidate (OFF code): stream/manoeuvre 5d4b3fa82** = my code + main e6e926160 + native's `pair/native-backout-skip`; its full
  check runs on builder2 (`~/overnight-manoeuvre/r45/check_tip/check-5d4b3fa82.log`; the hash and exit line go to the orchestrator the
  minute it lands); the default path is byte-identical to main (the default orders probe 60 / 60, builder2).
- **In his terms, what each would have changed:** (B2) a War Rig nose-on to a container backs out at once and swings the way its squad
  is going, round the box 3 s sooner, on his own start and on every pose where today's rig sits stuck; the costs he would also see are
  one crawl pose in 48 taking 6 s longer (fixed), a Terminus tanker doing an extra three-point turn behind the rigs, and a rig pinned
  against a wall pressing on it harder. (S v4) his first squad settles within 37 m of his click instead of 58, two seconds sooner on
  average, but the last tanker and gun truck in grind against the four already parked for 6 s on Locks. (A6 v4) the squad jammed in the
  side street for 30 s rolls through, at the price of a couple more friendly brushes at the mouth in a head-on meeting.
- **What was built and stands on the branch (all OFF, `=off` escapes where ON exists):** the staged nose-on corpus re-staged (six of
  round 44's fourteen poses stood inside a building, in water or against the arena wall; the squadmates are his deploy's hulls; an
  on-mesh assertion; the six old stagings as guard poses; `tests/manoeuvre/stage_check.py`); backout v2 (oriented-box hull test, the
  look follows the squad's transit route, a brain-order-only final goal, the stalled leg on net progress, the 11187 fallback that hands
  an empty look back to today's planner and keeps its cadence) with native's twin EQUAL on the whole B2 block (96 / 96) and the two
  stall fields + skip field in exec_fields; `--seat-last=open` (S v5's candidate: the open deep seat is the rear crew's); the
  `s_judge --cells` per-run wedged rows; `nosed_judge` guard poses; `NOSED_ONLY` / `NOSED_SETUP_ONLY` / `NOSED_GUARD` dev switches;
  the Makefile's gcp goals made light.
- **Round 46 starting points (numbers in this Status):** (1) B2b on 11601-11648 with 11187's pose as a named guard, after a filing
  redesign: judge the squad's time to clear its start, not k-turn seconds (a back-up IS a k-turn), and the rear crew's reaction to a rig
  backing toward it (Terminus +8 s on the tanker); the guard poses' wall ticks (11155 14 -> 102). (2) S v5: the open rear seat cures
  Locks (wedged -0.5 s a run, D1 +7.7 se, never-arrived 13 -> 3 on dev) and costs Terminus (+8.0 s a run): open it only where the bound
  shrinks the shape past the rear crew's reach, then a bar on fresh seeds (tactics-level GDScript, no twin). (3) A6 v5: the head-on
  release's brush at the mouth (seed 11466 0 -> 32 first). (4) The two-squad press (design note below). (5) The one-crew swarm / coil
  slot ~5 m off his click (engage's relay; `group_offsets` returns the anchor for a one-crew squad, so the offset is elsewhere).
- **To playtest (after the merge, with the escape switches):** `make skirmish` on Locks seed 56416 as the Gangs with `--traffic-on=backout`,
  click west from the start and watch Guns_2; `--seat-bound=on --seat-order=on` on the same start for the settle.
- **Cleanup for the close:** worktrees `../godot-manoeuvre-b2` (wip/manoeuvre-b2-freeze 0493977ed), `../godot-manoeuvre-b2x` (detached
  0493977ed), `../godot-manoeuvre-mainref` (detached main) and their builder folders (`godot-manoeuvre-b2` on builder2; `-b2x-light`
  on builder0; `-b2-light` on builder2; `godot-manoeuvre-mainref` on builder2); `~/overnight-manoeuvre/r45/` holds every series.
- **Questions for the lead:** none. **Requests to other streams:** native's two pairs are merged into this branch; nothing open.
- **Merge notes (shared files):** `Makefile` LIGHT_GOALS += `gcp-remote gcp-status gcp-start gcp-stop` (one line: `make gcp-remote` took
  a laptop heavy slot behind two other streams' lints; the gcp goals are ssh / gcloud calls). `native/**` only through native's pairs.

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

  - **B2 COMPLETE (14:24 PDT): FAIL as filed on three lines** (the 11187 ceiling; Terminus k-turn +2.6 se; **D3 guard poses 4 of 24
    worse**: 11155 wall ticks 14 -> 102, 11163 +0.3 s / +19 ticks, 11168 +3.5 s, 11171 +32 ticks). Everything else PASS: D1, D2's
    deciding 11 / 11, the other workload lines, b1_judge, group G5-G7 identical, G1 corridor 180 / 180 byte-identical, engage's Gorge
    line identical, fights G1-G4. **Evidence filed: `references/round45/manoeuvre/barsb2-builder0+builder2-0493977ed/README.md`.**
    Backout stays OFF (R45.14); the 11187 fix (0a80c3685) stays on the branch as OFF code for round 46.

- **main 78ef25caf merged (275aceb2e; R45.15, native N2, remote.sh's preemption re-queue; the workstreams.md conflict resolved to main's
  recorded copies again).** S v4's series (builder2 light, from 14:17) and A6 v4's (builder0 light, from 14:24) run on the frozen tree.

### M6 (A6 v4): FAIL as filed on guard 4 (2026-10-29 ~15:10 PDT)

- Frozen 0493977ed, builder0 light (`~/overnight-manoeuvre/r45/bars_a6v4/`; waited 27 min for the light slot behind B2's driver A),
  11449-11472 hold probe + 11473-11496 E1 probe, 0 SCRIPT ERROR. **Deciding side jam_s 397 -> 48 pooled, -29.1 s a run, z -5.6 PASS**
  (12 / 12 exercised); guards 1 (-14.3 s, z -5.0), 2a (+0.17, z 1.0), 2b one-sided (-30.2 s, z -1.8), 3 (contacts_mouth +14.2 a run,
  z 1.52), 5 (-2.3 s), 6 (E1 lines identical), 8: PASS; **guard 4 contacts_far 9 -> 70 pooled, +2.54 a run (se 1.41, z 1.81) v the
  line +max(1.645 se, 2) = +2.32: FAIL by 0.22 a run**, all on the head-on stages (11450 / 11458 / 11460 / 11464 / 11466). holdway
  stays OFF. Evidence `references/round45/manoeuvre/barsa6v4-builder0-0493977ed/README.md`. Round 46: the head-on release's brush with
  the passer at the mouth (v3 read the same line at +1.0 se).

### M5 (S v4): COMPLETE, FAIL as filed on two lines (15:51 PDT)

- Besides the Locks wedged guard (+4.4 se): group guards G5-G7 identical; the G1 corridor 180 / 180 byte-identical, g1v8 lines identical;
  fights G1-G3 PASS (deaths in give-ways 60 -> 53, stuck deaths 120 -> 150 under the +36.6 line, contacts -15 %), **G4 kill share Green
  0.634 -> 0.585, worst move 0.049 v 0.03: FAIL**. Evidence `references/round45/manoeuvre/barss4-builder2-0493977ed/README.md`. The seat
  bound stays OFF (R45.17).

### The round's merge candidate (R45.20; 2026-10-29 ~16:00 PDT)

- **stream/manoeuvre 5d4b3fa82** = the candidate below + native's `pair/native-backout-skip` 5ed7788ef (the exec field `_backout_skip_until`
  AND a C++ mirror of the fallback's cadence rule: native's stall twin found `_kturn_check` 6 v 30 at frame 31 on df74319af, so my
  "GDScript only" was wrong and their mirror closes it). Its full check runs on builder2 (`check_tip/check-5d4b3fa82.log`). Two earlier
  check launches were stopped before producing a number (df74319af, known red on the exec table; e4d9b95ac, launched by mistake on a
  tip without the field) and a stray `pkill -f` / pattern kill cost me two of my own shells today: kill by PID only.

- **stream/manoeuvre df74319af** = my code (all OFF: backout v2 + the 11187 fallback, `--seat-order=on`, `--seat-last=open`, the corpus /
  judge tools, the Makefile light-goal line) + main e6e926160 (E2 ON) + native's `pair/native-backout-b2v2` 04ce3abe9. Its full check
  runs on builder0 (`~/overnight-manoeuvre/r45/check_tip/check-df74319af.log`); **expected red on one test**: `test_native_exec_state`
  wants `_backout_skip_until` in `native/src/exec_fields.h` (the pair predates the fallback; native adds the one line). The default
  path's identity to main: the default orders probe (no flags, 60 rows) on my tip v a detached checkout of main e6e926160, builder2
  heavy, same machine, native ON: **60 / 60 ORDERS_PROBE_SQUAD rows byte-identical** (`~/overnight-manoeuvre/r45/identity/`). The
  builder0 check was stopped before it started (the orchestrator's main check held the lock; a known-red check); the full check runs
  once on native's exec_fields pair + this tip.

### Round 45 continues (R45.21, the lead: "why not just continue work as-is?"): B3 first

- **D3's cause (guard pose 11168, locks crawl +60, the hexagon wall 0.7 m behind; GDScript trace):** OFF and ON run identical planner calls
  through the first 4 s (the look fires at tick 2, every plan "blocked behind at 1.0 m (navmesh)", the fallback re-runs today's planner
  with the same refusal), yet the rig's position differs by 0.11 m at tick 45 while pressed on the box, and ON then takes a circle plan
  OFF never needed (t232 v t128). A look that fires and is withdrawn still moves the squad off today's tick-by-tick path (the mates
  beside it look too). **Fix (uncommitted, dev read running): no room behind on the NAVMESH = no look at all**: `_backout_look` requires
  BACKOUT_ROOM_M (2 m) of navmesh run behind the tail (`_free_run`, the same instrument as the nose test) before anything else; a rig
  that cannot back up drives exactly as today. The guard re-read on the pre-fix code (laptop, 24 poses) had 3 worse (11157 +1.4 s,
  11163 +26 wall ticks, 11168 +3.5 s); the fix's re-read runs on builder0 light (`~/overnight-manoeuvre/r45/d3/dev1/`: lab, guards,
  the 14 dev poses, 11187).
- **B3's replacement guard built (`b1_judge.py`): the squad's time to clear its start** (per arena, paired per cell, the last traced
  crew's tick clearing 8 m from its spot, ARM <= BASE + 2 se). Read on B2's workload rows (frozen 0493977ed): crossing +14.6 ticks a run
  (+0.6 se), locks +15.2 (+1.5 se), terminus -25.6 (-1.0 se): all PASS where the k-turn-seconds guard failed Terminus at +2.6 se.

- **D3 fix's dev read (builder0 light, `godot-manoeuvre-light`, GDScript, `~/overnight-manoeuvre/r45/d3/dev1/`):** lab 3 / 0 (his start
  t4 / t98, the stall stage t33); the 14 dev poses unchanged (3 / 3 sooner, ceiling worst +1.5 s, median 0.00); 11187 ON t207 v OFF t166;
  the 24 guard poses: 11168 (the wall) FIXED (t232 -> identical to OFF), 11155 / 11171 fixed; two seeds of guard pose 2 over the strict
  line (11157 +1.4 s, 11163 +0.3 s / +19 wall ticks) — pose 2's rig has room behind (its squadmates sit on a container), so a back-up is
  legitimate there and B3 judges that pose by the cost ceiling (+3 s), said in the filing. **Bar B3 FILED** (workstreams.md *Bars
  (round 45)*, 11701-11748, before any number) and the code committed; native's EQUAL + default probe on this hash next, then the
  freeze.
- **The laptop crashed ~17:00 PDT and restarted (builder2 rebooted too); session `godot-manoeuvre-bf` resumes at ~18:15.** Lost with it:
  the clean identity probe's copy-back (its rows recovered from builder2's `godot-manoeuvre-mc/build/identity3/`), the queued S v5
  Terminus dev read (dev4, never started), every local waiter. Merge candidate 5d4b3fa82's check (green, builder2) and B3's filing
  (26b1425e7) were committed before the crash; the shortfwd edits (below) were uncommitted and are picked up here.
- **The scout's short move, staged and first-read (laptop, GDScript; `tests/test_manoeuvre_short_move.gd`, `--traffic-on=shortfwd` OFF):**
  a lone Rat Rod (turning circle 4.5 m) on the open yard, his side's one-crew element sent 5 m to a point 56 deg off its nose: **OFF
  reverses at tick 3 for 21 ticks (0.7 s) and ends 1.9 m farther from the click** before coming round; **ON (the forward arc for a
  player's short move ahead-ish inside the circle, no k-turn plan) never reverses** but a point that deep inside the circle (2.8 m from
  the circle's centre) is orbited at ~1.7 m. His real Gorge case (engage's trace) was the k-turn PLANNER's 2 m back-up — an arc hit at the
  drop's edge — so the rule must keep today's planner when the forward arc meets an edge within reach, and the lab needs his geometry
  (the gap's edge) or the Gorge replay to decide. Parked behind B3 as OFF code; the ON lines are a dev read (`SHORTFWD_DEV=on`).
- **Queued after B3, before S v5 (engage's E5 relay via the orchestrator):** his short move to the lone scout (Gorge 83.7 s / 85.2 s): the
  click ~56 deg off the nose at 10.7 m, inside a wheeled scout's turning circle, so the mover starts a three-point turn and backs 3 m AWAY
  from his click for ~0.9 s before his next click replaces the order. A player's short move whose goal is ahead-ish (< 90 deg) but inside
  the circle should drive forward on the tightest arc (or stop and pivot) rather than reverse away. Dev read first; `movement.gd` + a
  native twin.

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

- **Bar S v4, deciding leg (frozen 0493977ed, builder2 light, 72 paired cells 11401-11424, C++ drive, 14:29 PDT):** **D1 seated within the
  bound by 15 s 219 -> 362 pooled (+1.99 a run, +8.6 se) PASS**; D2 (guard) yield+blocked -2.3 s a run (-1.6 se) PASS; per-arena
  yield+blocked +1.9 / +0.2 / -5.7 se PASS, k-turn -3.2 / -1.9 / -10.0 se PASS; **wedged s: crossing -0.1 se, terminus -0.2 se PASS,
  Locks +6.44 s a run (se 1.48, +4.4 se) FAIL**; never-arrived 243 -> 198 (-0.63 a run; Locks alone +0.9). Who carries Locks' wedged
  (sum over 24 seeds, by crew slot): 5: +88.5 s, 4: +54.2, 2: +23.7, 3: -12.0, 1: +0.1 — the squad's last two crews. **S v4 FAILS as
  filed on the Locks wedged guard** (the watch item); the other legs run for the record (`~/overnight-manoeuvre/r45/bars_s4/`).
- **S v5 dev read 1 (R45.17; `--seat-last=open` = the bound's deepest seat at its nominal depth; 2d88cff75's code; Locks 7001-7012,
  builder2 heavy, 12 paired cells an arm, `~/overnight-manoeuvre/r45/s5/dev1/`):**
  | arm | D1 seated by 15 s | yield+blocked s a run | k-turn s a run | never-arrived (pooled) | wedged s a run |
  |---|---|---|---|---|---|
  | s4 (bound + order) | 53 -> 83 (+3.5 se) | +0.0 | -3.7 | 13 -> 16 | +3.5 (se 2.0) |
  | s5 (s4 + seat-last) | 53 -> 80 (+4.6 se) | +1.5 | -2.1 | 13 -> 23 | +3.6 (se 1.8) |
  **Read (per cell):** on the Guns' seeds the press is GONE (7001 / 7002 / 7004 / 7010 wedged 15.8 -> 3.8, 15.4 -> 4.5, 11.1 -> 4.3, 11.1
  -> 4.6: the Tanker's 7 s vanished), but on 7007 / 7008 / 7012 it MOVED (3.9 -> 16.2, 6.0 -> 15.6, 4.5 -> 17.2: Guns_2, a War Rig, 6 s
  each plus the Hunters around it): the deep nominal seat went to whichever crew the seating's cost picked, and a War Rig driving
  to the far seat crossed the second squad. Pooled it is a wash; never-arrived worse. **Next (dev read 2):** bind the open seat to the
  REAR-MOST crew at the order (a depth-rank term in `seat()`), so the Tanker, not a War Rig, takes it.
- **S v5 dev read 2 (52493b473's code: the open deep seat is the REAR-MOST crew's alone; Locks 7001-7012, builder2 heavy, 12 paired cells,
  `~/overnight-manoeuvre/r45/s5/dev2/`):**
  | arm | D1 seated by 15 s | yield+blocked s a run | k-turn s a run | never-arrived (pooled) | wedged s a run |
  |---|---|---|---|---|---|
  | s4 (bound + order) | 53 -> 83 (+3.5 se) | +0.0 | -3.7 (-2.9 se) | 13 -> 16 | +3.5 (se 2.0) |
  | **s5 (s4 + seat-last, rear crew)** | **53 -> 89 (+7.7 se)** | -1.7 (-0.9 se) | **-5.5 (-3.1 se)** | **13 -> 3** | **-0.5 (se 1.3)** |
  **The press is gone on Locks dev**: per cell the Guns seeds read 5-8 s wedged (base 4-8), three cells read 2.3 (base 7.9), one cell
  (7009, the Guns2 squad) 14.6 -> 25.1. Round 46's S v5 starts from these numbers (a bar on fresh seeds; the three-arena read next).
- **S v5 dev read 3 (three arenas x 7001-7012, 36 paired cells an arm, builder2 heavy, `s5/dev3/`): NOT clean.** s5 v base: D1 127 -> 187
  (+5.1 se); never-arrived 115 -> 109 (s4: 89); k-turn -3.1 s a run (s4: -6.9); **wedged per arena: Locks -0.5 s a run (-0.4 se), Crossing
  +2.4 (+0.8 se), Terminus +8.0 (se 4.6, +1.7 se)**; s4's Terminus gains (yield+blocked -12.3 s a run, k-turn -13.5) shrink to -3.8 /
  -2.8 under s5. The open rear seat cures Locks' press and costs Terminus (the rear crew's far seat on that deploy). **No S v5 bar
  this round** (the orchestrator's condition: no arena worse than base). Round 46: the open seat only where the bound actually
  shrinks the shape past the rear crew's reach (Locks' 37 m v Terminus' room), or a per-arena read of what the Terminus rear crew does.
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

