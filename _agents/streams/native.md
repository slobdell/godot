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

### Report (round 38 worker, 2026-10-22 ~10:30 PDT)

**MERGED:** main cc7c7ef1a merges 595bb9208 (R38.1). The two load-49 reds were accepted on the solo re-runs (R36.12).
- **N1 done** (90adaf963): the row for round 37's shipped main 1c484a525, on builder2.
  - Fights: verdict ok, 40/48/36, 0 SCRIPT ERRORs (run.sh, SCORE_JOBS=14).
  - Guard lines (guard.sh, 320 of 320 fights, 0 lost): blob wins 49 % (± 7 %), kr 0.86; turtle 40 % (± 16 %), kr 0.81.
  - Paired v the 9d325e291 base: blob +0.013 (se 0.037, McNemar p 0.70), turtle +0.006 (se 0.019). Every line is inside
    its noise.
  - **Round 38's pairing base:** references/scoreboard/guards/1c484a525.fights.jsonl
    (`tools/scoreboard/guard.py --pair <that> <arm raw dir>`).
- **N3, step 1 done** (a61d3405d): perf-judge records the relative line beside the absolute, not deciding.
  - PERF_JUDGE_RELATIVE per attempt: usec per reference ms v FAIL_RATIO 25840 (20000 / builder0's 0.774 ms), the cpu model,
    and whether the two lines agree.
  - The builder2 trial mode: `make perf-relative-trial`, which exits 3 by design.
  - The reader: `tools/judge/perf_relative.py <dirs>`.
  - test_perf_judge 13/0, test_perf_relative 2/0.
  - **Left:** the record. Builder0 checks gather lines as they run; then builder2 trials on an Intel and an AMD start.
    Switch only if the verdicts agree and per_ref's spread across the machines is narrow.
- **N4 done** (595bb9208): guard.sh sends every seed it still needs in ONE call (GUARD_CHUNK=0), so xargs keeps 20 fights
  running across seeds.
  - Each call passes GUARD_RESUME=1: the remote build/guards/ is stamped (commit, kinds, args, seconds) and skips fights that
    already printed GUARD_RESULT. So a call cut by a 255 resumes per fight, and the local re-run still resumes per seed.
  - Smoke on builder2 (blob gorge, base tree 9d325e291): 6 of 6 fights identical to the base; the second call printed
    "resuming, 4 fights already read" and ran only the 2 new fights.
  - Not exercised: a real preemption mid-call.
- **N2 audit (2026-10-22):** settle (8bd480f96: element_plan/element_situation), manoeuvre M7 (b5775051e: element_commander
  `_member_ways`) and doctrine D2 (not yet written; aimed at element_commander/posture/element_plan) touch nothing native/src
  reads, so no twin is needed. **M5b (reverse-back) is the one to watch:** if it changes Manoeuvre.choose/behind/simulate, the
  native mirror (drive_native.cpp `manoeuvre_decide` / `man_choose` / `man_behind` / `man_simulate`, round 33 N5.M; twin
  test_native_manoeuvre.gd) must follow before its series. Manoeuvre was told (they had thought choose() was a callback). Spec
  pending their trace (lab/manoeuvre-r38-m5btrace 6d43ce7eb).
- **N5:** a row per main the round ships.

**Side worktrees to remove at close:** ../godot-native-guard, -score, -k5 (and round 37's: -m5, -unstick, -cp371,
-rulespair, if they still exist).
