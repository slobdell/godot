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
