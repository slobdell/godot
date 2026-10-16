# Stream: planner (the side gate brains' arrival needs; SLICE as a hardware preset; the gang-press queue that starves)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 32** (C32.4, C32.7, C32.8) and
> *Round 31* (C31.5, R31.2 the seam, R31.6, R31.7), `_agents/judging.md`, and your round-31 brief
> `streams/archive/round31/planner.md` (the report, **Hand-over for round 32 (1), (2) and (3)**, the seam, CP-P1's bar and
> line (f)). **You own:** `game/ai/planner/**`, `native/src/planner_*.{h,cpp}` (native reviews every C++ commit before you
> push it and owns the build glue: `mk/native.mk`, `exec_fields.h`, the seam's record fields), `tests/planner/**`,
> `tests/test_planner*.gd`, `mk/planner.mk`, `references/round32/planner/**`. **Granted this round:** the SLICE knob in
> `game/theme/fx/fx_quality.gd` (`FxQuality`, one additive field, merge note), or a sim-side preset read you design if a
> render preset must not steer the sim (your call, one reason recorded). **Model:** Opus (round 31 ran this stream on Fable;
> his rule this round is Opus everywhere, and the hard part, the port and the seam, is done).

## The lead's direction

Round 31: a long truck in a Terminus street turns in a few deliberate legs and never grinds a wall (SHIPPED ON as CP-P1).
His standing rule: **perf cuts ship as hardware presets; the full behaviour stays on better GPUs/CPUs**, and he plays on a
weak Intel UHD 620 laptop on purpose (~2.75× slower than builder0).

What he will notice: on the laptop the War Rig still turns in deliberate legs without the frame hitch; brains' cars arrive
at a slot facing the way they came by swinging out to the side with room (the side gate, through brains).

## Where things stand (main at the round-32 docs commit; inherits `e66b41f1`'s green check: builder0 exited 0, 2657/0)

- **CP-P1 is ON** for hulls ≥ 10 m (`PLANNER_DEFAULT` true; the C++ plan source, the GDScript planner kept as the twin;
  PlannerExecutor drives the legs; SLICE 2 expansions a tick, PENDING 90 ticks, one crew searched at a time).
- **Line (f), the cost:** seed 92721 MISS (SLICE 2 × warm 263 µs = 0.526 ms v 0.5, builder0 load 16.7, pinned 0–3, an upper
  bound per R31.6), seed 31337 PASS (0.372 ms). Not in the ship clause; round 32 makes SLICE a preset.
- **The gang-press queue starves** (hull-rest, builder0 `35f5df92`): drawn 177 of 784 asks abandoned (23 %), clicked 209 of
  1176 (18 %); GOAL_BLOCKED 161/145, START_BLOCKED 54/80 still enter the queue.
- **The side gate** is hand-over (2): two clearance reads through the C++ cache at `slot ± perp × R`, no search.
- Your round-31 branch is `round31/planner` (kept, not merged; `d8300843` holds the hand-overs).

## Backlog (in order)

1. **CP-S, the side gate (C32.4):** `PlannerSeam.side_gate(slot, facing, unit_id) -> Vector3` (ZERO when neither side has
   room), GDScript and C++ equal on fixtures (yard s27 t8's slot among them), a unit test per side and the no-room case,
   priced (µs on builder0). Nobody calls it on main, so it merges OFF-path on a green check; tell brains through the
   orchestrator the moment it is on main. Agree the exact signature with brains first (one message).
2. **SLICE per hardware preset (C32.7):** laptop preset SLICE 1, others 2, read once at match start, the same for both
   sides and deterministic across peers (a networked match uses the host's value; prove it with a test). PENDING_TICKS
   re-sized with it so a crew's expansion allowance is unchanged (hand-over (1) and (3)(4)). Price on builder0
   (`make planner-census PLANNER_CENSUS_PROBE=30 PLANNER_CPUS=0-3`) and the hold per rig event; a laptop price only in a
   slot the orchestrator grants. The default (non-laptop) path must be bit-for-bit today's: sim-baseline unmoved.
3. **The queue (hand-over (3)):** refuse early (a request that would GOAL_BLOCKED / START_BLOCKED never enters the queue),
   then a per-tick budget shared round-robin across the queue's heads (a session per crew in C++, with native). Bar to the
   orchestrator before numbers: hull-rest's gang arm `abandoned` ≤ 5 % of asks, the hold per rig event median not up,
   round 31's (d) lines, the whole suite on native's pair tree. Ships ON as a pair.
4. **Test splits (C32.8):** your files over ~60 s in `tests/shard_times.txt`, if any (`make test-times` first).
5. **Stretch, only if brains asks:** the full "slot" take point (`in_scope(unit_id, kind)`; goal = slot + facing, 1.0 m /
   8°) for short hulls, with its own bar (yard s27 t8, an arrival census, the cost line re-priced).

## How to verify

`make quick-remote` to iterate; `make remote T=check` for hashes you name (the pair tree with the switch ON before any
judged series, C31.1). `make planner-twin`, `planner-census`, `manoeuvre-hull-rest` (one arm a call), `nav-terminus-drive`,
`scenario_cp2`, `native-verify-scenarios`. Lessons from round 31: key any new static by hull NAME and release freed hulls in
`_sweep`; hull-rest is not run-to-run deterministic, so pair on (faction, seed) and quote the se. Long remote runs under
`systemd-run --user`. Every number: commit, machine, workload, n.

## Don't touch

Manoeuvre's executor and drive body (PlannerExecutor's consumer side is theirs per R31.2); brains' gate and re-seat (you give
them a point, they decide); traffic's give-way; native's `native/**` outside `planner_*`; `game/theme/**` beyond the one
granted field; `tests/baselines/**`; `tools/judge/**`. `origin` holds an old `stream/planner`: don't push.

## Waiting on the lead

Nothing. A laptop pricing slot goes through the orchestrator.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n and its row; bars to
the orchestrator before numbers; green hashes named)_
