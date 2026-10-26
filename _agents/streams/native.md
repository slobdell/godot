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

**2026-10-26 (session 1).** Plan: N1 (now) -> N2 on request (waiting on manoeuvre's Q2/Q3 spec via the orchestrator) -> N3 lines_r41.py
as bars are filed -> spare: builder0 test-time read.

- **N1 DONE: bfd033228** (`tools/remote.sh`, `tools/copyback_verify.sh`, `tools/test_copyback_verify.sh`). Cause reproduced against
  builder0 2026-10-26: `rsync -a --checksum --files-from=F builder0:~/tank_squad/godot-native/ L/` -> sender `change_dir
  "/home/slobdell/~/tank_squad/godot-native/" failed`, laptop exit 12 (laptop rsync 3.2.7, builder0 3.4.1); the plain `host:~/dir/`
  copy-back is unaffected; home-relative `host:tank_squad/...` with --files-from exits 0. Fix: remote.sh passes `$host:$remote_dir/`;
  copyback_verify.sh rewrites any `host:~/x` source to `host:x`. Test: a stub rsync on PATH that fails `~` + --files-from the same way
  runs the re-copy branch (32/0 with the fix, 29/3 without). `make remote T=shell-tools-test` exited 0 and `make quick-remote` exited 0
  on bfd033228 (builder0). Full check: running on builder0 (result below when it lands).
