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
  `planner-trace-drive-queue` (`planner-stage-s207` RETIRED in the round 33 overnight: its control no longer reproduces
  and the shared queue failed P2).
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

_Updated 2026-10-17 ~14:50 PDT by the planner worker (`godot-planner`, `stream/planner`; Opus). Every number builder0
unless named. While P3's series runs the `godot-planner` checkout sits on `pair/planner-face-keep-r33` (each remote call
rsyncs the working tree); this Status is committed from a scratch worktree._

### The report (read this first)

| item | state | evidence |
|---|---|---|
| **R33.3 (main bug, first by ruling)** `PlannerSeam.live()` stuck true after the order is replaced | **MERGED** (main `b122cf60` merges `1b5c69df`: builder0 `make check exited 0`, 2725/0, sim-baseline unmoved). **Shown by removal** to be why the FIFO's abandonment fell (R33.13, below) | `test_planner_seam_stale`; laptop removal test |
| **P1** line (3)'s noise | **DONE** (`4bbe8322`, builder0, `make planner-aa-queue`, hull-rest gangs seeds 66-71 x 6 tasks, fifo v fifo, 72 paired runs a mode) | `references/round33/planner/aa-4bbe8322/` |
| **P2** CP-Q re-judged | **FAIL, does not ship (R33.13, main `64d0f952`)**: line (1) fails both modes (the FIFO base is already ~1 % abandoned on main), (2) fails on the Terminus rigs, (3a) drawn fails. Pair tree `c75f20a6` (main `624cc957` + QUEUE_DEFAULT true), its whole suite green (builder0 exited 0, 2725/0) | P2's verdict below |
| **P3** open-ground face-behind | **FAIL -> PARKED** (the bar's own rule: (1) passes and a guard fails). Pair tree **`bca4eaca`** (main `b800a6aa` + P3, keep 1 + kept-first fallback + slot-law ordering; stream `c6def5b3`), whole suite green (builder0 `make check exited 0`, 2738/0; perf-judge and scenario_perf NOT JUDGED on load, moot now). Every line passes but **(2c) clicked**: face_far p90 15.4 v 12.8 m (n 18 v 27 plans). FIFO, no CP-F, one tree for every step | P3's verdict below; `references/round33/planner/p3-bca4eaca/` |
| **Stretch** early GOAL_BLOCKED / START_BLOCKED refusals | **NOT TAKEN**: P2 shows they cost nothing he would see | refused asks end in short holds (<= 4 ticks, ~1.5 each, 10-16 % of hold ticks); shared's 369 early refusals cut queue_waits 2679 -> 264 and moved no player line |

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

### P2's verdict: FAIL (read once, early stop OFF; R33.13)

Pair tree `c75f20a6` (main `624cc957` + `2f4d62b7` test tooling + QUEUE_DEFAULT true), whole suite builder0 exited 0,
2725/0, 26 targets ALL JUDGED, sim-baseline unmoved. Hull-rest gangs seeds 72-83 x 6 tasks, n 72 paired runs a mode,
base `--planner-queue=fifo` v candidate `shared` (explicit flags), the native drive; Terminus rigs 218-230 (n 13).
| line | drawn | clicked | |
|---|---|---|---|
| (1) abandoned share | 15/1764 = 0.9 % v 18/1894 = 1.0 %, Fisher p 0.44 | 14/1557 = 0.9 % v 25/1590 = 1.6 %, p 0.06 | **FAIL** (both under 5 %, neither below base) |
| (2) hold median | 2.0 v 2.0 | 2.0 v 3 | PASS; **Terminus rigs FAIL 17 v 11 ticks** (n 372 v 435) |
| (3a) at-rest error | +5.43 deg, line +4.50 (se 2.74) | +0.46, line +4.01 | **drawn FAIL** (worst: faced_ambush s73 83.0 v 18.4; per task ambush +4.2, attack_move +13.2, move +15.2, right +4.1, screen -2.1, sbf -2.0) |
| (3b) settle | -4.53 s, line +4.22 (never 44 v 54) | — | PASS |
| (3c) moving at 75 s | -17, line +22.8 | +12, line +17.7 | PASS |
| (4) Terminus arrivals | 183 v 180 of 208, +0.23 (se 0.43) | | PASS; contact median 442 v 529 reported |
| (5) s207 | shared: Green_S0_4 0 pinned ticks | | PASS (the shared-rolling control no longer pins: DOES NOT REPRODUCE) |
| (6) whole suite | green | | PASS |

**Why (1) failed: R33.3, shown by removal** (laptop, no native library: the GDScript drive both arms; hull-rest gangs
drawn FIFO, seeds 72-74 x 6 tasks, 18 runs an arm): with the release `c75f20a6` abandoned **7/594 = 1.2 %**
(stale_released 109, plans 128, driven 52, queue_waits 1298); with `_hook()` stubbed (`02934dec`, a throwaway, deleted)
**142/667 = 21.3 %** (stale_released 0, plans 86, driven 32, queue_waits 15767); Fisher one-sided p 6e-34. A crew whose
order was replaced used to sit at the head of the FIFO until the 90-tick cap and everyone behind it waited.
**Tool issues for the close (not this round's):** (a) `series_verdict.py`'s round-31 guard refuses when BOTH arms run
the seam ("the BASE arm's seam fired"): `make planner-series-queue` exits 2 and the PLANNER_SERIES_SQUAD lines are read by
hand; it needs a both-arms-seam mode. (b) `stage_s207.py` exits 1 now that round 32's pin does not reproduce: the stage
needs a new control or retirement. Also: a local `build/manoeuvre/hull-rest` keeps other seeds' arm dirs from earlier
runs; `queue_table.py` reads every run.log (re-run on the fresh seeds only, as above), `hull_aa.py` only runs with a
screen.json.

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
arrivals not down beyond 1.645 se. Early stop OFF. After P2 (R33.10). **Filed on main `8681d2aa`** with the orchestrator's
amendment (before numbers): both arms run on the queue main has when the series starts (`shared` if P2 shipped, else
FIFO; the verdict names it), and on a tree with manoeuvre's CP-F if it has merged (else the verdict says which tree).

### Closing check (stream/planner `1de6a692` = main `0b0d73f3` + the parked P3, keep 0 = OFF)

builder2 (GCP c4d-32), 2026-10-17 22:2x PDT: `>> remote: make check exited 2`; **2745 passed, 0 failed**; sim-baseline
**unmoved** on every arena (keep 0 is OFF); targets 23 passed, 1 FAILED, 2 NOT JUDGED. The FAIL is **web-smoke: no Chrome
on builder2** ("Browser was not found at ... /usr/bin/google-chrome"), a machine gap, not the code; perf-judge NOT JUDGED
(builder2 has no nominal yet). A first run there segfaulted in the cold `make import` (JetBrainsMono-Blocks.ttf), no test
run. Laptop `make test FILTER=test_planner` on `1de6a692`: 51/0 (GDScript drive). The two owed lines, run alone on
builder0 (the orchestrator's call) on `2e8a8721` (= `1de6a692` + this Status only): `make web-smoke exited 0` (WEB SMOKE
PASSED, WEB MATCH SMOKE PASSED; the screenshot shows the HUD, the tank and the caller line) and `make perf-judge exited 0`
(JUDGED, PASS attempt 1 of 3, ratio 1.09x, ai 8981 us/tick, builder0). **GREEN HASH: `1de6a692`** (the orchestrator merges it).

### P3's verdict (`bca4eaca`, builder0, 2026-10-17 20:25-22:07 PDT; bar main `8681d2aa` + amendment `e8383ce6`)

Arms: `--planner-face-keep=0` v keep 1 + the kept-first fallback, `--planner-queue=fifo` (P2 did not ship), no CP-F (not
merged). Every step ran on the same tree `bca4eaca`. Hull-rest gangs fresh seeds 84-95 x 6 tasks, n 72 paired runs a mode;
Terminus rigs fresh seeds 231-243, n 13. k 1.645, early stop OFF.

| line | result |
|---|---|
| (0) open-ground gain survives | **PASS**. yard_open stage NATIVE on (the check) and off (the cell): plans 1, abandoned 0, kept_served 1, fallbacks 0, drift 0.97 m, aligned 9.83 s v today's 15.43 s (abandon-then-executor). Hull-rest face plans from the kept search: drawn 23/23 = 100 %, clicked 16/18 = 89 % (line >= 50 %) |
| (0b) street face-back served | **PASS**, native on and off: plans 1, abandoned 0, fallbacks 1, kept_served 0, hold 26 ticks; test_planner_seam passes |
| (1) deterministic cell | **PASS**: test_manoeuvre_face_behind and test_manoeuvre_behind pass native on (check 2738/0) and off (cell 19/0) |
| (2a) P2's pooled guards | **PASS**. drawn rest_med +1.59 (se 3.01, line +4.94), settle -1.76 (se 1.53, +2.52), moving -4.0 (se 12.81, +21.07); clicked rest_med -1.00 (se 2.12, +3.48), moving +2.0 (se 15.07, +24.79). 3a null cells failing p < 0.05: 0 of 24. (hull_aa's HULL_PAIR "abandoned" rows are P2's reduction line, not P3's: P3's is (2b)) |
| (2b) face asks abandoned | **PASS**. drawn 7/104 = 6.7 % v 4/135 = 3.0 % (se 2.7 pts, line <= 7.5 %); clicked 1/210 = 0.5 % v 1/226 = 0.4 % (line <= 1.5 %) |
| (2c) face_far | drawn **PASS**: median 2.0 v 5.0 m (se 1.13, line <= 6.9), p90 5.6 v 16.9, max 11.9 v 19.2. clicked **FAIL**: median 2.0 v 3.1 m (se 0.89, line <= 4.6) ok, **p90 15.4 v 12.8 m over**, max 24.2 v 22.5 |
| (2d) face holds | REPORTED: median drawn 3.0 (n 880) v 2.0 (n 848) ticks; clicked 3.0 (n 714) v 3 (n 795) |
| (3) Terminus arrivals | **PASS**: rigs 175 v 181 of 208, paired -0.462 (se 0.550, line -0.905); contact-ticks median 465 v 481; mixed 293 v 293. series_verdict REFUSED ("the BASE arm's seam fired": both arms run the seam), so the PLANNER_SERIES_SQUAD lines were read by hand as the amendment says |

**The worst pair (clicked, faced_attack_move):** s87 candidate face_far [3.5, **15.4**, 3.4, 3.5] with kept_served 4 and
fallbacks 0 (so the 15.4 m plan came from the kept search) v base [2.7]; s95 candidate [5.6, **24.2**] with 1 kept and 2
fallbacks v base [0.6, 3.1, 22.5]. The candidate's p90 rests on those two plans out of 18. A kept plan at 15.4 m is past one
hull length (the rig's 14 m), which only a slot-law face's circle allows (its end circle + one hull length): **inferred**,
not traced per plan. The s95 tail is shared with the base (24.2 v 22.5).
**Crediting:** the slot-law ordering and the fallback are both in the candidate and no arm separates them, so this series
cannot credit either alone. The kept slot faces are the ordering's change, so the clicked tail is more likely the
ordering's than the fallback's (inference).
**Not judged/side notes:** `queue_table.py` read 180 runs (old seed dirs in the copied `build/`; it is not a P3 line);
perf-judge was NOT JUDGED on load in the check and is moot unless P3 is re-filed.
**If re-filed (a new candidate, the orchestrator's call):** cap a slot-law face's kept circle at one hull length from the
slot (or keep slotted faces unkept, as `6f89ecc1` did by accident). The open-ground gain (0) does not depend on slotted
faces.

### P3 revised: the street failure, the probe, the fallback

`6f89ecc1` (main `b800a6aa` + P3, FACE_KEEP_DEFAULT 1) failed C31.1 on builder0 (`make check exited 2`, 2733 passed, 4
failed, sim-baseline unmoved): test_planner_seam's Terminus street face-back (s31, the rig at (-70, 0, 0) told to face
south), test_planner_capture_freed and test_planner_slice (the same scene) and test_planner_queue's blocked ask. Probe
(laptop, GDScript search, the seam's own request planned whole, budget 20000; test scenes only):

| keep | yard_open face-behind: exp / cost / furthest | Terminus street face-back: exp / cost / furthest |
|---|---|---|
| 0 (today) | 189 (past 180) / 17.5 s / 25.3 m | 7 / 16.9 s / 28.9 m |
| 1.0 | **4 / 11.7 s / 11.5 m** | 10091 / 41.7 s (16 legs) / 13.9 m |
| 1.5 | 197 / 18.8 s / 20.5 m | 125 / 25.8 s / 20.6 m |
| 2.0 | 188 / 17.5 s / 25.3 m | 23 / 16.2 s / 27.6 m |
| 3.0 | 189 / 17.5 s / 25.3 m | 7 / 16.9 s / 28.9 m |

No single keep serves both. **Candidate (`bca4eaca`):** the kept search gets the first quarter of the hold
(`FACE_KEPT_SHARE` 45 expansions); a refusal or no plan by then and today's search runs from the same pose inside the
same pending cap (no budget raised; the split lives in the GDScript seam, native sees two ordinary requests: no twin).
Census `a6368824` (diagnosis seeds 66-71): at 45, today's 20 in-hold faces all served, 19 by the kept plan, none lost.
**Also fixed:** the keep was applied BEFORE the slot law, whose `req.keep` replaced it, so slotted faces went unkept on
`6f89ecc1`; it now applies after (the verdict credits that to the ordering, not the fallback). Laptop: the street served
in a 26-tick hold by today's plan after the fallback; the yard stage by the kept plan, no fallback (aligned 9.8 v 15.4 s).
Bar lines added (main `e8383ce6`): (0) the yard stage served by the KEPT plan NATIVE on and off, and >= 50 % of the
candidate's hull-rest face plans from the kept search; (0b) the street cell served; (2d) face holds reported.

### Plan (ordered)

1. R33.3: MERGED. 2. P1: DONE. 3. P2: FAIL (R33.13). 4. Stretch: not taken (above).
5. **P3: FAIL -> PARKED** (verdict above). The series as it ran, for the record:
   (1) `make test FILTER=test_planner_face_epsilon|test_manoeuvre_face_behind|test_manoeuvre_behind NATIVE=off` (native
   on = the whole suite's run); (2) `make planner-judge-face PLANNER_FACE_ARM=base|candidate` (seeds 84-95, keep 0 v 1,
   FIFO) -> `hull_aa.py --verdict` (2a), `face_keep_table.py` (2b, 2c); (3) `make planner-series-face` (231-243; its
   series_verdict exits 2 on guard (a): read the PLANNER_SERIES_SQUAD lines); lines (0)/(2d) by the scratchpad's
   `p3_kept_share.py` (the tree unchanged). Read once against the filed bar (main `e8383ce6`).

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

- native: none (CP-Q does not ship). If P3 passes: a look at `6f89ecc1` (no C++ change; keep is a request field native reads).

## Overnight (round 33 extension, 2026-10-18 ~00:45 PDT)

The lead has gone to bed and wants builder2 kept busy. Take these items in order (`workstreams.md` *Round 33, overnight
extension*; the details are in `roadmap.md` *Round 34 candidates*). Merge main first. builder2 FIRST (`make gcp-remote`,
6 heavy slots). Every judged stage pinned at `--fixed-fps $(SIM_HZ)`. A bar is filed (sent to the orchestrator) before any
number, judged on FRESH seeds, and every number labelled with its machine. Keep this Status current: the lead reads it in
the morning.

1. **The tools:** series_verdict gets a both-arms-seam mode; stage_s207 is re-made with a control that reproduces, or
   retired.
2. **P3 v2 re-judged PINNED:** the same candidate (keep 1 + fallback, the code on main OFF), with hull-rest pinned
   (manoeuvre's `670f4e12` flag, on main once manoeuvre merges; until then carry the one flag), on FRESH seeds, all on
   builder2. CP-F's misses turned out to be pacing (R33.23), and P3's clicked-drift p90 miss may be too. The bar is
   R33.19's, re-filed with the new seeds.
3. **Only if it fails pinned:** P3 v3, the slot cap (roadmap).

**Overnight Status (keep current; the lead reads this in the morning):**
- **(1) Tools: DONE** (laptop, `make planner-pytest` 4/4). `series_verdict.py seam=both`: the seam runs in BOTH arms, so
  the base's seam firing is expected. It prints `PLANNER_SERIES_SEAM_BASE_TOTAL` beside the candidate's, still judges
  arrivals the same way, and refuses if the base's seam NEVER fired (the flags missed the base). The default keeps round
  31's guard. `planner-series-face` passes `PLANNER_SERIES_SEAM=both`. **stage_s207 RETIRED** (target and script):
  round 32's pin no longer reproduces, and the shared queue it guarded failed P2 (R33.13) and does not ship. Re-make it
  with a new control seed if the shared queue is ever re-filed. `planner-pytest` is not in `make check` (core.mk is not
  planner's).
- **(2) P3 v2 re-judged PINNED: bar FILED** (main `daa71aaf`, before any number): R33.19's bar on pair tree main +
  manoeuvre's `670f4e12` (hull-rest at `--fixed-fps`) + FACE_KEEP_DEFAULT 1. Fresh seeds: hull-rest 96-107, Terminus
  244-256. All on builder2. The orchestrator added CP-F's rule: report distinct rows per cell, every se over distinct
  pairs only. **Tooling for that** (laptop, unit tests 7/7): `hull_distinct.py` (one pair per distinct (base,
  candidate) row in a cell), `hull_aa.py --distinct`, `face_keep_table.py --distinct`, `kept_share.py` (line (0)'s kept
  share and (2d)'s holds, now in the repo). **Decided before numbers:** the judged lines are the `--distinct` outputs
  (lines (2a), (2b), (2c) and (0)'s share all on the distinct pairs, (2c)'s median and p90 included). The all-runs
  lines are reported beside them.
- **(2) VERDICT: FAIL -> PARKED again, on (2c) clicked alone** (pair `c3acd47a2`, builder2 (GCP c4d-32), 2026-10-18
  11:55-12:20 PDT; check green by the orchestrator's rule: builder2 `2771 passed, 0 failed`, remote-guard-test failed
  under load there (quiet-window), builder0 `make remote-guard-test exited 0`). FIFO, no CP-F, one tree for every step.
  Pinned runs pair off by seed (96 = 101, 99 = 106, 100 = 104), so distinct pairs are 36 of 72 a mode. Judged on the
  distinct pairs; all-runs lines agree on every PASS/FAIL. Evidence: `references/round33/planner/p3-pinned-c3acd47a2/`.

  | line | result (distinct pairs; all runs in brackets) |
  |---|---|
  | (0) | **PASS**. yard stage native on (check) and off (cell): kept_served 1, fallbacks 0, abandoned 0, aligned 9.83 v 15.43 s, drift 0.97 m. Kept share drawn 17/21 = 81 % (29/36), clicked 14/14 = 100 % (26/26) |
  | (0b) | **PASS** native on and off: served after 1 fallback, hold 26, abandoned 0 |
  | (1) | **PASS**: the cell 19/0 native off; the check native on |
  | (2a) | **PASS**. drawn rest_med -0.15 (se 0.40, line +0.65), settle +1.15 (se 1.43, +2.35), moving -1 (se 1.00, +1.65); clicked rest_med +0.27 (se 0.25, +0.41), moving -1 (se 1.00, +1.65). 3a null cells failing: 0 of 24 |
  | (2b) | **PASS**. drawn 0/105 v 0/111; clicked 2/152 = 1.3 % v 1/154 = 0.6 % (line 2.5 %) |
  | (2c) | drawn **PASS** (median 3.4 v 3.9 m, p90 14.3 v 14.3). clicked **FAIL**: median 3.0 v 2.7 m ok (line 4.1), **p90 6.3 v 4.9 m over** (all runs 6.3 v 5.7), max 12.4 v 5.7; plans 14 v 10 distinct (26 v 18) |
  | (2d) | REPORTED: hold medians 4 v 4 both modes |
  | (3) | **PASS** (series_verdict seam=both): rigs 178 v 179 of 208, paired -0.077 (se 0.560); mixed 295 v 295; contact-ticks median rigs 488 v 415 |

  **What the miss is (traced):** the clicked tail is faces TODAY'S SEARCH DOES NOT PLAN. Clicked face asks 267 v 271,
  served plans 26 v 18: the candidate serves 8 more, from the same asks. The worst pair, faced_attack_move s100 (= s104),
  has base face_far [] (10 face asks, none planned) and candidate [12.4, 3.2] (2 kept, 0 fallbacks). So (2c) compares
  different populations: it charges the candidate for serving faces the base hands elsewhere. **12.4 m is inside one hull
  length (14 m), so the slot cap (v3) would not cut it.** It is not the slot-law extension that `bca4eaca`'s inference
  suspected. **Recommendation (to the orchestrator before any v3 work):** v3 as written cannot fix this line. Either
  re-scope (2c) to faces both arms planned (paired by face), with the extra faces reported along with what the base did
  instead, or park P3 for good. Either is a new bar on fresh seeds.
