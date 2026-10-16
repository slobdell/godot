> **ARCHIVED at round 31's close (2026-10-15/16).** This is the brief as its worker left it on `stream/planner` at `216367bf`; the live round's briefs are in `_agents/streams/`.

# Stream: planner (the lattice planner into play: its C++ port equal to the GDScript, a per-tick slice, the one seam into the drive; a long truck in a Terminus street turns in deliberate legs and never grinds a wall)

> Read `_agents/orchestration.md` (the worker contract; lessons 306–311), `_agents/judging.md`, `_agents/workstreams.md`
> **Round 31** (C31.1–C31.11, especially **C31.5** — your two checkpoints — and **C31.2**), round 30's planner report and
> hand-over (`streams/archive/round30/planner.md`; `references/round30/planner/{problem,design,handover}.md`), and round
> 30's manoeuvre report for the cases you now own (`streams/archive/round30/manoeuvre.md`: seed 31's and seed 51's grinds,
> the squadmate pin loop, the six-cusp car, Green_M_3; logs under `references/round30/manoeuvre/`). **You own:**
> `game/ai/planner/**`, **`native/src/planner_native.{h,cpp}` (NEW — native reviews every commit before it is pushed and
> owns the build glue: `mk/native.mk`, `exec_fields.h`, the seam's record fields)**, `tests/planner/**`,
> `tests/test_planner*.gd`, `tests/test_native_planner*.gd`, `mk/planner.mk`, `references/round31/planner/**`. **Granted
> (C31.5, CP-P1):** ONE seam in `movement.gd`'s k-turn block where a plan is asked for, behind `--nav-off=planner` DEFAULT
> OFF — the exact line and the leg shape agreed with manoeuvre in writing through the orchestrator BEFORE code. **Model:
> Fable 5.1** — the round's one Fable stream (his rule): the port and the seam are where capability, not process, is the
> bottleneck.

## The lead's direction

Round 26: *a stuck vehicle should make a planned three-point turn, not shuffle back and forth.* Round 28: **TURN THE
WHOLE VEHICLE** to a drawn facing. His Fable ask (round 30): the hard lingering problems. Round 31 (his quota rule): Fable
for the single most challenging problem — this one.

What he will notice when CP-P1 ships ON: a War Rig told to face back in a Terminus street turns in two or three legs
(the lab: 15.5 s, 3 gear changes, 0 wall contacts v today's 29.8 s, 53, 14); a truck wedged nose-first backs out and goes
round; a car ordered to a slot 9 m behind it with a facing takes 2–3 legs, not six cusps; nothing grinds along a wall.

## Where things stand (main `cff4307e`)

- **On main (round 30, isolated, reached by nothing):** `game/ai/planner/**` — a hybrid-A* lattice over whole legs on the
  plant's own arcs, time cost with cusps and a clearance band, squadmates as oriented boxes, a free-space table per hull
  class, an EXPANSION budget (never the wall clock), legs `Vector3(gear, steer, metres)`; 16 offline tests in `check`
  (`test_planner_model`, `test_planner_fixtures`: every plan audited exactly, drawn as ASCII, planned twice); `make
  planner-lab`. Pre-registered lines NOT met and recorded: the wedge and the causeway slot 4 legs not 3; a rig's 20 m
  in-street turn-round 9 legs not 6 (the lattice's best is 8); an IFV's turn-round in 12 m not found within budget.
- **The cost is the catch:** 0.06–3 s a plan in GDScript on builder0, 17 s for the rig's turn-round. In play it needs the
  C++ port (~100×) or a resumable slice a tick — `handover.md`'s cost line.
- **The executor:** manoeuvre took two of your four rules (arc-not-chord; the discrete stopping distance) as `kturnarc` —
  judged, then parked: the UNSIGNED arc counts a short hull's forward roll-out as progress (a scout's orbit, `scenario_cp2`);
  manoeuvre fixes it gear-signed this round (CP-H). The other two (brake on the leg's own lock with the opposite throttle;
  never zero throttle with the lock on) are manoeuvre's to take or refuse. Today's executor consumes `Vector2` legs on one
  lock; yours are `Vector3(gear, steer, metres)` — the P4 finding, to be decided before code.
- **Your cases, with traces:** F1 the creep at a corner (seed 51, Green_S0_3: the lift rolled a rig's turn into the
  plaza-crossing wall, 50 s at throttle 0.8/lock 0.44); F2/F6 the grind after an escape (seed 31: 77 s, plant 10.7, real
  0.1–3 m/s, goal distance 25–29 m); F4 a goal POSE (yard s25 t1: a car's slot 9 m behind with a facing → six cusps; the
  planned circle back-up never runs for a car since round 26's +14 % contacts); the squadmate pin (a rig pinned 61.4 s
  between two squadmates at 6.9 m/s reported, 0.0000 m moved; Green_M_3's backoff-and-re-pin loop).
- **The honest reading** `Tank.real_velocity` is on main (read by nobody); your plan can take it as the start state's
  true speed.
- `judging.md` has rows for the Terminus census (arrivals, contact-ticks, 13 seeds), hull-rest, the fights guard; a scout
  orbit stage has none yet (brains measures its A/A this round, C31.6).

## Backlog (in order)

**P5 — CP-P0: the C++ port, equal to the GDScript planner.** `native/src/planner_native.{h,cpp}`: the lattice search,
the kinematic model, the free-space table, the OBB squadmate check, the budget — the SAME algorithm (same expansion order,
same tie-breaks, same budget semantics) so plans are identical. `tests/test_native_planner.gd`: every offline fixture and
the lab fixtures planned both ways, 0 mismatches (legs, cost, expansions, the failure code), the twin test in `check`; a
`native-proof`-style arm if the planner is reached by a proof match (it is not until CP-P1: say so). **Price it** on
builder0 (µs a plan per fixture; the 17 s rig turn-round in C++) and write the number with commit and machine. Native
REVIEWS every commit before you push it (SendMessage with the diff hash; orchestrator copied) and owns `mk/native.mk`,
`exec_fields.h`, the seam's record fields — ask, don't edit. CP-P0 merges OFF on its own (worth having alone).

**P6 — the per-tick slice.** A resumable search: a plan request that runs N expansions a tick and returns the SAME plan as
one call would (prove it: the twin test runs each fixture sliced at 50/200/1000 expansions a tick and compares to the
whole plan); the budget per tick chosen from the cost line (≤ 0.5 ms a tick at Sumps 25 a side with every hull that
wants a plan — measure how many want one a tick in a Sumps fight, GDScript census, before choosing). What the hull does
while a plan is pending (hold? today's k-turn's first leg?) is part of the seam design (P7), written before code.

**P7 — CP-P1: the seam, designed in writing, then judged.** With manoeuvre, through the orchestrator, BEFORE code: the one
line in the k-turn block where a plan is asked for (today's planner call), the leg shape (`Vector3(gear, steer, metres)`
consumed by manoeuvre's executor, or your adapter to `Vector2` on one lock — the executor's two untaken rules decide
which is honest), the re-plan events (a leg done, a block, a stale obstacle; never per tick), the pending-plan behaviour,
and what the planner REPLACES when ON (the circle fill? the planned reverse? the creep lift is already gone). Then the
code behind `--nav-off=planner` DEFAULT OFF, native's mirror of the seam (C31.2), and **the pair-tree check (C31.1)
with the switch ON — the whole suite — before any series.** Bar (to the orchestrator before numbers, every line a
`judging.md` row): Terminus census rigs + mixed 13 fresh seeds (arrivals not down beyond 1.645 se EACH squad; rigs'
wall contact-ticks ≤ base + 1.645 se — the thing three rounds of rules broke), seed 31's and seed 51's stages re-run (the
grinds gone: contact-ticks on those runs reported), yard s25 t1 (the car's legs ≤ 3), the squadmate-pin fixture (freed, no
loop), `scenario_cp2` on brains' A/A seeds (a scout's orbit unchanged), `test_wheeled_arrival` + the 180° arrival, hull-rest
(one arm per call; crews still moving at 75 s per task ≤ base + 2 se), bridge-pooled 18/18, fights 24 seeds within 2 se,
cost ≤ 0.5 ms a tick at Sumps 25 a side or the budget that achieves it (stated), the thirteen explained if they move.
Last attempt named; partial: CP-P0 stays merged OFF; a CP-P1 miss parks with its traces. Ships ON as a pair (the C++
plan source on the default path; the GDScript planner kept as the twin). A clip of the Terminus west-street rig and the
yard car before/after for him.

**Stretch:** the squad-level schedule (four trucks facing east without boxing each other) — a design note only.

## How to verify

`make remote T=check` (the twin test in it); the pair-tree check with `planner` ON before any series (C31.1); `make
planner-lab`; the stages above (`nav-terminus-drive`, `manoeuvre-census`, hull-rest, `bridge-pooled`, `manoeuvre-fights`,
`scenario_cp2`, the arrival tests); `native-verify-scenarios`. Every number: commit, machine, workload, n, its row. builder0
only; one slot at a time for anything heavy; no laptop.

## Don't touch

Manoeuvre's executor (`kturn_on` … `_look_stop`, `_kturn_start_leg`, `_planned_reverse`, unstick, `_pressing_escape`) —
you ask for the seam line and consume its leg shape; traffic's, brains' paths; native's build files and `exec_fields.h`
(ask); `game/tank/**`; `tools/judge/**`.

## Waiting on the lead

Nothing (his calls: a planned turn, not a shuffle; the whole hull turns to his facing — both made).

## Status

_Updated 2026-10-15 ~17:55 PDT by the planner worker (`godot-planner`, `stream/planner`, from main `cff4307e`; Fable
5.1). The report first (empty until CP-P0 lands), then the DRAFT SEAM (the orchestrator's early ask), the plan, the log._

### The report (read this first)

**CP-P1 SHIPPED ON: merged to main as e175e660 (2026-10-15 ~17:55 PDT, the orchestrator; native's ship tree
166f7f1e, 2653 passed 0 failed, 0 seam-twin mismatches). Its baselines re-recorded next, then one main check (the
orchestrator's). stream/planner stays as the record.**

**CP-P1 VERDICT (every stage to completion, 2026-10-15 17:20 PDT): the pre-registered bar's ship clause is MET.**
Candidate = the seam ON (`--nav-off=planner` on the GDScript drive, `PLANNER_DEFAULT` false) at **series tree 35f5df92
= code f9d2c639** (the keep circle 1bec314d/38e9678d + the crew-per-hull fix f9d2c639); **gate = native's pair
85911f0b** (main a2ef0b31 + f9d2c639 + the C++ mirror + their seam_live fix + PLANNER_DEFAULT true: tests 2652 passed
0 failed; `make check exited 2` on sim-baseline MOVED on 6 of 13 maps -- foundry, pit, crossing, sumps, gorge,
archipelago, the expected ON move -- and remote-guard-test, box-state, non-blocking under R31.10). Every row below:
builder0, series tree 35f5df92, gate 85911f0b, unless named otherwise; every line read once at completion on the
fixed 1.645 se line (R31.8, no early stop).

| line | what | base | candidate | paired / line | verdict |
|---|---|---|---|---|---|
| (a) rigs arrivals, Terminus seeds 172-184, n 13 | of 208 | 180 | 172 | mean -0.615, se 0.500, line -0.823 | **PASS** |
| (a) mixed arrivals, the same seeds | of 312 | 289 | 289 | identical both arms, seam silent 13/13 | equality holds |
| (b) rigs contact-ticks (the sized deciding line) | median | 855 | 533 | mean -282.2, se 211.2 (candidate lower) | **PASS** |
| (c) scenario_cp2, the scout's orbit | 6 MEASURE cells | | | identical both arms; verdicts identical | **PASS** (no leak) |
| (d) hull-rest at-rest hull error, class x task | permutation p | | | smallest p 0.087; all >= 0.05 | **PASS** |
| (d) hull-rest settle time, paired median | s | | | +0.0 / +2.5 / -5.0 / +0.0 / +0.0 / +0.0 | **PASS** (<= +6) |
| (d) hull-rest crews still moving at 75 s, wheeled-turret row (the filed form) | 12 task x arm rows | | | all <= base + 1.645 se (closest +8 v 9.05, +8 v 8.39) | **PASS** (ruled as filed) |
| (e) fights, 24 seeds 181-204: kills / deaths / hit rate | | 1018 / 1024 / 0.702 | 1014 / 1020 / 0.714 | -4 se 4.5; -4 se 3.4; +0.012 se 0.009 | **PASS** |
| (e) bridge-pooled | runs | 18/18 | 18/18 | every row identical | **PASS** |
| the rig 180 (deterministic) | test_wheeled_arrival's rig case | | green on the gate | | **PASS** |
| (f) cost, Sumps 25 a side, pinned 0-3, load 16.7 / 16.5 (a1d9e1fc) | SLICE 2 x warm us/expansion, longest live hull | | 263 (seed 92721) / 186 (31337) | 0.526 ms / 0.372 ms v 0.5 | **MISS on 92721, PASS on 31337** (ruled: not in the ship clause; SLICE stays 2; round 32 makes it a hardware preset) |

**REPORTED (never pass lines).** Seam over the 13 rig runs of (a): requests 459, plans 137, driven 106, aborted 5,
abandoned 2, rerequested 0, refused GOAL_BLOCKED 203 / START_BLOCKED 83 / NO_PATH 23, queue_waits 486, **the hold per rig
event pooled n 448, median 11, max 104 ticks (3.5 s)**, pending_ticks 6573. Worst runs: contact-ticks base seed 180
(2561), candidate seed 182 (2141); per seed base/candidate 172 119/1014, 173 2083/471, 174 406/264, 175 424/393,
176 682/848, 177 221/302, 178 2410/1931, 179 855/297, 180 2561/2020, 181 555/533, 182 1860/2141, 183 2191/296,
184 1793/1982. (d) read per task over all classes: 3 of 12 task x arm lines over (drawn faced_attack_move +12 v 9.5,
drawn faced_support_by_fire +10 v 9.1, clicked faced_screen +15 v 12.6), carried mostly by the 108 runs where the
seam never fired (92 of them differ between arms: the hull-rest screen harness is not run-to-run deterministic);
wheels/fixed faced_attack_move drawn +4 v 3.62 over. The seam in hull-rest's gang army: drawn 784 requests / 170
plans / 57 driven / 177 abandoned, clicked 1176 / 115 / 45 / 209 (**a round-32 finding: the one-session queue starves
in a 19-crew press**); manoeuvre's face_plans drawn 893 v 970, clicked 1867 v 2130. (e) hits 19277 / 19172 (-105, se
472). (b)'s named n = 1 cases (`references/round31/planner/cases-b/`): seed 31 Green_S0_2 1930 -> 2198 contact-ticks,
a DIFFERENT grind of the same length (the west street, planted on a container behind Green_S0_1, no seam event in that
leg: nav's squadmate wedge, CP-H's); seed 51 Green_S0_3 267 -> 244, the candidate's one missed arrival 9.6 m short with
no seam event in that leg; the seed 9 pin: pinned unit-ticks 491 (16.4 s) -> 30 (1.0 s), freed, no re-pin loop; the
six-cusp car: a short hull, the mixed line identical is the leak check. Series 1 on the diagnosis seeds 133-145
(before the keep circle): rigs -1.462 se 0.595 MISS; the traces that found the fix in
`references/round31/planner/series1-diagnosis/`.

**(g) The clip for him:** `~/projects/clips/round31/planner_terminus_f9d2c639.mp4` (32 s, side by side, the final tree):
today's drive 29.8 s with the rig jackknifed at the wall v the seam 15.5 s, 3 legs, 0 contacts. **Ships as:** native's
SHIP TREE **166f7f1e** (main b352fa2a with CP-H + f9d2c639 + the mirror + PLANNER_DEFAULT true; builder0: tests 2653
passed 0 failed, sim-baseline the only red target, the expected move, 0 seam-twin mismatches; native's cut 3cd68da5
before it had a test_native_drive coverage floor at 12 under the required 20 station-keeping drives, fixed test-only
in 166f7f1e, none of my code changed) + the six moved baselines re-recorded (the orchestrator's). 85911f0b stays the
gate every judged row above names. Files: the verdict
`references/round31/planner/series2-fresh/`, hull-rest tables, fights table, bridge rows, cp2 measures, all under
`references/round31/planner/`.

**CP-P0 candidate a3755e37** (C++ `PlannerNative`, equal to the GDScript planner on 17 offline + 4 Terminus-navmesh
fixtures on every observable, the three hull tables bit for bit, the slice = the whole plan): **twin GREEN on builder0
twice** (41212da0 = a3755e37 + docs: `tools/remote.sh --quiet planner-twin PLANNER_CPUS=0-3` exited 0, 4 passed 0 failed,
pinned to cpus 0-3, load 0.76; and the unpinned light-lane run before it). **Full `make check` GREEN twice on builder0:**
41212da0 (CP-P0, merged OFF to main 950c7681: exited 0, 2615 passed 0 failed, 24 passed 2 NOT JUDGED) and the rebased
tip **86e5c646** (main 84e553cd + the seam's `yield_to_plan` hook: `>> remote: make check exited 0`, 2638 passed 0 failed,
24 passed 2 NOT JUDGED -- perf-judge refused 3x on the busy box, scenario_perf's cpu budget unpinned -- sim-baseline all
13 maps unmoved, determinism 2875411ff4ec6be7, 05:54 PDT). Green `make check` hashes: 41212da0, 86e5c646.

**The price (CP-P0's cost line), builder0 41212da0, pinned to cpus 0-3, QUIET WINDOW: NOT USABLE** (7 of 7 samples had
7-8 foreign runs live; load1 0.46-1.17 in `build/quiet-window.tsv`; the box never went quiet in a 65-minute wait, so these
are the best numbers the night allows, an UPPER bound, not a quiet-window figure):

| fixture (native, cold field each plan) | expansions | a plan | an expansion |
|---|---|---|---|
| Terminus turnround (rig face south) | 7 | 3.57 ms | 510 us |
| Terminus slot180 (scout) | 37 | 3.67 ms | 99 us |
| Terminus tjunction (rig onto the ring road) | 94 | 16.2 ms | 172 us |
| yard corner, BUDGET | 12 000 | 1.30 s | 108 us |
| offline F6a rig turn-round 20 m (rectangles) | 3735 | 150 ms | 40 us |
| offline mouth IFV (rectangles) | 47 | 2.66 ms | 57 us |

Against the unpinned load-13 run the same plans cost 2.7-3x more (9.7 / 47.9 ms / 3.8 s), so load, not the code, set
the earlier numbers. The per-expansion price on the navmesh is the LAZY FIELD'S first read of each cell (~1 ms a cold
expansion at the start of a plan, ~50 us once its cells are read): the commit after the candidate (d373af4e, fixed
17bd1ec8) keeps a navmesh's cells across plans and instances for the match, so a hull's plan in a fight pays the cold
price only where no plan has looked before. **The cap v the cost line:** at the pinned cold price SLICE at the 0.5 ms
line is 3-5 expansions a tick, a 94-expansion plan ~20-30 ticks (~1 s), inside PENDING_TICKS 90 (3 s); with the cells
warm (~50 us) the slice is ~10 a tick and the same plan ~10 ticks. SLICE is chosen from `planner-census`'s in-fight probe
on 17bd1ec8 (the next run), not from this table.

**Review state:** native APPROVED 7c286000, 50d380e1 (one fix taken), ad1d1f3d + a3755e37 (two nits, taken at
d373af4e), **d373af4e + 17bd1ec8 APPROVED** (the navmesh cell cache, the game's index handed in as `"nav"`, the
rolling-face seam test; three notes taken at 3b5c0b34: `nav_cache_clear()`, the rebake-within-a-session assumption
written down, memory bounded by the map). **Light twin GREEN on 17bd1ec8** (`make remote LIGHT=1 T=planner-twin`,
exited 0, 4 passed 0 failed, builder0, unpinned, load 10.4; the same plans, costs, expansions and nodes as a3755e37).
The orchestrator's ruling (R31.6): the price is accepted as an upper bound, no second quiet window this round; the
cache merges only with its own planner-twin ALL green + native's review (both held now for 17bd1ec8; c158aecf, the
signedness fix, and 3b5c0b34 need the next twin). **THE CENSUS (P6), builder0 light lane, c158aecf, Sumps 25 a side (50 hulls), `--brains-off=native_drive` (GDScript
drive, C++ planner), 120 s, seeds 92721 / 31337, `build/light/build/planner/census-<seed>.log`:**

| | seed 92721 | seed 31337 |
|---|---|---|
| ticks / plan events | 3590 / 373 | 2823 / 340 |
| events a tick: mean, max | 0.104, 7 | 0.120, 7 |
| ticks with 1 / 2 / 3+ events | 272 / 31 / 9 | 249 / 25 / 10 |
| busiest second | 24 events (tick 34) | 28 events (tick 216) |
| by kind: kturn / multi / none / face / face_none | 215 / 11 / 35 / 79 / 33 | 202 / 20 / 19 / 83 / 16 |
| nav probe (the seam's face-about for the longest live hull): plans | 119 | 94 |
| its codes OK / GOAL_BLOCKED / START_BLOCKED / BUDGET / NO_PATH | 80 / 28 / 9 / 2 / 0 | 33 / 35 / 23 / 2 / 1 |
| expansions of an answer: median, max | 131, 3000 | 0 (refusals), 3000 |
| us an expansion, cold quarter / warm quarter | 153 / 389 | 171 / 174 |
| a refused plan (world build + refusal) | ~118 us | ~93 us |
| cache at the end: chunks / hits / misses | 21 / 601.8 M / 47 125 | 21 / 193.0 M / 33 726 |

**The second census (fd36ecd5's C++, the tree at 98d3a9c9, same seeds, load ~12):** the same events (the fights are
deterministic); cache hits 601.8 M -> 0.88 M (the window fill works: one lookup a cell a search); the per-expansion
price UNMOVED once scaled for load (cold quarter 257 / 292 us, warm 392 / 205 us; the unchanged offline T-junction
probe ran 45 % slower, 2.74 / 2.37 ms, on the busier box). **So the warm price is compute, not lookups:** the sphere
walks of a long hull's four sides (the hull tests are distance-culled and cheap; the per-plan fixed cost ~100-200 us).
**SLICE = 2** (005a3837): 0.4-0.8 ms a tick at that price unpinned, ~0.3 ms pinned; counted, never timed (the tick a
plan lands must not depend on the machine: the lockstep relay). **The demand arithmetic, stated plainly:** ~3 plan
events a second x ~130 expansions x ~200 us = ~3 ms a tick if the seam served EVERY event the GDScript drive makes
today, six times the cost line; at SLICE 2 the seam serves 2 expansions a tick, so in a 25-a-side press most takes
would run out the 3 s hold (`abandoned`) and fall back to today's code. The Terminus fixtures the brief names (7-94
expansions) land in 4-47 ticks. The CP-P1 bar therefore judges the seam on the brief's hulls and streets; the SCOPE
of the seam (which kinds / hulls it takes) is the lever if the judged `abandoned` count says so, and a profile of the
expansion (where the ~200 us goes) is the stretch.

Read: (1) **one plan event a tick is the normal case** (272 + 249 of 3000 ticks), two in 1 %, a burst of 3-7 in
0.3 %: the one-deep queue serves it, a burst of 7 queues ~6 plans deep (the seam's `queue_waits` counter shows the
cost in the judged run). (2) The in-fight price of the seam's own navmesh request was **~170 us an expansion WARM**
with the cache hit 99.99 % of the time: ~1700 cell reads an expansion, each a hash lookup. **fd36ecd5** fills the
search's window from the cache on a cell's first read (one lookup a cell a search); its twin + a second census are
running (`planner-twin9`); SLICE is chosen from THAT census. (3) A quarter to a half of the probe's face-abouts are
refused START_BLOCKED (the hull's own pose is in contact in the planner's world: wedged against a wall or a hull) or
GOAL_BLOCKED (the turned-about footprint on the same spot clips something): in a 25-a-side press the seam's refusal
path (today's code continues) will be exercised often; the judged run's `refused` counts are the measure, and a
START_BLOCKED hull is exactly manoeuvre's unstick customer, not the planner's.

### Hand-over for round 32 (1): SLICE as a hardware-preset knob (the orchestrator's ruling on line (f), 2026-10-15 15:35 PDT)

Line (f) read as filed on the final tree: seed 92721 MISS (SLICE 2 x the warm 263 us = 0.526 ms at builder0 load
16.7, pinned 0-3, an upper bound per R31.6), seed 31337 PASS (0.372 ms); not in the ship clause, so it blocks no ship,
and SLICE stays 2 for round 31 (changing it after the numbers would change the judged candidate). **Round 32:**
`PlannerSeam.SLICE` becomes a hardware-preset knob (the lead's rule: perf cuts ship as presets), e.g. SLICE 1 on the
laptop preset, sized from a LAPTOP-CLASS price (`make planner-census PLANNER_CENSUS_PROBE=30 PLANNER_CPUS=0-3` on the
laptop, ~2.75x builder0; the hold per plan roughly doubles at SLICE 1: the series' hold per rig event was median 11 /
max 104 ticks at SLICE 2, so quote the laptop's hold beside its price).

### Hand-over for round 32 (3): the gang-press queue starves (the hull-rest finding, 2026-10-15 16:40 PDT)

**What the data says.** The seam serves ONE search at a time (`_queue`, the head's session stepped SLICE expansions a
tick; the others wait at zero/zero, `queue_waits`), capped at PENDING_TICKS 90 from the ask. In the Terminus rig
squad (4 rigs) that is fine: the series' 13 runs abandoned 2 of 459 asks, hold median 11 / max 104 ticks. In
hull-rest's gang army (19 crews, several War Rigs told to face at once in a press): **drawn 177 of 784 asks abandoned
(23 %), queue_waits 19179, pending_ticks 23402; clicked 209 of 1176 (18 %), 26578, 31283** -- the hull stands up to
3 s, gets nothing, and today's code takes over after the RETRY_TICKS decline. Refusals are the other half of the
demand: GOAL_BLOCKED 161 / 145 (the turned footprint clips a squadmate: C31.5's re-seat rule, brains'), START_BLOCKED
54 / 80. Every number from builder0 35f5df92, `references/round31/planner/hull-rest-d-reading.txt`.

**What to do, cheapest first.** (1) **Price before design:** the pinned census says ~230-260 us an expansion warm on
the longest hull, so SLICE 2 is ~0.5 ms a tick for ONE crew; N crews at once cost N x that -- the queue exists because
the cost line is per tick, not per crew. (2) **A per-tick BUDGET shared round-robin** (`PlannerSeam.BUDGET_PER_TICK`
expansions, handed to the queue's heads in turn, 1 expansion each) instead of one head: the same 0.5 ms, every pending
crew progresses, the worst hold falls from (queue length x its search) to (queue length x 1 expansion); the twin
harness (`capture`/`restore`, native's mirror) must carry the heads' sessions -- native's `Planner` holds one
session today, so this is a C++ change too (a session per crew, or a session stack). (3) **Refuse early:** the ask
already prices GOAL_BLOCKED / START_BLOCKED before the search (`parse_request`); a crew whose request would refuse
should never enter the queue (today it does, and holds the hull for the refusal's tick). (4) **The cap as a preset
with SLICE** (hand-over (1)): PENDING_TICKS x SLICE is the expansions a crew can get; a laptop preset at SLICE 1 needs
the cap re-sized or the abandonment doubles. The bar for (2): hull-rest's gang arm re-run, `abandoned` <= 5 % of asks,
the hold per rig event median not up, the at-rest and moving lines as round 31's (d). **Not a round-31 bar line:**
(d) was ruled PASS as filed; this is a REPORTED finding.

**Two lessons for whoever touches the seam next.** A crew is keyed by hull NAME; `Crew.tank` names the instance and
`_sweep` releases freed hulls (f9d2c639: a disposed match's crew drove a freed hull's executor in the next match under
the same name -- the pair gate caught it; any new static keyed by name needs the same). And the hull-rest screen
harness is NOT run-to-run deterministic (92 of the 108 seam-silent runs differed between arms): pair everything on
(faction, seed) and quote the se; never read a single hull-rest run as a signal.

### Hand-over for round 32 (2): the §2.8 SIDE gate for a wheeled hull under 10 m (the orchestrator's ask, 2026-10-15 ~04:20 PDT)

Brains' B5c-v5 parked on a Sumps limit cycle; its worst yard run (s27 t8, A_5 at its herringbone gate facing away, dot
-0.94, the gate given up 27 m from the slot, the car onto terrain by the containers) is the case design.md §2.8 names.
What it needs, honestly split between the planner (nothing new) and the seam (three things), with the cheapest
deliverable first:

1. **The planner needs nothing per hull length.** `PlanRequest.for_unit` builds the kinematics from the catalog
   (turn radius, speeds, the yaw cap), the C++ port is hull-agnostic and its tables are per unit (gang_tank, ifv and
   law_scout proven bit for bit); the lab's six-cusp car (yard s25 B_4, a slot 9 m behind with a facing) plans in
   <= 3 legs today, and the census's short-hull probe prices a car's face-about at 190-250 us an expansion, median
   11-113 expansions. What excludes the car is the SEAM: R31.7's scope (>= 10 m) and the seam's two take points (the
   k-turn block, the face at rest), neither of which is "arrive on a slot with a drawn facing".
2. **The cheapest deliverable, no seam at all: a side-gate POINT for brains' gate rule.** §2.8's geometry is `slot +
   perp x R` on the side with room, length R, never along the facing axis behind the slot. The planner's world answers
   "which side has room" without a search: `PlannerNavWorld.clearance(x, z)` at `slot +- perp x R` (two cell reads
   through the C++ cache, ~microseconds; the clearance must exceed half the hull's width + MARGIN_M) -- a static
   `PlannerSeam.side_gate(slot, facing, unit_id) -> Vector3` (or ZERO when neither side has room: today's gate stays).
   Brains keeps the gate (C30.5); it only asks the planner's world where to put it. A contract line in workstreams.md
   (brains' gate rule calls one planner static) and brains' own bar.
3. **The full answer, a third take point: a `"slot"` kind in the seam.** Request: goal pose (slot, facing), tol 1.0 m /
   8 deg, `arrive_gear` any (a tail-first slot = gear -1 allowed on the last leg), made when the hull is within
   HORIZON_M (30 m) of a slot with a drawn facing, at the line where brains' gate rule would lay the gate (brains' /
   manoeuvre's lines: a contract change, R31.2's form). The planner then answers the 180-degree arrival in three legs
   (F4: drive past, reverse arc, forward onto the slot) and no gate exists inside the horizon; beyond it, (2)'s side
   gate. The scope opens for THAT kind only (`in_scope(unit_id, kind)`: slot for any wheeled hull, face / kturn for >=
   10 m), so the k-turn and face demand of 48 short hulls (95 % of a fight's manoeuvre starts, census-4) stays with
   today's code. Its own bar: the yard s27 t8 trace as a named case, an arrival census (slots reached within tol,
   gates given up), and the cost line re-priced for the slot demand (one request per order per hull, not per k-turn).
   **Round 31's evidence for this kind:** the first judged series' whole loss was rigs "arrived, order complete"
   7-11 m from the census slot after the seam's FACE plan carried them off the slot (the keep circle, 1bec314d, is
   the face's version of manoeuvre's slot law and closed it: series 2 PASS); a `"slot"` kind makes the slot the GOAL
   instead of a circle the face may not leave, so the keep circle becomes a special case of it. The k-turn kind has
   no slot law today (its goal is the route's waypoint, `crew.order_goal` the order's goal for the new-goal release).
4. **The refusals the seam already has are the fallbacks:** START_BLOCKED (the hull in contact: manoeuvre's unstick)
   and GOAL_BLOCKED (the slot's turned footprint clips a squadmate's box: C31.5's re-seat rule, brains') hand the hull
   back to today's code within a tick, with `last_refusal(name)` for the counters.

### THE SEAM (CP-P1) — AGREED as R31.2 in `workstreams.md` (main 47be4134; drafted here 2026-10-14 ~22:45, agreed ~23:00)

**What the agreement added to the draft below (each a line I own in my seam commit):** (a) `Movement.manoeuvring() ->
bool` = `in_kturn() or (PlannerSeam.on() and PlannerSeam.live(String(ctl.tank.name)))`, next to `in_kturn()` (which keeps
its three readers as they are); traffic reads `manoeuvring()` in the crossing row and in `ask()`, manoeuvre's straight-leg
lever reads it, `manoeuvre_census` keeps `in_kturn()` and adds a planner column. (b) A gate in `Movement.unstick()`
right after traffic's `Traffic.holding` line: `if PlannerSeam.on() and PlannerSeam.live(String(ctl.tank.name)): return`
(OrderController calls `unstick()` after `_apply_move` regardless; manoeuvre reviews the line). (c) `PlannerSeam.live(name)`
is static and false when OFF. (d) `PlannerSeam.capture() / restore(snapshot)` for the twin harnesses (MoverState,
TrafficTwin snapshot statics; the seam's table holds Objects, so the pair's drive twin restores between arms through
this). (e) Manoeuvre: YES to both call lines, YES to `PlannerExecutor` driving `Vector3` legs; its executor stays
`Vector2` and does NOT take the two brake rules (mine); accepts 0/0 for <= 3 s then 1 s of declining. (f) Native: gates
`planned_reverse_cheap`'s cheap exits in C++ at the pair (while `PlannerSeam.on()` or any crew is live it calls back
`_planned_reverse`); `face_turn` needs nothing (wheeled face orders already return to GDScript); `BrainSwitches.
native_planner` (default true) is at stream/native bf8d4a78, read as `BrainSwitches.native and BrainSwitches.native_planner`;
no `exec_fields.h` rows; my `register_types.cpp` + `CMakeLists.txt` lines reviewed by hash with the rest.

### CP-P1 BAR (DRAFT v2, 2026-10-15 ~02:45 PDT, pre-registered before any judged number; to the orchestrator for `workstreams.md` *Bars (round 31)*; v1 of ~01:00 superseded on R31.7)

**Candidate:** the seam ON (`--nav-off=planner`) at the hash the pair-tree check passes (a073157e or its successor; the
check names it), GDScript drive, the C++ planner (`native` + `native_planner` on in BOTH arms). **Base:** the same commit,
`--brains-off=native_drive` (the GDScript drive with no seam; any `--nav-off` flag already makes `NativeDrive.usable()`
false, so this is the one flag that puts both arms on the same drive; each arm's run prints its own switch list, lesson
309). **Declared change (R31.2 + R31.7):** for hulls of length >= 10 m (`PlannerSeam.SCOPE_MIN_HULL_M`: the War Rig,
14.0 m, the only such hull in the catalog; the next is 9.7 m), the plan source of the k-turn block and of the face at
rest (the back-and-fill, the circle plan, `plan_face`) replaced by the lattice planner's legs driven by `PlannerExecutor`;
a short hull is never taken (its own test); nothing else. **SLICE 2 expansions a tick, counted never timed; PENDING 90
ticks of SEARCH from the tick it begins at rest (a rolling hull is braked to rest first; its whole hold is
`pending_ticks`); one crew searched at a time.** **Census numbers the bar is sized from (builder0 light lane, Sumps 25 a side,
seeds 92721 / 31337, c158aecf / fd36ecd5 / a6a66f31):** ~0.10-0.12 plan events a tick in the whole fight, bursts to 7;
the War Rig's in-press face-about ~200 us an expansion warm, median 131 expansions when it fits, a quarter to a half
refused START_BLOCKED / GOAL_BLOCKED in the press; **the long hulls' share (census-4, b37b9ecb, same seeds): 2 of 50 hulls
(the perf armies' War Rigs), 6 of 174 and 9 of 202 manoeuvre starts (`in_kturn` / face-leg edges per controller:
3.4 % / 4.5 %), no face orders at all in a bot fight; their fitted plan's expansion median 131 (seed 92721's rig
probe; seed 31337's fitted quarter 257); so the seam's in-scope demand is ~0.06 plans a second x ~131 expansions x
~200 us = ~1.6 ms a SECOND (~0.05 ms a tick averaged), a thirtieth of the whole fight's, and SLICE 2 (60 expansions a
second) leaves it idle ~85 % of the time; a median plan holds its rig ~65 ticks (2.2 s), inside the 3 s cap. The
short hulls' own face-about (never taken) prices the same per expansion (190-250 us) at a median of 11-113.** **First run; a second on fresh seeds
would be the last.** Lines, each from `judging.md`'s row (the table re-rendered at `3ca70af2`):

- (a) **Terminus census, rigs + mixed, 13 FRESH seeds (133-145; the draft's 61-73 collided with M4b's 62-74 and T4's 49-61), `nav-terminus-drive` both squads:** arrivals not down beyond
  1.645 se EACH squad (rigs row: se 6.07 of 16 x 13 at n 13, the guard base - 9.98; mixed: se 3.75, base - 6.17);
  `sequential.py arrived:guard:0.10` as the early-stop rule, never before 6 seeds; wall contact-ticks REPORTED per run and
  as the median (the rigs row's MDE is +74 % at n 13: a +-10 % line cannot be carried, lesson 4 of the table), with the
  worst run's trace before the median; `PlannerSeam.report()` printed per run (requests, plans, driven, aborted,
  abandoned, rerequested, refused by code, pending-ticks, queue_waits): a run where the seam never fired is an equality
  check, not a sample. **REPORTED, never a pass line: `abandoned`, `queue_waits`, `refused`** (R31.7: a starved seam is a
  finding, and the candidate parks with its traces; there is no second scope), **and the HOLD per rig event
  (`holds`: n, median, max hull-ticks from the ask to the plan, the refusal or the abandonment; the orchestrator's
  addition ~03:15: a rig told to face while moving fast stands up to ~3.8 s before its first leg -- ~45 ticks braking
  + up to 90 of search -- and he would see that), the worst one in the clip if it is long.**
- (b) **THE DECIDING LINES, the rig cases.** The n (the orchestrator's (i)): `terminus_drive.gd` has no tick-offset
  knob and is nav's file (not mine to edit), and a pure order delay in a one-squad deterministic drive would replay the
  same grind shifted in time (n copies, no se). So the SIZED deciding lines are the RIGS SQUAD'S paired rows over (a)'s
  13 fresh seeds: wall contact-ticks of the rigs squad <= base + 1.645 se of the paired difference, and the rigs'
  arrivals (a)'s line; the pin's sized form is hull-rest's pinned crew-seconds row (d: n 144 paired, se ~420); the
  rig's 180-degree arrival is deterministic (`test_wheeled_arrival`'s rig case green on the pair tree, `planner-lab`
  slot180 on a rig three legs). The named single-seed cases (round 30's, each REPORTED with its trace at n = 1; the
  mechanisms that produced two of them were not shipped, so the base may not show them):** rigs seed 31 (Green_S0_2's 77 s grind under M4b's escapes)
  and seed 51 (Green_S0_3's 50 s grind under the lift): contact-ticks of those runs both arms, the rig's grind not
  longer under the seam; the squadmate pin (`planner-repro-wedge`, rigs seed 9: a rig pinned 61.4 s between two
  squadmates): freed, no backoff-and-re-pin loop (pinned crew-seconds reported; sized by (d)'s row); the 180-degree
  arrival on a rig: three legs, not a gate, arriving within the row's tolerance (deterministic, a pass line). **The
  six-cusp car (yard s25 B_4: a slot 9 m behind with a facing) is a REPORTED line, not a pass line (R31.7):** a car is a
  short hull the scope never takes, so its legs per arm are reported with the expectation that they are EQUAL; a
  difference is a seam leak (the switch reached a short hull) and parks the candidate.
- (c) **`scenario_cp2` on brains' A/A seeds (C31.6's 12 seeds): a scout's orbit unchanged** (the no-change guard, a pass
  line: the scout is out of scope, so any moved cell is a leak, not a finding). `test_wheeled_arrival`, `test_tactics_pursuit`,
  `test_tactics_mixed_legs`, `test_nav_wall_contact` green on the pair tree with the switch ON (C31.1) BEFORE this series.
- (d) **Hull-rest (`manoeuvre-hull-rest`, one arm per remote call, lesson 311), 4 factions x 6 tasks, fresh seeds 60-65 (54-59 were M4b's chain),
  drawn AND clicked:** crews still moving at 75 s per task <= base + 1.645 se (C31.3) (wheeled turret row: sd 1.63 a run, se 6.3 at
  n 15 -> quote M1_CLASS's paired se); the at-rest hull-error median per class x task not worse (permutation p >= 0.05);
  settle time paired median <= +6 s (the row's form); REPORTED: the face plans the seam made v `plan_face`'s, for the rig
  class only (the others are equality).
- (e) **Bridge-pooled 18/18** (deterministic row). **Fights (`manoeuvre-fights`, 24 fresh seeds 181-204; 157-180 were M4b's):** kills, deaths, hit rate within
  1.645 se (C31.3; rows: se 28.2 / 28.8 / 0.0153 at n 24); hits reported.
- (f) **Cost (C31.5's line, R31.6 / R31.7):** at Sumps 25 a side (`planner-census`'s workload, the candidate's tree, both
  arms, `PLANNER_CENSUS_PROBE=30`): the seam's slice <= 0.5 ms a tick = SLICE (2) x the probe's warm per-expansion median
  for the longest live hull, on builder0 pinned to 4 cpus (`PLANNER_CPUS=0-3`) with the box's load quoted (R31.6: no
  quiet window this round; the pinned figure is the upper bound); the per-plan hold REPORTED (pending ticks per plan,
  the 90-tick cap's `abandoned`); the thirteen sim-baseline lines unmoved (the seam is OFF by default until the pair
  ships; when ON by default, the thirteen explained if they move).
- (g) **The clip for him:** the Terminus west-street rig (a face back), before/after (`planner-lab`'s frames plus the
  seam under the real drive: `make remote LIGHT=1 T="planner-lab PLANNER_ARMS=today"` with `PLANNER_FLAGS=--nav-off=planner`
  as the "after"), looked at by me first. The yard car is no longer a clip (out of scope).
**Partial rule:** (a) incl. the rigs' contact-ticks line, (c), (d), (e) met and the rig 180 green = ships ON as a pair;
(b)'s car line or (c) moved = a leak, parked; the rigs' contact-ticks or arrivals missed, or (a)'s `abandoned` says the
seam starved = a finding, parked with its traces (CP-P0 stays merged OFF); the named n = 1 traces are read, never judged. **Last attempt named:** the second judged run.

#### The draft as sent (kept as written)

Read against `movement.gd` at `cff4307e` and `drive_native.cpp`'s callback layer. Four answers, then the rules.

**(1) The line(s) where a plan is asked for.** Today TWO places make a plan of legs for a wheeled hull, and both are
"the k-turn block" in the sense of C31.5 (one executor rule set, `Vector2(gear, metres)` legs on one lock):
- `Movement._planned_reverse` (line 3311): on a routed forward move, when the forward arc toward `waypoint` meets a wall
  within `KTURN_HIT_WITHIN_M + stop`, `_best_fill` / `_circle_leg` make `_kturn_legs` and `_kturn_start_leg` drives them.
- `Movement.face_turn` (line 1244): a face at rest, `Manoeuvre.plan_face` makes `_face_legs` and `_face_start_leg` drives them.
  (The War Rig he will notice is a FACE order: the lab's `turnround` fixture is `{"type": "face"}`.)

The seam is ONE function of mine, `PlannerSeam.take(mover, cmd, kind, delta) -> bool` (`game/ai/planner/planner_seam.gd`,
my path), called at ONE line in each of those two functions, BEFORE today's plan is made, and only when the switch is on:
```
# _planned_reverse, first line of the body (before `if _kturn_left_m > 0.0`):
if PlannerSeam.on() and PlannerSeam.take(self, cmd, "kturn", waypoint, delta): return true
# face_turn, right after the `FACE_ALIGNED_DEG` early return (the hull is not aligned, no plan is live):
if PlannerSeam.on() and PlannerSeam.take(self, cmd, "face", _face_home, delta, want): return true
```
`take` returns true while it owns the hull (a plan pending or being driven) and has written `cmd`; false = the seam
declined (not a planner case, NO_PATH/BUDGET/GOAL_BLOCKED, the retry window, or the hull is not wheeled) and today's code
runs unchanged from that line. OFF: the two lines are never reached (byte-identical today).

**The switch:** `--nav-off=planner` turns it ON (`PlannerSeam.on() = Movement.switched_off("planner")`, the opt-in form of
`leash` / `nosestop`; `"planner"` added to `OFF_NAMES` in the same commit, my one shared-file edit). Note for every arm:
ANY `--nav-off=` flag makes `NativeDrive.usable()` false (`native_drive.gd` line 29), so an arm with the planner ON runs the
GDScript drive for every hull; the judged A/B runs both arms on the GDScript path (as C31.4's does), and the pair-tree
check with the switch defaulted ON is where native's mirror is exercised.

**(2) The leg shape: `Vector3(gear, steer, metres)`, driven by `PlannerExecutor`'s rule (my file), NOT adapted to
`Vector2` on one lock.** Why: an adapter to one lock is not honest, it would restrict the search to one lock per plan
(the lab's rig plan was F-1 8, F+1 24, R+1 10, F+1 12, F0 16.5: three locks), i.e. a different and worse planner. Driving
multi-lock legs needs the two executor rules manoeuvre has NOT taken (brake ON THE LEG'S OWN LOCK with the opposite throttle
until all but stopped, then the next leg's gear and lock; never throttle 0 with the lock on, which is the plant's creep):
without them a rig's next leg brakes 3-4 m on the WRONG lock and every plan misses. The two rules manoeuvre DID take
(`kturnarc`: arc-not-chord signed by gear; the discrete stopping distance) are in `PlannerExecutor` too. So: the planner's
legs are driven by `PlannerExecutor` (148 lines, proven in the lab within 1 % of the plan), held by the seam, for the hulls
and events the seam takes; today's k-turn and face executors are untouched and drive everything the seam declines.
**Alternative, if manoeuvre would rather consume the legs itself:** `_kturn_legs` of `Vector3`, `_kturn_start_leg` reading
`leg.y` as the leg's lock (`_kturn_turn = leg.y`, metres `leg.z`), and a `_kturn_braking` state in `kturn_leg` (own-lock
braking for `_kturn_plan_kind == "planner"` only, so every existing plan drives as today); `face_turn` routed through the
same executor for planner plans. ~25 lines of manoeuvre's + native's `kturn_start_leg`/`kturn_leg` mirror. I recommend the
first (nothing of manoeuvre's changes; CP-H's executor edits and this cannot collide), and will build it unless manoeuvre
asks for the second by the time CP-P0 is green.

**The request** (`PlanRequest.for_unit(tank.unit_id)`: the catalog hull, the k-turn's 0.7 throttles lowered under the yaw
cap): `kind == "face"`: goal = (`_face_home`, `want`), `tol_m = max(settle_radius - 1, 1.5)` (plan_face's `stay`), 8 deg,
`arrive_gear` 0; `kind == "kturn"`: goal position = the `waypoint` if within `horizon_m`, else the point 0.8 x horizon along
here -> waypoint; goal heading = toward the NEXT route vertex when `_path` has one past `_path_index`, else free (`tol_deg`
180); `tol_m` = `_arrive`; `arrive_gear` +1 (the route continues forward). World = `PlannerNavWorld.for_tank(tank,
tanks_root)` (the navmesh at the bake radius, every other living hull as a box, a snapshot at the request). Horizon 30 m
(the order's leash radius when smaller). Budget 1500 expansions coarse + the fine retry (3000 at most), `epsilon` default.

**(3) While a plan is PENDING under the per-tick slice.** The request is made from the pose at the request tick and the
search runs `PLANNER_SLICE` expansions a tick (the number chosen from CP-P0's cost line so the slice is <= 0.5 ms; one hull
a tick: a one-deep FIFO in `PlannerSeam`, the others wait their turn). Pending, the hull commands **zero/zero** (brake
straight, the lock off: not the creep, which needs the lock on) -- honest because every event here is a hull at or near
rest (the k-turn's arc-blocked case, the circle rule at <= 1.5 m/s, a face at rest). When the plan arrives: if the hull
moved > 0.5 m or yawed > 5 deg from the request pose (it was still rolling), ONE re-request from the rest pose; else the
legs start. Pending cap `PLANNER_PENDING_TICKS` (90 = 3 s): over it, the plan is abandoned as BUDGET, the seam declines for
`KTURN_RETRY_TICKS` (1 s) and today's rules run (counted: `planner_abandoned`). Re-plan EVENTS (never per tick): a leg
aborted (stall 2 s / timeout `metres x 1.5 s + 1 s`) -> re-plan from the pose with a fresh snapshot, at most 2 per order,
then decline for 1 s; a plan driven to its end -> done, the seam releases the hull (the route / the face's aligned test
take over); NO_PATH / GOAL_BLOCKED / START_BLOCKED -> decline for 1 s, counted by code (brains' re-seat and traffic's ask
are the layer that should act on them; nothing does this round, same as today's `kturn_none`). No "obstacle moved" event
this round (it could oscillate; an abort covers it). A new goal (`_goal` jump > `NEW_GOAL_JUMP`), a non-wheeled hull, a
dead tank or `Traffic.holding` release the seam's state.

**What the planner REPLACES when ON, for the hulls and events it takes:** the back-and-fill (`_best_fill`) and the circle
plan (`_circle_leg`) in `_planned_reverse`, and `plan_face`'s even/greedy legs in `face_turn`. Not replaced: the route,
the carrot, `_approach_gate` (brains'), unstick / `_pressing_escape` (manoeuvre's CP-H; they run for a hull the seam
declined or released), the creep lift (gone already). A hull in a planner plan is `in_kturn()`-like for traffic: I will
expose `PlannerSeam.live(name)` and ask traffic/manoeuvre whether `in_kturn()` should read it (today `_kturn_left_m > 0`).

**(4) Record fields native has to add to `exec_fields.h`: NONE in this design.** The seam's per-crew state (the executor,
the pending session, the request pose, the retry/pending/replan counters) lives in `PlannerSeam`'s own table keyed by the
crew's name (`PlannerSeam._crews: Dictionary`, cleared on death / release; read by key only, so determinism holds), not in
`Movement` members, so `test_native_exec_state`'s table is untouched and the C++-owned state never sees it. What native
DOES need for the ship-ON pair (C31.2): the C++ drive's `planned_reverse_cheap` (drive_native.cpp line 675) must NOT answer
from its cheap exits while the planner switch is on or a crew is live in `PlannerSeam` -- it calls back `_planned_reverse`
(already a callback) so the seam line runs; the same for whichever C++ path reaches `face_turn`. The search itself is C++
on both paths (`PlannerNative`, CP-P0), so the plan bits are the same whichever drive asked. If native prefers the state in
the record, the alternative is eight members on `Movement` (`_plan_exec` OBJECT, `_plan_session` OBJECT, `_plan_kind`
STRING, `_plan_retry` INT, `_plan_pending` INT, `_plan_replans` INT, `_plan_at` VECTOR3, `_plan_heading` VECTOR3) and their
eight rows; say which.

**Native's other ask (CP-P0):** a `native_planner` sub-switch in `BrainSwitches` (default true) so `Planner.plan` takes the
C++ search when `native and native_planner`, the GDScript search otherwise (the twin); until it exists `Planner` reads
`NativeBridge.available and BrainSwitches.native` and its own `Planner.native_on`. And `register_types.cpp` +
`CMakeLists.txt` each gain one line (`PlannerNative`, `src/planner_native.cpp`): I will make those two edits in my CP-P0
commit and name them in the merge notes; native reviews them with the rest.

### Plan (ordered, smallest foundation first)

1. **P5 / CP-P0** -- `native/src/planner_native.{h,cpp}`: `PlannerNative` (a RefCounted, its own GDREGISTER_CLASS like
   `NavNative`): the world (rectangles OR the navmesh map + bake radius; the hull boxes; the lazy float32 field with the
   GDScript's window/spill semantics and its first-read-returns-double quirk), the heuristic table (`PlannerHeuristic._build`,
   float32 nodes), the search (`Planner._search`, float32 node columns and heap, double sweeps, the same keys and
   tie-breaks), the coarse->fine retry, `trace` left in GDScript (cheap, and poses are for tests and the lab).
   `tests/test_native_planner.gd`: every `PlannerFixtures` request + the lab's four nav-world fixtures planned both ways:
   legs, code, cost, expansions, nodes, first_at, why all equal; the table bit for bit; priced (us a plan, builder0, pinned).
   Decision: the C++ takes the request as a Dictionary and the world as flat packed arrays (walls, hulls) or (map, radius);
   returns a Dictionary; `Planner.plan` is the one GDScript entry and chooses the path.
2. **P6** -- the slice: `PlannerNative.begin(req) / step(n) -> {done, ...} / result()`; the twin test plans each fixture
   sliced at 50 / 200 / 1000 a tick against the whole plan (equal by construction: the loop breaks only at the top of an
   iteration); the Sumps census of plan events a tick (GDScript counters over a 25-a-side fight); the slice chosen.
3. **P7 / CP-P1** -- the seam above once agreed, behind `--nav-off=planner`; the pair-tree check with it ON; the bar to the
   orchestrator; the judged series; the clip.
4. Stretch: the squad schedule note (handover.md already holds a first version).

### Progress log

- 2026-10-15 17:55 PDT: **MERGED: CP-P1 ON at main e175e660** (the orchestrator; native's 166f7f1e). Baselines
  re-recorded next and one main check, the orchestrator's. This stream's work for round 31 is complete; the branch
  stays as the record.
- 2026-10-15 17:50 PDT: **the SHIP CHECK is green: native's ship tree 166f7f1e** (main b352fa2a, which has CP-H,
  + f9d2c639 + the mirror + PLANNER_DEFAULT true): tests 2653 passed 0 failed on builder0, sim-baseline the only red
  target (the expected move), 0 seam-twin mismatches. Native's earlier cut 3cd68da5 had one test_native_drive
  coverage floor at 12 under the required 20 station-keeping drives; fixed test-only in 166f7f1e, nothing of mine
  changed. With the orchestrator to merge. Nothing left on this stream for round 31.
- 2026-10-15 17:35 PDT: **CP-P1 SHIPS (the orchestrator): the ship clause met on every stage, the verdict filed at
  main.** The order: CP-H's ship tree merges first with its baselines; native re-cuts CP-P1 on that main (f9d2c639 +
  the mirror + PLANNER_DEFAULT true) and its plain check is the ship check, the first with the planner and CP-H's four
  ON together; then the orchestrator merges and records the moved baselines. No rebase from me; stream/planner stays
  as it is. The round-32 hand-over is complete above: (1) SLICE as a hardware preset, (2) the §2.8 side gate and the
  `"slot"` kind (with round 31's evidence for it), (3) the gang-press queue (the data, a design, its bar, two lessons).
- 2026-10-15 17:20 PDT: **line (c) cp2 PASS, the last stage: the six MEASURE cells and the six verdict lines identical
  both arms** (`planner-judge-cp2`, builder0 heavy lane at 35f5df92; base exited 0 17:14 PDT, candidate exited 0
  17:15 PDT; `references/round31/planner/cp2-{base,candidate}-measures.txt`). **The full CP-P1 verdict is written at
  the top of The report.** Nothing running.
- 2026-10-15 17:15 PDT: **line (e) bridge PASS: 18/18 both arms, the rows bit for bit equal** (`planner-judge-bridge`,
  builder0 heavy lane at 35f5df92 = code f9d2c639; base exited 0 17:09 PDT, candidate exited 0 17:13 PDT;
  `BRIDGE_POOLED 18 of 18 runs pass` in each; every BRIDGE row (crossed, alive, rim, deck jam, arrival time) identical
  between the arms: no bridge crew is a long hull, the seam never fired, the deterministic row's equality check holds;
  rows filed `references/round31/planner/bridge-{base,candidate}-rows.txt`). Running: cp2 base (heavy,
  `planner-judge-cp2-base`, 17:13 PDT), then cp2 candidate: the last stage.
- 2026-10-15 17:10 PDT: **line (e) fights PASS** (`planner-judge-fights`, both arms on builder0's heavy lane at
  35f5df92 = code f9d2c639, base exited 0 16:47 PDT, candidate exited 0 17:05 PDT; `manoeuvre-fights` on the 24
  fresh seeds 181-204, `fight_table.py` base v candidate, filed `references/round31/planner/fights-table-35f5df92.txt`):
  kills base 1018 / candidate 1014, diff -4, se 4.5 (line 1.645 se = 7.4); deaths 1024 / 1020, -4, se 3.4 (5.6);
  hit rate 0.702 / 0.714, paired mean +0.012, se 0.009 (0.015); all within. REPORTED: hits 19277 / 19172 (-105,
  se 472), shots 27848 / 27084, touch hits 785 / 757, hit rate on touching targets 0.621 / 0.626 (+0.006, se 0.013).
  Running: bridge base (heavy, `planner-judge-bridge-base`, 17:05 PDT); then bridge candidate, cp2 x2.
- 2026-10-15 16:40 PDT: **line (d), hull-rest, both arms in (`planner-judge-hull-rest`: base at 0b2cf981 09:13 PDT,
  candidate at 35f5df92 = code f9d2c639, `exited 0` 16:12 PDT, builder0 heavy lane; 4 factions x 6 tasks x seeds
  60-65, drawn + clicked, 144 runs an arm; tables `references/round31/planner/hull-rest-tables-35f5df92.txt`, my
  reading `hull-rest-d-reading.txt`). **RULED PASS as filed (the orchestrator, 16:50 PDT): the filed form is per
  task on the wheeled-turret row, M1_CLASS's paired se, 12/12; the all-classes per-task reading and the wheels/fixed
  row are REPORTED; the harness's non-determinism (92 of 108 silent runs differ) supports the reading on the merits;
  the gang-press queue starvation is a round-32 finding, filed.**
  - *At-rest hull-error median per class x task not worse (permutation p >= 0.05):* **PASS everywhere**; the smallest
    p 0.087 (wheels/fixed faced_attack_move drawn, 3.6 v 2.7 deg), next 0.109, 0.149 (both better).
  - *Settle time paired median <= +6 s:* **PASS**: +0.0 / +2.5 / -5.0 / +0.0 / +0.0 / +0.0 s.
  - *Crews still moving at 75 s per task <= base + 1.645 se, the sized form the bar names (M1_CLASS's paired se,
    wheels/turret row):* **PASS on all 12 task x class rows of wheels/turret** (closest: faced_attack_move +8 v
    9.05, faced_support_by_fire +8 v 8.39); wheels/fixed faced_attack_move drawn +4 v 3.62 is OVER; hover/turret
    all <= 0.
  - *The same line read per TASK over all classes (n 24 paired on faction x seed):* **3 of 12 MISS**: drawn
    faced_attack_move +12 (line +9.5), drawn faced_support_by_fire +10 (+9.1), clicked faced_screen +15 (+12.6);
    the other nine pass (drawn faced_move -10, faced_right -14). **But the seam fired only in the gangs runs (36/35
    of 144); the 108 law/syndicate/condemned runs have requests 0, the candidate's code path identical to the base,
    and 92 of them still differ in their moving count: the hull-rest harness is not run-to-run deterministic
    (its screen judge), unlike the headless series (mixed 289/289 identical).** Split of the three misses, fired /
    silent: +5 / +7, +4 / +6, +2 / +13: the silent runs carry most of each.
  - *REPORTED, the seam in a gang army (the rig class):* drawn requests 784, plans 170, driven 57, aborted 24,
    **abandoned 177**, refused GOAL_BLOCKED 161 / START_BLOCKED 54 / NO_PATH 5, queue_waits 19179, pending_ticks 23402;
    clicked 1176 / 115 / 45 / 18 / **209** / GOAL_BLOCKED 145, START_BLOCKED 80, NO_PATH 25 / 26578 / 31283; holds
    pooled n 1141 median 14 max 110 ticks. Manoeuvre's face counters: face_plans drawn 893 v base 970, clicked 1867
    v 2130 (all classes). **A finding: in a 19-crew gang press the one-session queue starves (23 % / 18 % of asks
    abandoned at the 90-tick cap; the series had 2 of 459).** Not a bar line in (d); for the record and round 32.
  Running: fights base (heavy, `planner-judge-fights-base`, 16:12 PDT); then fights candidate, bridge x2, cp2 x2.
- 2026-10-15 15:20 PDT: **line (g), the clip on the final tree:** `~/projects/clips/round31/planner_terminus_f9d2c639.mp4`
  (3840 x 1080, 32 s, side by side: TODAY left, PLANNER SEAM right, the seam's last good frame held; joined with
  ffmpeg on the laptop from two `planner-lab PLANNER_ARMS=today PLANNER_FIXTURES=turnround PLANNER_SECONDS=40
  MOVIE=...` runs on builder0's light lane at 0620e36e = code f9d2c639, the after arm `PLANNER_FLAGS=--nav-off=planner`,
  both exited 0, 15:10 / 15:12 PDT). Rows: today 29.8 s, creep 821 ticks, end 2.9 m off, heading -173; the seam
  15.5 s, 3 legs, creep 0, 0 hull contacts, end 1.5 m off, heading -178: the same figures as the 03:40 clip on
  0a2a4a48. Looked at (16 s: the today rig jackknifed at the left wall, the seam rig straight, nose south; 31 s:
  both round, the today rig askew by the wall, the seam rig mid-street). Frames and rows in
  `references/round31/planner/clip/final_f9d2c639_*`. The after arm's own last frame is blank (the lab's scene gone
  before the recorder stopped), so the join holds its 17.4 s frame. Still running: the hull-rest candidate arm.
- 2026-10-15 15:10 PDT: **line (f), the price on the final tree, PINNED (`planner-census-11`, builder0 light lane
  a1d9e1fc = code f9d2c639 + the recipe's taskset, exited 0, 15:05 PDT; `PLANNER_CPUS=0-3`, box load 16.7 / 16.5 with
  native's CP-H gate and my hull-rest arm sharing it):** the seam's own face-about probe, native, warm us/expansion
  early/late medians **229/263 (seed 92721, 119 plans) and 227/186 (seed 31337, 94 plans)**; codes OK 80/33,
  GOAL_BLOCKED 28/35, START_BLOCKED 9/23, BUDGET 2/2, NO_PATH 0/1 (the same as every earlier read: the keep circle
  and the crew fix changed no probe plan); the short hull's probe 187/143. **As filed ("SLICE x the probe's WARM
  per-expansion median for the longest live hull <= 0.5 ms", warm = the LATE median): seed 92721 2 x 263 = 0.526 ms, a
  MISS by 0.026 ms at load 16.7; seed 31337 2 x 186 = 0.372 ms, PASS.** The 07:49 read on a quieter box (222/214,
  unpinned, load not quoted) sat at 0.43 ms on seed 92721, so a lighter box reads inside, but the filed form
  decides: the upper bound per R31.6 is 0.526 ms. The lever, if the orchestrator wants it, is SLICE 1 (0.263 ms) at
  roughly twice the hold per plan; nothing changed. (f) is not in the partial rule's ship clause; the orchestrator
  told 15:30 PDT. The unpinned re-read at 14:54 (`planner-census-10`, fe5f8a9e,
  load not quoted) was 253/391 and 284/210: load-inflated, not the cost line. `planner-census` now pins with
  PLANNER_CPUS and quotes the load (a1d9e1fc). Running: the hull-rest candidate arm (heavy); the clip's two arms on
  the final tree (`planner-movies-2`, light: before = today's drive, after = `--nav-off=planner`, turnround 40 s).
- 2026-10-15 15:05 PDT: **bar line (b)'s named rig cases, REPORTED (n = 1, read never judged):** `make
  planner-judge-cases` (fe5f8a9e, builder0 light lane, exited 0, 14:52 PDT; both arms, the candidate = `--nav-off=planner`
  on the GDScript drive). Logs: `references/round31/planner/cases-b/`.
  - **Seed 31 (Green_S0_2's round-30 grind):** run contact-ticks base 2143 / candidate 2687; Green_S0_2 base 1930
    (the plaza leg, steer against Floodlight_31 for 1790 ticks = the grind as filed) / candidate 2198 (the WEST
    STREET leg, planted on Container40_8 for 1987 ticks, "blocked by Green_S0_1", a squadmate wedge with NO seam event
    in that leg: the seam's two plans for it, a 2-leg face and a 1-leg face, were elsewhere and driven). The grind
    is NOT shorter under the seam: a different grind of the same length, nav's squadmate wedge (trace B's class,
    relayed to manoeuvre for CP-H). Arrivals 3/3/4/3 candidate v 3/4/2/4 base (13 v 13 of 16).
  - **Seed 51 (Green_S0_3's grind under the lift):** run contact-ticks base 374 / candidate 347; Green_S0_3 267 /
    244; the base arrives every leg (16/16), the candidate 15/16: Green_S0_3 on the far ring road "arrived, order
    complete, not touching" 9.6 m from the slot with NO seam event in that leg (its seam plans, a 2-leg face in the
    west street and a 10-leg k-turn in the plaza, were driven in earlier legs). Not a plan carrying the rig off.
  - **The squadmate pin (seed 9, both arms):** base pinned unit-ticks 491 (16.4 s; 8 pins, the longest 3.7 s:
    round 30's 61.4 s pin is not in today's base, as the bar foresaw) / candidate 30 (1.0 s, one pin). Freed, no
    backoff-and-re-pin loop.
  - The rig 180 (deterministic): `test_wheeled_arrival`'s rig case green on the gate 85911f0b. The six-cusp car: a
    short hull, the seam's `in_scope` test; the series' mixed line identical both arms (289/289) is the leak check.
  Running: the hull-rest candidate arm (heavy, `planner-judge-hull-cand`), the price on the final tree (light,
  `planner-census-10`, fe5f8a9e, line (f) re-read for the record).
- 2026-10-15 14:50 PDT: **THE SECOND JUDGED SERIES PASSES BAR LINE (a).** `make planner-series-fresh exited 0`,
  builder0, 14:45 PDT, series tree 35f5df92 (code f9d2c639), gate 85911f0b, Terminus seeds 172-184, n 13, every
  seed to completion, read once on the fixed line (R31.8). **Rigs arrivals: base 180, candidate 172 of 208, paired
  mean -0.615 se 0.500, pass line -0.823 -> PASS** (per seed 172 -1, 173 +1, 174 -1, 175 +2, 176 -1, 177 0, 178 +2,
  179 -2, 180 -3, 181 -3, 182 -3, 183 0, 184 +1). Mixed: 289/289 of 312, identical both arms (seam silent 13/13).
  Rigs contact-ticks (REPORTED): median base 855, candidate 533; paired mean -282.2 se 211.2; worst base seed 180
  (2561), worst candidate seed 182 (2141); per seed base/candidate 172 119/1014, 173 2083/471, 174 406/264, 175
  424/393, 176 682/848, 177 221/302, 178 2410/1931, 179 855/297, 180 2561/2020, 181 555/533, 182 1860/2141, 183
  2191/296, 184 1793/1982. Seam totals (13 rig runs): requests 459, plans 137, driven 106, aborted 5, abandoned 2,
  rerequested 0, refused GOAL_BLOCKED 203 / START_BLOCKED 83 / NO_PATH 23, queue_waits 486, pending per rig event
  pooled n 448 median 11 max 104 ticks, pending_ticks 6573. Series 1 (diagnosis seeds 133-145, before the keep
  circle) read -1.462 se 0.595 MISS. Saved: `references/round31/planner/series2-fresh/`. Next on the heavy lane:
  hull-rest candidate (unit planner-judge-hull-cand, launched 14:50), then fights x2, bridge x2, cp2 x2.
- 2026-10-15 14:35 PDT: **the 85911f0b gate landed; the FRESH SERIES is running (unit planner-series-2, launched
  14:31 PDT, tree 35f5df92 = code f9d2c639 + Status).** Native's gate line (builder0): tests 2652 passed / 0 failed;
  `>> remote: make check exited 2` on "check: 24 passed, 2 FAILED, 0 NOT RUN": sim-baseline MOVED on 6 of 13 maps
  (foundry, pit, crossing, sumps, gorge, archipelago; the expected ON move, adoption the orchestrator's call) and
  remote-guard-test (box-state: slot-light's quiet-window asserts while godot-nav ran; R31.10 non-blocking). NOT
  JUDGED: the 3 TIMING lines. Seam twin 900/344/0; the army_layout10 red gone. Read as the re-gate green on the
  tests; the orchestrator told (they may rule the two targets block). R31.9 noted: iterate on the light lane
  (`make quick-remote` / filtered tests), the full check only for a named hash; CP-P1's gate stays native's plain
  check. Result: `$S/remote-series-2.log`, `build/planner-series/verdict.txt` on builder0; rows name gate 85911f0b.
- 2026-10-15 12:45 PDT: **native's RE-CUT: pair/cpp1-on = 85911f0b** (main a2ef0b31 + f9d2c639 + the mirror
  dc9ac341/7f46591f + their seam_live fix 14f4de82 + PLANNER_DEFAULT true; 3a66f546 kept as pair/cpp1-on-3a66).
  Their review of f9d2c639 found the C++ `seam_live` (the unstick gate and the planned-reverse block) read only
  `_crews.has(name)`: on a reused name it would have held where live() now releases; fixed on the pair (a null,
  freed or queued hull calls back PlannerSeam.live, so the release is mine) with a twin case (a crew injected
  under the rig's name, its hull queued for deletion: unstick's command, the movers and the seam world equal).
  builder0 light lane on 85911f0b: native_planner|planner_seam|planner_keep exited 0, 15 passed / 0 failed; seam
  twin 344/900 held, 0 mismatches; my two-match test passes. The plain check (the gate) is unit native-chain9,
  right after the CP-H gate 130a069b. On its green line: `$S/planner-series-2.sh`; rows name gate 85911f0b.
- 2026-10-15 12:25 PDT: **the seam fix is GREEN at f9d2c639; native asked to re-cut and re-gate.** builder0 light
  lane, `make native test FILTER=planner exited 0`, 33 passed / 0 failed, 12:19 PDT. 216c7c43 read 32/1: the new
  test's own two asserts (it called `live()` inside the physics tick the sweep had already run in, and the
  once-a-tick guard skipped the freed crew); `live()` now reads its own crew's hull and releases a freed one
  (f9d2c639). The gate's path (the second match's rig under the same name held in its turn, no engine error) was
  clean at 216c7c43 already. Next: native's pair hash + gate line, then `$S/planner-series-2.sh` on its green.
- 2026-10-15 12:20 PDT: **the 3a66f546 gate was RED on a real seam bug of mine; fixed at 216c7c43, tests running.**
  Native's line (builder0, 12:05 PDT): `make check exited 2`, 2646 passed / 1 failed; 22 passed, 2 FAILED (test,
  sim-baseline MOVED on 6 maps = expected ON), 2 NOT JUDGED (perf-judge refused 3x on a busy box; scenario_perf
  unpinned); every test_native_* green (seam twin 900 drives, 344 held, 0 mismatches). The red:
  test_tactics_army_layout10 (four arenas built and disposed in ONE test, the same hull names in each) logged 8
  engine errors, "previously freed" at PlannerExecutor.tick:135 and `throttle` on Nil at planner_seam.gd:411.
  Cause: `PlannerSeam._crews` is keyed by hull NAME; a crew held at `lab.dispose()` outlived its freed hull and the
  next arena's hull under that name (same kind, fresh tick, goal within NEW_GOAL_JUMP) drove the dead executor.
  Fix (216c7c43, the seam only): `Crew.tank` names the hull instance at the request; `_serve` releases a crew whose
  `tank` is not the asking hull; `_sweep(tick)` (once per physics tick from `_serve` and `live()`) releases every
  crew whose hull is freed or queued for deletion, so a dead head never holds the queue and `live` counts hulls
  that exist. Test `test_a_crew_never_outlives_its_hull` (tests/test_planner_seam.gd): a rig held, its match
  disposed, a second match's rig under the same name held in its turn, the crew naming the second hull. Running:
  `$S/planner-test29.sh` (light lane, `native test FILTER=planner`); on green, native re-cuts and re-gates, then
  the fresh series. The orchestrator: no lane release needed (this stream's own heavy slot; CP-H runs in
  manoeuvre's); R31.8 early stop OFF on guard lines: the series recipe never had one (every seed to completion,
  one read on the fixed 1.645 se line).
- 2026-10-15 10:00 PDT: **native approved the C++ keep branch and RE-CUT the gate: pair/cpp1-on = 3a66f546** (main
  1fc72e66 + 38e9678d + the mirror + PLANNER_DEFAULT true; 8bb2ad4e kept as pair/cpp1-on-8bb2). Their read: the end
  rule before the tol test binds the aim branch too; the sweep's break after the horizon test; all doubles squared
  against squared; KEEP_NONE 1e29 v the GDScript's `< INF` differ only for a finite radius >= 1e29 (never bound);
  the seam's slot-law inputs are GDScript-only and wheeled faces hand back to GDScript, so the drive mirror needs
  nothing. Their light pre-run (native_planner|planner_seam|planner_keep) is going; the plain check queues as
  native-chain7 behind CP-H's 68280cce and T4's fafe49ea. On its green line: `make planner-series-fresh`
  (f142f241: seeds 172-184; `$S/planner-series-2.sh`, heavy lane when the orchestrator frees it from CP-H), then
  hull-rest candidate, fights x2, bridge x2, cp2 x2 as filed; rows name gate 3a66f546 + the series tree.
- 2026-10-15 09:55 PDT: **THE KEEP CIRCLE IS IN AND GREEN; native has the re-cut hash 38e9678d.** The orchestrator
  ACCEPTED the declared fix as written (the keep circle carrying manoeuvre's slot law, nothing else) and sent the law
  bit for bit: (a) the slot counts only under `face_slot_on()` and within FACE_SLOT_REACH (2.0) x settle; (b) the end
  no further than the start + FACE_SLOT_SLACK_M (0.5); (c) the inner radius max(max(ORDER_ARRIVE 3.5, settle) -
  FACE_KEEP_MARGIN_M 0.75, from here) only under turnhull (OFF on main: the series tree applies (a)+(b)); read from
  Manoeuvre's own names, never copied values. Coded (1bec314d, 38e9678d): `PlanRequest.keep(x, z, all_m, end_m)`
  (INF = no circle, `to_native` keep_x/keep_z/keep_all_m/keep_end_m); planner.gd's sweep breaks on a pose outside
  all_m (after the horizon test), `_at_goal` refuses an end outside end_m (before the tol test, so the aim branch is
  bound too); the C++ mirror the same two checks (KEEP_NONE 1e29: the GDScript's INF arrives as inf); the seam's
  face request sets the circle only when the slot is in reach. New `tests/test_planner_keep.gd` on seed 134's plaza
  geometry (rig at (-7.2,20.3) heading 82, slot (-2.7,19.6) 4.55 m off, an 18-degree face) and two twin rows.
  **builder0 light lane, 38e9678d: `make native test FILTER=planner exited 0`, 32 passed 0 failed (09:53 PDT).**
  The rows: free plan "R+1.0x2.0 F+1.0x2.5" ends 4.17 m from the slot, worst pose 6.55 (the test world holds no
  squadmates, so the game's one 3.5 m chord to 7.4 m did not reproduce there -- the re-run series is the proof);
  kept at the law's 5.05 m: the same plan; a circle at 3.67 m (tighter than the free end) changes it to "F+1.0x2.5"
  ending 2.09 m, 32 expansions = the end rule binds; turnhull's inner radius 5.25: "F+1.0x2.5", worst pose 4.55, 8
  expansions. Twin rows equal both ways (end rule 3 expansions / 92 nodes, native 4.5 ms; inner radius 8 / 64,
  1.0 ms). Next: native reviews the C++ keep branch, re-cuts and re-gates (the plain check); then the series on
  FRESH seeds 172-184 (133-145 are the diagnosis set), the other stages as filed; the heavy lane is CP-H's.
  Trace B (the rig pressed into a squadmate for 65 s with no seam event) is relayed to manoeuvre for CP-H.
- 2026-10-15 09:50 PDT: **THE DECLARED FIX (the orchestrator's ruling on the first judged series: diagnose 133/134/138/140,
  declare before any new number).** The series (builder0 0fcdd5dd = code 05ce260b, gate 8bb2ad4e, `make planner-series
  exited 0`, 09:27): rigs arrivals base 178 candidate 159 of 208, paired -1.462/seed se 0.595 = MISS of (a); mixed
  identical (the seam silent 13/13). Per seed: 133 -4, 134 -5, 135 +2, 136 +1, 137 +1, 138 -4, 139 -2, 140 -3,
  141 -1, 142 -1, 143 0, 144 -1, 145 -2. The MISS CLASSES over the 13 rig runs (`references/round31/planner/
  series1-diagnosis/misses-by-arm.txt`): "arrived, order complete, not touching" base 13 -> candidate 24 (+ 4 touching);
  "blocked by a squadmate, touching" 13 -> 17. **Of the candidate's 28 arrived-short misses, 13 sit at gaps 7.0-8.5 m
  (base 1) and 8 more at 8.5-11 m (base 3): the whole -19 is hulls that ARRIVED and were then carried just past
  the census's ARRIVED_M 7.0 line**, at the same slots seed after seed (plaza (-3,19.6) in 133/134/138/143/144,
  (10.9,5) in 134/138/141/144, west street (-69,21) in 135/141/143/145).
  **Trace A (`planner-trace-drive`, light lane 9fe29f54, seed 134 Green_S0_4, plaza leg):** t 19.5 s arrived
  4.5 m from its slot (phase arrived, the order complete); t 19.5 the seam's FACE plan "R+1.0x3.5" (1 leg, 5
  expansions) reversed it 3.4 m on full lock to (-10.1,20.2): 7.4 m from the slot, where it sat to the leg's end =
  a miss. **The cause:** the seam's face request carries manoeuvre's `stay` (settle - 1 = 5 m round where the hull
  stands) but NOT manoeuvre's slot law -- round 30 M1b (a face plan may not END further from the last move's slot
  (`ctl.face_slot`, within 2 x settle) than it starts + FACE_SLOT_SLACK_M 0.5) and round 31 M1b(2) under turnhull
  (EVERY pose within max(ORDER_ARRIVE 3.5, settle) - FACE_KEEP_MARGIN_M 0.75 of the slot, or no further out than it
  starts). Base's `plan_face` obeys both, so its hulls face inside the arrive circle; the seam's planner is free to
  end anywhere in its 5 m stay circle, and a rig's one-leg face is a 3.5 m chord outward.
  **THE FIX (declared, nothing else changes):** `PlanRequest.keep(x, z, all_m, end_m)` -- a KEEP circle: every pose
  the search expands lies within `all_m` of the slot and the goal pose within `end_m`; both planners (GDScript +
  C++ mirror, the twin fixture), and the seam's FACE request sets it exactly as manoeuvre does: slot =
  `ctl.face_slot` when within FACE_SLOT_REACH x settle, `end_m` = dist(here, slot) + 0.5, `all_m` = max(max(3.5,
  settle) - 0.75, dist(here, slot)) under `turn_hull_on()` else unbounded; no slot in reach = no circle (as today).
  The k-turn request, PENDING/RETRY, the hold: unchanged.
  **Trace B (seed 134 Green_S0_3, ring road, the -1 "blocked by Green_S0_1" at 23.8 m):** the seam's one k-turn
  ("R+1.0x9.5", t 6-10 s) was driven to its end and released; the route then drove the rig into Green_S0_1 at
  t 25 s and it sat pressed at full throttle (plant speed 10 m/s, no motion) for 65 s with NO seam event in the
  rest of the leg (the per-event report lines: none between t 26 s of leg 0 and leg 2). That class (13 base, 17
  candidate) is nav's wedge on a squadmate, in both arms; the seam changed when the rig reached the corner, not
  the wedge. **The hold hypothesis, answered from the numbers:** pending 7226 hull-ticks over 13 runs = 2.3 s per
  hull per run; refusals (GOAL_BLOCKED 174 / START_BLOCKED 121) decline for 1 s and the mover drives on; neither
  appears in the two traces as a mechanism of a miss. Leg-seconds 2041 -> 2283 (+12 %) are the 90 s timeouts of
  the misses above. **Verification before the re-cut:** a seam test on trace A's geometry (a rig 4.5 m from its
  slot, a 180-degree face: no pose of the plan outside 6.5 m of the slot), the twin fixture, `test FILTER=planner`
  on the light lane, the trace test's wedged row (a kept face that cannot be planned hands back = the give-up
  still reached). Then native re-cuts and re-gates; the series on FRESH seeds 172-184 as ruled.
- 2026-10-15 09:15 PDT: **the hull-rest judge's BASE arm is in** (`planner-judge-hull-base`, builder0 heavy lane,
  tree 0b2cf981, `exited 0`, wrapper exit 0 at 09:13): both base arms (drawn + clicked) on seeds 60-65, tables under
  `build/manoeuvre/hull-rest/` (M1_REST at-rest share per task 69-96 %, the A/B columns empty until the candidate
  arm lands beside it on builder0; the sync excludes `build/`, so the base arm's rows stay there). The heavy lane
  idle and native's gate line not a lead gate: **the judged series launched** (`planner-series`, 09:14 PDT, tree
  0fcdd5dd = code 05ce260b; the reader prints PLANNER_SERIES_SQUAD / _SEAM / _SEAM_TOTAL, verdict in
  `build/planner-series/verdict.txt`). Next on the lane, in order: hull-rest candidate, fights x2, bridge x2, cp2 x2.
- 2026-10-15 07:49 PDT: **the price on the final tree** (`planner-census9`, builder0 light lane 0b2cf981 = code
  05ce260b, unpinned on the busy box, exited 0): the seam's own face-about probe on the Sumps navmesh, native, warm
  us/expansion early/late medians **222/214 (seed 92721, 119 plans) and 159/183 (seed 31337, 94 plans)**; the short
  hull's probe 169/114; codes OK 80/33, GOAL_BLOCKED 28/35, START_BLOCKED 9/23, BUDGET 2/2, NO_PATH 0/1 -- the same
  numbers as the cache commits (170-390), so the aim goal and its estimate changed no price, STEERS is three locks,
  and SLICE 2 stays inside ~0.45 ms a tick per crew (R31.6's bound). Native's light pre-run on 8bb2ad4e: 11/0, the
  twin held the rig on 344 of 900 compared drives, 0 mismatches, one 2-leg plan driven to its end. Running: the
  hull-rest judge's BASE arm on the heavy lane (`planner-judge-hull-base`, tree 0b2cf981; base = planner OFF, so it
  owes the gate nothing), the gate's plain check third in native's chain.
- 2026-10-15 07:44 PDT: **the outcome assertions ON are green** (`planner-test26`, builder0 edb773cf, 4 passed 0 failed,
  exited 0): k-turn ON 2 segments / 0 contacts / 7.0 s; wedged ON at nav's 8 s window yaw 9.0 deg, 0.67 m over (bar
  1.8), give-up reached. **Native re-cut CP-P1's gate as 8bb2ad4e** (pair/cpp1-on = main 83341378 + edb773cf merged
  clean + the mirror + PLANNER_DEFAULT true; nothing needed in the mirror); its plain check is third in native's
  heavy chain (~2.5 h). 05ce260b: `last_plans` captured/restored (native's note; measurement only, after the re-cut,
  so the series tree is 05ce260b+ and the gate 8bb2ad4e -- rows name both). While the gate queues: the census price
  on the final tree (`planner-census9`, light lane).
- 2026-10-15 07:41 PDT: **THE K-TURN ROW MET on manoeuvre's scene** (`planner-test25`, builder0 1f325b91, 30 passed 0
  failed): seam ON = arrived 7.0 s, 0 wall contacts, nose clearance 2.20 m, TWO real gear segments (R 4.0 m ticks 3-54,
  F 29.6 m ticks 57-209), 1 request, 1 plan "R4 F18" at lock driven to its end, held 2 ticks; base = 2 segments (R4.5
  F29.8), 5.6 s, 0 contacts, 1.64 m. The one cost: 1.4 s (the reverse at 0.7 throttle, the brake to rest at the
  cusp), REPORTED. Outcome assertions ON added to the trace file (edb773cf: k-turn arrives, <= 3 segments, contacts
  <= the base's 0; wedged at nav's 8 s window: footprint <= 1.8 m over, yaw < 20, the give-up reached). **Re-cut hash
  for native: edb773cf** (code 1f325b91; the C++ planner changed: `aim` in Request, `at_goal`'s aim branch +
  `straight_clear`, `heuristic`'s aim branch). Sent to the orchestrator and native ~07:50.
- 2026-10-15 ~08:00 PDT: **half lock measured and REVERTED** (0b5a6d3d -> b0bdbd89; `planner-test22` exited 2, 07:25):
  manoeuvre's scene unchanged (the identical "R3 F2 R12.5", 9 expansions, 4 real segments) and three named fixtures
  broke (packed-line rigs 1-2 BUDGET at 800 -- the fixtures test FAILED; the lab turnround 3 -> 5 legs; packed rig 0 a
  78 m loop). The real cause: with an aim goal the HEURISTIC still priced the goal POINT 24 m off (distance + the
  table's pose cost), so the anytime bound stopped at 9 expansions behind the 10.8 s wiggle. **5ffda2b4: an aim
  request's estimate owes only the heading change to point at the goal (R per radian) plus its cusps in the start's
  room** (both planners). Result (`planner-test23`, 30/0, 07:32): the plan is **2 legs "R4 F18" at lock, 6.8 s, 5
  expansions**, the twin equal, every fixture back on its bar (packed lines 4 legs, turnround 7 expansions as in the
  price run). Real motion STILL 4 segments (R3.3 F2.5 R2.1 F28.1): the plan was RELEASED 4 m into leg 1 -- the
  release trace (5c677280, `planner-test24`): "new goal; goal moved 3.7 m" = the route's steering CARROT slid along
  the path as the hull moved; the order's goal never moved. **1f325b91: a k-turn crew's new-goal release judges
  `Movement._goal` (the order's goal), not the carrot.** Running: `test FILTER=planner` (`planner-test25`).
- 2026-10-15 ~07:45 PDT: **the aim goal's result** (`planner-test19/20`, builder0 9d168af8, 30/0, 07:12 PDT): the k-turn
  plan is 3 legs "R3 F2 R12.5" (2 cusps, 17.5 m, 9 expansions; the first cut f66fddfb still appended a 23.5 m straight
  because the arrive gear bound the aim too -- 9d168af8 binds it to the position goal only); the twin plans it the
  same in C++; every named fixture holds (F6a 9, T-junction 2, mouth 1, yard corner 2, slot180 4, wedge 4). But the
  hull's REAL motion in manoeuvre's scene is still 4 gear segments (R3.0 F1.4 R1.6 F29, 7.1 s, 0 contacts; base R4.5
  F29.8, 5.6 s): the wiggle sits at the START. The street's geometry under three locks: a 14 m hull in the 22 m street
  can reverse at full lock ~46 deg before its tail corner meets the back wall's margin, pointing at the waypoint needs
  ~65-70 deg, and a forward leg at FULL lock from a 26 deg reverse dips the nose under the margin at the block face.
  The base's own trajectory (`planner-test21`): R4.5 to (40.8, 33.4) at -22 deg, then a forward arc of radius ~13 m
  swinging 75 deg over 17 m, first within 15 deg of the goal at t138 (25.3, 25.5) -- a GENTLER arc than full lock.
  **The orchestrator's ruling: half lock** (STEERS -1 -0.5 0 0.5 1 in the search, its heuristic table and the C++
  twin: 0b5a6d3d; the plant's yaw is linear in `turn`, so a half-lock leg is a double-radius arc), re-read every named
  fixture, price the branching on the census; NOT an aim tolerance fitted to this street. Time-box: the k-turn row
  (<= 3 real gear segments, contacts <= base) met on manoeuvre's scene by 12:00 PDT, else CP-P1 parks with its traces
  and CP-P0 + the OFF seam stay on main. Running: `native test FILTER=planner` on 0b5a6d3d (`planner-test22`).
- 2026-10-15 ~07:30 PDT: **the k-turn's lever read off the sweep** (`planner-test18`, builder0 d8c2e742, 06:55 PDT,
  exit 0): every variant of the seam's own request (the clipped v the order's point, arrival 1/2.5 m, heading
  free/30/8 deg, cusp cost x1/x2/x4, any arrive gear, a 12 m goal) begins with the same "R3 F2 R12" wiggle, 4-5 legs,
  3 cusps -- so tolerance, cost and gear are NOT the lever. The cause is the goal itself: standing on a 1 m point 24 m
  off needs ~2 deg of heading from a lattice of three locks and twelve leg lengths (the lattice dedupes poses at 15
  deg bins, so the search composes R3-F2+R12 to land the exact heading a straight final leg needs), where today's
  k-turn reverses 4.5 m and lets the pursuit law correct. **f66fddfb, the ONE thing changed: the k-turn's goal AIMS**
  (`PlanRequest.aim`, mirrored in `planner_native.cpp`): a pose pointing at the waypoint within `KTURN_AIM_DEG` 15
  with the straight run to it clear by the margin counts as the goal; the route drives from there. Face requests are
  untouched (the fixtures turnround/T-junction/mouth/slot180/yard corner/F6a are face/arrival requests). The twin
  gets an aim fixture (the War Rig nose-on scene on the Terminus navmesh); the sweep's aim rows print its legs. The
  wedged semi after the two hand-backs (same run, ON over 20 s): the plan touched the slab at 1.7 s and handed back,
  the give-up fired at 4.6 s (base 4.5 s); at the test's 8 s: yaw 9.0 deg, footprint over by 0.67 m (bar 1.8), path
  7.6 m -- manoeuvre's outcome (b) met at the test's window; over 20 s BOTH arms grind past the bar (ON 47.6 deg /
  7.78 m, OFF 26.2 deg / 4.35 m): the base keeps shuffling after its give-up, the ON arm from 2 m nearer the end cap.
  Running now: `native test FILTER=planner` on the light lane (`planner-test19`, the lib rebuilt).
- 2026-10-15 06:37-07:00 PDT: **CP-P1's gate on aa0615e4 RED** (native's pair/cpp1-on, builder0: `make check exited 2`,
  2634 passed 6 failed; the mirror clean, 87/87 test_native_*, the seam twin 195 held drives 0 mismatches). The 6:
  (a) 4 in `test_planner_seam` -- the test assumed default OFF with `--nav-off=planner` the opt-in; on the ON tree
  that flag turns the planner OFF. **Fixed 032af15f**: `_with_switch` lists the switch only when the asked state
  differs from `PLANNER_DEFAULT` and asserts `on()` equals the ask. (b) manoeuvre's `test_kturn_three_point` (War Rig
  nose-on: 4 legs, 7.2 s, where today drives 2 legs in 5.6 s) and nav's `test_nav_face_recovery` wedged semi (the
  give-up never reached in 8 s): both the seam taking the rig. The orchestrator's ruling (manoeuvre's outcomes):
  both FINDINGS, fixed before the series, re-gated on a re-cut. **Traces** (`tests/test_planner_trace_manoeuvre.gd`,
  the two scenes copied, run ON and OFF, builder0 032af15f 29/0): k-turn ON = real motion R3.0 F1.4 R1.6 F29.0 (4
  gear segments) from plan "R3 F2 R12 F31.5" to the seam's horizon-clipped point (24 m along, FREE heading, 1 m
  arrival) -- the 4 is the lattice hitting a 1 m circle from a nose-on start, not a hold counted as a leg; OFF = R4.5
  F29.8. Wedged ON over 20 s = 3 plans through the unbaked slabs, 3 stall aborts (5.0/8.1/9.3 s), give-up checked
  first at 14.2 s, footprint over by 1.93 m (bar 1.8); OFF = give-up at 4.5 s, then the base grinds on to 26 deg /
  4.35 m over by 20 s. **Fixes**: 1e513bcf a face hands back on its FIRST abort; d8c2e742 a face plan hands back on
  its first WALL TOUCH (`mover.contact.touching`); the k-turn lever is read off a sweep of the seam's own request
  (`tests/test_planner_kturn_sweep.gd`: goal, tolerances, cusp cost, arrive gear) running now (`planner-test18`).
  Wrecks are NOT a blind spot: `Tank._set_alive(false)` disables the wreck's collision, so skipping dead hulls in
  `PlannerNavWorld` is right; unbaked scenery (the test's own corridor) is the one the abort catches.
- 2026-10-15 ~06:10 PDT: **86e5c646 MERGED OFF to main** (the orchestrator, on its exited-0 line). **33d5a158: the
  orchestrator's reported line** -- the hold per rig event (ask tick to the plan's, refusal's or abandon's tick, zero/zero
  throughout) now travels in the PLANNER_SEAM_REPORT line as the per-event list `hold_ticks`, and series_verdict.py
  pools every event in the arm: `pending per rig event (candidate, pooled) n/median/max ticks` per squad and in
  PLANNER_SERIES_SEAM_TOTAL. Measurement only; the base arm's seam never fires (the reader refuses if it does).
  All five judged recipes dry-run on the laptop: each arm's flags reach the runner's command line (cp2's
  AI_SCEN_FLAGS forwarding verified). `test FILTER=planner` on the light lane (`planner-test16`): **25 passed 0 failed, exited 0** (builder0, 33d5a158,
  06:01 PDT; `hold_ticks` lists in the report lines); the series launch
  script is ready (`planner-series.sh`, heavy lane), fired on native's aa0615e4 exited line (still running at 05:56).
- 2026-10-15 05:54 PDT (wrapper exit): **the rebased tip's full check GREEN** (`planner-check8`, builder0, commit
  86e5c646): `>> remote: make check exited 0`, 2638 passed 0 failed, `24 passed, 2 NOT JUDGED` (CP-P0's same two:
  perf-judge refused 3x at 2.31-2.35x, scenario_perf's cpu budget unpinned), sim-baseline 13/13 unmoved, determinism
  2875411ff4ec6be7. Sent to the orchestrator and native. The judged chain now waits on ONE line: native's pair/cpp1-on
  check at the gate hash aa0615e4 (native-chain4); on it, `make remote T=planner-series` (line a), then the (c)-(e)
  wrappers one heavy job at a time, each row naming aa0615e4 and the series tree hash.
- 2026-10-14 ~22:30 PDT: oriented (CLAUDE.md, HANDOFF round 31/30, orchestration's worker contract + lessons 306-311,
  orientation, workstreams Round 31, the brief, round 30's planner report / handover / design, native.md's hazards and
  flags, the GDScript planner (six files), the k-turn block and face executor in movement.gd, drive_native's callback
  layer, exec_fields.h, native.mk / CMakeLists / build.sh, remote_builds). Local toolchain present (cmake, ccache g++,
  godot-cpp 10.0.0 source in .tools); builder0 reachable (load 0.08). The draft seam written (above) at the orchestrator's
  ask; starting P5.
- 2026-10-14 ~23:05 PDT: **P5 coded**: `native/src/planner_native.{h,cpp}` (1 000 lines: the world with the lazy
  float32 field and its first-read-double quirk, the OBB test in real_t, the navmesh wall distance, the free-space table,
  the search as a resumable session with `begin / step(n) / result / cancel`, `plan` = begin + step(all)), `Planner.plan`
  takes it when `native_usable()`, `PlanRequest.to_native()`, `PlannerWorld.native_view()`; `tests/test_native_planner.gd`
  (17 offline + 4 lab fixtures both ways: legs, code, cost, expansions, nodes, why, end pose, the lazy field's cells; the
  table bit for bit; the slice at 50/200/1000); `make planner-twin` (pinned) and `make planner-census` (P6's census +
  an in-fight plan probe). Laptop PRE-CHECK only (unpinned, killed by its 900 s cap in the yard build): 17/17 offline and
  3/3 Terminus lab fixtures EQUAL on every observable; native 47-300x the GDScript offline, 6-37x on the navmesh fixtures
  (the field's `map_get_closest_point` reads dominate there: NavNative's index is the next speed-up if the cost line
  needs it). Committed as 7c286000; sent to native (reviewed: APPROVED, notes 1-4; note 1 = one shared C++ session, taken:
  static table cache, the seam's own session instance, `plan()` refuses on a live session, `step(n<1)` clamps, `cancel()`).
- 2026-10-15 ~04:40 PDT: **native's seam twin GREEN on aa0615e4** (light lane, exited 0, 2/0): 900 drives + 900 unsticks
  compared, the seam held the rig on 195, 0 mismatches on the live members and the owned state; the seam's own report
  there: requests 2, plans 1 (5 legs), driving 138 ticks, pending 59, holds median 52, one GOAL_BLOCKED; FILE_TIME
  64 s. Native keeps the move_to (not the face) on purpose: a wheeled FACE hands back to the GDScript execute, so only
  the move_to puts the C++ drive against a held crew. The gate's plain check is first in native's heavy chain.
- 2026-10-15 ~04:30 PDT: **CP-P1's gate hash is native's pair/cpp1-on aa0615e4** (stream/native's mirror + the seam
  86e5c646 + PLANNER_DEFAULT true + native's new test_native_planner_seam: a War Rig in the west street, drive + unstick
  twinned every tick through capture()/restore(), held >= 30 compared drives; it replaces ef38361f, which never got a
  slot; the earlier light twin on 0914dafd + the mirror: 90/0, 0 mismatches). Its plain check runs first in native's
  chain (native-chain4); its exited line clears the series. Told native the proven take is the FACE order (the seam
  test's rig: taken 4 ticks after the order), and the two k-turn takes' conditions (a point straight behind is never
  inside the circle; the blocked arc needs the wall within KTURN_HIT_WITHIN_M).
- 2026-10-15 ~04:15 PDT: **the judged chain's wrappers** (29930949, mk/planner.mk): `planner-judge-hull-rest`,
  `planner-judge-fights`, `planner-judge-bridge`, `planner-judge-cp2`, each `PLANNER_JUDGE_ARM=base|candidate` (one arm a
  call, lesson 311), both arms `--brains-off=native_drive` with the C++ planner on, the candidate + `--nav-off=planner`;
  hull-rest on the fresh seeds 60-65 (M1_NEW_OFF=planner, M1_BASE_OFF empty, `--turn-states`), fights on 181-204 (then
  fight_table.py base v candidate), bridge-pooled and scenario_cp2 through BRIDGE_FLAGS / AI_SCEN_FLAGS. The chain
  (after both gates): planner-series (a), then (d) x2, (e) fights x2 + bridge x2, (c) cp2 x2, each heavy, one at a time.
- 2026-10-15 ~04:05 PDT: **the series tooling PROVEN** (`make remote LIGHT=1 T="planner-series PLANNER_SERIES_SEEDS=1
  PLANNER_SERIES_SQUADS=rigs NAV_JOBS=1"` on 2f7e9442, exited 0; the first try refused on a stale light-lane library
  after the rebase, so the target builds native first now). Seed 1 is a USED tuning seed at n = 1: a tooling proof,
  never a number for the bar. What it printed, for the shape only: rigs contact-ticks 2176 -> 393, arrivals 13 -> 12
  of 16; the seam asked 30 times, planned 7 (11 legs), drove 3 to their end, refused 14 (GOAL_BLOCKED 11,
  START_BLOCKED 3), abandoned 1, queue_waits 109, holds median 20 / max 90 ticks, pending 488 hull-ticks; 4 plans
  released before their end without an abort (the caller stopped asking: STALE_TICKS -- a reported detail to read in
  the judged traces). The base arm's seam never fired (the reader's equality check).
- 2026-10-15 ~03:55 PDT: **CP-P0 MERGED OFF to main** (950c7681 on 41212da0's exited-0 line; HANDOFF 84e553cd; the one
  conflict OFF_NAMES resolved as the sorted union; the seven seam lines intact). **stream/planner rebased onto main
  84e553cd** (33 commits, clean) + **86e5c646: `mover.yield_to_plan()` wired** at the seam's first-take site (R31.2 (H);
  manoeuvre's, main 298e4498; no shim). The pre-rebase check (c1b15323) withdrawn before it ran a target; the rebased
  tip's full check queued (`planner-check8`, behind three worktrees' slots). Native rebases pair/cpp1 onto main +
  86e5c646 for the gate hash. The series tooling's dry run (seed 1, rigs, light lane, `planner-seriesdry`) proves
  series_verdict.py before the judged run.
- 2026-10-15 ~03:45 PDT: **CP-P0's check GREEN:** `make remote T=check` on 41212da0 (a3755e37's code + docs), builder0:
  `>> remote: make check exited 0`, 2615 passed 0 failed, `24 passed, 2 NOT JUDGED` (both the busy box's perf lines:
  perf-judge refused 3x at 2.3-2.7x, scenario_perf's cpu budget unpinned); sim-baseline 53/0, every map unmoved;
  scenarios 52/0. **The series tooling** (ad2e02f1 after the rebase): `make planner-series` (nav-terminus-drive over
  the bar's fresh seeds 133-145 x mixed/rigs in two arms, base `--brains-off=native_drive` v candidate +
  `--nav-off=planner`) and `tests/planner/series_verdict.py` (paired arrivals v 1.645 se per squad, contact-ticks
  reported with the worst run, the seam's last PLANNER_SEAM_REPORT per run and the totals; refuses a base arm whose
  seam fired).
- 2026-10-15 ~03:40 PDT: **the clip for him rendered:** `~/projects/clips/round31/planner_terminus_0a2a4a48.mp4` (3840 x
  1080, 32 s, side by side: TODAY left -- 29.8 s, 53 gear changes, 14 wall contacts; PLANNER SEAM right -- 15.5 s, 3 legs,
  0 contacts, its last frame held once done), from two `planner-lab PLANNER_ARMS=today PLANNER_FIXTURES=turnround
  PLANNER_SECONDS=40 MOVIE=...` runs on builder0's light lane (the after arm `PLANNER_FLAGS=--nav-off=planner`), joined
  with ffmpeg on the laptop; looked at (16 s: the today rig jackknifed against the left wall, the seam's straight nose
  south). The orchestrator's HANDOFF *To show him* line.
- 2026-10-15 ~03:35 PDT: **the planner test files GREEN on 0a2a4a48** (`make remote LIGHT=1 T="test FILTER=planner"`
  exited 0, 25 passed 0 failed, builder0 light lane): the seam with the hold record and the PLANNER_SEAM_REPORT line
  (the rolling face: one event, held 112 ticks = ~45 braking + 67 of search; the War Rig face at rest: 4 ticks).
  **0a2a4a48 is the seam tip for the series' tree**, pending its own plain check (queued behind CP-P0's in my heavy slot).
- 2026-10-15 ~03:30 PDT: **the pair tree named by native:** pair/cpp1 = 24435c3c = stream/native's mirror 12221d04 + the
  seam tip 3daf47e6 (my own `on()` form; native's scratch a6c6c804 dropped); **pair/cpp1-on = 8909c217** = that +
  `PLANNER_DEFAULT := true`, the gate hash; its plain `make check` is next in native's heavy queue (unit native-chain),
  the four named tests inside. Native's twins compare report() (holds inside), crews, queue, retry, last_refusal.
  0a2a4a48 (the PLANNER_SEAM_REPORT print line, measurement only) is after 3daf47e6: the series' rows name the gate
  hash 8909c217 AND the tree the series runs on (my tip, 0a2a4a48 or later, its own check green). The orchestrator asked
  for the clip as an mp4 at `~/projects/clips/round31/planner_terminus_<hash>.mp4` (round 30's form, before/after):
  both arms rendering in the light lane behind the planner tests (`planner-movies`), joined on the laptop with ffmpeg.
- 2026-10-15 ~03:20 PDT: **the clip's BEFORE arm** (the same run, no flag, faeab49c, light lane, exited 0): **29.8 s, 54
  legs (gear changes), 14 wall-contact ticks, 822 creep ticks, 39.8 m, end 2.9 m off and 173 deg round**; the end frame
  looked at: the rig canted across the street after a short tangled grind. Both arms' frames and rows are in
  `references/round31/planner/clip/` (bar line (g) under the real drive: before 29.8 s / 54 / 14, after 15.5 s / 3 / 0).
- 2026-10-15 ~03:15 PDT: **the clip's AFTER arm under the real drive** (`make remote LIGHT=1 T="planner-lab PLANNER_ARMS=today
  PLANNER_FIXTURES=turnround PLANNER_FLAGS=--nav-off=planner"` on faeab49c, builder0 light lane, exited 0): the Terminus
  west-street rig's face back = **15.5 s, 3 legs, 0 wall-contact ticks, 0 hull contacts, 70.5 m, end 1.5 m off and
  178 deg round** (the lab's planner figure was 15.5 s / 3 / 0; today's drive 29.8 s / 53 / 14). Frames + row in
  `references/round31/planner/clip/` (turnround_after_*.png, the end frame looked at: the rig mid-street nose south,
  a smooth three-leg trace clear of both walls). The BEFORE arm (today's drive, no flag) running (`planner-labbefore`).
  3daf47e6: the hold per event (`holds` n/median/max in report(); the orchestrator's reported line).
- 2026-10-15 ~03:10 PDT: **the rolling face CLOSED at faeab49c** (`make remote LIGHT=1 T="test FILTER=planner_seam"`
  exited 0, 5 passed 0 failed, builder0 light lane): one request, one plan of 5 legs, driven to its end, abandoned 0,
  pending 113 ticks (~45 braking from 8 m/s + ~68 of search = 136 expansions), 4.1 deg off south at 40 s. The seam's
  CODE TIP for the pair tree and CP-P1's candidate: **faeab49c** (ff66116c with Status). Sent to native and the orchestrator.
- 2026-10-15 ~03:10 PDT: **the rolling-face finding traced.** 0914dafd's brake changed nothing (25/0 on it, exit 0,
  light lane: the same abandoned 1 / pending 114 to the tick), so 77db86eb recorded the abandoned search
  (`PlannerSeam.last_abandoned`): begun, 92 expansions stepped, start (-70, -14.7) facing north = 8.8 m past the face's
  home (-70, -5.9; stay 5 m), speed 0. So: the 90-tick clock ran from the ASK and the rig's braking from 8 m/s ate ~45
  ticks of it, leaving 46 ticks x SLICE 2 = 92 expansions for a search harder than the at-home turnround (7). **faeab49c:
  the 3 s cap counts the SEARCH from the tick it begins at rest** (the hull's whole hold stays in `pending_ticks`);
  seam test file running (`planner-test14`). Also 39ba4b0b: the switch in the CP-H form (`PLANNER_DEFAULT` false, `on()
  = default != switched_off`; native's ask on pair/cpp1 a6c6c804, so the pair tree flips the const and keeps the
  native drive on). **Native: the CP-P1 ship-ON mirror is built on pair/cpp1 = stream/native + 0914dafd; pair/cpp1-on
  = 89090b3b, twins running; its full plain check follows in native's heavy queue.** The orchestrator: cleared for the
  judged series once CP-P0 is merged OFF (planner-check6) and the pair tree's plain check is green with the four tests.
- 2026-10-15 ~02:55 PDT: **census-3 / census-4** (a6a66f31 / b37b9ecb; the `by_hull` row missed the line at a6a66f31,
  fixed at b37b9ecb): long hulls 2 of 50, 6 / 9 of 174 / 202 manoeuvre starts (3.4 / 4.5 %), zero face orders; the rig's
  fitted plan median 131 expansions; the short hulls' face-about 190-250 us an expansion at a median of 11-113. **The
  planner test files GREEN on b37b9ecb** (25/0, exit 0, light lane) -- but the rolling face STILL abandoned its first
  request: zero/zero lets a rig at 8 m/s coast past the 3 s hold before it is under 0.5 m/s. **0914dafd: a pending
  rolling hull is BRAKED to rest** (the opposite throttle at 0.7 on a straight lock, as PlannerExecutor brakes a leg);
  its planner tests running (`planner-test12`). **CP-P1 BAR DRAFT v2 filled and sent** (below).
- 2026-10-15 ~02:40 PDT: **the planner test files GREEN on 005a3837** (`make remote LIGHT=1 T="test FILTER=planner"`
  exited 0, 24 passed 0 failed, builder0 light lane): the seam's War Rig face in the Terminus street at SLICE 2 --
  pending 4 ticks, one plan of 5 legs, driven to its end at 15.6 s, 2.1 deg off south at 40 s, plan_face never asked;
  the rolling face -- held to 0.23 m/s before its plan, 1.1 deg at 40 s, BUT the first search (begun while still
  rolling) ran out the 3 s hold (abandoned 1, pending 114 ticks) and the retry from rest planned: fixed in the next
  commit (`REST_MPS`: a pending search begins only once the hull has all but stopped). **R31.7 (the orchestrator):**
  the SCOPE is chosen now from the census, never after a judged number: **long hulls only (>= 10 m: the War Rig)**,
  every kind, at a6a66f31 (`PlannerSeam.in_scope`, a short hull never taken, test); planner-census now attributes
  today's plan events by hull class (`by_hull`) and probes the shortest live hull beside the longest; census-3 on
  a6a66f31 running (`planner-census3`) for the long-hull share and its expansion median, which go in the bar.
- 2026-10-15 ~02:35 PDT: **twin GREEN on fd36ecd5** (4/0, exit 0, light lane, load 12); **census-2** (same events; hits
  601.8 M -> 0.88 M; the per-expansion price unmoved for load: the walks, not lookups). **SLICE = 2** at 005a3837 with
  the derivation and the demand arithmetic in the report. 98d3a9c9: `PlannerSeam.last_refusal(name)` for manoeuvre's
  CP-P1 handover counters (`esc_after_refusal`, `refusal_then_free`; they write it once the seam is on main). Light
  lane: `make remote LIGHT=1 T="test FILTER=planner"` on 005a3837 (`planner-test10`): the seam tests incl. the
  rolling face and last_refusal, before the full check (the heavy slot is still CP-P0's check).
- 2026-10-15 ~02:20 PDT: **the census landed** (c158aecf; the table in the report): ~0.1 plan events a tick at Sumps 25 a
  side, bursts to 7; the seam's own navmesh request ~170 us an expansion WARM (hash lookup a cell read, 99.99 % hits).
  fd36ecd5: the window fills from the cache on first read (flat reads inside the search); twin + census-2 running.
  Native approved 3b5c0b34; its load guard is in check at stream/native 3331f81d (hazard 7: a C++ static holds plain data only).
- 2026-10-15 ~02:15 PDT: **light twin GREEN on 17bd1ec8** (4/0, exit 0, builder0 light lane, load 10.4, unpinned);
  native APPROVED d373af4e + 17bd1ec8 with three notes, taken at 3b5c0b34 (`nav_cache_clear()`; the rebake assumption;
  `planner-census` builds the library first; its probe also plans the seam's own request on the arena navmesh);
  c158aecf the signedness warning. Census launched on c158aecf (`planner-census1`). The orchestrator: price accepted as
  an upper bound (R31.6); CP-P0 = a3755e37 merges OFF on `planner-check6`'s exited 0; the cache merges on its own twin ALL
  green + review.
- 2026-10-15 ~02:10 PDT: **the price run landed** (41212da0, builder0, pinned cpus 0-3, QUIET WINDOW: NOT USABLE after a
  65-minute wait with 7-8 foreign runs live; the table in the report): twin 4/0, exit 0. The follow-on check was REFUSED
  (the price run's cleanup still live: nothing ran); relaunched as `planner-check6` on 41212da0. **d373af4e**: the C++
  navmesh field cache (per match: map id + iteration id + bake radius; 64x64 chunks; `nav_cache_stats()`), the GDScript
  `_cell` stores-then-reads so a cell is one float32 on every read (the first-read-returns-double quirk gone from both),
  `"nav"` = `NativeBridge.nav` through the world dict, native's header nit, and the seam test
  `test_a_face_ordered_while_rolling_is_held_to_rest_then_planned`. Its light twin segfaulted at `--import` (signal 11
  before any test): the static cache held a godot-cpp `RID`, whose constructor calls a binding not yet set at library
  load. **17bd1ec8** keys by `RID::get_id()`; light twin relaunched (`planner-twin8`).
- 2026-10-15 ~01:00 PDT: **CP-P0 candidate a3755e37** = 0c2d30c4 + the field through NavNative's index (ad1d1f3d; native:
  APPROVED, two nits for the seam-ON commit: the header comment, and passing `NativeBridge.nav` in so one index serves
  the game) + the index held per instance (a3755e37: a C++ static Ref outlived the ObjectDB and segfaulted at exit after
  a green run). **Twin (ALL fixtures, the yard included) GREEN on a3755e37**: `make remote LIGHT=1 T="planner-twin
  NATIVE_JOBS=2"` exited 0, 4 passed 0 failed, builder0 light lane, load 13, unpinned; the Terminus fixtures 9.7 / 11.1 /
  47.9 ms a plan (7 / 37 / 94 expansions) against 28 / 24 / 65 ms before the index; the yard BUDGET row 3.8 s for 12 000
  expansions (~320 us an expansion warm on a navmesh). FILE_TIME with ALL 333 s (the yard's GDScript 239 s of it); in
  check (no yard) ~95 s. Its full check follows the 0c2d30c4 baseline check in my heavy slot.
- 2026-10-15 ~00:50 PDT: **builder0's equality twin GREEN on 0c2d30c4** (`make remote LIGHT=1 T="planner-twin
  NATIVE_JOBS=2"`: runner exited 0, 4 passed 0 failed, builder0 light lane, load ~10, unpinned): 17 offline + 4 lab
  navmesh fixtures equal both ways on every observable; the three hull classes' tables equal in all 24 576 cells; the
  slice at 50/200/1000 a step = the whole plan on six fixtures. Native's review of 50d380e1: APPROVED, one fix (the
  refusal's keys) taken at 0c2d30c4. UNPINNED prices (not the cost line): offline 14-63x (F6a 199 ms v 10.9 s; 30-55 us
  an expansion warm); Terminus navmesh fixtures only 2-16x (28-65 ms for 7-94 expansions: each lazy-field cell is an
  engine closest-point scan, ~4 ms an expansion cold). The yard lab fixture is BUDGET after 12 000 expansions (129 s of
  GDScript, 2.26 s native; FILE_TIME 165 s): gated out of `check` behind PLANNER_TWIN_ALL (set by `planner-twin`). The
  C++ field now reads the navmesh through NavNative's polygon index (bit-equal to the engine by its own twin) — re-proved
  by the next light twin run. The full check on 0c2d30c4 runs as `systemd-run --user --unit=planner-check` (the tooling
  rule: backgrounded wrappers were being reaped).
- 2026-10-15 ~00:20 PDT: **the seam's request lines RE-PLACED** (a correction to the draft's "first line of
  `_planned_reverse`", which that function's every-tick cadence would have turned into a plan request for every routed
  wheeled hull): `PlannerSeam.hold()` at the top of `_planned_reverse` and of `face_turn` only CONTINUES a crew the seam
  holds (never asks); `PlannerSeam.take()` asks at the three points today's code makes a plan: the circle plan (a hull
  near rest with the carrot inside its circle), the blocked forward arc (after the `KTURN_HIT_WITHIN_M` test, where the
  back-and-fill is searched) and the face after its aligned test. So a hull mid k-turn leg is never taken (the leg block
  returns before the request lines). Manoeuvre's R31.2 (H): `mover.yield_to_plan()` once on the first take (their
  9b257348) — PENDING until it reaches main; the call site is marked in `_request`.
- 2026-10-14 ~23:40 PDT: the orchestrator's correction taken: every Godot run on builder0 from here (C31.7), the laptop
  only for parse checks. `make remote T="planner-twin PLANNER_CPUS=0-3"` queued on builder0 (position 6 of 9 behind
  traffic's and brains' two checks). **P7 coded, OFF**: `game/ai/planner/planner_seam.gd` (`PlannerSeam.take` at the two
  agreed lines, the FIFO slice, zero/zero pending, the re-request from rest, abort re-plans, the refusal windows,
  `live()`, `report()`, `capture()/restore()` with a pending session replayed by its expansions); `movement.gd`: `"planner"`
  in OFF_NAMES, the two `take` lines, `manoeuvring()`, the `unstick()` gate (R31.2's five lines, nothing else);
  `PlannerExecutor.to_state/from_state`; `Planner.begin_session/step_session/session_result/cancel_session`;
  `tests/test_planner_seam.gd` (OFF never asks; ON: the Terminus rig's face taken, planned, driven, within 15 deg at 40 s,
  plan_face not asked; capture/restore round-trips). `SLICE` is 100 expansions a tick until the cost line says otherwise.
