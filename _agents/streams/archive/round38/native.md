> **ARCHIVED (round 38 closed 2026-10-23).** The branch becomes `round38/native`; its unmerged references stay on that branch. Round 39's brief is `streams/native.md` where one exists.

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

### Report (round 38 worker, 2026-10-23 ~12:45 PDT)

**HAND-OVER (green): 0e1753e0f.** It carries: the N5 row for main 686150ed2 (3797a9ccc: rows/, guards/ json + fights.jsonl,
mains.txt, the README table); run.sh's gcloud PATH fix (5fa327ace); the R38.25 lesson in remote_builds.md (1f714933a); Status.
main 686150ed2 is merged in (ceaf6a38c; remote_builds.md conflict: kept both round-38 bullets).
- Full check, builder2, 13:04-13:38 (load at start 1.19 6.20 13.44): `make check exited 0`, 3135 passed / 0 failed, 25 passed,
  2 NOT JUDGED (perf-judge: builder2 isn't a judging machine; scenario_perf: loaded, ref 2.60x). Scenarios 53 passed, 4 pending.
- In it: web match smoke first sound 16.4 s (bound 30 s); test_loaded 9/0 (box at 23.50 on 16 cores, 1.47 per core);
  builder-checks 9/0; quiet-window 28/0; slot-light 6/0.
- **First-sound watch:** 29.9 s (a15a48de8, 2.15 per core) and 29.2 s (main 9a6909305), now 16.4 s here. No quiet-box read near
  the bound, so no change to the bound or the line.

**R38.25 twin case (orders' 18 s jam split): MACHINE, not path.** glibc 2.39 (laptop) v 2.43 (builder0, builder2).
- The float trig `atan2f acosf asinf atanf tanf` differs; native == GDScript on each machine. Lesson + shim recipe: remote_builds.md
  (1f714933a).
- Under the shim, `atan2f` alone flips the case (dropping the others changes nothing). The laptop's native arm gives 28.6 there
  because Godot DEEPBINDs the extension: native keeps the system libm, while the engine takes the shim (LD_DEBUG=bindings).
- So it's a shim limitation, **not a native seam.** Engine and native call the same libm functions.
- Scratch worktree ../godot-native-twin: removed 2026-10-23.

**MERGED:** main 9a6909305 merges a15a48de8 (merged back into stream/native, 51d5cd262).
- **Watch (orchestrator):** web-smoke's first sound. a15a48de8 passed at 29.9 s v the 30 s bound, at 2.15 per core (above the
  1.5 line, so a miss there would have read NOT JUDGED). Record first-sound time and per-core load from each check. If quiet
  boxes (< 1.5 per core) also land within ~1 s of the bound, revisit the bound or the line.

**Was the hand-over (green): a15a48de8** = 68301e6a7 (guard.py --pair G2) + 47112af3d (builder_checks ssh) + 54898f5b1 (per-core
gates; mk/web.mk ruled IN for the first-sound gate call only) + Status notes.
- Full check, builder2: `make check exited 0`, 3055 passed / 0 failed, 25 passed, 2 NOT JUDGED.
  - perf-judge: builder2 isn't a judging machine.
  - scenario_perf: loaded, ref 4.95x.
- In that check: test_loaded 9/0 (box at load 34.38 on 16 cores, 2.15 per core); builder-checks 9/0; quiet-window 28/0;
  slot-light 6/0; scoreboard 14/0. Web match smoke PASSED, first sound 29.9 s (bound 30 s).

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
- **N5: a row per main the round ships.** **Done: 686150ed2** (3797a9ccc, builder2, 2026-10-23 10:56-12:35). Run on main
  686150ed2 rather than 9d2897fd8 at the orchestrator's ask: it includes 9d2897fd8 and adds the latch ON (e1f602fbf).
  9d2897fd8's run had been preempted at ~10:40 before reading anything.
  - Fights: verdict ok, 40/48/36, 0 SCRIPT ERRORs (run.sh SCORE_JOBS=14). Every moved line is inside its noise (e.g. never settled
    9 -> 8 of 48, twitch 11.5 -> 10.8 m).
  - Guard lines (320 of 320 fights, 0 attempts lost): blob wins 47 % (± 7 %), kr 0.85; turtle 41 % (± 16 %), kr 0.81.
  - Paired v round 37's 1c484a525 (round 38's base): blob -0.019 (se 0.010, flips 4 lost / 1 won, McNemar p 0.19); turtle
    +0.012 (se 0.009, 1 / 3). Kills and losses a fight and median lengths are all within ~2 se. Only 5 and 4 of the 160 fights
    flip, so the round's changes barely touch the guard fights.
  - Per-fight rows: references/scoreboard/guards/686150ed2.fights.jsonl (a pairing base for round 39 if it wants one).
  - run.sh fix (5fa327ace): its 255 retry's gcp-start died with Error 127 under systemd-run (no gcloud on PATH); it now has
    guard.sh's PATH line.
