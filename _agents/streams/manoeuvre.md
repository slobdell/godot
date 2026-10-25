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
4. **Stretch:** if M2 names a cheap fix, build it OFF and lab it.

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

**Native twin MERGED:** pair/native-chainrelease 18e5dbca8 (quick-green builder0 114/0, 0 mismatches) merged clean as ee659b522;
chainrelease now runs in C++ (chainside alone keeps the GDScript bypass). Full check of ee659b522 started on builder0.
