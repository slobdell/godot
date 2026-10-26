# Stream: manoeuvre (a parked crew steps aside for a friend without wedging the squads behind it)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 40** (C40.1, C40.2) and
> *Rulings (round 39)*. Your round-39 brief: `streams/archive/round39/manoeuvre.md` (Status: *CLOSE REPORT* and its *round-40 input*
> section), evidence under `references/round39/manoeuvre/`. **You own:** `movement.gd`'s drive / unstick / side-step and traffic's
> give-way block, `game/ai/traffic.gd`, `tests/manoeuvre/**`, `tests/traffic/**`, `tests/test_manoeuvre*.gd`, `tests/test_traffic*.gd`,
> `mk/manoeuvre.mk`. A change to the C++ mirror (`native/**`, `begin_yield`) is native's: request it through the orchestrator (round
> 39's twin took a few hours). **Model:** Opus. **Machine:** builder0 light lane (J<=4). **Seeds:** 8101-8124 (registered, C40.1).

## The lead's direction

His standing bar: "the feel of the game needs to have the user perceive that the units are smart and under their control". What he'd
see today: a parked crew pushed off its seat by a passing friend keeps giving way down the street in a chain (round 38's s3866). Round
39's fix (stop the chain) held those crews in the street, and late squads wedged behind them.

## Where things stand (main at launch: see HANDOFF)

- **M1 `--giveway-chain` FAILED on G5** (never-in 2 -> 7; deciding -96.6 % at -8.4 se; G1-G4, G6 passed). Stays DEFAULT_OFF. Traced: late
  squads wedge behind seated crews the rule holds in a street with no way round. The 5 deterministic G5 runs are listed in your archived
  Status with `make manoeuvre-probe-wedge PW_CELLS=...`; native's C++ twin of the rule is on main (bb8043686).
- Instruments ready: `tests/manoeuvre/probe_wedge.gd` (extends orders' `tests/orders_probe.gd`; don't rename `_match`/`_squads`/`_order_tick`
  without telling orders), `wedge_trace` partner classes, `partner_table.py`.

## Backlog (in order)

1. **M1 v2: the give-way limit without the street wedge.** Start from the three directions in your archived Status. Test first on the
   5 deterministic G5 runs: every squad in on every one, and s3866's chain still stopped. Pick the direction that does both on the lab;
   record why. Native twin request if the rule changes `begin_yield` (via the orchestrator).
2. **Bar M1 v2** on 8101-8124 (filed before numbers; G5 never-in is a guard, unamended; name settle's T1 and S1 switch states, C40.2).
   A pass ships ON with one full check (CP40.2).
3. **M2 the long ORCA episodes (round 39's unrun stretch):** `make native manoeuvre-wedge-trace WEDGE_AT=locks,terminus,sumps
   WEDGE_RANGE=7001-7008` on builder0 light, then `python3 tests/manoeuvre/partner_table.py <dir>`; name the partner classes behind the
   82 long episodes and file the next fix (report; a bar only on a fresh block from the orchestrator).
4. **Stretch:** if M2 names a cheap fix, build it OFF and lab it. (Not built: holdrelease is withdrawn, 847429f96: ending a hold
   opens nothing.)
5. **M3 (R40.12, added by the orchestrator 2026-10-24 night): a wedged asker re-routes round its holder**, with the holder as an
   obstacle (M2's hold-wall). GRANT `game/ai/planner/**`. OFF. Lab on M2's longest WHEELED episodes, locks s7006 Rust_Battery_5 first;
   sumps s7004's hover Battery_1 is a named gap (orchestrator, 2026-10-25). Bar on 8601-8624, filed before numbers. A C++ twin, if
   needed, goes through the orchestrator.

## How to verify

Pure tests (`tests/test_traffic*.gd`); the wedge probe; `make quick-remote`; a full check of every hash you name before a series. Smoke:
`make skirmish ARENA=terminus SKIRMISH_FLAGS="--giveway-chain"` against without; five squads down one street, every one gets in.

## Don't touch

settle's deploy/halt functions, orders' `game/control/**`, balance's brains, `native/**` (request), `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### ROUND-41 ITEM 1 (top): a speed-only bridge-mouth rule (R40.24: F1 stopped OFF; balance's stat change carries behind it)

**The rule to build:** a WHEELED crew slows before a sharp turn on its route that its leader is in. ORCA's steering is untouched:
the crew keeps ORCA's direction and only its speed is capped, so it reaches the turn at a speed and a line it can make.
- Every F1 form changed ORCA's answer itself, and that reshuffled who meets whom across the whole map.
- What made the bridge case: a follower at 10-11 m/s, 7 m behind a leader slowing into the deck mouth. ORCA carried it wide past
  the entry (it never slowed enough to stay behind), and with a fixed 8 m turning radius no line back reached the deck.
- A speed cap keyed to the turn (e.g. the speed at which the turn is still reachable from here, given the min turn radius and the
  leader's place in it) leaves open traffic and straight streets exactly as today.
- **Judge it on the bridge drill:** the orchestrator's Bar F1 v2 design (R40.23) fits it as written.
  - Deciding: bridge-drill rim seconds on fresh seeds, BRIDGE_POOLED_SEEDS x ticks {1,8,15} x both sides, on main AND under
    balance's v2 overrides. ON <= 0.8 x OFF pooled at >= 2 se, and every surviving crew crosses in both trees with ON.
  - Guards: the wedge trace and the orders probe with M3's lines.
  - BRIDGE_POOLED_SEEDS is a plain make variable (bridge-series loops BRIDGE_SEEDS), so any seeds work.
- **A C++ twin** is needed before it ships ON (the cap would sit in the drive, inside native_drive's mirror).

**The evidence it starts from (all builder0 light, n 1 a run; bridge-pooled 18 runs an arm):**

| F1 form (commit) | Main tree: OFF -> ON | Overrides tree: OFF -> ON | Dev cells (12 fights / 24 runs, lab read) |
|---|---|---|---|
| v1: queue behind any moving friend ahead (1267b1635 / a4e34d70e) | 18/18 -> 18/18; rim 8.1 -> 9.9 s, deck 7.5 -> 16.2 s, arrival 36.6 -> 37.8 s | 17/18 -> 18/18; rim 14.2 -> 10.0 s, deck 17.1 -> 23.2 s | D +70 %; G3 +19 %, G4 deaths 493 -> 466, G7 +2.2 s FAIL; waits >= 3 s in most fights, longest 8.8 s behind 1.1-1.3 m/s leaders |
| v2: only with a turn > 45 deg within 2 radii (3f23a36ab) | 18/18 -> 18/18; rim 8.1 -> 5.9 s, deck 7.5 -> 6.4 s, arrival 36.6 -> 35.6 s | 17/18 -> 18/18; rim 14.2 -> 6.4 s, deck 17.1 -> 13.6 s | D +3.8 %; G4 deaths 493 -> 461 and G7 +2.3 s FAIL (terminus +20.0 / +13.8 / +12.0 s); no wait >= 3 s |
| v2 + the leader within 8 m of the turn (e516edcec) | 18/18 -> **17/18** (green t1 s1, 4.0 s); rim 8.1 -> 9.2 s, deck 7.5 -> 4.8 s | 17/18 -> 18/18; rim 14.2 -> 8.6 s | D -12 %; G3 +13 % and G7 +3.3 s FAIL; terminus s7001 squad 1 fixed, squad 5 +12.1 s |

- **The original cause** (rust t15 s2 under the overrides, 5a233f42b): Rust_S_3 was carried past the deck entry by ORCA round its
  slowing leader. It was not the native drive (identical with `--brains-off=native_drive`); `--no-avoidance` gave rim 0.
- **The terminus trace** (R40.23, 3f23a36ab): Green_Alpha_4 queued at 3.5 m/s for 6 s behind a steady friend because a route turn
  lay within 16 m. It reached the junction late into crossing squad 3, circled, and its squad came in 20 s later.
- **Main's own bridge margin:** with F1 OFF, main's three worst runs have a crew at the rim 1.5 s (a rust seed-2 run), 1.4 s and 1.1 s:
  1.5-1.9 s under the 3 s line, identical in all three labs (deterministic). A stat change (balance's v2: 5.1 s) or a traffic rule
  (F1 final: 4.0 s on green t1 s1) is enough to push one crew over. The drill's margin is thin, not just balance's tree.
- **F1's code stays on the branch, OFF** (`--traffic-on=follow`, DEFAULT_OFF; tests/test_traffic_follow.gd; follow_judge.py).
  Bars F1 and F1 v2 were never run; 8125-8148 are unspent (R40.24).

### Late round-40 item: bridge-pooled at the bridge mouth (orchestrator, 2026-10-25 evening)

**Ask:** balance's ARM d385cd308 (stat overrides fm_c5r2_lawt5) fails bridge-pooled 17 / 18 on builder0. Rust, start tick 15, seed 2:
Rust_S_3 pressed at the rim 5.1 s against the 3 s bar, though all 4 crossed (4 Law Assault Guns, wheeled, v 3 Lancers). Find the
cause, propose a fix in one line, build only on the orchestrator's go. A symmetric fix ships ON if bridge-pooled stays green on main
AND on d385cd308's overrides, the rest of the check green, and the C++ twin matches; one that moves guard lines needs a bar.

**Cause (traced 2026-10-25 18:20-18:40 PDT, builder0 light, my side worktree `../godot-manoeuvre-bt` at balance's 5a233f42b = d385cd308 +
the trace target; n 1 a run, deterministic):**
- **Not the native drive:** `--brains-off=native_drive` is identical (arrived 48.9 s, Rust_S_3 rim 5.1 s, rim_total 5.4 s). The
  laptop's 31.0 s is some other difference.
- **ORCA moves a wheeled follower around its leader at the deck mouth** (`--turn-trace=Rust_S_3`):
  - S3 is the second crew of a single-file move at 10-11 m/s, about 7 m behind Rust_S_1, which slows to turn onto the deck.
  - f 515-535: ORCA's answer (pace 0.96 -> 0.71) moves the steer point off the route to the outside, past the entry: (91.3, -12.4)
    to (94.6, -9.2), against the route corner at (86, -10.5). The two hulls touch at f 520.
  - When the steer point returns to the deck, S3 is heading east beside the mouth. A fixed 8 m turning radius can't reach the deck
    at any speed.
  - It presses at the rim and circles (17.5-20 s), then yields to S1 backing out (20.5-24.5 s). The same thing happens at the far
    end behind S1 (28.5-32 s).
- **Diagnostic, n 1:** `--no-avoidance` gives rim 0 (arrived 38.8 s).

**Proposed (sent 18:45 PDT; no build until the go):** a WHEELED crew whose ORCA conflict is a friend ahead on its route going its way
(FOLLOW_COS, moving) keeps steering on its route and takes only ORCA's along-route speed: it queues instead of passing. A stopped friend
is passed as today. Symmetric, OFF until judged, GDScript first, then a C++ twin request. Expected to move guard lines, so seeds were
asked for a bar.

### F1, the follow-queue (R40.21, approved 2026-10-25 evening; `--traffic-on=follow`, DEFAULT_OFF until judged)

**Built OFF (1267b1635, main 7f9414dd5 merged).**
- **The rule:** in `Movement._avoid`, when ORCA would deflect a WHEELED crew and the nearest living friend ahead along its way (16 m,
  35 deg cone) is moving its way (Traffic.FOLLOW_COS, >= 1 m/s), the crew keeps its route's steering and takes ORCA's along-route
  speed. A stopped friend is passed as today. Counter: `Movement.follow_queued` (crew-ticks, in route_arms()).
- **Native:** ON turns native_drive off (Traffic._chain_native, M3's pattern): `_avoid` runs inside the drive's C++ mirror.
- **Tests** (tests/test_traffic_follow.gd, 5): off by default; the follow test (ahead and moving = followed; behind, off the way or
  stopped = not); live, two law_tanks in file, ON keeps the follower's line (0.00 m, 236 queued crew-ticks); ON runs the GDScript
  drive. Laptop NATIVE=off: 5 / 0; traffic|test_manoeuvre|movement|steering 197 passed, 0 failed (1267b1635).
- **Lab 1 (running, builder0 light):** bridge-pooled OFF / ON on 1267b1635, and on 1267b1635 + balance's 8e257f3bc + d385cd308
  cherry-picked (side worktree `../godot-manoeuvre-bt`, detached 29b9072ed; nothing of balance's on this branch). Raw data:
  `~/overnight-manoeuvre/r40/f1lab1/`.

**C++ twin request (for native, via the orchestrator; F1 can't ship ON without it):**
- **Where:** native's mirror of `Movement._avoid` (drive_native.cpp), after ORCA's `chosen` velocity and its `keep` are computed,
  BEFORE the start-of-order grace / min-pace branch.
- **When:** `follow` is ON (Traffic.DEFAULT_OFF lists it; `--traffic-on=follow`), the call isn't a hold's inner call (`held` false),
  and the hull is wheeled (`wheel_radius() > 0`).
- **The test, `_following(here, way)`:** `way` = (waypoint - here) flat, normalised. Over the living friends of its team (not
  itself), take the NEAREST whose flat offset `off` has length d with 0.01 <= d < FOLLOW_AHEAD_M = 16.0 and off.way >=
  FOLLOW_CONE_COS (0.819) x d. It is followed if its flat `real_velocity` v has |v| >= FOLLOW_MOVING_MPS = 1.0 and v.way >=
  Traffic.FOLLOW_COS (0.866) x |v|. Ties go to the first in tanks_root child order (the strict `d >= best_d` skip).
- **Then:** `follow_queued += 1`; return [waypoint, clamp(chosen.way / max(desired, 0.1), 0, 1)]. The steer point is unchanged and
  the pace is ORCA's along-route share.
- **OFF: nothing changes.** Twin check: tests/test_traffic_follow.gd under native, and bit-identity per seed (R38.24) with
  `--traffic-on=follow` on and off.

- **Lab 1 (builder0 light, bridge-pooled, 18 runs an arm, n 1 a run):**

  | Tree | Arm | bridge-pooled | Rim | Deck jam | Worst rim crew | Mean arrival |
  |---|---|---|---|---|---|---|
  | 1267b1635 (main + F1) | OFF | 18/18 | 8.1 s | 7.5 s | 1.5 s | 36.6 s |
  | 1267b1635 | ON | 18/18 | 9.9 s | 16.2 s | 2.0 s | 37.8 s |
  | 29b9072ed (+ d385cd308's overrides) | OFF | 17/18 (rust t15 s2) | 14.2 s | 17.1 s | 5.1 s | 34.9 s |
  | 29b9072ed | ON | **18/18** | 10.0 s | 23.2 s | 1.1 s | 36.4 s |

- **Lab 2 (a4e34d70e, builder0 light J4, both arms GDScript drive; dev seeds: wedge locks/terminus/sumps x 7001-7004, 12 fights;
  orders x 7001-7002, 24 runs; follow_judge.py as a lab read): F1 as built is TOO BROAD.**
  - D moving-stuck 137.7 -> 234.4 s (+70 %).
  - G3 contacts +19 % (FAIL). G4 deaths 493 -> 466 (FAIL). G7 last-in +2.2 s (FAIL). G1, G2, G5, G6 pass.
  - The rule fires all over open traffic: 2,756-10,490 queued crew-ticks a fight, 0-13 waits >= 3 s.
  - The longest waits run 2.8-8.8 s, behind leaders crawling at 1.1-1.3 m/s, just over the 1 m/s floor (locks s7001
    Green_Wrenches_7 8.8 s behind Green_Wrenches_3).
  - **Not gated; series not started** (it would spend 8125-8148 on a near-certain FAIL).
  - Proposed to the orchestrator: **F1 v2, corner-gated.** Queue only when the wheeled crew's route turns by more than 45 deg
    within 2 x its min turn radius ahead (a turn it can't make back to after a swerve). Both bridge ends qualify. Waiting on the
    go.

- **F1 v2 built (3f23a36ab, R40.22, main 6dc9f67d3 merged):** queue only where the route turns by more than FOLLOW_TURN_DEG = 45 deg
  within FOLLOW_TURN_RADII = 2 x the min turn radius ahead (`Movement._turn_ahead`); elsewhere ORCA passes as today
  (`follow_open` counts those follows). Laptop NATIVE=off: traffic|test_manoeuvre|movement|steering|wedge 216 passed, 0 failed.
- **F1 v2 labs (builder0 light; bridge 18 runs an arm; dev cells as lab 2, GDScript drive both arms; `~/overnight-manoeuvre/r40/f1v2lab/`):**

  | Tree | Arm | bridge-pooled | Rim | Deck jam | Worst rim crew | Mean arrival |
  |---|---|---|---|---|---|---|
  | 3f23a36ab (main + v2) | OFF | 18/18 | 8.1 s | 7.5 s | 1.5 s | 36.6 s |
  | 3f23a36ab | ON | 18/18 | 5.9 s | 6.4 s | 1.1 s | 35.6 s |
  | 5fb35635e (+ d385cd308's overrides) | OFF | 17/18 (rust t15 s2) | 14.2 s | 17.1 s | 5.1 s | 34.9 s |
  | 5fb35635e | ON | **18/18** | 6.4 s | 13.6 s | 0.8 s | 32.8 s |

  - **Dev cells (follow_judge.py as a lab read, n 12 fights / 24 runs):**
    - D moving-stuck 137.7 -> 142.9 s (+3.8 %, 0.1 se): flat, nowhere near the 0.8 line.
    - G4 deaths 493 -> 461 (FAIL, line +/- 25; kill share unmoved).
    - G7 last-in +2.3 s (FAIL): terminus 5 route s7001 +20.0 s, terminus 5 route s7002 +13.8 s, terminus 3 click s7001 +12.0 s.
    - G1, G2, G3, G5, G6 pass. G5 never-in 1 -> 0.
  - **Queue left in open traffic: 0 by construction.** 1,730-8,967 follows a fight passed to ORCA (`follow_open`); 413-1,486
    queued crew-ticks a fight, all at turns.
  - **Waits >= 3 s: 0 in every fight.** The longest is 2.23 s (terminus s7003 Rust_Spears2_1 behind Rust_Spears2_5, the
    leader's least speed 1.27 m/s). No crawler wait outside a turn, so no trace (the orchestrator's condition).
  - **Reading:** v2 fixes the bridge (rim and deck jam both down, on both trees) and no longer queues in the open. On D it is
    neutral, so Bar F1 as filed would very likely FAIL on D. The terminus last-in cost (squads queued at street corners) is a
    risk for G7.

- **R40.23 terminus trace (3f23a36ab, builder0 light, `--turn-trace=Green_Alpha_4` both arms, terminus 5 route s7001):** squad 1 at
  21.9 -> 51.0 s. Green_Alpha_4 queued at 3.5 m/s for 6 s (f 440-620) behind a friend driving steadily up the street, because the
  route turned within 16 m (the leader nowhere near it). It reached the junction late into crossing squad 3 (Green_Charlie_1,
  f 700), circled, and spent 20 s off the drive path. OFF: 5-12 m/s up the same street.
- **Fix (e516edcec):** queue only while the LEADER is within FOLLOW_AT_TURN_M = 8 m of the turn's vertex (`_turn_vertex`).
  Laptop NATIVE=off 216 / 0.
- **Labs on e516edcec (builder0 light; overrides tree 0c5d4ca6f): NOT a clean fix.**
  - bridge-pooled main: OFF 18/18 -> ON **17/18** (green t1 s1, a crew at the rim 4.0 s; rim 8.1 -> 9.2 s, deck jam 7.5 -> 4.8 s,
    arrival 36.6 -> 36.2 s).
  - bridge-pooled under the overrides: OFF 17/18 -> ON 18/18 (rim 14.2 -> 8.6 s, deck 17.1 -> 17.7 s, worst 1.8 s).
  - Dev cells: D 137.7 -> 120.9 s (-12 %, -0.4 se); G3 contacts +13 % (lab FAIL); G7 last-in +3.3 s (lab FAIL, 4 runs > 10 s
    later v 1 earlier); G1, G2, G4, G5, G6 pass. Queued 201-955 crew-ticks a fight; waits >= 3 s: 0; the longest 2.4 s.
  - terminus 5 route s7001: squad 1 24.6 s (fixed, OFF 21.9), but squad 5 43.1 v 31.0 s.
- **Reading:**
  - Each F1 form fixed the case in front of it and moved a failure somewhere else: v1 open-ground queues; v2 the terminus corner;
    v2 + the leader-in-turn gate fails main's own bridge seed (green t1 s1).
  - n 1 a cell and any change to ORCA's answer reshuffles who meets whom where. Tuning the gate further against these labs is
    fitting noise.
  - Recommended to the orchestrator: stop F1 here (OFF, no bar run, 8125-8148 unspent). Balance's ARM fails bridge-pooled on a
    traffic-order seed, a known fragility, not a new defect of the stat change. Round 41 could try a speed-only rule (a wheeled
    crew slows before a sharp turn its leader is in, ORCA's steering untouched) with a bar built on the bridge drill.

**Twin spec diff, v1 -> v2 (NOT final, not sent to native: F1 is recommended stopped; on e516edcec the queue also needs the leader within FOLLOW_AT_TURN_M = 8 m of `_turn_vertex`'s vertex):**
- **Added:** after `_following` finds a leader, the queue holds only if `_turn_ahead(here, FOLLOW_TURN_RADII x wheel_radius())`.
  Otherwise the leader is dropped (`follow_open += 1`, measurement) and the code falls through to today's path.
- **`_turn_ahead(here, within_m)`:**
  - prev = flat(here), walked = 0, way_in = 0. For i from `_path_index` to the end of `_path`:
    - leg = flat(_path[i]) - prev; skip if |leg| < 0.1 (prev is NOT advanced);
    - way = leg / |leg|; if way_in != 0 and way_in . way < cos(45 deg), return true;
    - walked += |leg|; if walked > within_m, return false;
    - way_in = way; prev = flat(_path[i]).
  - After the loop, return false.
- **Constants:** FOLLOW_TURN_DEG = 45.0, FOLLOW_TURN_RADII = 2.0.
- **Measurement only, no twin needed for behaviour:** follow_open, follow_longest, follow_long_waits. The rest is as the v1
  request above.

### Bar F1 (filed 2026-10-25 ~19:10 PDT, BEFORE any number on 8125-8148)
- **Gate:** the tree's full check green on builder0 FIRST (C31.1), F1 OFF. The checked hash is named here before the series starts.
  The series runs from that one frozen tree (R40.13): no game/ or tests/ commits until its `end` line.
- **Arms:** OFF (default) v ON `--traffic-on=follow`. **Both run the GDScript drive (`--brains-off=native_drive` in BOTH),** as Bar
  M3, so the pair compares the rule alone. Native ON otherwise. settle's switches at main's defaults in both.
- **Machine:** builder0 light lane, J 4. **Seeds (R40.21):** A on 8125-8136, B on 8137-8148.
- **A, wedge trace** (`manoeuvre-wedge-trace`, locks/terminus/sumps x 8125-8136, 180 s, 36 fights an arm, paired by fight):
  - **D (deciding): moving-stuck seconds:** long episodes (touching a hull, net < 0.5 m, >= 3 s) whose `phase` has `arrived` under
    half its ticks (M3's lesson: a parked crew touching a parked friend is not stuck to the player). PASS: ON <= 0.8 x OFF AND
    paired per-fight mean < 0 by >= 2 se.
  - G1 give-way deaths (jam:yielding + jam:friend), G2 stuck deaths (stuck:*): ON - OFF <= max(2 paired se x n, 3).
  - G3 friendly contact ticks: ON <= 1.10 x OFF.
  - G4 kill share within +/- 0.03 of OFF; total deaths within +/- 5 %.
- **B, orders probe** (locks/crossing/terminus x 3,5 squads x click,route x 8137-8148, 144 runs an arm, arms
  `main:--brains-off=native_drive` / `follow:--traffic-on=follow,--brains-off=native_drive`):
  - **G5 never-in runs: ON <= OFF.**
  - G6 all-in, paired median ON - OFF <= +2.0 s.
  - G7 last-in, paired mean <= +2.0 s AND runs > 10 s later <= runs > 10 s earlier + 3.
- **G8 bridge-pooled:** 18/18 with `--traffic-on=follow` on the bar's tree (builder0 light, native, as the check runs it; ON forces
  the GDScript drive).
- **Reported, not judged:**
  - long episodes (all) and the three longest;
  - follow_queued, if the wedge logs carry route_arms;
  - bridge-pooled ON under d385cd308's overrides (the lab's ask; it's balance's tree, not this bar's).
  - **Added by the orchestrator after lab 1, reported only (the bar's judged lines stand as filed):** bridge-pooled deck jam and
    mean arrival, OFF v ON; and the longest single follow-queue wait in the wedge cells, with its crew, leader, seed and the
    leader's least speed (`follow_longest` / `follow_long_waits` in WEDGE_TRACE, measurement only, a newer commit). Lab 1 on
    1267b1635: deck jam 7.5 -> 16.2 s, mean arrival 36.6 -> 37.8 s. If lab 2 shows a crew queued behind a friend that slows for
    no reason, one is traced before the series.
- **Judge:** `python3 tests/manoeuvre/follow_judge.py wedge-off wedge-on probe/rows.jsonl --on-arm=follow` (D on moving-stuck
  seconds, the rest as reroute_judge.py), plus bridge_verdict.py's line for G8. Committed before the series starts.
- **A pass** goes to the orchestrator; F1 ships ON only with native's twin matching. **A fail:** F1 stays OFF; no re-run on these
  seeds.

### CLOSE REPORT (round 40, 2026-10-25 ~08:00 PDT; the bridge item after it is above): done for the round

**Done:** every backlog item.
1. **M1 v2:** built OFF; its code is on main (65a5c5b70).
2. **Bar M1 v2:** FAIL on G5. Stays OFF; G5 traced.
3. **M2:** report filed.
4. **Stretch:** not built, as no cheap fix was named.
5. **M3:** built OFF; **Bar M3 FAIL on D** (below). Stays DEFAULT_OFF as a report; no re-run on 8601-8624.

**Bar M3 verdict:** FAIL.
- Run: game code b21565b37 (GREEN builder0); series tree 8c8d9035b; builder0 light J4.
- Both arms GDScript drive (`--brains-off=native_drive`, the orchestrator's condition).
- A: 36 paired fights on 8601-8612. B: 144 paired runs on 8613-8624.

| Line | OFF | ON | Result |
|---|---|---|---|
| **D** long-episode seconds | 544.1 s | 554.0 s (+1.8 %) | **FAIL** (line <= 435.3; paired +0.28 s a fight, se 5.83, 0.0 se) |
| G1 give-way deaths | 84 | 87 | PASS |
| G2 stuck deaths | 248 | 213 | PASS |
| G3 friendly contact ticks | 829,543 | 820,818 | PASS |
| G4 kill share (Green / Rust) | 0.402 / 0.598 | 0.375 / 0.625 | PASS (worst move 0.028, line 0.03) |
| G4 deaths | 1458 | 1435 | PASS |
| G5 never-in runs | 3 | 3 | PASS |
| G6 all-in, paired median | | +0.0 s | PASS |
| G7 last-in, paired mean | | +0.0 s | PASS (1 run later v 2 earlier) |

- **Reported:** long episodes 65 -> 51 (fewer, as in the labs), but the seconds didn't move.
- **ON's reroute:** 608 searches, 583,491 expansions (16 k a fight, each search whole on one tick), 271 plans, 96 driven to the end,
  176 BUDGET + 162 NO_PATH refusals (unheld).
- **ON's two longest (diagnosis read of the logs, not a re-judge):** both Rust_Battery2_4 (gang_artillery), sumps s8605 99.0 s and
  terminus s8605 71.6 s.
  - The seam never drove that crew: no planner force; ORCA slowed it for 2647 / 2085 ticks.
  - In terminus it had ARRIVED for 2054 of 2147 ticks: a parked crew touching a parked friend, which the episode definition counts
    as stuck.
  - Both are the fight diverging after other crews' re-routes. Counted, as filed.
- **Measurement note for a later bar (not an amendment):** the long-episode definition (touching, net < 0.5 m, >= 3 s) counts
  arrived, parked crews. A "stuck while ordered to move" filter would read closer to what the player sees.

**Decisions:**
- The re-route plans only with a plan in hand: the first search is whole, inside the scan (lab 2: refused takes cost the crew its
  unstick).
- `reroute` (holds only) was dropped for `=any`; holds rarely have a way round.
- Wheeled hulls only (orchestrator). Hover crews are the named gap: lab 3's 73 s outlier was a hover syn_artillery.

**Known issues if anyone turns M3 on:**
- The scan's search is unsliced: up to BUDGET expansions in one physics tick, a laptop hitch risk.
- ON forces native_drive off: the re-route leg rule is not twinned in C++.
- The pack-wait (a re-routed battery's leg clocks wait while deploy_ratio > 0) has no cap.

**Requests:** none. The C++ twin was conditional on a pass; not filed.

**Questions for the lead:** none.

**Round-41 items (the orchestrator, 2026-10-25):**
1. **M1 v3, own-squad-arriving reach:** limit a parked crew's give-way reach only while its OWN squad is still arriving. The chain
   drift is the arrivals' cost; a parked squad making way for a later squad is the job. From the G5 trace, where Bar M1 v2's
   regressions were last squads threading through squads already parked at the objective. Not built.
2. **M3, count only unparked crews:** the long-episode measure should exclude arrived, parked crews ("stuck while ordered to move").
   Bar M3's ON 71.6 s was a crew ARRIVED for 2054 of 2147 ticks. Lesson: "fewer but not shorter" (65 -> 51 episodes, flat seconds).
3. **M3, slice the scan:** the re-route's first search runs whole on one physics tick (16 k expansions a fight on Bar M3's ON).
   Slice it, or budget it per tick, before any ON.
4. **M3, widen the planner past wheels:** hover and tracked askers, since hover crews held the longest stalls (lab 3's s7004 and
   M2's sumps s7004). Filed for later, not M3's scope.

**Playtest commands** (both OFF by default):
- `make skirmish ARENA=locks SKIRMISH_FLAGS="--giveway-reroute=any"` against without: squads threading a street past parked friends.
- `--giveway-chain=v2` is M1 v2, also OFF.

**Merge notes:**
- Everything ships DEFAULT_OFF; OFF behaviour is unchanged (sim-baseline unmoved on b21565b37).
- Files: game/ai/planner/{planner_seam,planner_nav_world}.gd (the M3 grant), game/ai/traffic.gd, movement.gd's drive (one
  `planned_leg` gate), tests/test_traffic_reroute.gd (13 tests), tests/manoeuvre/reroute_judge.py.
- Green: b21565b37 (builder0, 3219 / 0). The orchestrator merged the tip 68a70aba2 (docs only on top of it) and stopped the
  docs-only final check before it started (it was waiting on balance's builder0 lock); no other check ran.
- Raw data: `~/overnight-manoeuvre/r40/` (m3lab1-3, m3t7004, barm3).

**Start (worker, 2026-10-24 evening):** stream/manoeuvre = main 33a2cc285 + round-40 docs (afce35a74); code = 68d0410d3, GREEN
builder0 per HANDOFF (3176/0), so no baseline check (contract 1).

**Plan (in order):**
1. **M1 v2 built OFF (d35eb24d1):** `--giveway-chain=v2` = givewaychain + `chainrelease` (direction 1): the reach is lifted for an
   asker that is WEDGED, i.e. it has made no progress toward its goal for CHAIN_RELEASE_S = 3 s (its own `stalled_ticks`, no new
   per-crew state, so the C++ twin reads one existing field); a hold the reach left as the only answer is refused instead (after a
   hold the asker never asks that crew again, `_last_yielded_to`; a refused asker asks again and, once wedged, is let through).
   `--giveway-chain=side` = givewaychain + `chainside` (direction 3, a lab arm): a far spot is allowed when it is no farther along
   the asker's travel from the seat (across the street, not down it). Both DEFAULT_OFF; both turn native_yield off until twinned.
   - **Direction 2 not built (decided from round 39's census, no run):** a reach only from chain index >= 2 leaves index 0-1 alone,
     and on the bar's OFF census (c35cc93ac, builder0, 36 fights) every parked give-way of index >= 2 carries 378 m of out_m against
     1,249 m chained: the deciding line (ON <= 0.5 x OFF) can't pass by construction.
2. **Lab (test first):** the 5 G5 regressions + the 2 old never-ins + s3866 (crossing 5 click), arms main / chain (v1) / v2 / side /
   chaingd (v1 on the GDScript yield: the path control). Wanted: every squad in on the 5, s3866 squad 4 in, chained out_m near v1's.
3. Pick, native twin request (via the orchestrator), bar M1 v2 filed before numbers on 8101-8124, series, verdict.
4. M2 (the long ORCA episodes trace, 7001-7008), then the stretch.

**Orchestrator (2026-10-24 evening), recorded:**
- **Twin request:** sent once the release time is picked, with the exact rule (the asker's stalled_ticks >= CHAIN_RELEASE_S lifts
  the reach; a reach-cut hold becomes a refusal). Native takes it after N1 (CP40.0) and before N2/N3.
- **"Last squad in" is a JUDGED guard** in Bar M1 v2, not just reported: the later arrivals are what he'd see.
- **The bar runs on native's twin,** not the GDScript bypass, unless the twin is late. Then the bar names its path.
- **R40.5:** no M1 v2 line reads orders' places-outside corridor read (G5/G6 read arrived_s and never-in only).
- **Orders' extra lab cell (dev only, NOT a bar seed):** terminus 5 route s3805, squad 1 never in on orders' 2eedf9f7f (both arms);
  Alpha_3 wedged at (7, 83) in the x=0 street among parked squads t40-t90. Lab `--giveway-chain=v2` v main once ee659b522 is green;
  tell orders (via the orchestrator) whether it gets in.

### M1 v2 lab (builder0 light, native, n 1 a run; `~/overnight-manoeuvre/r40/lab1`, `lab2`)
The 5 G5 regressions + the 2 old never-ins + s3866, d35eb24d1 (lab1) / 4406e1f52 (lab2). Never-in runs of 8 / chained out_m:
main 3 / 79.6 m; v1 `--giveway-chain` 7 / 0.6; **v2 (3 s) 0 / 42.9**; side 2 / 39.2; release 1.5 s 2 / 76.2, 5 s 3 / 32.3, 8 s 3 / 21.3.
- v1 on GDScript v C++: identical in all 8 runs (the path control).
- s3866 under v2: squad 4 in at 88.6 s (main never), chained 0.2 m. **The chain stays stopped.**
- The three Terminus regressions are in at every release time. The leftovers at 1.5/5/8 s are all Locks squad 1 behind squad-2 crews
  parked AT their seats (mostly inside CHAIN_M, rule not in play), the cells main itself fails or is late on (6119 never, 6124 61.8 s,
  6113 78.2 s). So 3 s's 0/8 on Locks is partly luck. **Pick: direction 1, CHAIN_RELEASE_S 3.0** (the one value with every squad in).
- Cost at 3 s: the last squad in is 4-26 s later than main on 4 runs (s6117 sq5 45.7 -> 71.3 s), hence G7 below.
- Direction 3 (side): 2 never-in, the wedges Locks's. Kept as a lab arm, not twinned.

### M1 v2 census (DEV, registered dev block): builder0 light J4, native, terminus/locks/sumps x 7001-7008, 24 paired fights
OFF on 65da436ec; v2 on the same game code (d35eb24d1 + knob), GDScript yield path (before the twin). `~/overnight-manoeuvre/r40/census_dev/`.
- The OFF arm reproduces round 39's census exactly (650.5 m chained, 449 chained, 1,246 parked refusals, deaths jam 64, stuck 162).
- **v2: chained drift 650.5 -> 140.7 m (0.22x), paired -21.2 m a fight, -5.3 se.**
- Give-way deaths 64 -> 60. Stuck deaths 162 -> 181 (2 paired se x n = 29.5). Contacts 17,906 -> 17,921.
- 103 releases, 51 holds refused, 533 refusals.
- So Bar M1's deciding line (<= 0.5x) stands as filed in round 39. v2 clears it here by more than half.

### Bar M1 v2 (filed 2026-10-24 ~21:00 PDT, BEFORE any number on 8101-8124)
- **Gate:** the tree's full check green on builder0 FIRST (C31.1). The tree = ee659b522 (native's twin merged; this Status commit on
  top is docs only), or its green docs-only successor. The checked hash is named here before the series starts.
- **Arms:** OFF (default) v ON `--giveway-chain=v2` (givewaychain + chainrelease, CHAIN_RELEASE_S 3.0). Native ON, **C++ path**
  (pair/native-chainrelease twin, no GDScript bypass; chainside off).
- **C40.2, settle's switches, in BOTH arms:**
  - T1 `--deploy-arrive=near`: **OFF** (not in this tree; CP40.1 not landed at filing).
  - S1 `--seat-route-clear`: **OFF** (main default). DEPLOY_HOLD **ON** (main default since round 39).
  - If CP40.1 lands before the series starts, the series still runs this tree. No restart, no amendment.
- **Machine:** builder0 light lane, J 4. **Seeds (registered C40.1):** A on 8101-8112, B on 8113-8124.
- **A, jam census** (`traffic-jam-census`, terminus/locks/sumps x 8101-8112, 180 s, 36 fights an arm, paired by fight):
  - **D (deciding): chained seat drift** (sum of `giveway_chain["parked:chained"].out_m`). PASS: ON <= 0.5 x OFF AND paired per-fight
    mean < 0 by >= 2 se. (Bar M1's line, unchanged.)
  - G1 deaths in give-ways (jam:yielding + jam:friend): ON - OFF <= max(2 paired se x n, 3).
  - G2 stuck deaths (stuck:*): ON - OFF <= max(2 paired se x n, 3).
  - G3 friendly contacts: ON <= 1.10 x OFF.
  - G4 the fights: each team's kill share within +/- 0.03 of OFF; total deaths within +/- 5 %.
- **B, orders probe** (`orders-probe`, locks/crossing/terminus x 3,5 squads x click,route x 8113-8124, 144 runs an arm):
  - **G5 never-in runs: ON <= OFF** (the guard, unamended).
  - G6 all-in time (the run's last arrival), runs both arms got all in: paired median ON - OFF <= +2.0 s, and no cell's median worse
    by more than 10 s.
  - **G7 last squad in (judged, the orchestrator's ask):** the same runs: paired MEAN ON - OFF <= +2.0 s, AND runs more than 10 s
    later ON <= runs more than 10 s earlier + 3. (Calibration, not a number on these seeds: round 39's v1 data reads -0.6 s, 4 v 9.)
- **Reported, not judged:** chained n, chain_in_play / releases / holds_refused / refusals, parked_refusals, all parked drift.
- **Judge:** `python3 tests/manoeuvre/chain_judge.py census-off census-on probe/rows.jsonl --on-arm=v2 --d-ratio=0.5 --last-in`
  (committed before the run, 6c28abd3e; no options = round 39's judge, re-judged line for line).
- **Gate MET: 479bf90f9 GREEN on builder2** (`>> remote: make native check exited 0`, 3186 passed / 0 failed, 24 targets passed + 3 NOT
  JUDGED (perf-judge on builder2, and scenario_perf / remote-guard-test refused at load 65), sim-baseline unmoved, copy-back verified;
  23:05 PDT). builder0's first check of it was lost in builder0's crash (R40.11). The series tree: the branch tip d379fd017, game code =
  479bf90f9 (since then: Status, the judge's reported-deaths line, a wedge_trace field the series doesn't run).
- **Series STARTED 2026-10-24 ~23:07 PDT** (`~/overnight-manoeuvre/r40/bar.sh`, builder0 light J4, C++ path). ETA ~01:00 PDT. No
  game-code edit in this tree until it ends.
- **Verdict:** every line passes -> PASS -> ships ON (CP40.2: one full check of the flip). Any FAIL -> stays OFF, no re-run on these
  seeds, the cause traced and written up.

### M2 report: the long ORCA episodes (DEV trace, report only)
Code 479bf90f9 (M2) / d776ed30f (M2b, + one trace field). All switches OFF (main's behaviour). builder0 light J4, native,
locks/terminus/sumps x 7001-7008, 24 fights. `~/overnight-manoeuvre/r40/m2`, `m2b`.
- **37 target episodes (touching, net < 0.5 m, >= 3 s), 268.8 s.** Round 37's 82 were another block on an older main. M2b
  reproduces M2 exactly.
- Episodes by team: CPU 23, his side 14. No wedged crew died (37/37 alive). 15 had an enemy in sight.
- Partner tick shares (wedge_trace classes): giving way 49.5 %, parked 25.9 %, no partner 11.6 %, driving or slow ~13 %. 23 of 37
  top partners are another squad's crew. Forces on the wedged crew: orca_slow 2,646 ticks, unstick 2,269, hold 857, yield 742.
- **Artillery: 18 of 37 episodes, 135.7 of 268.8 s** (gang_artillery 12, artillery 4, syn_artillery 1, + 1).
- **Whom a yielding partner gives way to (M2b's partner_yields, 8,065 partner ticks):**
  - for the wedged crew itself: HOLD in place 1,365 (17 %), spot 943, short 138, back 64.
  - for someone else: spot 879, back 462, hold 130.
  - Longest: sumps s7004 Rust_Battery_1 (syn_artillery) 28.2 s, 607 ticks of Rust_Battery_2 holding in place FOR it.
- **Named: the hold that is a wall.** When no spot fits, the asked crew gives way IN PLACE (round 6/13's `hold`: stop pushing, let the
  other through). That frees the asker only if the asker has a way round. When it doesn't, the asker sits behind the holder for the
  hold's YIELD_MAX_SECONDS (6 s). The hold then ends UNFINISHED (yieldfit2: the asker is still touching behind), so `_last_yielded_to` is
  not set, the asker asks again, and it gets the same hold. Battery_2's 607 ticks are back-to-back 6 s holds. The wedge stands until
  unstick or a re-plan moves someone. It's M1 v2's mechanism in the base give-way: a hold for a WEDGED asker should hand the
  give-way back (the asker backs off or swaps) instead of standing.
- **The hold's timing:** an unfinished hold is retried YIELD_RETRIES = 2 times in YIELD_RETRY_WINDOW_S (30 s), so it's 3 holds x 6 s
  ~ 18 s, then the cap records it finished (`yields_unfinished_capped`). That matches Battery_2's 607 ticks.
- **No cheap fix, so the stretch is NOT built (decision 2026-10-24 ~23:20).** A hold happens only when NO spot fits the holder, and the
  wedge stands only when the asker has no way round. Ending the hold early (the `holdrelease` I first filed) opens nothing:
  - against a parked holder the asker keeps its route (CP1a2);
  - backing the asker off drives it straight back into the same street.
  The levers that would work aren't cheap: re-route the asker around the holder (the planner: a re-plan with the holder as an obstacle),
  or let the holder take a spot that doesn't fit whole (round 13 measured scraping give-ways worse: arrivals 115 -> 105).
  Candidate for a later round, if he reports artillery crews sitting behind a squadmate: the planner re-plan, lab on the 8 longest
  episodes above (sumps s7004 Battery_1 first).

**Known issue (comment only, fix after the series):** M1 v2's comment in movement.gd says that after a hold "the asker never asks that
crew again (_last_yielded_to)". Under yieldfit2 (ON) an UNFINISHED hold leaves _last_yielded_to unset and the asker re-asks. So the
hold-refusal's real effect is that each re-ask is judged again with the release (a wedged asker gets a real spot, not another hold).
The rule is right; the sentence is wrong. Not edited now: the series' tree must stay the checked game code.

**Native twin MERGED:** pair/native-chainrelease 18e5dbca8 (quick-green builder0 114/0, 0 mismatches) merged clean as ee659b522;
chainrelease now runs in C++ (chainside alone keeps the GDScript bypass). Full check of ee659b522 started on builder0.

**M3 scope (orchestrator, 2026-10-25 ~00:30): wheeled hulls only.** The planner plans only for wheeled hulls (`side_gate_in`:
locomotion == "wheels"). M3 opens its lab on the longest wheeled episode, locks s7006 Rust_Battery_5 (gang_artillery, 21.6 s).
Wheels cover 7 of M2's 10 longest episodes. **Named gap:** sumps s7004 Rust_Battery_1 (syn_artillery, hover, 28.2 s), and tracked
artillery and tanks.
**Filed for a later round (not M3):** widen the planner past wheels (tracks, hover), so the re-route reaches s7004's kind of wedge.
**C40.2 noted:** settle's T1 ships ON. The M1 v2 series keeps its tree as filed (T1 OFF in both arms). On a pass, one dev read of
M1 v2 on a T1-ON main before the flip.

**Bar M1 v2: FAIL on G5 alone (2026-10-25 01:25 PDT).** Game code 479bf90f9 (GREEN builder2), on builder0 light, native, J4.
A = census on 8101-8112 (36 paired fights); B = orders probe on 8113-8124 (144 paired runs). Raw data:
`~/overnight-manoeuvre/r40/bar/`.
- PASS D chained seat drift 884.0 -> 190.4 m (-78.5 %; line <= 442.0), paired -19.27 m a fight, se 2.11 (-9.1 se).
- PASS G1 give-way deaths 91 -> 86 (line +19.7). PASS G2 stuck deaths 229 -> 242 (line +33.5). PASS G3 contacts 24051 -> 23279.
- PASS G4 kill share worst move 0.018 (line 0.03); deaths 1463 -> 1451.
- **FAIL G5 never-in runs 2 -> 5 (no more).** PASS G6 all-in paired median +0.0 s. PASS G7 last-in paired mean +0.3 s (7 runs
  more than 10 s later v 4 earlier).
- Reported deaths by team: OFF {0: 720, 1: 743}, ON {0: 737, 1: 714}.
- Stuck by sub-cause, OFF -> ON: wedged 86 -> 104, static 61 -> 55, still 77 -> 78, no_path 5 -> 5.
- Never-in runs:
  - main: locks 3 click s8116 sq1 (v2 got it in); terminus 5 route s8114 sq5.
  - v2: crossing 5 click s8120 sq4 (main 37.0 s); locks 3 click s8119 sq1; terminus 5 route s8114 sq1 (main 84.7 s) + sq5;
    terminus 5 route s8118 sq5 (main 56.6 s); terminus 5 route s8119 sq5 (main 41.3 s).
  - So 3 of the 5 are terminus 5-squad route cells, the last squad in; in main those squads came in late (41-85 s).
- **Not shipped; no re-run on these seeds.** The guard stands unamended. Trace (diagnosis only, not a re-judge): probe_wedge on the
  5 v2 never-in cells, main v v2, `~/overnight-manoeuvre/r40/trace5/`.

**The G5 trace (diagnosis, not a re-judge; 2026-10-25 01:26-01:35 PDT, builder0 light native, n 1 a cell, probe_wedge on the 5
v2-only never-in cells).** Raw data: `~/overnight-manoeuvre/r40/trace5/` and `trace5b/`.
- On 479bf90f9: never-in runs main 1/5, v2 5/5. The bar's 5 regressions reproduce deterministically.
- On main 9d5907ddd with settle's T1 ON (merged here as a92ce7b73): mainT1 1/5, v2T1 3/5.
  - crossing s8120 sq4 recovers: in at 41.5 s v 35.5 s. terminus s8119 sq5 recovers: in at 40.1 s, the same as mainT1.
  - So T1 halves v2's G5 cost, but the cost survives on the main that ships.
- The 3 survivors (v2T1):
  - **terminus s8118 sq5:** 8 chain refusals, 1 release. Echo's crews sit behind Delta_4 (sq4, parked, yielding head_on and cross,
    26.6 s): the limit keeps sq4's parked crews from stepping far enough to let the last squad through. This is the rule's own cost.
  - **terminus s8114 sq1:** 9 refusals, 7 releases. The same shape, against sq4's Delta_5. Fragile: mainT1 had sq1 in only at 84.7 s,
    and sq5 is never in on both arms.
  - **locks s8119 sq1:** in_play 1, no refusals. An own-squad column jam (Alpha_2 behind Alpha_3, slow/same, 41 s). One rule event
    changes the run's whole path: chaos, not the rule. Fragile: mainT1 had sq1 in only at 70.0 s.
- **Reading:** the regressions are the last squad threading through squads already parked at the objective. M1's limit keeps a far
  parked crew from taking the far spot that would let it through, and the release only helps a WEDGED asker (stalled 3 s); a slow
  one doesn't qualify. M1 v2 stays OFF. The next form, if a later round wants it: limit the reach only for a crew whose OWN squad is
  still arriving (the chain drift is the arrivals' cost; a parked squad making way for a later squad is the job). Not built.

**M3 built OFF (db55d1fdb, `--giveway-reroute`; `=any` is a lab arm).** A wedged wheeled asker that a friend holds in place for is
planned round the holder by the planner's seam.
- **Trigger:** PlannerSeam's once-a-tick scan, connected only while ON. The asker is wheeled and has stalled for
  Movement.chain_release_ticks() (3 s, M1 v2's "wedged"). A friend's yield_spot is "hold" with yield_to = the asker (=any: any
  give-way to it).
- **The plan:** a k-turn crew to the first point along the asker's route (walked in 1 m steps, within HORIZON_M) past the holder and
  clear of both boxes, ending within 2.5 m, pointing the route's way within 30 deg. The holder is a box in the plan's world, like
  every living hull. Once taken, it's an ordinary seam crew: `_planned_reverse`'s hold drives it every tick (and the C++ drive's
  `seam_live` calls it back), and every release rule applies. The hull-length scope (10 m) isn't asked: M2's wedged wheeled
  crews are 6.6-7.3 m.
- **Three things the test stage found** (a tank parked at the origin, a gang_artillery 12 m south ordered straight through it):
  - The search needs 246 expansions and a hold gives 180, so a re-route may run 3 holds (REROUTE_HOLD_X). The crew is wedged; it
    loses nothing by waiting.
  - ORCA's share is 0 behind a hull holding head-on, which zeroed the leg. A re-route's leg is driven as planned, like a k-turn
    leg (`Movement.drive`, gated on `PlannerSeam.rerouting`).
  - **A battery held still for the search digs in** (Tank._deploy_step: legs down after 1/4 s at rest), and the leg's 2 s stall
    rule aborted it before the legs came up. The leg's clocks now wait while deploy_ratio > 0 (59 ticks on the stage). This
    may be part of why M2's long wedges are artillery: any stop near a squadmate starts a dig-in.
- **Native:** the leg rule is in `Movement.drive`, which has a C++ mirror, so while ON the GDScript drive runs (native_drive off,
  restored when OFF; the chainside pattern). The twin request (drive_native.cpp: a seam crew in `_rerouted` drives its leg
  unscaled) goes to the orchestrator only if the lab is promising.
- Tests: tests/test_traffic_reroute.gd, 10 tests. Laptop flightdeck NATIVE=off: traffic|planner_seam|test_manoeuvre 173 passed,
  0 failed (6f92700fa).
- **M3 lab 1 (running, builder2 light J14, 6f92700fa):** the fights holding M2's longest wheeled episodes (locks 7002-7007,
  terminus 7003) x off / reroute / any, under wedge_trace. Raw data: `~/overnight-manoeuvre/r40/m3lab1/`.
- **M3 lab 1 result (6f92700fa, builder2 light J14, load 22-41 at start (shared with balsa); n 1 a fight, 7 fights an arm):** WORSE.
  Long episodes (touching, net < 0.5 m, >= 3 s): off 19 / 141 s, reroute 22 / 204 s, any 19 / 276 s. locks s7006 Battery_5 went
  21.6 s -> 30.4 + 24.0 + 9.8 s. The re-route almost never planned: reroute 1 plan of 57 asks (58b7cb865's message says 72: wrong), the rest refused START_BLOCKED (the
  wedged crew touches its holder, and its start pose overlapped the hull box) or GOAL_BLOCKED (the route's next point stands in the
  squad's own parked crews). Each refused take still held the crew at zero/zero and cleared its stall and escape clocks
  (`yield_to_plan`), so the re-route only delayed the unstick. Lesson: a take must be a plan the planner will make.
- **Fix (58b7cb865):** the scan checks the start (exact overlap, in a world whose other hulls are REROUTE_SHRINK_M = 0.3 m smaller a
  side; `PlannerNavWorld.hull_shrink_m`, 0 everywhere else), and walks the route to a goal pose the footprint clears, BEFORE the
  take. Laptop NATIVE=off: traffic|planner|test_manoeuvre 227 passed, 0 failed. Lab 2: the same cells, reroute / any.
- **M3 lab 2 (58b7cb865, builder2 light J14, load 56 at start):** start_blocked 0, so the shrunk world works. Long episodes:
  reroute 23 / 299 s, any 13 / 138 s (off 19 / 141 s, lab 1). Under `reroute` the refusals left were NO_PATH (19 of 30 asks): a
  holder holds because no spot fits, so the street often has no way round. Each refusal still held the crew still for up to
  3 holds. `any` planned 36 and drove 13 to the end.
- **Fix (b10c8dee8):** the scan makes the first search whole (Planner.plan, the library's one-shot search, apart from the seam's
  sliced session) and takes the crew only with a plan in hand. A refusal costs the crew nothing; the cost moves to the scan's
  tick (searches and expansions reported). Lab 3: the same cells, reroute / any.
- **M3 lab 3 (b10c8dee8, builder2 light J14, load 40 at start; n 1 a fight, 7 fights an arm):**

  | Arm | Long episodes | Total |
  |---|---|---|
  | off (lab 1) | 19 | 141 s |
  | reroute | 23 | 228 s |
  | any | 11 | 149 s |

  - start_blocked is 0 in every log.
  - `any`: 103 searches and 73 k expansions over 7 fights; it planned 56 and drove 17 to the end.
  - The `reroute` arm's other cells match off's episodes exactly; it planned only 3 times.
  - Both ON arms carry one 73.2 s episode that off doesn't have: locks s7004 Rust_Battery_2 (syn_artillery), pinned by a parked
    Rust_Eyes_5 until the match ends, with ORCA's pace under half for 2192 of its 2196 ticks.
  - The seam planned once in that fight (2 legs, 30 driving ticks, then released stale), so the 73 s follows from that one
    re-route. Without it, `any` is 10 / 76 s.
  - **Traced (fd9c9d0f7, builder0 light, `--turn-trace=Rust_Battery_2`; the same 73.2 s, from tick 3206):** the seam never took
    Rust_Battery_2. syn_artillery is a HOVER hull (outside M3's wheels-only scope), wedged against a parked Rust_Eyes_5
    (stall/unstick cycling, pace 0.05-0.08). The one re-route was another crew's, earlier, and changed the fight's path: a cost of
    the arm through divergence, not the rule acting on the stuck crew. It is counted, as a bar counts it. Raw data:
    `~/overnight-manoeuvre/r40/m3lab3/`, `m3t7004/`.
- **Reading:** `reroute` (holds only) is worse and is dropped. `any` is the bar's ON arm: fewer long episodes (19 -> 11), with
  seconds that a single divergent fight can swing.

### Bar M3 (filed 2026-10-25 ~05:00 PDT, BEFORE any number on 8601-8624)
- **Gate:** the tree's full check green on builder0 FIRST (C31.1), with M3 OFF (the default). The checked hash is named here before
  the series starts.
- **Arms:** OFF (default) v ON `--giveway-reroute=any`.
  - **Both arms run the GDScript drive: `--brains-off=native_drive` in BOTH** (the orchestrator's condition, 2026-10-25, before any
    number). ON would turn native_drive off anyway (`Traffic._chain_native`: the re-route leg rule is not twinned in C++), so the
    pair compares the rule alone, not the rule plus the drive path. The rest of native stays ON in both. Lab 3's match between
    off and the never-planning fights is NOT claimed as evidence (that was one tree, not a measured fact).
  - The tree is b21565b37's game code; this amendment is docs and the series script only, made before any number.
  - settle's switches: main defaults in both arms (T1 `--deploy-arrive=near` ON since C40.2; S1 off; DEPLOY_HOLD on).
- **Machine:** builder0 light lane, J 4. **Seeds (registered R40.12):** A on 8601-8612, B on 8613-8624.
- **A, wedge trace** (`manoeuvre-wedge-trace`, locks/terminus/sumps x 8601-8612, 180 s, 36 fights an arm, paired by fight):
  - **D (deciding): long-episode seconds** (touching a hull, net < 0.5 m, >= 3 s; partner_table's target, every unit). PASS: ON <=
    0.8 x OFF AND paired per-fight mean < 0 by >= 2 se.
  - G1 deaths in give-ways (jam:yielding + jam:friend): ON - OFF <= max(2 paired se x n, 3).
  - G2 stuck deaths (stuck:*): ON - OFF <= max(2 paired se x n, 3).
  - G3 friendly contact ticks: ON <= 1.10 x OFF.
  - G4 the fights: each team's kill share (from the logs' `destroyed` lines) within +/- 0.03 of OFF; total deaths within +/- 5 %.
- **B, orders probe** (`orders-probe`, locks/crossing/terminus x 3,5 squads x click,route x 8613-8624, 144 runs an arm, arms
  `main:--brains-off=native_drive` / `any:--giveway-reroute=any,--brains-off=native_drive`):
  - **G5 never-in runs: ON <= OFF.**
  - G6 all-in time: the paired median ON - OFF <= +2.0 s, over runs both arms got all in.
  - G7 last squad in: the paired mean ON - OFF <= +2.0 s, AND runs more than 10 s later <= runs more than 10 s earlier + 3.
- **Reported, not judged:**
  - long-episode count and the three longest;
  - the reroute report summed: asks, searches, expansions, outcomes, pack_ticks.
  - The scan's search is whole on one physics tick. Up to BUDGET expansions in a frame is a hitch risk on the laptop; it must be
    sliced before ON ships, whatever the verdict.
- **Judge:** `python3 tests/manoeuvre/reroute_judge.py wedge-off wedge-on probe/rows.jsonl --on-arm=any`, committed with this bar.
- **Gate MET: b21565b37 GREEN on builder0** (`>> remote: make native check exited 0`, 3219 passed / 0 failed, sim-baseline unmoved,
  copy-back verified; 06:00 PDT). Series tree: this commit, docs-only on top (b21565b37's game code). Series STARTED ~06:05 PDT
  (`~/overnight-manoeuvre/r40/barm3.sh`, builder0 light J4). No number seen before this line.
- **R40.13:** the series re-syncs this worktree three times: each of its three `tools/remote.sh` calls (wedge off, wedge on, probe)
  rsyncs the tree, and the judge runs from it at the end. So nothing is committed under game/ or tests/ until its `end` line; docs
  only.
- **VERDICT: FAIL on D** (07:49 PDT; full lines in the CLOSE REPORT at the top of Status). M3 stays OFF; no re-run on these seeds.
- **A pass** goes to the orchestrator, with the C++ twin request and the slicing, before ON ships. **A fail:** M3 stays OFF, as a
  report; no re-run on these seeds.
