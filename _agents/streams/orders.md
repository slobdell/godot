# Stream: orders (his many-squad order sets off as one: a shared direction, nobody nose-to-nose)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 41** (C41.1, C41.3,
> C41.4). Your round-40 brief: `streams/archive/round40/orders.md` (Status: G1 v6, G3 v9, the probe). **You own:** `game/control/**`,
> `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`; GRANT `game/ai/planner/**` for a group
> order's departure order and route spread only (C41.3). **Model:** Opus. **Machine:** builder0 light lane (J<=4); builder2 for a bar
> series. **Seeds:** O2 9101-9124 (C41.1).

## The lead's direction

His playtest of round-40 main (2026-10-26, verbatim in `game_design.md`): "when I'm controlling a large set of squads at once and
commanding all of them to go somewhere, a bunch of units block other units, but this is a symptom of all units generally not moving in
the same direction (i.e. a scout is pointed north and thus blocking a unit that's trying to go West) ... I suspect that we might get
better navigation with a little more coordinated movements".

Manoeuvre owns what a blocked crew does (wait, don't detour). You own the order itself: who leaves first, which way each squad turns,
which route each takes, so fewer crews start pointed across each other's lines.

## Where things stand (main at launch: see HANDOFF)

- T1 ON (`--deploy-arrive=settled`). G1 v6 and G3 v9 OFF with causes in your archived Status; G1 v7 parked (its dev read: a1602cca9,
  round40/orders-t1on).
- The orders probe (`tests/orders_probe.gd`) and probe_wedge (manoeuvre's, extends yours) measure squad-in times for a group click.

## Backlog (in order)

1. **O1 the group-order workload + start census.** Build (or extend the probe into) the case he played: select every squad (8+ on the
   bigger maps), one move order across the map, squads starting at mixed headings. Report per order: time until every squad is in,
   how many crews start with their nose > 90 deg off their first route leg, how many first-leg routes cross another squad's, crews'
   blocked-seconds. Give manoeuvre and the orchestrator its hash the minute it runs (manoeuvre's Q1 census reads on it).
2. **O2 a coordinated departure.** From O1's numbers pick the cheapest lever and say why before building: departure order (the squad
   whose path is clear goes first; those behind wait their turn rather than all starting at once), a shared heading (crews turn toward
   the group's direction of travel before setting off), route spread (adjacent squads take non-crossing routes / lanes). Build OFF,
   lab, then file **Bar O2** on 9101-9124 before any number: deciding = every-squad-in time on the group-order workload; guards = never-in,
   G1/G3 lines as round 40 used, fight lines. Name manoeuvre's Q2 switch state (C41.3).
3. **C41.4 getter for camera (on request):** if camera asks, expose a read-only "player is aiming" read (cursor over a pickable target,
   a drag in progress, an order pending) without changing pick behaviour.
4. **Stretch:** G1 v7 (archived Status) on the T1-ON main.

## How to verify

Pure tests (`tests/test_control*.gd`); the probe; `make quick-remote`; a full check of every hash you name. Smoke he can run:
`make skirmish ARENA=terminus SKIRMISH_FLAGS="<O2's flag>"`: select all, send them across, watch them set off.

## Don't touch

manoeuvre's movement/traffic, the planner outside C41.3's grant, camera's `game/camera/**`, settle's deploy functions, `native/**`,
`tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### NOW (2026-10-26)
- **REPORT so far (2026-10-26 ~03:00):**
  - **O1 DONE (8b828ec59, `make orders-group`).** Census (builder0, 8b828ec59, native off, dev seeds 7001-7006, n 6 a
    cell; evidence `references/round41/orders/o1-census-builder0-8b828ec59/`): his "pointed different ways" is mostly not
    the cause. All-in crew v formed headings: terminus 57.1 v 60.5 s, locks 66.2 v 61.9 s; crews nose > 90 deg are
    ~1 s slower each. First-leg crossings 0 in 48 runs (roads converge on one street / deck). The time goes to traffic:
    under-way crew-seconds a run yielding 50-258, slow 53-197, blocked 5-67. Never in within 90 s: crossing 6 / 6, locks
    3-4 / 6, sumps 3-5 / 6; terminus always in. Sent to manoeuvre + orchestrator.
  - **C41.4 DONE (b973ba955, quick-green builder0 356 / 0):** `RtsControls.is_aiming()`; skirmish hands it to the rig with
    `rig.set("aiming", ...)` (RtsCamera has no `aiming` until camera's lands; camera types it after merge).
  - **O2 lever = departure order (approved by the orchestrator).** Why: no crossings to spread, headings cost little, and
    the jam is crews meeting where five squads' roads converge at once. Built OFF (25525980a): `game/control/departure_queue.gd`.
    **Bar O2 FILED** (25525980a, below). Probe fix 4c9dd0a67 (a waiting squad read "in" from its old task; OFF unaffected).
  - Lab (laptop, 4c9dd0a67 tree, s7001, n 1 a map; a sign, not a number): terminus all-in 75.4 -> 59.0 s; crossing
    never-in -> 93.4 s; waits 0-5.5 s, none by the cap; yielding 80 -> 53 and 320 -> 147 crew-s.
  - **Dev read 1 (v1 front-first; builder0 light, 25525980a, native on, crew headings, across click, 180 s window,
    7001-7006, n 6 a map):** all-in median main -> queue: sumps 120.0 -> 56.5 s, crossing 149.7 -> 91.4 (never-in 5 -> 4
    of 6), terminus 57.1 -> 61.4, **locks 73.5 -> 87.6 (never-in 2 -> 3)**. Dev judge: deciding FAILS (-7.9 +/- 7.6 s);
    wait guards pass (median 5.1 s of the 18 squads of 120 that waited; 0 by the cap). Locks: the flank squad with the
    longest drive sets the all-in time and v1 ranks it last, so it is the one that waits. No run touched by the old probe bug.
  - **Dev read 2 (v2 `--group-depart-rank=drive`; 3d35eee6f, same setup):** nearly nothing: locks and sumps identical to
    main, crossing never-in 5 -> 4, terminus 57.1 -> 62.8; paired -1.0 +/- 2.0 s; 16 of 120 queued, 2 by the cap.
  - **Finding:** the corridor rule rarely fires (16-18 of 120 squads); the jams form where roads merge mid-way.
    **v3 `--group-depart=merge` (b8116ec21):** each pair's first merge outside the halt area; the shorter-drive squad
    goes when the longer one's tail is no farther from the merge than it is, less 10 m.
  - **Dev read 3 (v3, b8116ec21, same setup):** the only variant that moves never-in (15 -> 8 squads; locks 2 -> 0;
    contacts 34157 -> 26085; paired all-in -8.7 +/- 6.6 s, deciding still fails) and it does it by holding squads: median
    18 s of the 40 that waited, 17 released by the 20 s cap, 18 of 24 clicks with a squad waiting > 5 s (every wait
    guard fails: he would see squads that did not hear him). Third variant on the same seeds: partly fitted.
  - **O2 RESULT: written up, no bar** (orchestrator's call for this case). Departure order is not where the time goes:
    the time is crews meeting inside the merges (stalled / crossing / same_way, manoeuvre's Q1), i.e. what a blocked crew
    does, which is Q2. Switches stay OFF in code (`--group-depart=queue|merge`, `--group-depart-rank=drive`); evidence
    `references/round41/orders/o2-dev-reads-builder0/` (ba0d14aab). The stale check of 25525980a was stopped (mine,
    exit 143); a full check of ba0d14aab runs on builder0.
- **Plan:** O1 census probe (done, 8b828ec59) -> census on builder0 dev seeds 7001-7006 (crew v formed headings) -> hash to
  manoeuvre + orchestrator -> O2: pick the lever from the numbers, build OFF, lab, file Bar O2 on 9101-9124 before any number
  -> C41.4 getter if camera asks -> stretch G1 v7.
- **Decisions:**
  - "8+ squads" in the brief: the game fields at most `Units.MAX_SQUADS` = 5 squads a side (garage and skirmish), so his
    biggest group order is five FULL squads (25 crews, `tests/control/orders_probe_group_5.json`, mixed tanks/IFVs/scouts).
  - Mixed headings: every crew a seeded random heading just before the click (`--probe-headings=crew`), as squads stand
    after a fight; `formed` (untouched) is the control.
  - "Across the map": the click is the point opposite his army through the arena's middle, halfway to the far edge
    (`--probe-target=across`), so every squad drives 110-150 m through streets; the base probe's deck click is short.
  - Blocked-seconds are split by Movement's own phase: `blocked` (by a friend), `yielding` (stepping aside), `slow` (any
    other under-way tick < 1 m/s, its own turn on the spot included).
- **O1 first look (laptop, 8b828ec59-equivalent tree, terminus s7001, crew headings, n 1):** all in 75.4 s; squads 1 and 5
  (the flanks) 75 / 63 s, the middle three 23-39 s; squad 1 drove 224 m for a 150 m route; 12 of 25 crews nose > 90 deg
  off their first leg; first-leg crossings 0; crew-seconds under way: yielding 80, slow 60, blocked 10.

### Bars (filed here before any judged number; the orchestrator records them on main)
- **WITHDRAWN UNREAD (2026-10-26, orchestrator agreed): Bar O2 v1** (no bar number was ever read; dev reads 1-3 below
  replace its rule). Kept for the record:
- **Bar O2 DEPARTURE QUEUE (orders, round 41; filed 2026-10-26 before any number on 9101-9124; switch
  `--group-depart=queue`, OFF).** What he would see: he selects all five squads and clicks across the map. Every squad
  takes the order (the same marker on the click). The front squad sets off at once, and each squad behind it sets off as
  soon as the street in front of it is clear of the squads ahead, so the crews pull out one squad after another instead
  of all nosing into one street together. Every squad gets in sooner, and no squad stands long enough to look as if it
  didn't hear him.
  - **Turn rule (as sent to the orchestrator, approved):** rank front to back along the approach; corridor = the first
    30 m of the squad's own navmesh route (at most half of it), 7 m a side; it leaves on the first tick no living crew
    of a squad ranked ahead stands in it (an arrived squad's crews don't count; a still-waiting squad's do); cap 20 s;
    a squad still driving an earlier task leaves at once; a new order cancels the wait. Plain move / attack-move to 2+
    squads only (no shift).
  - **Arm:** `queue:--group-depart=queue`. Base `main:`. **Manoeuvre's Q2 OFF in both arms** (C41.3: OFF until it
    ships; if Q2 ships first, the series re-runs on that main with Q2 ON in both arms).
  - **Tree:** a frozen detached worktree at the commit whose full check is named green here (main as launched + O1's
    probe + O2's switch; T1 ON both arms as main has it; every G1 / G2 / G3 switch OFF both arms).
  - **Probe:** `tests/control/orders_o2_bar.sh b2 queue:--group-depart=queue "9101 ... 9124" "9101 ... 9112" <out> 8`
    (builder2, Spot re-runs). Part A his group order (`make orders-group`: crossing / locks / sumps / terminus, crew
    headings, five full squads, the across click, window 180 s), **FRESH seeds 9101-9124**, n 24 a map. Parts B / C
    (guards) seeds 9101-9112, n 12 a cell: B the probe's 12 street cells (locks / crossing / terminus x 3 / 5 x click /
    route) + his click (terminus `--probe-click=-29.3/85.8`, 3 / 5); C the probe's fight (`--probe-fight=on`, terminus /
    locks, 5 squads, click).
  - **Judge:** `tests/control/orders_group_judge.py <out> main queue` (filed with this bar, unamended once numbers are
    seen). Counter: squads queued > 0. **Deciding (part A, pooled, paired by map and seed):** all-in time (a never-in run
    counts as 180 s) mean paired difference + 1.645 se < 0; AND squads never in, arm <= base. **Guards:** part A: each
    map's median all-in <= base + 5 s; friendly contacts <= base x 1.1 + 5; **the wait** (orchestrator's): of squads that
    waited, median <= 6 s; released by the 20 s cap <= 10 % of squads queued; clicks with any squad waiting > 5 s <= 50 %
    (per-squad median / max reported). Part B: every R36.6 probe guard per cell (`orders_judge.probe_guards`: all-in <=
    base x 1.2 + 3 s, never-in no more, twitch <= base + 3 m, end foreign >= base - 3 m, crossed no higher), contacts
    <= base x 1.1 + 5. Part C: his kills, his losses, the CPU's losses within base +/- 1.645 se.
  - **Known risk:** a squad whose own place sits inside a squad-ahead's corridor start waits for it to arrive; the 20 s
    cap bounds it. A waiting squad keeps its old task; in his case (parked or holding) it stands still.
  - **Plus:** paired top-down shots of the across click on terminus, main v queue, looked at. A pass ships ON.
- **WITHDRAWN UNREAD (2026-10-26): Bar G1 v7**, replaced by Bar G1 v8 below before any bar number: its plus (the shots of
  his click, laptop s7007) showed the arm giving 3 of 5 squads places no nearer his click than they stood (squad 5's 103 m
  from it, 15 m farther than it stood; "in" at 0.1 s without moving). The deciding lines miss it on the open yard. Kept:
- **Bar G1 v7 TWO SIDES ON T1 (orders, round 41; filed 2026-10-26 before any number on 9101-9112; code ba0d14aab, all
  OFF).** What he would see: select all and click a street; every squad lands in that street, the nearest on it, the
  others stacked back along their own way in, none driving through another's halt, every squad in without a reshuffle.
  It is Bar G1 v6 (round 40, failed on one guard: terminus 5 route twitch, a cap deploy among passers) re-run on today's
  main, where T1 (`--deploy-arrive=settled`) is ON in both arms.
  - **Arm:** `sides:--group-lay=column,--group-rank-shift=half,--group-whole=click,--group-clear=reached,--group-lead=drive,--group-sides=both`
    (G1 v6's, unchanged). Base `main:`.
  - **Tree:** a frozen detached worktree at the commit whose full check is named green here (ba0d14aab or a docs-only
    descendant; main as launched; T1 ON both arms; DEPLOY_HOLD ON both; every G2 / G3 switch and O2's `--group-depart`
    OFF both arms; manoeuvre's Q2 OFF both arms).
  - **Probe:** `tests/control/orders_bar.sh b2 g1v4 <arm> "9101 ... 9112" <out> 8` (builder2, Spot re-runs), **FRESH
    seeds 9101-9112** (round 41's orders block; O2's bar was withdrawn unread, so they are unseen), n 12 a cell. Cells as
    Bar G1 v6: the 12 street cells, his click (terminus_his 3 / 5), yard_open 3 / 5 x click / route.
  - **Judge:** `orders_judge.py g1v4`, unamended from G1 v6 (deciding: places outside the corridor <= 25 % of base,
    route_left_m <= 50 %, re-dealt 0; guards: every R36.6 guard per cell over all 14 cells, contacts <= base x 1.1 + 5,
    yard_open identical; the old gate read reported beside).
  - **Dev evidence:** builder0 light, 941325eaa (= ba0d14aab + docs), native on, dev seeds 7007-7012, n 6 a cell: PASS
    every line (outside 26 -> 2, route_left 1037 -> 335, re-dealt 0, contacts 6554 -> 5155, 14 cells' probe guards,
    yard_open 96 / 96). `references/round41/orders/g1v7-dev-builder0-941325eaa/`. One variant read (G1 v6's arm, as is).
  - **Known risk:** round 40's s3805 squad-1 wedge (R38.44's whole-squad deal on a route's first click). On today's main
    (laptop, s3805, terminus 5 route) it is main that leaves a squad never in (squad 5), and the arm gets all five in.
  - **Plus:** paired top-down shots of his click, main v sides, looked at. A pass ships ON.
- **Bar G1 v8 TWO SIDES, NEVER AWAY (orders, round 41; filed 2026-10-26 before any number on 9101-9112; code: the commit
  below, all OFF).** G1 v7 + `--group-column-toward=on`: a column that would give any squad a place > 10 m farther from his
  click than it stands is refused (today's places stand). What he would see: as G1 v7, and a click beside his army never
  sends a squad away from it.
  - **Arm:** `v8:--group-lay=column,--group-rank-shift=half,--group-whole=click,--group-clear=reached,--group-lead=drive,--group-sides=both,--group-column-toward=on`.
    Base `main:`. Tree, probe, seeds (9101-9112, n 12 a cell), cells and judge (`orders_judge.py g1v4`, unamended) as
    G1 v7. **Added guard (filed now, before any number):** no squad row's place more than 10 m farther from the click
    than its start (`toward_m < -10`) in the arm beyond base's count + 2, over all cells.
  - **Variants read on the dev block 7007-7012: two** (v7's arm; v8). Lab: his click s7007 falls back to main's places;
    s3805 terminus 5 route keeps the column (all five in).
