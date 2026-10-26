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
