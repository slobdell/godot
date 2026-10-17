# Stream: native (every pair; N5's held ports once traffic's far-loop design settles)

> Read `_agents/orchestration.md` (the worker contract), `_agents/native.md` (*N7*, *Stage 1*), `_agents/workstreams.md`
> **Round 33** (C33.2, C33.8; C31.1, C31.2, R31.1 and its addendum stand), and your round-32 brief
> `streams/archive/round32/native.md` (the pairs, the twin splits and their lesson, the swap pair's assessment, N5's hold).
> **You own:** `native/**` (outside the planner's `planner_*`, which you review), `game/ai/native/**`, `tests/native/**`,
> `tests/test_native*.gd`, `mk/native.mk`, `mk/pace.mk`, `brain_switches.gd` (others add one switch line: merge note),
> `cover_map.gd`, `incoming_fire.gd`'s seam, `think_quiet.gd`, the seams on main, `exec_fields.h`, the planner's build glue;
> plus the stage-1 grants (the seam at the top of `OrderController.compute_command`; `Movement`'s and `Gunnery`'s member
> STORAGE; `traffic.gd` for its port; `wall_contact.gd`'s observer). You review every planner C++ commit for fidelity before
> it is pushed. **Model:** Opus.

## The lead's direction

Round 26: core components in C++ (stage 1 ON 2026-10-12), even without a gain, with an equal answer; stage 2 deferred (his
call). Nothing he plays changes because of this stream alone; every behaviour he sees ships as a pair with its owner.

## Where things stand (main at the round-33 docs commit; inherits `0c124cf7`'s green check: builder0 exited 0, 2724/0)

- Round 32: every pair shipped (T3b-c, T1c-b2 "none ported", H1b), the four twin files split (CPU seconds roughly halved
  per file), two order-dependent twin reds fixed. The swap pair (`pair/swap-ship`) did not merge: the swap is parked.
- **N5's held ports** (`_negotiate`'s body / ask / `_begin_yield`, `_manoeuvre`) stay HELD until traffic's CP-X design is
  written (C33.2 (2)): it will likely change exactly those.
- `test_native_face_behind` compared 0 native executes in round 32 (vacuous): check whether a floor landed; if not, add one.
- Your round-32 branch is `round32/native` (merged).

## Backlog (in order; pairs pre-empt your own work, C31.2)

1. **The face_behind floor** (if missing): a native-execute floor so the twin cannot pass vacuously; test-only; name the hash.
2. **Pairs as they arrive:** manoeuvre's F0/CP-F (the face at rest touches the drive and the executor), brains' R1 (likely
   none ported: say so), B10b, B11b and B5c-v6 (the side-gate mirror on `pair/brains-v6-carry`), planner's CP-Q and
   face-behind budget (review its C++), traffic's CP-X. Each: mirror, twins at 0, the pair tree with the switch ON, plain
   check, named hash. Under `NATIVE=off`, `native-live-guard` fails by construction (R31.1 addendum).
3. **N5's held ports**, once CP-X's design is written in traffic's brief (the orchestrator tells you): each a pair with its
   own switch, proofs and price.
4. **Stretch:** the slowest remaining twin files (`tests/shard_times.txt`), split by frame where a floor is a branch
   (your round-32 lesson), measured as CPU seconds.

## How to verify

`make remote T=check` and `make remote T=check NATIVE=off` where a port changes; `make native test FILTER=...` for twins
(`tools/remote.sh --light native test 'FILTER=a|b'` when FILTER has `|`); `native-verify-scenarios`, `native-proof`;
determinism and the thirteen lines unmoved unless a pair moves them on purpose. A waiter greps `>> remote: make.* exited`.
Long remote runs under `systemd-run --user`. Every number: commit, machine, workload, n.

## Don't touch

Brains' think side (`tank_brain.gd` outside your seams, `game/tactics/**`, elements); manoeuvre's drive body and executor
logic (you mirror, they own); traffic's give-way logic; the planner's GDScript; `game/control/**`, `game/camera/**`,
`game/match/**`; `tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
