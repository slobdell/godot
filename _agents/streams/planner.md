# Stream: planner (CP-Q: the shared queue without the gang-press starvation; the War Rig's open-ground face-behind served on the library path)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 33** (C33.3, C33.6; C31.5, R31.2
> the seam, R31.6, R31.7 stand), `_agents/judging.md`, and your round-32 brief `streams/archive/round32/planner.md` (CP-Q's
> verdict and its two traces, **Next (round 33 hand-over)** (a)–(c), C32.13). **You own:** `game/ai/planner/**`,
> `native/src/planner_*.{h,cpp}` (native reviews every C++ commit before you push it and owns the build glue: `mk/native.mk`,
> `exec_fields.h`, the seam's record fields), `tests/planner/**`, `tests/test_planner*.gd`, `mk/planner.mk`,
> `references/round33/planner/**`. **Model:** Opus.

## The lead's direction

Round 31: a long truck in a Terminus street turns in a few deliberate legs and never grinds a wall (ON since CP-P1). His
standing rule: **perf cuts ship as hardware presets; the full behaviour stays on better machines**, and he plays on a weak
Intel UHD 620 laptop on purpose (~2.75× slower than builder0). No new words at round 33's preparation.

What he will notice: in a crowded press of gang trucks every long truck gets its planned turn (none starved), without
trucks pinning on a wall at speed; a War Rig told to face behind in open ground turns in planned legs on the C++ path too.

## Where things stand (main at the round-33 docs commit; inherits `0c124cf7`'s green check: builder0 exited 0, 2724/0)

- **On main:** CP-S (the side gate), the SLICE preset (laptop back to SLICE 2: ~0.18–0.24 ms a tick on his laptop,
  `65cc43dd`), the capture fix, `--planner-queue=shared` (refuse early ONLY at rest, `d98656ab`) OFF, `shared-rolling` kept
  for the record. Targets: `planner-judge-queue`, `planner-series-queue`, `planner-trace-hull-rest`,
  `planner-trace-drive-queue`, `planner-stage-s207`.
- **CP-Q PARKED in round 32:** the starvation is gone, but serving 1.5–2× the face plans in a 19-crew press cost drawn
  facing, settling and wall contact; the FIFO's hold was an implicit brake (Terminus s207: shared-rolling pins
  Green_S0_4 on Block_7 2043 ticks; refuse-at-rest 0). Line (3)'s misses at n 6 seeds were not shown to be the queue's:
  its noise was never sized.
- **The seam never serves a War Rig's open-ground face-behind with the library** (189 expansions > PENDING_TICKS × SLICE
  = 180); today's face executor turns the rig.
- Your round-32 branch is `round32/planner` (merged).

## Backlog (in order)

1. **P1 Size line (3) (C33.6 (a)):** the hull-rest gang arm A/A, fifo v fifo, seeds 66–71, per-class sd; file it in
   `judging.md`'s sense (a row the orchestrator adds to `tools/judge/probes.py` at the close).
2. **P2 Re-judge CP-Q (C33.6 (b)):** `--planner-queue=shared` on FRESH seeds, the bar filed in *Bars (round 33)* before any
   number with P1's noise; s207 as a named stage line; the whole suite on the pair tree with the switch ON. Ships ON as a
   pair (native reviews) if it passes; if not, the trace and the reason.
3. **P3 The open-ground face-behind (C33.6 (c)):** the budget or heuristic so the seam serves it (189 > 180), priced per
   preset (laptop and default), deterministic across peers; judged on test_manoeuvre_face_behind's cases and the hull-rest
   rigs. Agree with manoeuvre first who owns a faced finish (its CP-F turns the hull at rest).
4. **Stretch:** the gang-press GOAL_BLOCKED / START_BLOCKED requests that still enter the queue (round 31's numbers): refuse
   them before they queue, if P2 shows they cost.

## How to verify

`make quick-remote` to iterate; `make remote T=check` for hashes you name (the pair tree with the switch ON before any
judged series). `make planner-twin`, `planner-census`, `manoeuvre-hull-rest` (one arm a call), `nav-terminus-drive`,
`scenario_cp2`, `native-verify-scenarios`. Key any new static by instance id, not hull NAME (C32.13), and release freed
hulls in `_sweep`; hull-rest is not run-to-run deterministic, so pair on (faction, seed) and quote the se. Long remote runs
under `systemd-run --user`. Every number: commit, machine, workload, n. A laptop pricing slot goes through the orchestrator.

## Don't touch

Manoeuvre's executor and drive body (PlannerExecutor's consumer side is theirs per R31.2); brains' gate and re-seat;
traffic's give-way; native's `native/**` outside `planner_*`; `game/theme/**`; `tests/baselines/**`; `tools/judge/**`.
Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
