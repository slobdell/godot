# Stream: native (every pair, T3b-c first; the four slow twin files split; N5's held ports)

> Read `_agents/orchestration.md` (the worker contract), `_agents/native.md` (*N7*, *Stage 1*), `_agents/workstreams.md`
> **Round 32** (C32.1, C32.8; C31.1, C31.2, R31.1 and its addendum stand), and your round-31 brief
> `streams/archive/round31/native.md` (*Round 31* report: the T3b mirror `413252ea`, T1c-b2 "none ported", the CP-H and
> CP-P1 pairs, *Carried to round 32*; the twin lessons). **You own:** `native/**`, `game/ai/native/**`, `tests/native/**`,
> `tests/test_native*.gd`, `mk/native.mk`, `mk/pace.mk`, `brain_switches.gd` (others add one switch line: merge note),
> `cover_map.gd`, `incoming_fire.gd`'s seam, `think_quiet.gd`, the seams on main, `exec_fields.h`, the planner's build glue;
> plus the stage-1 grants (the seam at the top of `OrderController.compute_command`; `Movement`'s and `Gunnery`'s member
> STORAGE; `traffic.gd` for its port; `wall_contact.gd`'s observer). You review every planner C++ commit for fidelity before
> it is pushed. **Model:** Opus.

## The lead's direction

Round 26: core components in C++ (stage 1 ON 2026-10-12), even without a gain, with an equal answer. Nothing he plays
changes because of this stream alone; every behaviour he sees ships as a pair with its owner.

## Where things stand (main at the round-32 docs commit; inherits `e66b41f1`'s green check: builder0 exited 0, 2657/0)

- Round 31 shipped every pair it was sent: T3b and T4 (OFF), CP-H (`76b7ee46`), CP-P1 (`166f7f1e`). The T3b-c mirror
  `413252ea` (`NativeTraffic.avoid_shape` → `Traffic.shape` as a GDScript callback; inert unless Traffic has `shape`) was
  judged on `f5dc4147` with 0 mismatches in its four twins, and **his yes ships it this round**.
- Your round-31 branch is `round31/native` (kept, not merged).
- **Shard times (builder0, `tests/shard_times.txt`):** `test_native_traffic_hold` 316 s, `test_native_execute` 308 s,
  `test_native_drive` 241 s, `test_native_wall` 185 s: four of the six slowest files in the suite. A check is ~55 min of
  test time (R31.9).

## Backlog (in order; pairs pre-empt your own work, C31.2)

1. **The T3b-c pair (C32.1, CP-T):** re-carry `413252ea` onto current main (CP-H and CP-P1 landed since), twins at 0
   mismatches (`make native test FILTER=native_traffic`), and build the pair tree with traffic's carried T3b-c (agree with
   traffic where it is built; tell the orchestrator). Plain `make remote T=check` on it, switch ON by default; name the hash.
2. **T1c-b2:** confirm "none ported" still holds on current main (`ask()` only through GDScript callbacks) and run
   `native-verify-scenarios` + `traffic-native-verify` on traffic's tree.
3. **The four twin splits (C32.8, R31.9 (3)):** `test_native_traffic_hold`, `test_native_execute`, `test_native_drive`,
   `test_native_wall`, in round 31's `TrafficTwin` pattern (a shared harness, one case or case group per file). Measure
   each on builder0 first; the same assertions divided; test count and the slowest file's seconds before and after; check
   green; name the hash. Test-only, so the orchestrator can merge it on its own.
4. **Pairs as they arrive:** manoeuvre's H1b, brains' B3b-2c and B5c-v6, the planner's side gate and SLICE preset (if any
   of them touch C++ or the drive), in that rough order. Each: mirror, twins at 0, the pair tree with the switch ON,
   plain check, named hash. Under `NATIVE=off`, `native-live-guard` fails by construction (R31.1 addendum).
5. **N5's held ports** (carried, unblocked by CP-P1): `_negotiate`'s body / ask / `_begin_yield`, `_manoeuvre`; each a
   pair with its own switch, proofs and price. Only when no pair waits.

## How to verify

`make remote T=check` and `make remote T=check NATIVE=off` where a port changes; `make native test FILTER=...` for twins
(plain `make test` builds no library; call `tools/remote.sh --light native test 'FILTER=a|b'` when FILTER has `|`);
`native-verify-scenarios`, `native-proof`; determinism and the thirteen lines unmoved unless a pair moves them on purpose.
A waiter greps `>> remote: make.* exited`. Long remote runs under `systemd-run --user`. Every number: commit, machine,
workload, n.

## Don't touch

Brains' think side (`tank_brain.gd` outside your seams, `game/tactics/**`, elements); manoeuvre's drive body and executor
logic (you mirror, they own); traffic's give-way logic; the planner's GDScript; `game/control/**`, `game/camera/**`;
`tests/baselines/**`; `tools/judge/**`. `origin` holds an old `stream/native`: don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
