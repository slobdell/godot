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

_Updated 2026-10-16 by the planner worker (`godot-planner`, `stream/planner`, from main `6efdf42b`, which inherits
`e66b41f1`'s green check: no baseline check run; Opus)._

### The report (read this first)

_2026-10-16 ~11:30 PDT. Every number builder0 unless named; commit, workload and n beside it._

**THE BRANCH IS GREEN, MERGE HERE: `d98656ab`** (builder0 `>> remote: make check exited 0`, 2670 passed, 0 failed,
24 passed + 2 NOT JUDGED on a busy box (perf-judge, scenario_perf), **sim-baseline 13 maps unmoved**). Later commits
are this Status only. Every backlog item is done, judged, or handed over below.

| item | state | evidence |
|---|---|---|
| 1. **CP-S side gate** (C32.4) | **ON MAIN** (`530e85cf` → `3a85d092`), OFF-path; brains told | check `530e85cf`: exited 0, 2670/0, 26 ALL JUDGED, sim-baseline 13 unmoved; native APPROVED the C++ |
| 2. **SLICE per preset** (C32.7) | **ON MAIN**; then **RESOLVED** on the laptop's own price: SLICE 2 on every preset (`92d7a80b`, merge note below) | same check; laptop census (see below) |
| 3. **The queue** (CP-Q) | **JUDGED: FAIL on line (3), PARKED** (`pair/planner-queue` `65cc43dd`; the code stays OFF behind `--planner-queue=shared`) | `references/round32/planner/cpq-65cc43dd/VERDICT.txt` |
| 4. **Test splits** (C32.8) | DONE | `d586292a`, `15f0a60c` |
| — **main bug** (`capture()` copied a freed hull's crew) | **ON MAIN** (`fix/planner-capture-freed` `8904c9c4`, the orchestrator merged it; R32.6) | red without / green with; native APPROVED |
| 5. stretch "slot" take point | not asked by brains | — |

**After the merge: the face-behind divergence (the orchestrator's ask, moved off manoeuvre's item 0b).**
`test_manoeuvre_behind::test_the_war_rig_faces_behind_in_a_planned_turn` failed under NATIVE=off (legs 2, drift 25.3 m)
and passed native. Not the drive, not the search (offline both planners give the same 5-leg, 189-expansion plan):
the NO-LIBRARY SESSION planned whole at begin and answered on the first `step_session`, so the seam's 180-expansion
cap never applied: native abandons that face at 90 ticks (today's executor turns the rig), NATIVE=off drove the 25 m
plan. Fix `c74f5943`: each search records how it ended; `Planner.emulate_step` replays the C++ `step(n)`.
`test_planner_session_steps` holds call, code, legs and expansions equal on 7 fixtures + the face-behind at slices
1/2/3/50 and a mixed replay sequence; laptop: test_manoeuvre_behind 6/0 with `--planner-gdscript` and without; every
planner test file 49/0. Round-33 note (recorded by the orchestrator): the seam never serves a War Rig's open-ground
face-behind (189 > 180 expansions). Native's test_native_face_behind compared nothing (928 handed back).

**CP-S.** `PlannerSeam.side_gate(slot, facing, unit_id, map: RID, from := Vector3.INF) -> Vector3`, the signature agreed
with brains: `slot + perp × R` (R = the unit's turning radius) on the side with room, ZERO when neither side has
room, the side the hull comes from when both do (then more clearance, then the left). Room = clearance ≥ min(half
width + 0.4 m, bake radius − slack − 0.05). Two reads through `Planner.clearances` (C++ `PlannerNative.clearances`,
the shared navmesh cell cache). Equal both ways bit for bit on 4 rectangle + 6 navmesh fixtures
(`test_planner_side_gate.gd`). **Price** (quick on `b204a489`, unpinned, busy box, 1 call a fixture): C++ warm
10–59 µs a call, cold first read 1.9–2.7 ms (the polygon index), GDScript 102–253 µs. **Yard s27 t8** (brains'
fixture): both sides have room; the scout's gate is (−12.96, −41.97), R 5.5 m to the side it comes from.

**SLICE.** `PlannerSeam.slice()` latched once per match: `--planner-slice=N` (the host's value; player-hosted matches
simulate on the host only, `client_mode.gd` `simulate = false`) > the render preset ("laptop") > 2;
`pending_cap()` keeps 180 expansions per hold. `test_planner_slice.gd` proves the flag wins on a peer of either preset,
the latch, the same legs at 1 and 2, two runs at 1 identical. **The laptop price** (flightdeck, i5-8365U, `65cc43dd`
at `--planner-slice=1 --planner-queue=fifo`, `taskset -c 0-3`, Sumps 25 a side, seeds 92721 / 31337, n 112 / 116
plans; load 2.66 → 1.55, an upper bound): **89 / 79 µs an expansion warm**, so SLICE 2 is ~0.2 ms a tick there, under
the 0.5 ms line. The orchestrator's ruling: SLICE 2 on every preset, the knob kept (`92d7a80b`). Record:
`references/round32/planner/laptop-census-65cc43dd/`.

**CP-Q, the verdict** (pre-registered bar, read once at completion, `65cc43dd`, base `--planner-queue=fifo` v
candidate `--planner-queue=shared`): (1) abandoned 1.0 % drawn / 3.7 % clicked v base 18.6 / 14.5 % (hull-rest
gangs, seeds 66–71, n 36 runs an arm): PASS. (2a) hold median 0 / 1 v 4 / 9.5 ticks: PASS. (2b) Terminus rig hold
median 0 v 19 (seeds 205–217, n 13): PASS. (4) rig arrivals 187 v 180 of 208: PASS. (5) C31.1 suite 2670/0: PASS.
**(3) FAIL:** at-rest error faced_support_by_fire drawn p 0.035 (106.8 v 74.3°); faced_move settle +14.5 s;
moving at 75 s faced_move +5 (line 2.96), faced_screen +3 (line 2.14). Reported: Terminus rig contact-ticks median
522 v 321 (paired +336, se 173). **What it means:** the queue does what it was built for (the starvation is gone),
but serving 1.5–2× the face plans in a 19-crew press costs drawn facing, settling and wall contact: the FIFO's
starvation was HIDING the cost of the seam's face plans in a press. Not tuned on these seeds.

**The traces (after the verdict; reading, not a re-judge; `VERDICT.txt` TRACE 1 and 2).** (1) Hull-rest: neither
worst rig pair reproduces on rerun (faced_move s66: both arms end ~150° off and the seam never acted, a `stop` with
no face step after the move, relayed to manoeuvre as a likely main bug; faced_support_by_fire s67: reversed, shared
0.3° v fifo 12.8°). Paired over every rig the medians are +0.3° / +0.4°: line (3)'s misses at n 6 seeds are not shown
to be the queue's. (2) **Terminus seed 207 (deterministic): the real cost.** Refuse-early answers a ROLLING rig's ask
at once (GOAL_BLOCKED), so today's code keeps its 7–9 m/s and pins it on Block_7 for 2043 ticks. Under the FIFO the
same refusal comes only after the hold has braked the hull to rest: **the FIFO's hold was an implicit brake.**

**Next (round 33 hand-over):** (a) **BUILT, not judged (`d98656ab`, the orchestrator's ask):** refuse early ONLY at
rest under `--planner-queue=shared` (a rolling ask braked to rest first, as the FIFO holds it), round-robin unchanged;
the first cut kept as `--planner-queue=shared-rolling` for the record. Stage `make planner-stage-s207` (Terminus rigs
seed 207, deterministic, builder0 light): shared-rolling pins Green_S0_4 on Block_7 2043 ticks (reproduces), shared 0
(all rigs 4007 → 2223; the FIFO's run 2444). Stopped before any series; (b) the hull-rest gang arm A/A (fifo v fifo, seeds 66–71) to size line (3)'s noise
(the orchestrator: light lane only after H1b/B10, else round 33); (c) re-judge CP-Q on fresh seeds with (b)'s bar.
Targets ready: `planner-judge-queue`, `planner-series-queue`, `planner-trace-hull-rest`, `planner-trace-drive-queue`.

**Merge notes.** Main has CP-S + SLICE + the queue (OFF) + the capture fix. Still on `stream/planner` only:
`92d7a80b` (SLICE_LAPTOP 2: `game/ai/planner/planner_seam.gd` one const + its doc, `tests/test_planner_slice.gd`),
the C32.8 splits (two new test files + `.uid`s), `mk/planner.mk` (planner-series per-arm flags,
`planner-judge-queue`, `planner-series-queue`), `tests/planner/queue_table.py`, references. Its named green hash is
below when the check reads green. `game/theme/**` untouched (the preset is read from `RenderLevers.preset()`).

**Known issues.** `tests/planner/series_verdict.py` refuses a series whose base arm runs the seam (round 31's guard);
the queue's per-squad lines print before the refusal and are what the verdict read. `test_tactics_body::
test_his_three_squads_keep_together` fails ALONE on main's code (builder0 light, off 33.5 / on 24.5 s, identical with
or without my fix): brains' (R32.6).

**To playtest:** nothing new he will see: the side gate waits on brains' B5c-v6, SLICE is unchanged on his laptop
(2), the queue is OFF.

### Plan (ordered, smallest foundation first)

1. **CP-S side gate** — `PlannerSeam.side_gate(slot, facing, unit_id, map: RID, from := Vector3.INF) -> Vector3`
   (signature AGREED with brains 2026-10-16, one message: `map` added because the read needs the navmesh; `from` the
   hull's position). `Planner.clearances(world, xz)` reads through C++ `PlannerNative.clearances` (a world of its own,
   the shared navmesh cell cache) or the GDScript field. Tests: `tests/test_planner_side_gate.gd` (each side, no room,
   tie-breaks, tracked hull / null facing, both reads equal on rectangles + yard_open s27 t8 + Terminus, µs printed).
2. **SLICE per preset (C32.7)** — `PlannerSeam.slice()` latched once per match: `--planner-slice=N` > the render
   preset (`RenderLevers.preset()` "laptop" → 1) > 2; `pending_cap()` = 180 expansions / slice. Tests:
   `tests/test_planner_slice.gd`.
3. **The queue** — refuse early, then a round-robin per-tick budget over a session per crew (one `PlannerNative`
   instance per crew: the library's session is per instance, the cell cache and tables static, so possibly no C++
   change; native asked to review). Bar to the orchestrator BEFORE numbers.
4. **Test splits (C32.8)** — read my files' times from the named check's `build/test-times.txt`.
5. Stretch (only if brains asks): the "slot" take point.

### Decisions

- **SLICE reads the render preset, not an FxQuality field** (the grant's either-or): FxQuality's tier is not the
  laptop/desktop split (his laptop runs FX tier HIGH: `platform_default()` is HIGH on desktop), and the HUD can flip the
  render preset mid-match; the sim reads it once per match (keyed by the Match instance) and a launch flag
  (`--planner-slice`) carries the host's value. Headless is always "desktop" → SLICE 2 / 90 ticks: today's bits.
  `game/theme/**` untouched.
- **Side gate room test** = clearance at the gate ≥ min(half width + `Planner.MARGIN_M`, bake radius − field slack −
  0.05): the navmesh field reads at most the bake radius on the mesh, so without the cap no hull wider than ~3 m (the
  IFV bus) could ever get a gate.
- **Networked play:** player-hosted matches run the AI on the host only (clients get state), so the host's preset is
  the match's; for replays / lockstep the value is a launch flag beside `--seed`.

### Questions for the lead

None.

### Requests to other streams

- native: reviewed and APPROVED `clearances` (df45fac3) and `refused_at_begin` (0b9e96bc); the queue ships ON as a pair
  with native once CP-Q passes.

