# Stream: native (every pair; a shell never RPCs a dropped player; every judged stage pinned)

> Read `_agents/orchestration.md` (the worker contract), `_agents/native.md` (*N7*, *Stage 1*), `_agents/workstreams.md`
> **Round 34** (C34.2, C34.4, C34.5, C34.7, C34.8 (a); C31.1, C31.2 stand; R33.25 in *Round 33*), `_agents/remote_builds.md`
> (the native traps), and your round-33 brief `streams/archive/round33/native.md` (its close-out Status).
> **You own:** `native/**` (outside the planner's `planner_*`, which you review), `game/ai/native/**`, `tests/native/**`,
> `tests/test_native*.gd`, `mk/native.mk`, `mk/pace.mk`, `brain_switches.gd` (others add one switch line: merge note),
> `cover_map.gd`, `incoming_fire.gd`'s seam, `think_quiet.gd`, the seams on main, `exec_fields.h`, the planner's build glue,
> the stage-1 grants, and round 33's test-infra grants (mk/core.mk's `test`/`check`, mk/web.mk's web-smoke judge,
> tools/test_slot_light.sh, tools/remote.sh). **Granted (round 34):** C34.7's guard on `_shell_hit`'s RPC in
> `game/match/match.gd` and the shell's teardown, with a test. C34.8 (a)'s `--fixed-fps $(SIM_HZ)` token in nav.mk,
> pace.mk, planner.mk, command.mk and tactics.mk's direct run_tests.gd callers, and in each unpinned JUDGED stage target.
> One token each, with a merge note. **Model:** Opus.

## The lead's direction

Round 26: core components in C++ (stage 1 ON 2026-10-12), even without a gain, with an equal answer; stage 2 deferred
(his call). Nothing he plays changes because of this stream alone; every behaviour he sees ships as a pair with its owner.
He is building toward relay-only network play, so a network log that is clean under load matters.

## Where things stand (main at the round-34 docs commit)

- **Round 33 shipped from native:** N5.M (`_manoeuvre` in C++), N5.Y (the give-way negotiation in C++), the fresh-process
  twin stages (the order-dependent floors are fixed for good), the controller twin's timer fix on Zen 5, and the test infra
  (the suite at `--fixed-fps`, `make test` refusing without a library, load-aware NOT JUDGED, npm once under a lock,
  test_native_gate split). C33.9's stop hand-back (`pair/native-c339` `2f9ad0fb9`) waits for manoeuvre's turn-in, which did not ship
  (R33.39; C34.10). It covers any narrowing.
- **Waiting pairs (C31.2: they pre-empt everything):**
  - traffic's parkedroom v4 needs your hand-back REBASED onto current main (`pair/native-parkedroom` `5e5465af8`:
    `ae8d6e858`, `f16f49867`, `a7999c5c4`, `bcb0af2ba`, `6596e871c`).
  - brains' scout try 2: the `decide` mirror (`pair/native-scout` `0565d1a89`, green for try 1; rework for the duel-only rule).
  - manoeuvre's CP-F attempt 4: its mirrors.
  - traffic's T4 only if it returns (`pair/native-ghost-on` `b2b97188d`).
- **R33.25:** relay-smoke under a full check's load logs ×6 "Trying to call an RPC via a multiplayer peer which is not
  connected" from match.gd:2094 `_shell_hit` ← shell.gd `_fly`. It passes alone. It's the known red that doesn't block
  (R33.20's family).

## Backlog (in order)

1. **N1 Pairs, as they arrive.** Each: review the diff, mirror or hand back, twins at 0 mismatches, and the owner's pair
   check names the hash.
2. **N2 relay-smoke's shell RPC (C34.7).** A test that drops the peer while a shell is in flight and fails without the
   fix. Then guard the RPC on a connected peer, or stop shells at teardown. relay-smoke and net-smoke green in a full check
   on a loaded box (builder2 with other jobs running).
3. **N3 Pin every judged stage (C34.8 (a)).** Audit `mk/*.mk` for unpinned `$(GODOT) --headless` calls that a JUDGED target
   runs (renders, smokes and network targets keep the wall clock where that's the point; say which and why). Pin them and
   the five direct run_tests.gd callers. Make a moves list like the suite's bar (twice pinned, twice free, one commit).
   Every mover gets a reason, and nothing is loosened.
4. **N4 The library refusal, the rest of the way:** `make test` refuses; audit native-verify-suite, the shard targets and
   the FILTER paths that could still pass the twins vacuously ("native: absent").
5. **N5 Move the yield Sumps stage off the pits** (your round-33 note).
6. **Stretch:** a native turn-in, only if perf-judge shows the C33.9 hand-back costs; twin splits only if shard balance
   needs them.

## How to verify

`make native check` (never `make remote T=test` for twins: it now refuses without a library). `native-proof`,
`native-verify-scenarios`, the twin files. Long remote runs under `systemd-run --user`. Every number: commit, machine,
NATIVE line, n.

## Don't touch

Gameplay behaviour in any stream's GDScript (mirror it, don't change it); `game/ai/planner/**` (review only);
`tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
