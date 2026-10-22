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
  - **Builder2 trial, Intel start** (tree bed8b7596, builder2 "Intel(R) Xeon(R) CPU @ 2.20GHz", 2026-10-22 ~12:30 PDT, idle
    box at load 0.3–0.8, `make perf-relative-trial`, n=5):
    - ai_usec_per_tick 19978–21202: the absolute line (20000) flips, FAIL 4 / PASS 1.
    - Reference ratio 2.51–2.54x builder0's nominal. Relative PASS 5 of 5, agreeing 1 of 5.
    - usec per reference ms: median 9054 (8852–9303) v the line 25840.
  - **Reading:** builder2's reference benchmark runs ~2.5x slower than builder0's, but its AI tick only ~1.6x. So
    usec-per-reference-ms isn't machine-invariant. Older builder0 attempts in local build/ logs (no RELATIVE line, commits
    unrecorded, so indicative only) work out to ~11000–16000 per reference ms under load, against builder2's idle ~9000.
    On builder2 the relative line sits 2.85x above what it measures, so it would pass a 2x AI regression. **Not switching.**
    The two verdicts disagree and per_ref's spread across machines is wide.
  - **Left:** builder0 checks keep gathering RELATIVE lines (with their commit). A builder2 AMD start, if the box lands on one.
    If the gap holds, a per-host calibrated line (FAIL_RATIO per cpu model) is the honest next option, not one shared ratio.
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
  test_native_manoeuvre.gd) must follow before its series. Manoeuvre was told (they had thought choose() was a callback).
  **Closed:** manoeuvre isn't building M5b. Their trace (builder0 native, c16c4a0b6, jam 3 maps x 8 seeds, 24 fights): 107 of
  1,166 seated give-ways turned round, 72 of them the scout's kept turn-in, and choose() ran for only 16 returns. No twin.
  N2 has no pending pair. It reopens if doctrine's D2 moves into a mirrored path.
- **N5:** a row per main the round ships. **Next: e1f558d83** (feedback F3 ON). Queued LAST on builder2 (R38.14): after settle's S2
  and S1 v2, doctrine's D2b (OFF + ON) and D3, once its main check is green; doctrine pings "builder2 free". Keep it off builder0 (R38.8). Pair against
  1c484a525.fights.jsonl.
- **guard.py --pair** (68301e6a7, doctrine's Bar G2): the guard's kills and losses a fight and median length, all and per
  guard faction, each with a paired se from the per-seed differences. test_guard 0 failed, test_scoreboard 14/0 (laptop);
  not yet through a full check.
- **N3 closed** for the round (orchestrator accepted "not switching"); an AMD sample only if builder2 comes up on one.

**Side worktrees to remove at close:** ../godot-native-guard, -score, -k5 (and round 37's: -m5, -unstick, -cp371,
-rulespair, if they still exist).
