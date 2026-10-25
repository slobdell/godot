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
4. **M3 (R40.12): a wedged asker re-routes round its holder** (`game/ai/planner/**` granted). OFF; lab on M2's 8 longest episodes
   (sumps s7004 Battery_1 first); bar on 8601-8624 filed before numbers. holdrelease is withdrawn (847429f96: ending a hold opens nothing).

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
- **Verdict:** every line passes -> PASS -> ships ON (CP40.2: one full check of the flip). Any FAIL -> stays OFF, no re-run on these
  seeds, the cause traced and written up.

**Native twin MERGED:** pair/native-chainrelease 18e5dbca8 (quick-green builder0 114/0, 0 mismatches) merged clean as ee659b522;
chainrelease now runs in C++ (chainside alone keeps the GDScript bypass). Full check of ee659b522 started on builder0.
