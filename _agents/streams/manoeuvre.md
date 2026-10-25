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
