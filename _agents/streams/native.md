# Stream: native (the rules-ON pairing base; the same sim on every machine; the tools every stream leans on)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/remote_builds.md`, `_agents/workstreams.md`
> **Round 39** (C39.0, C39.1, C39.6) and *Rulings (round 38)*: R38.25, R38.50, R38.52, R38.55. Your round-38 brief:
> `streams/archive/round38/native.md`. **You own:** `native/**`, `mk/native.mk`, `tools/scoreboard/**`, `references/scoreboard/**`,
> `tools/judge/**`, `tools/perf_judge.sh`, `tools/loaded.sh`, `tools/slot.sh`, `tests/ai_scenarios/guard_line.gd`; GRANT (C39.6):
> `mk/play.mk`'s skirmish recipe. **Model:** Opus. **Machine:** builder2 (rows), builder0 for perf only.

## The lead's direction

C++ for core components long-term ("Native code is C++"); the builders are for throughput. He asked (2026-10-23) whether a faster
physics engine would speed development; the answer was "physics is a small share, Jolt already" with an offer to measure it.

## Where things stand

- **Round 38's row (R38.52):** 686150ed2, rules OFF: blob 47 %, turtle 41 %, inside noise of round 37. Per-fight rows
  `references/scoreboard/guards/686150ed2.fights.jsonl`.
- **R1-R3 ON by default (R38.55)**, so that base no longer describes main.
- **Machine trig (R38.25):** the laptop (glibc 2.39) and builders (2.43) differ in float trig (atan2f etc.); native == GDScript per
  machine. Pairs across machines are forbidden until this is fixed.
- **Loaded gates are per physical core** (builder2 24, builder0 15). Orders' check failed test_slot_light's setup at 1.49 per core
  (R38.18 cleared on a solo re-run).

## Backlog (in order)

1. **N1 the rules-ON base (CP39.0, FIRST).** CP37.1's guard lines (320 paired fights, same seeds) on main as launched, rules ON; file
   `references/scoreboard/guards/<main>.fights.jsonl` and a scoreboard row v 686150ed2 per faction. Tell the orchestrator the minute it
   lands (doctrine waits on it).
2. **N2 `make skirmish SKIRMISH_FLAGS="..."` (C39.6).** Passthrough only; default unchanged; a test that the flags reach the game.
3. **N3 the begin_yield twin** for manoeuvre's chain-aware give-way (when manoeuvre names the function).
4. **N4 machine-independent trig.** Make the sim's trig the same on glibc 2.39 and 2.43 (own implementations or a pinned libm in
   native and the GDScript path), sim-baseline equal on the laptop and both builders. A design note first (cost, perf).
5. **N5 the quiet-window line ~1.0 per core** (SLOT_LOADED_PER_CORE / QW_LOADED_PER_CORE): it waits for quiet, costs no judging power.
6. **Stretch:** the physics-share measurement (what share of a tick and of a check is physics on builder0), for his question.

## How to verify

`make native check` on builder2 per named hash; perf-judge on a quiet builder0; shell-tools-test for tool changes; sim-baseline on
every machine for N4.

## Don't touch

Game code outside `native/**` (twins mirror their GDScript owners' code, which stays the owners'), `tests/baselines/**` (the orchestrator
adopts). Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
