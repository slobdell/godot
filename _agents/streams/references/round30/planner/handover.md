# P4 — The hand-over to manoeuvre (one page, and the diff I would make)

_Planner stream, round 30 (Fable 5.1). Nothing here is applied: C30.4. Numbers carry their commit and machine; the
lab's are in `planner.md` Status and `build/planner-lab/` on builder0._

## The seam (one line, and where)

`game/ai/movement.gd` `drive()`, right after `order = _manoeuvre(order)` (line ~930 at `bd05077d`): a wheeled hull
whose goal pose is within `PlanRequest.horizon_m` (30 m) of it, or whose order is a `face`, asks the planner ONCE
per event and drives the plan's legs through `PlannerExecutor` until the plan is done or aborted; while a plan is
live, `drive()` returns after the executor wrote `cmd` (the route, the carrot, the circle rule, the k-turn block, the
creep lift and the face executor do not run for that hull). The event set: a new goal (`_goal` moved by more than
`NEW_GOAL_JUMP`), a leg aborted (stall / timeout / lead hit), a hull obstacle in the plan's window moved more than
1 m since the plan, a plan finished short of its pose (re-plan from the pose, at most twice, then today's path).

```
# movement.gd drive(), after `order = _manoeuvre(order)`:
if _plan_live(order, delta):          # PlannerSeam (new, manoeuvre's file): asks Planner on an event, drives PlannerExecutor
    cmd.throttle = _plan_cmd.throttle
    cmd.turn = _plan_cmd.turn
    return
```

`PlannerSeam` (manoeuvre's, ~80 lines): holds `PlannerExecutor`, `PackedPlan`, the obstacle snapshot, the event
flags; builds `PlanRequest.for_unit(tank.unit_id).at(pose).to(goal pose).in_world(PlannerNavWorld.for_tank(tank,
tanks_root))`, with `arrive_gear` from the order (`reverse: true` → −1), `tol_m` = the order's arrive radius (the
settle radius for a face), `tol_deg` 8. The face path: `OrderController` line ~501 (`movement.face_turn`) calls the
same seam with goal = (home, want).

## What the planner needs from the drive's state

The hull pose (`global_position`, `-global_basis.z`), `unit_id`, the navigation map and the bake radius
(`Movement.bake_radius`), every other living hull's pose and `hull_size` (`tanks_root`), the goal pose and arrive
radius, the order's `facing` (a goal heading) or the lack of one (then the goal heading is free: `tol_deg` 180), and
the tick. Nothing per tick: the executor reads `tank.speed()` and the position.

## What it replaces (for the hulls and goals it is asked for)

| today | with the seam |
|---|---|
| the planned reverse / back-and-fill / circle plan (`_planned_reverse`, `_plan_fill`, `_plan_circle`; one lock a plan) | the plan's legs (any lock per leg) |
| the creep lift (round 28 M2, not shipped) and the plant's creep on an in-drive turn | no leg is ever under the creep line: the executor's throttle is the request's (0.7, or the hull's yaw-cap throttle) |
| `face_turn` → `Manoeuvre.plan_face` (even legs on one lock, then greedy) | a plan to the pose (home, want) with the squadmates as boxes |
| the approach gate (`_approach_gate`) for a goal within the horizon | the goal pose itself; brains' gate stays for goals beyond the horizon, placed to the SIDE (design §2.8) |
| `Manoeuvre.choose` (reverse v route by plant simulation, open ground) | the same answer from the search, with obstacles |
| `unstick` / `_pressing_escape` while a plan is live | an aborted leg is an EVENT: re-plan from the pose (a wedged start is allowed to not get deeper); `NO_PATH` hands back to today's rules and reports |

## What native must port (C30.2)