- **guard.py --pair** (68301e6a7, doctrine's Bar G2): the guard's kills and losses a fight and median length, all and per
  guard faction, each with a paired se from the per-seed differences. test_guard 0 failed, test_scoreboard 14/0 (laptop);
  not yet through a full check. Doctrine cross-checked it against their scratch script on D2 (acbdef4c5-defend v 1c484a525):
  turtle kills -2.91 and losses -3.30 a fight sum to their -6.21, and the medians match.
- **builder_checks.sh** (47112af3d, R38.15): a failed ssh (255) is never "0 running" any more. Plain mode exits 3 with no count;
  `--wait-below` asks again each poll and gives up (exit 3) after BUILDER_CHECKS_TRIES (30) failed asks in a row.
  test_builder_checks 9/0 (laptop, a fake ssh). Real asks: builder0 and builder2 each count 1; an unreachable host exits 3.
- **Wall-clock gates per physical core** (54898f5b1, R38.19): tools/loaded.sh (1-min load per lscpu core, 1.5) is now the one
  rule for web-smoke's first-sound bound (tools/web_smoke/first_sound_gate.sh, called from mk/web.mk), test_quiet_window and
  test_slot_light. The per-nproc rule read builder2 (32 vCPU / 16 cores) as quiet up to load 48, so 4 checks FAILed at 31–38.
  Now the line is builder2 24, builder0 15 (was 18). test_loaded 9/0 (loaded box -> NOT JUDGED; quiet box or a 2nd FAIL ->
  FAIL); shell-tools-test exit 0 (laptop, 30 suites). Touches mk/web.mk (native's round-33 gate; not in the owned list, so
  flagged in the hand-over).
- **N3 closed** for the round (orchestrator accepted "not switching"); an AMD sample only if builder2 comes up on one.

**Round-39 note (R38, orchestrator, information only): the quiet-window setup should refuse at a lower line.** Orders' builder0
check FAILed test_slot_light's setup "not in 30 s, at load 14.91 on 10 cores" (1.49 per core, just under 1.5), the same red
R38.18 cleared by a solo re-run. That setup WAITS for quiet; it doesn't measure a bound, so a lower loaded line there (~1.0 per
core, SLOT_LOADED_PER_CORE / QW_LOADED_PER_CORE) costs nothing in judging power. Not changed this round, per the orchestrator.

**Side worktrees (2026-10-23):** removed ../godot-native-twin, -cp371, -m5, -rulespair, -unstick and -k5 (their pair/native-*
branches are kept; -k5's four modified test files were an overlay of committed versions, d9fde0b33 / 7a76164dc). Kept:
../godot-native-guard and -score, the scratch trees guard.sh and run.sh reuse.

**END STATE, round 38:** a7aab60be (green 0e1753e0f) merged alone as main 30c23d4c8.
