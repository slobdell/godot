# Stream: native (C++ twins for manoeuvre's traffic rules; the tools every stream leans on)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 41** (C41.1, C41.2), and your round-40 brief
> `streams/archive/round40/native.md` (Status: N4 closed, the twin process, exec_fields rules). **You own:** `native/**`,
> `mk/native.mk`, `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`, `tools/loaded.sh`,
> `tools/slot.sh`, `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`, `tests/ai_scenarios/guard_line.gd`,
> `mk/play.mk`'s skirmish recipe. **Model:** Opus. **Machine:** builder2 for rows; builder0 light lane; native-proof on builder0.

## The lead's direction

Nothing he sees directly: "core components in C++ long-term". This round, manoeuvre's rules (Q2 wait-for-a-turning-friend, Q3 the
bridge speed cap) sit inside `native_drive`'s mirror and can't ship ON without a bit-identical twin.

## Where things stand (main at launch: see HANDOFF)

- native_drive twin, exec_fields.h, native-proof bit identity; pair/native-follow 1838537d7 (F1 v1's twin, not merged: F1 is OFF).
- N4 closed (CORE-MATH v libm 4-4 over 8 rounds, no fix). Round 40's judged lines in `tools/judge/lines_r40.py`.

## Backlog (in order)

1. **N1 remote.sh's literal-~ re-copy.** After a failed copy-back, the `--checksum` re-copy used `/home/slobdell/~/tank_squad/<folder>/`
   (exit 12; manoeuvre, builder2, 2026-10-25 ~21:00). Fix, with a test that runs the re-copy branch. Quick check, merge.
2. **N2 twins on request.** When the orchestrator sends manoeuvre's spec (Q2, Q3), build the twin on a `pair/native-<rule>` branch off
   manoeuvre's named hash; native-proof 0 mismatches; quick-green. Per-crew state = real Movement members with exec_fields.h entries
   (C41.2; reject a static table).
3. **N3 lines for round 41.** As round 40's close step 5b: `tools/judge/lines_r41.py` for the round's bars as they are filed (camera's
   jerk lines if camera asks; orders' and manoeuvre's group-order lines).
4. **Spare time:** read builder0 test time (the bottleneck, not builds): which targets dominate a full check now, and one proposal to
   cut wall time without dropping coverage. Report only.

## How to verify

native-proof; `make native quick-remote`; a full check of every hash you name.

## Don't touch

GDScript gameplay files (twins mirror them; changes go through their owners), `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**ROUND 41 CLOSE REPORT (native, 2026-10-26 ~08:30).**
- **Final green hash: c19dc10ec** (builder0 full check: `make check exited 0`, test 3243 passed / 0 failed, `26 passed, 2 NOT
  JUDGED` (timing refusals on a 2.1-2.45x loaded box), sim-baseline 13 unmoved, determinism 258cc8b1c957a796; merged as 6209e9f89).
  Commits after it on stream/native, none with a full check of its own: a0c281dec (tools/test_full_check_lock.sh case 7 only; builder0
  light shell-tools-test exited 0, 22/0; in the orchestrator's next main batch), 467d36596 + a18a8a2b8 (tools/judge/lines_r41.py
  data; 548 lines load, judge tests pass, laptop) and Status commits. No separate tip check (orchestrator): a0c281dec is on main, and
  the tip goes into the next main batch, whose check covers it. Native is idle for the round unless a twin is asked for.
- **N1 DONE** (bfd033228; remote.sh's re-copy no longer passes a literal `~` with --files-from; covered by c19dc10ec's real re-copy).
- **N2:** pair/native-wait-fields e59aca6aa (the four `_wait_*` members; on manoeuvre's tree) and **pair/native-wait 20300bb52** (Q2 v2's
  wait rule twinned; builder0 quick 151/0, native-proof EQUAL x6). Bar Q3 FAILED (R41.13): 20300bb52 is KEPT AS A REF BRANCH,
  UNMERGED (do not delete). Q5's nopush fields not built (Q5 closed OFF, R41.10).
- **N3:** lines_r41.py holds Bar K3 v1 (4 lines) and Bar Q3 (7 lines). Not added (no verdict lines): O2, G1 v7 / v8 (withdrawn
  unread), Q4 / Q5 (closed OFF, no bar). Owed when they land: K3 v2, G1 v9, B5, B2s v2 (carried). Note:
  references/round35/native/sizing/inventory.{md,csv} were last rendered in round 35; `python3 tools/judge/inventory.py` would add
  rounds 36-41 (~470 lines of diff): left for whoever owns the next inventory pass.
- **N4 (report) -> N5 (R41.2, granted core.mk's lint gate): lint-fast is the check's gate** (a64611c15; merged with c19dc10ec): 715 s
  gate -> 17 s on builder0; the critical path is test alone (~-700 s projected at main's test speed; the after-read was on a loaded
  box: a quiet-box read is still owed, not blocking).
- **Asks done for others:** GUARD_TARGET (balance, e41b6d70e); case 7 flake (a0c281dec).
- **Known issue:** slot.sh kills a full check at 5,400 s; a saturated builder0 (c32dc33ff's N1-alone check, CHECK_JOBS=2) hit it.
- **Worktrees:** `../godot-native-pair` (pair branches, local.mk offset 9) can be removed at the round's close; builder0 folders
  `godot-native-pair*` likewise. Nothing waits on the lead.

**2026-10-26 (session 1).** Plan: N1 (now) -> N2 on request (waiting on manoeuvre's Q2/Q3 spec via the orchestrator) -> N3 lines_r41.py
as bars are filed -> spare: builder0 test-time read.

- **N1 DONE: bfd033228** (`tools/remote.sh`, `tools/copyback_verify.sh`, `tools/test_copyback_verify.sh`). Cause reproduced against
  builder0 2026-10-26: `rsync -a --checksum --files-from=F builder0:~/tank_squad/godot-native/ L/` -> sender `change_dir
  "/home/slobdell/~/tank_squad/godot-native/" failed`, laptop exit 12 (laptop rsync 3.2.7, builder0 3.4.1); the plain `host:~/dir/`
  copy-back is unaffected; home-relative `host:tank_squad/...` with --files-from exits 0. Fix: remote.sh passes `$host:$remote_dir/`;
  copyback_verify.sh rewrites any `host:~/x` source to `host:x`. Test: a stub rsync on PATH that fails `~` + --files-from the same way
  runs the re-copy branch (32/0 with the fix, 29/3 without). `make remote T=shell-tools-test` exited 0 and `make quick-remote` exited 0
  on bfd033228 (builder0). Full check c32dc33ff (N1 alone, builder0, CHECK_JOBS=2 on a saturated box): **killed by slot.sh at 5,400 s**
  with 3243 passed / 0 failed in test, sim-baseline 13 unmoved, determinism 258cc8b1c957a796; army-loop-smoke and
  native-verify-scenarios read FAIL only because they were mid-run at the kill (empty logs). Its copy-back's --checksum re-copy ran for
  real with no exit 12. N1 is covered by the tip check below (orchestrator: no N1-alone re-run).
- **TIP CHECK GREEN: c19dc10ec (N1 + GUARD_TARGET + N5), builder0, 2026-10-26: `make check exited 0 (build/ copied back)`, test
  3243 passed / 0 failed, `>> check: 26 passed, 2 NOT JUDGED`** (perf-judge refused 3x at 1.33-2.45x load; ai-scenarios-check's
  scenario_perf unpinned), sim-baseline 13 unmoved, determinism 258cc8b1c957a796, copy-back verified 237 files, 4,077 s. Merged to
  main as 6209e9f89 by the orchestrator.
- **N3 scaffold: 7a1cd1227.** `tools/judge/lines_r41.py` (empty `LINES`, same fields as lines_r40) wired into `tools/judge/lines.py`
  (537 lines load). **467d36596: Bar K3 v1** (R41.11; lines 1, 2, 4 PASS, 3 FAIL). **a18a8a2b8: Bar Q3** (R41.13, 7 lines: both
  deciding lines, the crossing line, G5-G7, fight G1-G4). 548 load, judge tests pass.
- **N4 (spare, REPORT ONLY): what dominates a builder0 full check, and one proposal.**
  *Read:* main's last full check on builder0 (`~/tank_squad/godot/build/check/{started,done}` mtimes, 2026-10-26 01:20, main
  c36217f79-era tree): wall **2,208 s**. `lint` **715 s** (start +14 to +729), then `test` **1,479 s** (+729 to +2,208); every other
  target ran inside test's shadow (native-verify-scenarios 385, ai-scenarios-check 376, remote-guard-test 219, bridge-pooled 192,
  announcer-check 152, web-smoke 143, audio-check 120; the rest <= 44 s). **Critical path = lint + test = 2,194 s of 2,208.** Lint gates
  every target by design (`mk/core.mk:582`, `_cp-X: | _cp-lint`), so for 12 minutes builder0 runs only lint's 6 checkers.
  *Why lint is slow:* 1,212 files, one Godot `--check-only` process each at -P6 = ~3.5 s a file. The cost is each process re-loading
  the file's dependency graph: builder0, load ~5.7, single runs: `steering.gd` 0.26 s / 103 MB, `movement.gd` 4.40 s / 493 MB,
  `match.gd` 4.57 s / 470 MB, a bare `--quit` 5.3 s.
  *Measured alternative:* one Godot process that `ResourceLoader.load`s all 1,212 scripts (scratch loader, not committed; builder0,
  load 5.9, the round-40 godot-native-score tree): **13.9 s wall, 495 MB peak**. Mutation check (same run + three planted files): a
  syntax error, the file that preloads it, and a typed-assignment error each print `SCRIPT ERROR: Parse Error ... (res://<file>:<line>)`.
  *Proposal (core.mk is not mine; whoever owns check decides):* add `lint-fast` (that one-process load, ~15 s, fails on any `Parse
  Error`/`SCRIPT ERROR` not in the baseline) as THE gate, and make the per-file `lint` an ordinary check target running beside `test`.
  Coverage is unchanged (per-file lint still runs and judges exactly as now; the gate still stops 25 targets running into a parse
  error). Expected: test starts ~700 s earlier, wall ~2,208 -> ~1,500-1,600 s (-25-30 %) at that load; lint's 6 checkers + test x5
  on 12 threads will slow test somewhat, so the bar is an A/B of 3 pairs on builder0 like T1's (round 9). Unknowns: the 8 baselined
  lint artefacts are per-file findings and may not appear in a one-process load (the gate needs its own small baseline, or none).
- **GUARD_TARGET (balance's ask via the orchestrator): e41b6d70e.** `tools/scoreboard/guard.sh` takes `GUARD_TARGET` (default
  `guard-run`; validated as a target name; the exit-line match follows it). `tools/test_guard_target.sh` runs guard.sh end to end on a
  stub repo, 8/0 (4 fail without the knob). Retires `tools/balance/guard_probe.sh` (its sed now refuses, by design, on the new line).
- **N2 first piece: pair/native-wait-fields e59aca6aa** (off manoeuvre e6624abe5; worktree `../godot-native-pair`, local.mk offset 9).
  exec_fields.h: `_wait_for`, `_wait_since`, `_wait_refused`, `_wait_refused_until` after `yield_spot`. builder0: `make native quick`
  exited 0; `make native test FILTER=test_native_exec_state` 4/0; native-proof EQUAL on/off/ab 5cf09094178e2984. Merge WITH manoeuvre's
  Q2 scaffold (on main the members don't exist).
- **N2 the wait rule's twin (Bar Q3, `--traffic-on=wait` v2): pair/native-wait 20300bb52** (off manoeuvre f6d9d7b1b; worktree
  `../godot-native-pair`). drive_native.cpp: `avoid`'s two wait points, `wait` / `wait_end` / `wait_blocker` / `wait_kind` (the other
  mover through its ObjectView) / `meet_in`, the ask gate's `_wait_for == ""`; configured from Movement.WAIT_* (absent: off).
  Traffic._chain_native keeps native_drive for wait; test_traffic_wait's switch test flipped. New tests/test_native_wait.gd (a file
  crossed by a column, a crew behind a pivoting tracked friend, one behind a parked friend; ON / ON owned / OFF). Laptop: 2,880
  drives a stage, 0 mismatches; ON 491 crew-ticks held, 21 waits (moving 464, turning 6, waiting 20), OFF 0; with
  test_traffic_wait 8/0. Mutations: wait branch dropped -> 377 mismatches, the ask gate's clause dropped -> 400. `wait_long` is never
  incremented, mirroring the GDScript (manoeuvre: the spec line came from v3; keep it). If Bar Q3 fails, the twin is discarded.
  **QUICK-GREEN builder0 light 20300bb52: exited 0, 151 passed, 0 failed** (the diff's tests + the five drive twins; the wait stages
  2,880 drives each, 0 mismatches). native-proof EQUAL on/off/ab, builder0, sumps: 92721 off 5cf09094178e2984 / on cd879db30c7894e5;
  8001 off a092d3b70748e62b / on 674f8f6bb426edac; 8002 off 09d72fa169555ee6 / on 1db462f745d0e8d7 (ON moves every fight).
  Sent to the orchestrator; merges with manoeuvre's Bar Q3 tree on a pass.
