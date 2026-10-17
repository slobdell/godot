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

_Updated 2026-10-17 ~08:10 PDT by the planner worker (`godot-planner`, `stream/planner`, from main `ae3dad71`, which
inherits `0c124cf7`'s green check: no baseline check run; Opus). Every number builder0 unless named._

### The report (read this first)

| item | state | evidence |
|---|---|---|
| **R33.3 (main bug, first by ruling)** `PlannerSeam.live()` stuck true after the order is replaced | **FIXED, check RUNNING** on `fix/planner-live-stale` `03d1a50c` (main `86975667` + 1 commit; cherry-picked here as `48a694b0`). Native APPROVED, no C++ change | `test_planner_seam_stale`: red without (laptop: still live 2 s after `stop`), green with (released 2 ticks after) |
| **P1** line (3)'s noise | **DONE** (`4bbe8322`, builder0, `make planner-aa-queue`, `make remote exited 0`, hull-rest gangs seeds 66-71 x 6 tasks, fifo v fifo, 72 paired runs a mode) | `references/round33/planner/aa-4bbe8322/` |
| **P2** CP-Q re-judged | bar SENT to the orchestrator (below), before any number; the pair tree waits on R33.3's check | — |
| **P3** open-ground face-behind | candidate = the **FACE KEEP circle** (`--planner-face-keep=1`, OFF, `45390507`); bar SENT before numbers (below). The weight (ε 2.0) is DROPPED: it serves the wrong plan | builder0 light `7ff19c2f`: ε 2.0 serves the face-behind 25.3 m off its spot; keep 1 (laptop stage): served, aligned 9.8 s, drift 1.0 m v today 15.4 s / 1.5 m |

**R33.3, the orchestrator's three questions (evidence from the code at `03d1a50c`):**
1. **"Asked about"** = `PlannerSeam.take()` or `hold()` reached for that hull: `_serve` writes `crew.tick_seen` and nothing
   else does (`grep tick_seen`: lines in `_serve` and `_request` only). `live()` writes nothing (unchanged: a lookup and the
   freed-hull release). `hold()` is the FIRST line of `Movement.face_turn` (movement.gd:1278) and of `_planned_reverse`
   (:3770), so a crew being driven or pending is asked about every tick it is executed.
2. **The native path refreshes the same way.** A wheeled hull's face is HANDED BACK to the GDScript executor
   (`execute_native.cpp:363-376`: `simple_face` only for a hull with no wheels, and the seam takes only wheeled hulls), so
   `face_turn` -> `hold()` runs every tick. The k-turn: the C++ drive calls back `_planned_reverse` for a seam-live crew
   every tick it drives (`drive_native.cpp:2211-2214`), which calls `hold()`. Native's review agrees (tick_seen is written
   only in take/hold, both reached on both arms through the same GDScript callbacks). Twins: native is running
   native_drive* (k-turn), native_execute*, test_native_face_behind and test_planner_seam_stale on `03d1a50c` (counts to
   come). Stride: a controller that skips ticks (`_stride`) would leave a crew unasked, but the default runs every tick
   (L1's QUIET_STRIDE = L1_STRIDE 1.0, off; the far stride needs an EMPTY order, and a held crew is executing one).
3. **STALE_TICKS = 2**, the rule `_serve` already applied (since round 31): a crew unasked for > 2 ticks was released at
   its NEXT call ("stale"). The fix applies the same test once a tick instead of waiting for a call that never comes, so a
   crew released here is one `_serve` would have released anyway the moment its hull asked again; PENDING_TICKS (90) and a
   long leg are untouched because both are asked about every tick (pending: `hold`; a leg: `hold`). **Peers:** the release
   reads only `Engine.get_physics_frames()` and `tick_seen` (written from the same counter) and runs from
   `SceneTree.physics_frame`, which the engine emits at the start of each physics step before any node's
   `_physics_process`: a fixed point in the tick on every peer, no clock, no node order. (Only the host simulates the AI in
   player-hosted play.) The connection is static and never disconnected: a no-op while `_crews` is empty (native's note).

**P1: the hull-rest gang arm's A/A** (`4bbe8322`, builder0 at load ~23, seeds 66-71, 6 tasks, drawn and clicked, both
arms `--planner-queue=fifo`, n 36 paired runs a mode; per-run rows `hull-aa-rows.jsonl`). Gangs field one class
(wheels/turret = ALL). The row for `tools/judge/probes.py` (judging.md S5 step 8, the orchestrator at the close):

| probe | metric (a run) | form | sd a run (paired) | base level | n |
|---|---|---|---|---|---|
| hull-rest gang arm (queue) | at-rest hull error, median of the run, drawn | mean of paired diffs | **21.7 deg** | task medians 34-67 deg | 36 |
| same | the same, clicked | mean | **17.5 deg** | 61-91 deg | 36 |
| same | crews moving at the 75 s judge, drawn | total | **1.54** | 0.5-4.5 a run | 36 |
| same | the same, clicked | total | **2.04** | 0-2.5 | 36 |
| same | settle s (75 = never), drawn | mean | **16.1 s** | mostly censored at 75 | 36 |
| same | the same, clicked | mean | **13.9 s** | 28-75 | 36 |
| same | abandoned share of asks | share | drawn 25.2 v 26.3 %, clicked 15.5 v 12.5 % (the null's swing) | — | 36 |

**What it says about round 32's line (3):** on the null, (3a)'s crew-pooled p failed 0 of 24 cells, but medians swung up to
13.6 deg (drawn faced_attack_move 70.4 v 56.8); (3b) settle swung -10 s (faced_move: round 32's miss was +14.5); (3c)
moving swung **+8** on faced_ambush (its own se 4.0) against round 32's lines of +2.96 / +2.14 (its misses +5 / +3). So
round 32's (3b) and (3c) misses sit inside this probe's run-to-run noise, and the per-task lines at 6 runs cannot see a
harm smaller than ~2.5 x their se. P2's bar therefore pools the six tasks and runs 12 fresh seeds.

### P2's bar (pre-registered, sent to the orchestrator before any number)

Arms: base `--planner-queue=fifo`, candidate `--planner-queue=shared` (refuse early only at rest, `d98656ab`), both the
native drive, ONE tree: the pair tree (`QUEUE_DEFAULT` true) on top of R33.3's fix, after its whole suite is green (C31.1).
Hull-rest gangs, FRESH seeds **72-83** (12) x 6 tasks, drawn and clicked: **n 72 paired runs a mode**. Terminus rigs FRESH
seeds **218-230** (13). Early stop OFF on every line (R31.8: guards). The se on each guard is the PAIR's own paired se (the
A/A's figure in brackets is what n was sized on). No tuning on these seeds; this is CP-Q's last attempt this round.
1. **(gain) abandoned share of asks <= 5 % in each mode, AND below base (Fisher one-sided p <= 0.05).** (Round 32: 1.0 /
   3.7 % v 18.6 / 14.5 %; A/A base 25 / 13-16 %.)
2. **(gain) the hold per event, pooled median, candidate <= base** in each mode; and on the Terminus rigs.
3. **(guards, pooled over the six tasks, paired on (task, seed)):**
   (a) at-rest hull error: mean paired per-run median diff <= **+1.645 se** in each mode [A/A: se 2.56 deg drawn -> line
   +4.2 deg, MDE 6.4; clicked se 2.06 -> +3.4, MDE 5.1];
   (b) settle (drawn): mean paired diff <= +1.645 se [A/A se 1.9 s -> +3.1 s]; never-settled runs reported (censored);
   (c) crews moving at 75 s: summed paired diff <= +1.645 se of the sum in each mode [A/A: drawn se 13.1 -> +21.5 crews
   over 72 runs, ~0.3 a run; clicked se 17.3 -> +28.5].
   Per-task numbers REPORTED (each is inside the A/A swing at n 12).
4. **(guard) Terminus rig arrivals:** paired not down beyond 1.645 se (judging.md's Terminus rigs row: sd 1.68 a seed);
   wall contact-ticks REPORTED (not affordable: the row's n > 700).
5. **(deterministic cell) s207 stage:** under `shared`, Green_S0_4 pinned on Block_7 0 ticks (`make planner-stage-s207`).
6. **C31.1:** the whole suite on the pair tree, green.
Pass = every line. Partial (1)-(2) pass, a guard fails: PARKED with the worst pair's trace (lesson 302), not tuned.

### P3: the finding, the census, the bar

**Finding.** The face-behind's 189-expansion plan is the WRONG plan: F-1x24 R-1x15 F-1x4 F+0x17 F+1x5.5 (17.5 s) swings
the rig 25.3 m off its spot (served at ε 2.0 on builder0 light `7ff19c2f`; round 32's NATIVE=off failure). With every
pose kept within one hull length (14 m) of home the lattice finds F-1x12 R-1x12 F-1x12.5, a three-point turn, **11.7 s,
4 expansions**: cheaper, so the search MISSED it unconstrained (the heuristic overestimates near a turn in place and the
anytime stop ends first). The keep circle is a request field native already reads: no C++ change, the per-tick price
is the slice on every preset (laptop and desktop alike).
**Census** (`make planner-face-shadow`, builder0 light, hull-rest gangs drawn, seeds 66-71 = diagnosis, never judged):
run 1 `9259321d` 31 face searches, 24 under the slot law's END circle, furthest from home max 19.7 m; run 2 `a6368824`
58 searches: today max 29.0 m, **kept (s1.0) max 14.2 m**, median 4.7 v 4.4, the same cost on all 21 both found, inside
the hold 20 v 20. ε 2.0 / 3.0: +1 inside the hold, max 29.8 / 30.4 m. Run-to-run the count of face searches swings 31 v
58 (hull-rest is not deterministic).
**Bar (sent ~09:55 PDT, before numbers):** tree = main after R33.3 + P3 with FACE_KEEP_DEFAULT 1, whole suite first.
(1) deterministic cell, the face-behind stage NATIVE on and off: served, abandoned 0, drift <= 8 m, aligned no later
than today's, legs <= 3; (2) hull-rest gangs FRESH 84-95, drawn + clicked, n 72 paired a mode: (2a) P2's pooled guards;
(2b) face asks abandoned not up beyond 1.645 se; (2c) DRIFT: served face plans' furthest-from-home (`face_far`),
candidate median <= base + 1.645 se (bootstrap) and p90 <= base p90, max reported; (3) Terminus rigs FRESH 231-243:
arrivals not down beyond 1.645 se. Early stop OFF. After P2 (R33.10).

### Plan (ordered)

1. R33.3 (ruling): fix + test + check (`03d1a50c`), native twins. **← check running**
2. P1 A/A: DONE.
3. P2: verdict tooling (pooled paired lines, `hull_aa.py` on base v candidate), the pair tree (QUEUE_DEFAULT true) on
   the fix, its full check, then hull-rest 72-83 (one arm a call) + Terminus 218-230 + s207, read once.
4. P3: the face-shadow census on hull-rest drawn + Terminus rigs (which face requests land inside the hold at 1.5 / 2.0 /
   3.0, at what cost), then its own bar to the orchestrator; judged on test_manoeuvre_face_behind + the hull-rest rigs.
   Decision (why a weight, not a longer hold): the per-tick price is the slice on every preset, so a weight costs nothing
   per tick on the laptop or desktop (a face only searches LESS); a longer hold would keep the rig standing longer.
5. Stretch: early refusals of GOAL_BLOCKED / START_BLOCKED, if P2 shows they cost.

### Decisions

- **R33.10 (the orchestrator, builder0 overloaded):** ONE heavy builder0 job at a time for this stream, in priority order:
  a named merge check > P2's judged series > tuning and traces (light lane or laptop). As of ~09:25 PDT: the heavy job is
  the full check of `1b5c69df` (R33.3; `03d1a50c`'s was killed at slot.sh's 5400 s cap, not a verdict: sim-baseline 13
  unmoved, shards 0-2 763/778/618 passed 0 failed, shard 3 cut at 504/0); P3's shadow census runs on the light lane.

- **R33.2 (agreed with manoeuvre, the orchestrator's ruling):** manoeuvre owns WHEN a faced finish runs and its residual;
  planner owns HOW while `take()` holds the hull.
- **R33.3 as a release, not a check in `live()`** (the orchestrator's amendment on native's assessment): `live()` stays a
  lookup, so the C++ inline mirror `seam_live` needs no change.

### Questions for the lead

None.

### Requests to other streams

- native: twins on `03d1a50c` (running); later the pair for CP-Q (QUEUE_DEFAULT) if it passes.
