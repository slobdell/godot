# Stream: native (Q5's fields first; C++ twins for the rules that pass; the judged lines and the judging table)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 42** (C42.1, C42.4, CP42.0), your round-41
> brief `streams/archive/round41/native.md` (Status: N1 remote.sh, N2 the wait twin, N3 lines_r41, N5 lint-fast). **You own:**
> `native/**`, `mk/native.mk`, `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`,
> `tools/loaded.sh`, `tools/slot.sh`, `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`,
> `tests/ai_scenarios/guard_line.gd`, `mk/play.mk`'s skirmish recipe, `_agents/judging.md`. **Model:** Opus. **Machine:** builder0
> light lane; builder2 for rows (it is STOPPED at launch; balance starts it); native-proof on builder0.

## The lead's direction

Nothing he sees directly: "core components in C++ long-term" (memory). This round two rules may ship ON from GDScript-only labs
(manoeuvre's Q5 and Q6) and need bit-identical twins first; engage's rule lives in `ElementPlan` (no twin today) and, if its trace
lands in `order_controller.gd`, in a seam you mirror.

## Where things stand (main at launch: see HANDOFF)

- `pair/native-wait` 20300bb52 (Q2 v2's twin) kept as a ref, unmerged; `pair/native-wait-fields` e59aca6aa. Q5's four members
  (`_nopush_for`, `_nopush_until`, `_nopush_since`, `_nopush_press_until`) have no `exec_fields.h` lines, and
  `test_native_exec_state::test_the_table_is_the_scripts_members` fails a tree that carries them (manoeuvre's round-41 close).
- `tools/judge/lines_r41.py` holds Bar K3 v1 and Bar Q3 only; owed: Bar K3 v2 (R41.17), Bar G1 v9 (R41.15), B5's dev lines (R41.18,
  dev: say so). Close step 5b (the inventory + table re-render) was last run for round 40; rounds 41 (and 36-41's inventory) are owed.
- lint-fast is the gate (715 s -> 17 s, loaded box); a quiet-box before/after read is owed, not blocking. slot.sh kills a full check
  at 5,400 s.

## Backlog (in order)

1. **N1 CP42.0: Q5's four exec_fields.h lines, merged alone on day one.** On main the members don't exist yet, so add the lines in the
   form the table test accepts for a member declared later (or land the member declarations too, from `wip/manoeuvre-m1v3` fc8f3697d,
   with manoeuvre's agreement via the orchestrator); `make native quick` green, the exec-state test green with and without the
   cherry-pick (lab it on a scratch tree). Name the hash to the orchestrator the minute it is green.
2. **N2 twins on request.** Q5 (`nopush`) when its bar passes; manoeuvre's Q6 bridge rule; any `order_controller.gd` seam engage's E1
   lands in. `pair/native-<rule>` off the owner's named hash; native-proof 0 mismatches; quick-green; real members only (C42.4).
3. **N3 the judged lines and the table.** lines_r41.py: K3 v2, G1 v9 (and B5's dev lines marked dev); `lines_r42.py` as round 42's bars
   are filed (E1, K4, Q5, Q6, B7, B8, B2s v2); then close step 5b for round 41 now (`tools/judge/probes.py`, `inventory.py`,
   `table.py`, commit `_agents/judging.md` and the csv under `streams/references/round41/native/sizing/`), so round 42's bars read
   the table's sd.
4. **N4 a quiet-box lint-fast read** when builder0 is quiet (`make remote-quiet`): the before/after wall time with the gate, named.
5. **N5 the close's perf-judge windows:** when the orchestrator asks, `make remote-quiet T=perf-judge` on builder0 for each ON flip
   (E1, K4, Q5/Q6, B7), the verdict lines quoted.
6. **Spare:** builder0 test time (the bottleneck): which test shards dominate now that lint is off the path; one proposal, report only.

## How to verify

native-proof; `make native quick-remote`; `python3 -m pytest tools/judge`; a full check of every hash you name.

## Don't touch

GDScript gameplay files (twins mirror them; changes go through their owners), `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**2026-10-26 (session 1, round 42).** Plan: N1 CP42.0 (first; the round's first merge) -> N3 lines_r41 + step 5b while N1's check
runs -> N2 twins as asked (Q5 nopush, Q6 bridge, any E1 seam) -> N3 lines_r42 as bars are filed -> N4 quiet-box lint-fast read when
builder0 is quiet -> N5 perf-judge windows when the orchestrator asks -> spare (test-shard time).

- **N1 CP42.0: 75495744b. builder0 full check RUNNING (started ~evening 2026-10-26).** Decision (the brief's first option, one line
  why): Q5's four members (`_nopush_for` String, `_nopush_until`, `_nopush_since`, `_nopush_press_until` int) go in a new
  `EXEC_MOVER_LATE_FIELDS` list in `exec_fields.h` instead of declaring them in movement.gd: the merge stays inside native's paths,
  and manoeuvre's cherry-pick of a45c0b953 + fc8f3697d stays conflict-free. A late member the script doesn't declare is left
  at its default by the pull (`m_absent` bit), skipped by the scramble and the push, and accepted as absent by
  `test_the_table_is_the_scripts_members`. Once declared it is checked like any other member. New test
  `test_a_late_member_is_skipped_until_declared_then_mirrored` (a Movement subclass declares them). Lab (laptop): without Q5,
  test_native_exec_state 5/0; with Q5 cherry-picked on a scratch branch (clean apply), the table's 191 rows = 191 members,
  the pull compares 114,600 values with 0 mismatches, scramble + push leaves 0 unrestored, and test_native_exec_state +
  test_traffic_nopush 8/0. After Q5 is on main for good, the four lines can move up to the core list (cosmetic).
- **N3:** lines_r41.py + K3 v2 (5), G1 v9 (7), B5 dev (3, `REPORTED (dev)`): 0e93002cd. Step 5b for round 41: 3df630755
  (`references/round41/native/sizing/`: inventory 563 lines / 271 with noise; table unchanged; note in judging.md). lines_r42.py
  scaffold: c63142b73. Judge tests 86/86 (laptop).
