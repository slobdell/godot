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

### NOW (2026-10-31 ~13:00): M1 tracing

**Plan (in order, smallest foundation first):** M1 trace every class-B clip at main df9aacc1a (new tool `make manoeuvre-yield-trace`:
tests/manoeuvre/yield_trace.gd, one YTRACE row a tick for the named crews and the chain they wait on; `tests/manoeuvre/ytrace_table.py`
prints it as state changes) -> M2 the give-way fix ON, tests first from M1's staged cases -> M3 Bar B filed before numbers -> M4 Sumps
Alpha_5 -> M5 watchdog v2 / Bar C -> M6 sliver 20/20 -> stretch.

**M1 cause 1 (crossing 13215, Green_Spears_1, main df9aacc1a, builder3 light, ticks 360-800): the in-place "hold" give-way that frees
nobody.** Green_Spears_1 (HOLD, move `face`, parked) is asked by squadmate Green_Spears II_1 (HOLD verb, returning to its post on a
move_to, rem 10.2 m, its route through Spears_1). No spot fits in the crowd (a 10-crew Hunters squad drives through the held Spears),
so `_begin_yield` falls through to `_start_yield(.., here, .., "hold")`: give way IN PLACE. A parked crew holding in place changes
nothing. The asker sits `blocked` by it, and `_negotiate` returns early on `mover.yield_to != ""`, so the asker never re-negotiates
or treats it as parked. The hold runs YIELD_MAX_SECONDS 6 s, ends unfinished (yieldfit2: not recorded), and is asked again
(yleft 14 -> 179 at tick 515). The loop broke at tick 675, only because Spears_1 got a new move of its own: 315+ ticks
(10.5 s+) with neither crew moving.

**M1 cause 2 (crossing 13215 80-100 s, gorge 13215 7-25 s, locks 13215 15-28 s): held crews play musical chairs.** A crew on HOLD at
its post is asked by a passing or returning squadmate, gives way 5-10 m off its post (`spot(5,9)`, `spot(5,-9)`, `back(6)`), and
HOLD's return (a move_to back to the post) drives it into the next held squadmate and asks THAT one off its post. Crossing:
Wrenches_2 yields 2430, returns 2490, yields 2580, returns 2610; Wrenches_1 / Hunters_2 / Hunters_4 the same, ~10 s. Locks:
Spears II_6 (HOLD) gives way to Spears_7, whose move ends 2.2 m from II_6's post, where it holds. II_6's return asks Spears_7 to
`back(6)` toward II_6's own post, and both push for ~7 s (600-810). Gorge: both causes together. Spears II_2 holds in place 4 s for
returning Spears_1, then the passing Wrenches push it off its post. Guns_4's HOLD return is blocked 10 s by Guns_1 / Guns_2, which
give way (in place, and to spot(10,0)) to passing Hunters.

**Not class B at main (the clip's moment does not reproduce at df9aacc1a):** sumps 13216 Rust_Battery_1 (arrived on HOLD, nobody
near); crossing 13216 Rust_Hunters_4 (its order FLAPS move <-> hold every 3 ticks, 1761-1776, and Rust_Hunters_2's with it: an
element / order flap, relayed to orders through the orchestrator).

**The two causes, named:** (1) a PARKED crew gives way IN PLACE: it frees nobody, and the asker waits on it and is re-asked every
6 s; (2) a crew on HOLD leaves its post to give way, and HOLD's return starts the next give-way. Mutual yield between two movers
was NOT the cycle in any clip (the "a crew yielding to one that yields to it" guess).

**M2 built (`heldpost`, ON, `--traffic-off=heldpost`):** Movement.ask: a crew on HOLD at its post (brain verb hold, move order not a
move_to) refuses every ask but via `behind`, offering T7's pass lane when there is one. Movement._begin_yield: a parked crew
(not under way) refuses instead of the in-place hold. Counters `heldpost_refusals`, `heldpost_holds_refused` (route_arms). The C++
yield has no mirror yet, so while ON every ask runs the GDScript yield (Traffic._chain_native, native_yield off), as holdyield did
before its twin. Replay stamp: MatchRecorder.rules() `heldpost` + tests/replay/rules.py (dated at the commit; re-date at the merge).
Test: tests/test_manoeuvre_heldpost.gd.

**Plan change (orchestrator, 2026-10-31 ~15:00, from spotter's list-B at df9aacc1a):** 9 of the 11 batch-2 clips he judged B are
MOVING squadmates jammed for 8 s+, not held crews (held crews are 11.63 of 17.00 B moments a fight, but short). So after Bar B, M2b
= the moving-squadmates jam (4.55 moments / 29.5 crew-s a fight), ahead of M4 / M5. **First read of list-B's moving rows:** the
longest ones are a QUEUE BEHIND A CLASS-C HEAD. On crossing 13215 / 13152, Rust_Guns_3 waits on Guns_2, which waits on Guns_1,
for 180-200 s of a CPU spring-ambush MOVE. Seats are 8-13 m ahead and crews stacked 2.7-5 m apart, and Guns_1 is #18 (`no_path`
the whole match). Crossing 13175 Green_Guns_3 / Guns_1 and 13206 Rust_Eyes_2 / Eyes_1 are the same shape. So M2b's first candidate
overlaps M5: the head gives up an unreachable goal to the nearest reachable spot, and a crew blocked by a stuck squadmate within a
few m of its seat for N s settles there (arrived) instead of pushing forever. To trace first.

