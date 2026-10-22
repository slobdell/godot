# Stream: native (scoreboard rows, twins, guard tooling, a perf line builder2 can judge)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/native.md`, `_agents/workstreams.md` **Round 38**
> (C38.1, C38.2). Your round-37 brief and close notes: `streams/archive/round37/native.md`. **You own:** `native/**`, `mk/native.mk`,
> `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`, `tests/ai_scenarios/guard_line.gd`, the
> test-hygiene grant (C36.5). **Model:** Opus, CONTINUING in its round-37 session and worktree (`stream/native`). **Machine:** builder2.

## The lead's direction

Native is C++ for core components long-term; nothing in play depends on this stream alone. The guard lines are the round's measure of
"a blob frontal assault loses" (round 36/37).

## Backlog (in order)

1. **N1 finish round 37's row:** the scoreboard row (fights + both guard lines) for main 1c484a525; hand over a green hash (the
   orchestrator merges it, then you `git merge main` and keep working on `stream/native`).
2. **N2 twins** for every round-38 pair that needs one (settle's seat deal / latch v2, manoeuvre's M5b reverse-back, doctrine's hold):
   0 mismatches before their series.
3. **N3 perf-judge's machine-relative line** (your round-37 close note): both verdicts recorded on a round of builder0 checks plus
   builder2 runs on an Intel and an AMD start; switch only if they agree.
4. **N4 guard.sh's rolling queue** (keep ~20 fights running across seeds, keep resumability and the 255-retry).
5. **N5** a scoreboard row for every main the round ships.

## How to verify

Twins 0 mismatches; `make native check` per named hash; every number with commit, machine, workload, n.

## Don't touch

Game GDScript outside your grants, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