- **test_full_check_lock case 7 (orchestrator, a builder2 flake): a0c281dec.** The holder holds until released; builder_checks is polled
  up to 10 s for the holder's folder (was a fixed 0.3 s). Laptop 22/0 (and x3 under 8 busy loops); builder0 light shell-tools-test
  exited 0, 22/0.
- **Q5 `nopush` fields: NOT BUILT** (Q5 closed OFF, R41.10). Bar Q3 FAILED (R41.13): pair/native-wait 20300bb52 kept as a ref,
  unmerged.
- **N5 (R41.2, granted core.mk's lint gate): lint-fast.** a64611c15 (+ .uid 0165f3d67). `make lint-fast`: tests/lint/lint_fast.gd loads
  every script in one process; tools/lint_fast.py turns `SCRIPT ERROR`/`Parse Error` + `at: (res://f:l)` into `f:l: msg` findings; no
  baseline; fails on: any finding, a planted file not reported, a file count short, no LINT_FAST_DONE. Planted every run: syntax error,
  a script preloading it, a typed-assignment error (tests/fixtures/lint_fast/), lint's ternary probe. CHECK_TARGETS = lint-fast lint
  test ...; every wrapper ordered after `_cp-lint-fast`. Tests: tools/test_lint_fast.sh 12/0 (canned engine output);
  test_engine_log_gate.sh now stubs lint-fast (23/0). builder0 light lane on the real tree: 1,217 scripts, 24.4 s, 4 planted seen,
  0 findings.
  *What per-file lint catches that lint-fast misses (builder0, planted, both checkers):* no real error found. A preload cycle (b reads a
  missing const of a): lint-fast names b:4, plus `Compile Error: Failed to compile depended scripts` on a when a loads first; per-file
  names both files with the same message. Typed errors in an inner class, a runtime error in a static initializer: both see them.
  An unused-variable warning: neither. What lint-fast does NOT have are lint's 8 baselined --check-only artefacts (false positives).
  *Before v after full checks (builder0):* before = main's 01:20 check, wall 2,208 s (lint gate 715 s, then test 1,479 s). After =
  c19dc10ec's tip check on a box loaded 2.1-2.45x (perf-judge's ratios): lint-fast gate **17 s** (1,217 scripts, 16.2 s, 4 planted
  seen), test started at +17 s and ran 3,385 s (2.3x main's: the load), per-file lint 2,445 s beside it, wall 4,077 s. The walls are
  NOT comparable (load). What the load cannot move: the gate fell 715 -> 17 s, so the critical path is test alone (projected ~1,496 s
  v 2,194 s at main's test speed, ~-700 s; a projection, not a reading). A quiet-box read is wanted when one opens (orchestrator:
  don't hold anything for it).