`planner_world.gd` (the lazy field, the side walk, the OBB test), `planner.gd` (the search: heap, keys, sweeps),
`planner_heuristic.gd` (the table build and lookup), `planner_executor.gd` (the per-tick rule). The plant twin is
`TankMotion.turn_heading`'s arithmetic, already native (`motion_native.cpp`). ~900 lines of GDScript, pure
arithmetic over packed arrays: the natural first thing to port is the search loop with the world's `footprint`
(which is `_outline_offs`' navmesh query, already native in `nav_native.cpp`).

## The cost line (GDScript on builder0, the fixtures' and the lab's MEASURE lines; the native estimate beside it)

| what | GDScript, builder0 | expansions | native (estimate: ~100× on the same arithmetic) |
|---|---|---|---|
| a hull class's free-space table (once a process) | 2.2–2.5 s | 21.6 k states | ~25 ms, or shipped as a resource |
| a street mouth, a T-junction, a yard corner, a wedge | 0.06–0.5 s | 10–50 | 1–5 ms |
| a 180° slot on a 14 m causeway; a packed line's middle hull | 0.6–3.3 s | 60–200 | 6–30 ms |
| a War Rig's turn-round in a 20 m street (its hardest) | 17 s (9 legs); 56 s to the lattice's best (8 legs) | 3 700 / 8 200 | 0.2–0.6 s |
| an IFV's turn-round in a 12 m street | not found in 45 s (6 000 expansions, both lattices) | — | — |

Per expansion: ~2–5 ms in GDScript (six leg sweeps of up to 24 m, a footprint every 0.5 m). **The claim against the
tick (P0 §5.7): one plan ≤ 1 ms on builder0 in C++ holds for everything but the corridor turn-rounds; in GDScript no
plan fits a tick, so the seam must run the search as a resumable session (design §2.7: a slice of expansions a tick,
one hull a tick) or wait for the port.** Event-driven: a plan per turn, not per tick; the lab's three plans were 7,
36 and 94 expansions.

## The bar I would pre-register for its first judged run (C30.1; sizing's table, CP-N, for n)

The workloads are manoeuvre's own (M2's census, M4's Terminus rigs drive, M1's hull-rest), unchanged, so the rows
compare with rounds 28–29:
1. **Terminus rigs drive** (seeds as sizing's table says; round 29 used 6): arrivals ≥ base on every seed; wall
   contact-ticks down, also with each arm's two worst runs dropped (lesson 302); the arm's own counter shows plans
   made and legs driven.
2. **The turn census** (M0b's three workloads): episodes over 3 legs down by half (the number four rounds set and
   missed); creep episodes down; `kind: open` creep gone for hulls the seam covers.
3. **Hull-rest** (M1's point tasks, drawn): median ≤ 15° and ≥ 70 % within 15° at rest, AND the 75 s guard ≤ base +
   the table's noise (the number M1 missed by 8 at ±17 of A/A swing).
4. **His bridge 18/18; the arrive series = base; fights guard within 2 se on fresh seeds.**
5. **Cost:** the tick at 25 a side within the table's noise of base on builder0 (planning is event-driven and one
   hull a tick).
Partial rule: 1–2 met and 3 missed ships the seam for routed moves only (`face` stays on today's path); the last
attempt is the second judged run.

## Risks the lab showed (builder0, the Terminus, GDScript path, n = 1 each; `planner.md` Status has the table)

1. **The executor is the plan's weak half.** Four executor rules had to change before a plan drove true (brake on
   the leg's own lock with the opposite throttle; never zero throttle with the lock on; the discrete stopping
   distance; the ARC, not the chord). Today's k-turn executor has the chord and the stopping rule; the face executor
   ends on zero/zero (the creep) — all three are in `movement.gd` and are manoeuvre's to change.
2. **The planner uses what is there.** Asked to turn round mid-street it drove 25 m to the ring-road junction, turned
   in it and came back (70 m, 15 s, no contact) instead of shuffling in the street (today: 30 s, 53 gear changes,
   14 wall contacts). Right, and not what a player who said "turn round here" might expect: the seam should pass
   the order's leash (`within_leash`) as the horizon.
3. **A 14 m rig's in-street turn-round is 8–9 legs** on this lattice (6 cusps, 23–26 s of driving): better than the
   creep's 53, not the three the lead described. Fewer needs a finer lattice near walls or a continuous last leg.
4. **GOAL_BLOCKED and NO_PATH are frequent, honest answers** (a slot against a kerb, a hull boxed on both sides):
   the layer above must act on them (brains' re-seat, traffic's ask) rather than retry; today nothing listens.
5. **Moving squadmates** are boxes extended one second along their velocity; a plan through a formation on the
   move will go stale within a leg. The event "an obstacle moved > 1 m" re-plans, which could oscillate: cap re-plans
   per order (two), then today's rules.
6. **The free-space table is per hull class and 2.3 s to build in GDScript:** built on first use, it would stall a
   tick; the seam builds the wheeled classes' tables at match load (or native ships them).

## Stretch: the squad-level version (a design note only)

Four 14 m trucks line abreast at 12 m, each wanting to face east, planned one at a time with the others as boxes:
the planner finds 3–4 legs for every one (P2's packed line) — but driven at once they box each other, which is M1's
measured cost (the lab's F3 reproduction: one clean plan of four, 33 gear changes at the boxed end). The squad answer
is a SCHEDULE, not a better plan:
1. The element asks the planner for each crew's plan with the others as they STAND (what P2 does), and reads the
   swept box of each plan (the union of its poses' OBBs, `PackedPlan.poses`).
2. Crews whose swept boxes do not overlap turn together; crews whose boxes overlap are ordered: the one whose plan
   is shorter in time goes first, the other waits (a `hold` on its slot) and re-plans when the first is done, with the
   first's END pose as the obstacle. A line of four at 12 m pitch is two waves (the ends, then the middles).
3. The schedule is the element's (brains' `element.gd`, where the slots and the facing live), re-made when a crew's
   plan aborts; the planner stays per hull. A crew that gets NO_PATH in the second wave is re-seated (brains' rule).
Cost: one plan per crew per wave; two waves for a line of four. What he would notice: a line turns in two beats, not
four crews grinding on each other.
