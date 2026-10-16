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

**CP-S and SLICE per preset are ON MAIN: `530e85cf` → main `3a85d092` (the orchestrator, 2026-10-16).** Green check
on `530e85cf`: builder0 `>> remote: make check exited 0`, 2670 passed, 0 failed, 26 targets ALL JUDGED,
**sim-baseline 13 maps unmoved** (the default path bit for bit). Brains told side_gate is on main.
**C32.7 RESOLVED (the orchestrator's ruling, 2026-10-16 ~05:30):** the laptop's own price (flightdeck, i5-8365U,
`65cc43dd`, pinned 0–3, Sumps 25 a side, seeds 92721 / 31337, n 112 / 116 plans; load 2.66 → 1.55, an upper bound)
is **89 / 79 µs an expansion warm**, so SLICE 2 costs ~0.18–0.24 ms a tick there, under the 0.5 ms line: SLICE 2 on
every preset, the knob and `--planner-slice` kept (`92d7a80b`, rides CP-Q's ship or merges alone). Record:
`references/round32/planner/laptop-census-65cc43dd/`. The SLICE 1 v 2 rig series is dropped (ruling).

**Main bug fixed (the orchestrator's priority):** `PlannerSeam.capture()` copied a crew whose hull a previous test's
match had freed (traffic's check on cf81aedc: `test_native_traffic_turns_owned`, "previously freed" at
`planner_executor.gd:70`). Branch `fix/planner-capture-freed` `8904c9c4` (off main `254973bb`, alone): capture()
skips such a crew and its queue place. `test_planner_capture_freed` RED without the fix, GREEN with it (builder0
light). Native APPROVED. Full check RUNNING.

**CP-Q** (the queue): bar FILED. C31.1 DONE on pair tree `pair/planner-queue` `65cc43dd`: `make test` exited 0,
2670 / 0 (the check before it was killed at slot.sh's 5400 s cap at load 23 with 0 failures; its other targets green
bar sim-baseline: 7 War-Rig maps moved, the expected ON move, and R31.10's flake). Series RUNNING on `65cc43dd`:
hull-rest gangs base DONE (FIFO: abandoned 69 / 370 asks drawn 18.6 %, 82 / 564 clicked 14.5 %; builder0, seeds
66–71, n 36 runs an arm), candidate running, then the Terminus series 205–217. Verdict read once at completion.

_In progress (2026-10-16 ~01:30 PDT)._ Nothing verified on builder0 yet: builder0 had 3 heavy runs ahead of me for 25+
min; the first quick was replaced by one covering the whole diff (`make quick-remote QUICK_BASE=6efdf42b` on
`b204a489`, 12 test files + lint + smoke).

- **CP-S** (`df45fac3`): built, native APPROVED the C++ (`clearances`). Merges OFF-path on its own green hash.
  **Quick on builder0 `b204a489` (unpinned, the box busy with 3 other streams' runs): 56 passed, 1 failed** (the one
  failure my queue test's own read, fixed at `530e85cf`). Every side-gate fixture equal both ways, the two reads bit
  for bit. **The price, a whole `side_gate` call (two reads + the choice):** navmesh, C++ warm 10–59 µs, C++ cold
  (the process's first read: the polygon index) 1.9–2.7 ms, GDScript 102–253 µs; rectangles 22 µs warm. n = 1 call
  per fixture × 9 fixtures. **Yard s27 t8** (brains' fixture: slot (−13.016, −47.469) facing west, from (2.5, −46.1)):
  both sides read 1.85 m (room); the gate goes to the side the car comes from, law_scout (−12.96, −41.97) = R 5.5 m
  south of the slot (gang_ifv R 6.5, ifv R 7.0 likewise).
- **SLICE** (same quick): the War Rig's Terminus face-about plans the same legs and expansions at 1 and 2; hold 7 ticks
  at SLICE 1 v 3 at 2 (n = 1 each, 7 expansions), nothing abandoned, two runs at 1 identical.
- **Test splits (C32.8)** from that quick's FILE_TIME (builder0 `b204a489`): `test_planner_seam.gd` 113 s → 3 + 3
  (`test_planner_seam_hold.gd`, `d586292a`); `test_planner_trace_manoeuvre.gd` 63 s → 2 + 2 by scene
  (`test_planner_trace_wedged.gd`, `15f0a60c`); bodies byte-identical, test counts 6 = 6 and 4 = 4. Under 60 s:
  slice 38 s, queue 37 s, keep 3 s, fixtures 3 s, side gate 2 s. (`test_native_planner*.gd`, 72 / 64 s, are the twin
  files: native's, not split by me.)
- **SLICE per preset** (`df45fac3`): built; tests `test_planner_slice.gd` (flag > preset > default, the host's flag
  wins on a peer of either preset, the hold keeps 180 expansions, headless = SLICE 2, the same legs at 1 and 2,
  latched per match, two runs at 1 identical). The named check must read sim-baseline UNMOVED (the orchestrator's
  reminder).
- **The queue** (`0b9e96bc`, `a46c2bf3`): built behind `--planner-queue=shared` (default OFF); native APPROVED the C++
  getter `refused_at_begin` and the instance-per-crew design. Bar **CP-Q FILED** by the orchestrator (workstreams.md
  *Bars (round 32)*). Targets `planner-judge-queue` (hull-rest gangs, seeds 66–71) and `planner-series-queue` (Terminus,
  seeds 205–217), reader `tests/planner/queue_table.py` (`867a4b38`).

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

