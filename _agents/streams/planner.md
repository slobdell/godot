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

**In progress: P5 (CP-P0) is coded and reviewed by native (7c286000 APPROVED for fidelity, four non-blocking notes,
note 1 taken), its builder0 twin run is queued behind three checks; P6's slice is in the C++ and proven by the twin
test's slice case (laptop pre-check); P7's seam is coded OFF (R31.2 as agreed) with its own test, not yet run.**
Green hash: none of mine yet (the laptop pre-check is not evidence: C31.7).

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
- 2026-10-14 ~23:40 PDT: the orchestrator's correction taken: every Godot run on builder0 from here (C31.7), the laptop
  only for parse checks. `make remote T="planner-twin PLANNER_CPUS=0-3"` queued on builder0 (position 6 of 9 behind
  traffic's and brains' two checks). **P7 coded, OFF**: `game/ai/planner/planner_seam.gd` (`PlannerSeam.take` at the two
  agreed lines, the FIFO slice, zero/zero pending, the re-request from rest, abort re-plans, the refusal windows,
  `live()`, `report()`, `capture()/restore()` with a pending session replayed by its expansions); `movement.gd`: `"planner"`
  in OFF_NAMES, the two `take` lines, `manoeuvring()`, the `unstick()` gate (R31.2's five lines, nothing else);
  `PlannerExecutor.to_state/from_state`; `Planner.begin_session/step_session/session_result/cancel_session`;
  `tests/test_planner_seam.gd` (OFF never asks; ON: the Terminus rig's face taken, planned, driven, within 15 deg at 40 s,
  plan_face not asked; capture/restore round-trips). `SLICE` is 100 expansions a tick until the cost line says otherwise.
