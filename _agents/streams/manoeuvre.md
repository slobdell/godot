# Stream: manoeuvre (squadmates stop jamming each other; a stuck crew tries something else)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 345, 352, 353, 354), `_agents/judging.md`, `_agents/workstreams.md`
> **Round 48** (C48.1-C48.4, R48.1-R48.3) and **Round 47** (C47.1-C47.11; R47.42 Bar W, R47.43, R47.47), your last brief
> `streams/archive/round47/manoeuvre.md` (FINAL REPORT and its round-48 list), spotter's classes
> `streams/references/round47/spotter/batch1-classes.md` (**B** and **C** are yours), `game_design.md` *His spotter labels* and *His answer
> on spotter batch 2*. **You own:** movement's drive / unstick / side-step / avoidance / yield / backout and the no-progress watchdog
> (`game/ai/movement.gd` but the planner seam), `game/ai/traffic.gd`, `game/ai/wall_contact.gd`, `game/ai/avoidance.gd`,
> `game/ai/noprogress_census.gd`, `game/tactics/tactics_formation.gd`'s manoeuvre functions, `game/tactics/element_plan.gd`'s `grouped()`
> and converge, `tests/manoeuvre/**`, `tests/traffic/**`, `tests/test_manoeuvre*.gd`, `tests/test_traffic*.gd`, `tests/test_formation*.gd`,
> `mk/manoeuvre.mk`; R47.43's one TankBrain line; **GRANT (R48.2)** `game/ai/pathing.gd`'s `reroute` / `reroutes` bodies and
> `tests/test_pathing_reroute.gd` (route is not running; the watchdog asks, `Pathing.reroute` decides). Read: `make route-trace`,
> `make route-census`. **Model:** Opus. **Machine:** builder3. **Seeds:** 13217-13312. Dev 7001-7012 (never a bar).

## The lead's direction (verbatim)

2026-10-30, Locks: "At least one them just drove straight forward into a building and got stuck, which makes no sense, and it makes our
units look dumb"

2026-10-31, on spotter's flagged clips: "For 100% cases that I've checked, it does in fact look dumb." (64 of 64 flagged clips "looks dumb",
batches 1-2; class B was the largest class in batch 1, 9 of 30.)

Memory: units must look smart and under his control; contention first; smart AI on both sides; his direct order to a unit wins.

## Where things stand (main df9aacc1a GREEN builder3 3630/0)

- **ON:** buried stations (Bar M), holdyield (Bar H: a held crew never gives way toward the enemy), backout, shortfwd. **OFF:** the
  no-progress watchdog `noprogress` (Bar W FAILED, R47.42: on touched cells it ADDED +24.6 no-progress crew-s a cell; Crossing worst
  +58.5; R47.25's reroute body is inert without it).
- **Class B, give-way loops (9 clips in batch 1; batch 2 adds more):** phase `yielding` / `blocked` by a NAMED squadmate 5-18 s, the crew
  reverses or swings off its route for a crew of its own squad that is itself waiting, sometimes under fire. HOLD orders yield too
  (#6, #7, #29, #30 — a crew told to hold drives off its post to give way; holdyield stops only the give-way TOWARD the enemy).
- **Class C, stuck and never gives up (5):** blocked `terrain` / `no_path` 8-37 s; #18 Rust_Guns_1 sat 224 s (crossing 13215) on a
  spring-ambush MOVE with no path; #26 reversed 37 s into Barricade_45; artillery #3 / #14 stuck 20-97 m short of their firing spots.
- **His Sumps Alpha_5** (round 47 list item 1): his direct move blocked 10 s by his own set-up battery Charlie_1, 6.6 m away, no go-round.
- **The sliver test** (R47.47) is PENDING: a knife edge, 19/20 on jittered starts; the bar is 20/20 (`make native-repeat ...
  REPEAT_JITTER=on YIELD_CYCLE=on`).
- Every batch-1 clip line reproduces (`make spotter-clip ...` in the classes file); batch 1 ran on 1209a934f, so re-run on main first.

## Backlog (in order)

1. **M1 class B traced at main df9aacc1a.** Re-run every class-B clip (batch 1 and batch 2's B-like flagged clips: ask spotter for the list
   through the orchestrator, C48.3) on main; for each, the chain of who waits on whom, tick by tick, and why the loop never breaks.
   Name the cause(s) in Status and message the orchestrator. Expect one or two causes behind most of them (mutual yield; a hold that yields).
2. **M2 the give-way fix, ON (C47.2 smallest change):** e.g. a crew never yields to a crew that is itself yielding to it (break the cycle by
   a stable priority), and a crew on HOLD never leaves its post to give way (it may turn). Tests first, from M1's staged cases.
   Escape `--traffic-off=<name>`. Twin through native before ON (C47.6). Replay stamp entry in the same merge (lesson 354).
3. **M3 Bar B** in workstreams.md *Bars (round 48)* BEFORE any number, on 13217-13264: deciding = yielding/blocked-by-friendly crew-seconds
   a fight (the class's own signal) and the staged cases; guards = arrival all-in, contacts, wedged crew-s, holdyield's post drift, the
   authority probe (a held crew never moves), orders' group-click probe rows, Bar M's buried line. Name the green hash.
4. **M4 his Sumps Alpha_5:** his direct move past a parked, set-up friend. Stage Charlie_1 at its tick-3060 pose; "his crew goes round or the
   unordered battery shuffles within N s". Ships under M3's bar or its own.
5. **M5 class C, watchdog v2:** why Bar W's reroutes cost more than they saved on Crossing (R47.42), then the narrow version: trip only when
   the crew is off the navmesh island or `no_path` for > N s, a per-crew reroute cap, then give up the goal to the nearest reachable
   spot and say so in the order trace. Bar C on 13265-13312. #18's whole-match sit is the headline case.
6. **M6 the sliver test 20/20** (R47.47) once M5 changes the watchdog it arms.
7. **Stretch:** the doors' overstay consumer ON once doors reach a dealt map; holdway head-on; backout pose 10.

## How to verify

`make quick-remote` to iterate (`QUICK_BASE=<your last green>`); `make remote T=check` only for a hash you will NAME (read `>> remote: make
check exited <N>` and `N passed, M failed`, never an exit code through a pipe). `make spotter-clip ...` to watch a case before and after;
screenshots looked at. After your ship merges, spotter re-reads class B / C at the new main (C48.2): that is the number he'll hear. Every
number with commit, machine, workload, n.

## Don't touch

Target choice / RETREAT / gunnery (engage), `game/control/**` and the follow station (orders), `native/**`, the planner and the rest of
`pathing.gd` (route's; only the reroute grant), `arenas/**`, `game/camera/**`, `game/units/**`, `tests/baselines/**`, `tools/spotter/**`.

## Waiting on the lead

Nothing at launch. His playtest notes on round 47's ships arrive through the orchestrator.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
