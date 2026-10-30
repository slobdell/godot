# Stream: native (the game stays fast as rules ship; every ON rule has its C++ twin)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 351), `_agents/judging.md`, `_agents/workstreams.md` **Round 47**
> (C47.1-C47.11; C47.6 is yours; C47.4's reader is yours), your last brief `streams/archive/round46/native.md` (FINAL REPORT), R46.16.
> **You own:** `native/**`, `mk/native.mk`, `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`,
> `tools/loaded.sh`, `tools/slot.sh`, `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`, `tools/builder_checks.sh`,
> `tests/ai_scenarios/guard_line.gd`, `mk/play.mk`'s skirmish recipe, `mk/gcp.mk`, `_agents/judging.md`, `tests/replay_orders.gd`,
> `tools/recording_arrivals.py`, `tools/playtest_report*`, `tests/replay/**`; GRANT the C++ seams in `game/control/**`, `game/ai/tank_brain.gd`'s
> native call site, and the native call site of `ElementPlan.build` / `ElementSituation.build` (R46.16), each GDScript body kept as the
> fallback. **Model:** Opus. **Machine:** builder3; builder0 for perf-judge lines set there (quiet window). **Seeds:** the owner's.

## The lead's direction

Memory: native code is C++ (core components in C++ long-term, even without a gain); the laptop is the test bed (UHD 620). His asks
this round are the other streams'; native makes them fast and proves the C++ path plays the same game.

## Where things stand (main fccfaadea; code e306ce27f GREEN builder3 3518/0, 28 ALL JUDGED)

- **R46.16 (probe/native-elements 9145cc82a, builder3 light, his Terminus 149 s, native ON, n 1, tick 12.24 ms):** elements 2.67 ms;
  ElementPlan.build 1.06 ms a tick (0.46 a call; ~3 ms on his laptop), ElementSituation.build 0.55, grounding 0.32, take/issue 0.32,
  corridor/transit/crossing 0.25. Round 47: ElementPlan.build to C++, then build_situation.
- This round's rules that will need twins (C47.6): manoeuvre's no-progress watchdog (drive), route's cost change if the planner's cost
  runs in C++, engage's fire fix if it touches the brain's scoring, orders' if a seam moves.
- Recordings carry `sel` and the `rules` stamp; orders adds `inp` (C47.4) for you to read in `playtest_report`.

## Backlog (in order)

1. **N1 twins as bars are filed** (C47.6), in the order they arrive; EQUAL on the frozen bar tree, reported to the owner and the
   orchestrator the same hour. A twin is a bar's gate: it outranks everything below when a bar waits on it.
2. **N2 ElementPlan.build in C++** (R46.16): agree the seam with its owners through the orchestrator (element_plan's functions are
   engage's / manoeuvre's / route's by function); output-identical first (a decide-style twin proof over his four recordings), then
   judged on the box the line is set on.
3. **N3 `inp` rows in `playtest_report`** the hour orders' C47.4 lands: a "selection changed by" column; re-read Sumps 601-618.
4. **N4 ElementSituation.build in C++** (build_situation 1.51 ms with contacts), same method.
5. **N5 judging lines:** `lines_r47.py` as verdicts land; re-render the table at the close.
6. **N6 builders:** keep builder3 healthy (disk, cold-import watchdog, the full-check lock); seven streams share it this round, so
   watch the queue and tell the orchestrator if a check waits > 30 min.

## Don't touch

Every GDScript body behind your seams (the owner's), `game/camera/**`, `arenas/**`, `game/ui/**`, `tests/baselines/**`.

## How to verify

`make remote T=check` on builder3 (read `>> remote: make check exited <N>` and `N passed, M failed`, never an exit code through a
pipe); `make quick-remote` to iterate (`QUICK_BASE=<your last green>`); `make replay-match RECORDING=...` and `make playtest-report
RECORDING=...` on his four recordings; screenshots at desktop and phone aspect, looked at. Every number with its commit, machine,
workload and n. **No local Godot runs** except a lock-held laptop budget read (C47.1: seven sessions on a 7 GB laptop).

## Waiting on the lead

Nothing at launch. If a bar fails, write in player terms what he would see ON v OFF and message the orchestrator the same hour.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Plan (2026-10-30 evening, start; from main c789b55a6, code e306ce27f GREEN builder3 3518/0: no baseline check of mine).**
1. N1 twins: none filed yet (*Bars (round 47)* empty at start); each one jumps the queue when it arrives.
2. N2 ElementPlan.build: profile INSIDE it first (probe branch probe/native-plan47, wrappers on ~40 functions, not merged), so
   the port is the hot leaf functions with the GDScript kept as the fallback, not a 4000-line rewrite of code three streams edit
   this round. Reason: element_plan.gd is manoeuvre's / route's / engage's by function and all three change it in round 47; a
   whole-body twin would go stale with every merge.
3. N3 the `inp` reader: written ahead against C47.4's format (synthetic rows); the Sumps 601-618 re-read waits for a recording
   with real rows.
4. N4 build_situation: same method as N2, after it.
5. N5 lines_r47 as verdicts land; N6 builders every hour.

**N3 reader DONE ahead of orders (1702fbd2c, laptop: `make replay-pytest` 12/0).** `make playtest-report` gains section (d): every
`sel` row with the `inp` row that made it (key + action, matched by sel_after within 2 frames) or "no input (the game)", and the
summary line "selection: N changes, M by no key or click (first at ...)". A recording without inp rows says so. NEW target
`replay-pytest` (tests/replay's Python tests; rules + divergence + this); **request to the orchestrator: add it to `make check`'s
list in mk/core.mk** (those tests ran nowhere before).
