# Stream: planner (a local motion planner for long wheeled hulls in tight space: designed, tested offline, shown in a lab scene; nothing in play this round)

> Read `_agents/orchestration.md` (the worker contract; lessons 295–305), `_agents/game_design.md` *Round 26 direction*
> (three-point turns), *Round 28 direction* (his call 2: turn the whole hull), `_agents/workstreams.md` **Round 30**
> (C30.1–C30.10, especially **C30.4**: you are isolated), `_agents/roadmap.md` *AT ROUND 29's CLOSE* (item 2 is this
> stream), rounds 26–29's manoeuvre briefs (`streams/archive/round2{6,7,8,9}/manoeuvre.md`: every M1/M2/M3/M4 attempt and
> its trace) and round 29's traffic (T3's crawl) and brains (B5c's worst run) reports. **You own ONLY:**
> `game/ai/planner/**` (new), `tests/planner/**` (new), `tests/test_planner*.gd` (new), `mk/planner.mk` (new),
> `_agents/streams/references/round30/planner/**` (new). **Nothing you write is reached in play this round**: no seam in
> `movement.gd`, `manoeuvre*.gd`, `order_controller.gd` or `tank.gd`; manoeuvre integrates next round from your P4
> hand-over (C30.4). builder0: light targets only, one slot at a time, no judged series. **Model:** this stream runs on
> **Fable 5.1** — his ask (2026-10-14); this is the costliest repeat failure in the project.

## The lead's direction

Round 26: *a stuck vehicle should make a planned three-point turn, not shuffle back and forth.* Round 28, his call:
**TURN THE WHOLE VEHICLE** to a drawn facing, "a few seconds longer on arrival". His ask for Fable (2026-10-14): *"hard
or lingering problems that we can throw at Fable to mitigate any bottlenecks in our project."* The lingering problem: a
10–14 m wheeled hull (War Rig, gang truck, mortar truck) in a street, a yard corner or a packed formation. Four rounds of
local rules (the creep lift, the k-turn block, planned reverses, the arrival gate, honest velocity) each fixed one case
and broke another.

What he will notice this round: nothing (C30.4). What he will notice when manoeuvre wires it in: a long truck in a tight
street turns in two or three deliberate legs, backs out of a wedge, arrives nose-on to his facing, and does not grind
along walls or creep forward and back.

## Where things stand (main `0d35f215`)

The failure record, each with a branch and a table (`references/round29/manoeuvre/`, the archived briefs):
- **The creep (M2, `manoeuvre-m2-r29`):** short forward/back shuffles at the line; the lift (roll the turn) fixes open
  ground (long episodes −72 %) but rolls 10 m rigs into street walls (wall contact-ticks 3938 → 6494). Half the remaining
  creep is a squadmate in the way (traffic's). Base census: 917 turn episodes, creep 121.
- **The wedge (M4, `manoeuvre-m4-r29`):** `move_and_slide` returns the wanted velocity when fully blocked, so a pinned
  truck reads 12 m/s at zero displacement and unstick never fires; an honest velocity zeroes wheels' `_speed` on every
  wall brush and rigs grind along walls (Terminus rigs arrived 81 → 64/96). Manoeuvre's M4b this round gives the real
  displacement to the progress readers only (C30.6).
- **The boxed-in face (M1, `manoeuvre-m1-r29`):** turning the hull to a drawn facing inside a packed formation: each
  hull's face legs are boxed by its neighbours; point tasks 3° median but 8–12 more crews still turning at 75 s.
- **The arrival gate (brains' B5c):** a gate laid beyond the goal for a 180° facing; a car 9 m from its slot pulled
  17.5 m back to a gate and jammed on terrain (Terminus seed 3, B_4).
- **The crossing crawl (traffic's T3):** a yielding squad crawling at 0.4 for 30–45 s.
- **What exists to build on:** `game/ai/clothoid.gd` (clothoid legs), the k-turn / planned-reverse / circle block in
  `movement.gd` (`kturn_on` … `_look_stop`), `game/ai/manoeuvre*.gd` (the census: `--turn-trace`, `--turn-states`),
  `game/ai/wall_contact.gd` (the wall observer), the navmesh queries in `game/ai/pathing.gd`, the hull footprints in
  `game/units/**`, the tank's plant (`game/tank/tank.gd`, `tank_motion.gd`: steering, turning radius, reverse);
  TacticsLab (`tests/tactics/**`, `make screen-slots` is a one-scene lab run) as the pattern for a lab scene. The C++
  twins of the drive (`native/src/drive_native.cpp`) show what a port would need.

## Backlog (in order)

**P0 — the problem statement (a doc, first; `references/round30/planner/problem.md`).** From the record above and your
own reading of the code: the vehicle model as the game has it (wheelbase, max steer, turning radius per class, reverse
speed, what `tank_motion.gd` actually integrates), the environments (street widths on Terminus / the yard / Sumps, the
navmesh's margins), the squad context (slot pitch, who moves when), and the five failure modes above each as a concrete
fixture: a pose, a goal pose, the obstacles, what today's code does (reproduce three of them from manoeuvre's branches
with the exact command; ask the orchestrator to get traces from manoeuvre if a branch does not run). State what a
planner must guarantee (no wall penetration, bounded legs, bounded time per plan at 25 a side, a plan that today's drive
can execute as legs) and what it must not do (change the plant; re-plan every tick).

**P1 — the design (`design.md`).** A LOCAL planner over a short horizon (≤ ~30 m): candidates to weigh in writing with
the fixtures in hand — a state lattice / hybrid-A* over (x, z, θ, gear) with the kinematic model and a footprint check
against walls (navmesh edges + the wall observer's statics) and squadmates' predicted footprints; a Reeds–Shepp /
clothoid primitive set (today's `clothoid.gd`) searched the same way; or a sampling planner. Choose ONE and say why
against the fixtures and the time budget. Define the interface so manoeuvre can wire it in with one seam:
`Planner.plan(start_pose, goal_pose, footprint, obstacles, budget_ms) -> PackedPlan` (legs the k-turn block already
executes: forward/reverse arcs with a steer and a length; a `why` string; a failure code), re-planned on an event (a
leg done, a block, a stale obstacle), not per tick. State the cost model (time, wall clearance, reversals, squadmate
space) and how a drawn facing and a 180° arrival become goal poses with a side gate instead of a gate beyond the goal.

**P2 — offline tests (pure GDScript, no scene; `tests/test_planner*.gd`, run in `make check`).** The kinematic model
(`tests/planner/`: a step function that matches `tank_motion.gd`'s integration for a straight, a max-steer arc and a
reverse within 1 %); the planner on the fixtures from P0: a 12 m street turn-round, a T-junction, a street mouth with a
squadmate stopped in it, a yard corner, a 180° arrival onto a slot, a wedge against a wall (start touching), a packed
line of four 14 m trucks each wanting to face east. Each fixture has a pass line: reaches the pose within x m / y°, no
footprint ever penetrates a wall, ≤ N legs, plan time ≤ t ms on builder0 (state t from a 25-a-side budget: say what
share of the tick you claim). Test first, then build until they pass. Print the plan per fixture as ASCII in the test
log so a reviewer can see the path.

**P3 — the lab scene (`make planner-lab`, builder0 light).** One real hull (gang truck, War Rig) on a real arena cut
(Terminus street, the yard corner), driven by a tiny harness that calls the planner and feeds its legs to the EXISTING
k-turn executor (through your own harness script in `game/ai/planner/`, not through `movement.gd`), beside the same hull
under today's code on the same fixture. Screenshots and a clip (`MOVIE=`), the paths overlaid, times to the pose. Look
at them; the clip goes to him through the orchestrator. If the executor cannot follow a leg the planner wants, that is a
P4 finding (what manoeuvre must change in the executor), not a reason to edit `movement.gd`.

**P4 — the hand-over (`handover.md`; one page + the diff you would make).** Where the seam goes (the one line in
`drive()`/`_manoeuvre` or the k-turn entry), what the planner needs from the drive's state, what it replaces (the creep
lift? the circle fill? the planned reverse?), what native must port, the cost line, the bar you would pre-register for
its first judged run (C30.1; cite sizing's table), and the risks the lab showed. Manoeuvre writes its reading in its
Status; round 31's split decides.

**Stretch:** the squad-level version (four trucks facing east without boxing each other: a shared schedule of who turns
first), only as a design note after P4.

## How to verify

`make remote T=check` green with your tests in (C30.10); `make planner-lab` on builder0 (light; one slot); the fixtures'
ASCII plans and the lab clips looked at by you and sent to the orchestrator. Every number carries its commit, machine
and n. No judged series.

## Don't touch

Everything outside your five paths: manoeuvre's `movement.gd`, `manoeuvre*.gd`, `clothoid.gd` (read, call, never edit —
copy a function into your paths if you must change it), `order_controller.gd`; `game/tank/**`; native's `native/**`;
brains', traffic's and sizing's paths.

## Waiting on the lead

Nothing. (Design pillars: a planned turn, not a shuffle; the whole hull turns to his facing — both are his calls already.)

## Status

_Updated 2026-10-14 by the planner worker (`godot-planner`, `stream/planner`, from main `bd05077d`; Fable 5.1).
Report at the top of this section once there is one; the plan and the log below it._

### Plan (ordered, smallest foundation first)

1. **P0 `problem.md`** — the vehicle model as `tank_motion.gd` integrates it, the environments measured from the
   arena JSON, the squad context, the five failure modes as fixtures, three reproduced on main with exact commands
   (`make planner-repro-*` in `mk/planner.mk`, builder0 light lane, one at a time): the wedge (Terminus rigs seed 9),
   the creep (Terminus mixed seed 1 census), the boxed-in face (my own TacticsLab probe: four rigs in a line, face east).
   The arrival gate and the crossing crawl from brains' and traffic's round-29 traces (their branches, not run here).
2. **P1 `design.md`** — the candidates weighed on the fixtures; ONE chosen with the reason; the interface, the cost
   model, the goal poses for a drawn facing and a 180° arrival. Decision recorded here when made.
3. **P2** — `game/ai/planner/**` + `tests/test_planner_*.gd` (pure, in `make check`): the kinematic twin of the plant
   (within 1 % of `TankMotion.step_in_place`), then the fixtures, each with a pass line and an ASCII plan in the log.
4. **P3** — `make planner-lab` (builder0 light): one real hull on a real arena cut, my harness feeding the plan's legs
   to the plant beside today's code; screenshots and a clip.
5. **P4 `handover.md`** — the seam, the diff, what it replaces, the native port, the cost line, the pre-registered bar.
6. Stretch: the squad schedule note.

Decisions so far (one line each, reversible): the planner's budget is an EXPANSION cap, not milliseconds — a decision
that reads the wall clock breaks `make determinism` (orientation trip-up 28); ms are measured and reported per
commit and machine, never read. Legs carry their own steer (`Vector3(gear, steer, metres)`), a superset of the
executor's `Vector2(gear, metres)` on one lock: that difference is a P4 finding, not an edit to `movement.gd`.

### Progress log

- 2026-10-14: oriented (CLAUDE.md, HANDOFF, orchestration, orientation, game_design rounds 26/28/30, workstreams
  round 30, the brief, rounds 26/28/29 manoeuvre reports, the M4 judged table, the plant, `clothoid.gd`, the k-turn and
  face executors, `wall_contact.gd`, `pathing.gd`, the arena JSON). Starting P0.
- 2026-10-14 ~11:20 PDT: **P0 written** (`references/round30/planner/problem.md`) with three reproductions on main
  `bd05077d`, builder0 light lane, n = 1 each: the wedge (`make remote LIGHT=1 T=planner-repro-wedge`: a rig pinned
  61.4 s between two squadmates at 6.9 m/s reported, 0.0000 m moved), the creep (`planner-repro-creep`: 16 of 30 turns
  over 3 legs, the worst 13 legs in open ground), the boxed-in face + the 180° gate (`planner-repro-face`: four rigs at
  12 m, one clean plan of four, 33 gear changes at the boxed end, every rig 5.5–7.8 m off its spot; a scout 9 m from a
  slot facing back drives 102 m through a gate 13.75 m beyond it). **P1 written** (`design.md`): a lattice / hybrid-A*
  on the plant's own arcs, time cost, OBB squadmates, expansion budget; pre-registered pass lines for P2.
