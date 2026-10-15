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

_Updated 2026-10-14 ~22:45 PDT by the planner worker (`godot-planner`, `stream/planner`, from main `cff4307e`; Fable
5.1). The report first (empty until CP-P0 lands), then the DRAFT SEAM (the orchestrator's early ask), the plan, the log._

### The report (read this first)

**CP-P0 candidate a3755e37** (C++ `PlannerNative`, equal to the GDScript planner on 17 offline + 4 Terminus-navmesh
fixtures on every observable, the three hull tables bit for bit, the slice = the whole plan): **twin GREEN on builder0
twice** (41212da0 = a3755e37 + docs: `tools/remote.sh --quiet planner-twin PLANNER_CPUS=0-3` exited 0, 4 passed 0 failed,
pinned to cpus 0-3, load 0.76; and the unpinned light-lane run before it). **Full `make check` on 41212da0 is running**
(unit `planner-check6`; the first attempt was REFUSED by the wrapper because the price run's own 15 s cleanup was still
live in the folder -- nothing ran, nothing was lost). Green `make check` hash: none yet.

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
  finding, and the candidate parks with its traces; there is no second scope).
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
