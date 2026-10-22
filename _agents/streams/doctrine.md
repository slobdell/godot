# Stream: doctrine (the CPU defender stops, holds and shoots first)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 38** (C38.1, C38.2) and
> in *Round 37*: CP37.1, R37.14 (the guard lines' base), R37.22-R37.26 (the rules arms and the motion read), R37.44 (Bar K). Then
> `game_design.md` *OPEN QUESTIONS for him before round 37* and *Summary of his answers*. Rules' close notes:
> `streams/archive/round37/rules.md`. **You own:** brains' paths (`game/ai/**`, `game/tactics/**` outside the carve-outs in
> workstreams *Round 38* Ownership), `tests/tactics/**`, `tests/test_tactics*.gd`, the `tests/ai_scenarios/**` scenarios you add,
> `tests/rules/**` re-reads, `mk/tactics.mk`. **Model:** FABLE. **Machine:** builder2 for guard-line series; builder0 light runs.

## The lead's direction

"How can we make it so that tactics and strategy can win out over a large frontal assault?" ... "in the real world, the defender
generally has an advantage" (round 36, game_design.md). His round-37 answers built rules that reward stopping (sight, accuracy, pinning,
hull-down); every one leaned the right way but none cleared noise because **the CPU defender itself keeps moving**. And his standing
rule: smart AI on both sides; symmetric AI improvements ship without asking.

What he will notice: a CPU force holding a zone stops in cover and shoots first; a blob of his (or the CPU's) charging it loses more
often than today; his own defending squads do the same when parked (settle owns "parked").

## Where things stand

- The guard lines (CP37.1): BLOB (his right-click, everything at once) wins 48 %, TURTLE 39 % against today's CPU (R37.14), paired
  320-fight reads with `tools/scoreboard/guard.py --pair`; guard.sh GUARD_CHUNK=2.
- The motion read (R37.26, `make rules-guard-motion`): blob fires faster than a crawl 70.1 % of rounds, the CPU 55.5 %, and the CPU fires
  41 % more rounds.
- Rules on main, OFF: `--rules-on=sight,spread,pin_slow` (R1-R3), `--cover-on=hulldown` (K2).

## Backlog (in order)

1. **D1 the read:** when CPU elements are tasked to HOLD / defend a zone, how often do their crews fire while moving, and why (which
   brain options move a holding crew: ENGAGE, SPOT, FLANK, re-seat). Design note to the orchestrator before code.
2. **D2 hold-and-fire:** a defending CPU element halts to fire (stops, uses cover seats, bounds only when it must), behind a switch;
   lab first; bar on the guard lines (deciding: the blob's win rate down; guards: the turtle not up, kills/length per faction, perf, and
   "the CPU still attacks when it is the attacker"). A pass ships ON (symmetric).
3. **D3 the re-read:** R1-R3 and K2 ON top of D2, each and as a package, on the same 320 fights.
4. **Stretch:** the CPU choosing low-cover seats when it defends (K5 maps have barriers).

## How to verify

Lab both paths; `make quick-remote`; guard-line series on builder2 (`make guard-run GUARD_ARGS=... GUARD_TAG=...`); every number with
commit, machine, workload, n. Smoke: `make skirmish ARENA=locks`, watch the CPU hold its zone.

## Don't touch

orders' control paths, settle's deploy/halt/seat functions and the parked-hold seam (merge notes), manoeuvre's movement blocks,
`game/match/**`, `game/combat/**`, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