**Orders' O2 hand-over (orchestrator, ~15:20): class D's top ten at df9aacc1a are DRIVE stalls on good move orders, mine.**
Rust_Battery_5 gorge 13147 (speed 0 while `driving` 78 s, 17.5 m short); Rust_Lances_4 crossing 13171 (creeps at 15 m for 21 s);
Rust_Battery_3 locks 13187 (reverses 17 s); batch 1's #28 (circling, to_go flat at 118 m). Also Rust_Eyes_5 crossing 13174 15-31 s (a reroute points the route behind it; it drives on away (route_off 179, path +57 m in 5 s), then saws -1.6 / +1.3 m/s for 9 s at to_go 74-75 m before it lines up; rows in spotter's list-D.md). Full table in stream/orders' brief
Status. Artillery stopping short is folded into M2b+M5 where it is the same cause; the rest come after M5. Order: Bar B -> M2b+M5
(the stuck head gives up its unreachable goal, the queue settles; the drive's safety net, engage makes the spot reachable when
chosen) -> M4 -> class D drive stalls -> M6.

**M4 staged (not yet committed, scratchpad):** Sumps, Charlie_1 / Charlie_4 parked where his census had them (tick 2940), Alpha_5 on
his move. OFF and ON are identical: Alpha_5 stops at (-6.2, 29.9) between the batteries and is not past x < -12 in 20 s (blocked
3 s). heldpost does not fire (no in-place hold in the stage). So his case is not cause 1 in this stage. Trace next.

### Bar B (heldpost), FILED 2026-10-31 ~14:45 PDT, before any number on 13217-13264

**What he picked it for:** squadmates stop backing and filling around each other; a held crew stays put (his class B, 64/64
"dumb"). **Arms:** OFF = `--traffic-off=heldpost --brains-off=native_yield`; ON = the default tree (heldpost ON, which forces the
GDScript yield). Both arms run the same GDScript yield, so the rule is the only difference. **Machine:** builder3, the full-check
tree named before the series (C31.1). **Workload W1 (deciding):** 48 CPU-v-CPU showmatch fights an arm, the spotter feature probe
(tests/spotter/feature_probe.gd, `--skirmish --demo-match --clean --mute`, 240 s, native), seed 13217+i on map i mod 6 (terminus,
crossing, locks, sumps, gorge, parade), i = 0..47: 8 fights a map. Paired by fight; judge tests/manoeuvre/barb_judge.py
(`--selftest` is the mutation check: every line fails on a staged pair built to break it, lesson 350).
- **D1 (deciding): jam_s a fight** (crew-seconds `yielding`, or `blocked` by a friendly crew: class B's own signal): paired mean
  ON-OFF < 0 and z <= -2.0.
- **D2 (staged):** tests/test_manoeuvre_heldpost.gd green in the ship check (the held crew stays within 1.5 m of its post and the
  asker gets past it within 30 s; an unheld parked crew moves exactly as OFF).
- **G1 the asker's wait on a held crew** (the orchestrator's line: "refuse" can make an asker wait longer when the pass lane fails):
  heldwait_s a fight (crew-seconds blocked by / yielding to a crew whose order that second is hold): paired mean <= +5 and z < +2.
- **G2 friendly contacts:** friendtouch_s a fight (crew-seconds touching a friendly hull): z < +2.
- **G3 wedged / no progress:** noprog_s a fight (on a move, > 15 m to go, < 1 m gained in 5 s): z < +2.
- **G4 the fights:** crews alive at the end, each team: |paired mean| <= 0.5 and |z| < 2.
- **G5 holdyield's post drift (Bar H D1):** engage's lane probe on 12328 with the ON arm: post drift <= 1.0 m.
- **G6 the authority probe (a held crew never moves):** engage-authority-probe 13019-13024, both arms: hold / stop `moved_m`
  ON <= OFF + 0.5 m on every seed, and `taken_back` unchanged.
- **G7 orders' group-click probe:** Bar M's group probe (orders-group, 13001-13006 x terminus / crossing / locks / sumps, crew
  heading), barm_judge: all_in_s z < +2 and never_in not up.
- **G8 Bar M's buried line and the rest:** the ship tree's full check exits 0 (test_manoeuvre_noprogress and buried's tests in
  it), no SCRIPT ERROR in either arm's logs.
- **Read, never a bar (C48.2):** spotter's class B rate at the merged main v its df9aacc1a "before" (17.00 moments / 69.7 crew-s a
  fight; held-crew share 11.63 / 34.3).
- Amendments: at most two, before the numbers (lesson 345).
- **R48.11 (orchestrator, arm detail, not an amendment):** the named tree is native's pair = stream/native 1f6559852 (the C++
  mirror, main's N5, the adopted baseline, FIFO lock) + this stream's fix commit + native's gate lift, with ONE full check there.
  Both arms add `--brains-off=native_yield`, so both still run the GDScript yield. Every Bar B number comes from that tree (main
  moved under N5: every fight differs from tick 1).
- **d6b28827b's own check (builder3, exited 2, 3612 / 21):** 20 native twin asserts fail by construction on this branch alone (the
  gate forces the GDScript yield; the pair lifts it). The 21st, test_nav_yield_fit, expected a parked rig to give way in place.
  heldpost refuses that on purpose, so the test now reads both arms (fix commit below; quick-remote builder3 5 / 0).


