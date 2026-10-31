# Stream: route (a crew takes the short way: no 230 m detour for a 93 m gap)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 345, 348, 352), `_agents/judging.md`, `_agents/workstreams.md`
> **Round 47** (C47.1-C47.11; C47.3 and C47.8 are yours to serve), `game_design.md` *His second match* and its third note, and
> `_agents/arenas.md` (lanes, crossings). **This is a new stream:** nobody owned the planner in round 46. **You own:**
> `game/ai/pathing.gd`, `game/ai/planner/**`, `game/ai/tactical_query.gd`'s path-cost terms, `game/tactics/element_plan.gd`'s corridor /
> transit / crossing choice functions (name them in your first Status entry and message the orchestrator), `tests/route/**`,
> `tests/test_pathing*.gd`, `tests/test_planner*.gd`, `mk/route.mk` (new; one include line in the Makefile, listed in merge notes).
> **Model:** Opus. **Machine:** builder3. **Seeds:** 12501-12548 (Bar R), 12549-12596 (reserve). Dev 7001-7012 (never a bar).

## The lead's direction (2026-10-30 ~15:55, Locks, verbatim)

"ok in the game I'm playing now, I'm down to my last IFV, it was part of a squad where I told everyone to attack a target directly in
front of it. This lone IFV has travelled in the opposite direction south - for some reason it took the counter-intuitive path of going
south and all around a building to then cross a bridge in the middle of the map. I'm not sure how this makes any sense to begin with,
because that seems like we're not using shortest path algorithms"

Memory: units must look smart and under his control.

## Where things stand (main fccfaadea; code e306ce27f GREEN builder3 3518/0, 28 ALL JUDGED)

- **His case** (`references/round46/playtest/2026-10-30T15-49-20-locks.jsonl`): attack order on Rust_Lances_3 at tick 1461 (Hunters_1/4/5). Lances_3 about
  (-26, -20); **Green_Hunters_4** at (-83, 57): straight line 93 m. Its census stays on the earlier `attack_move` until tick 1680 (the
  order lag is ORDERS' item O2; you own the route). From tick 1710 on `attack` it goes east along y ~ 90 to (-7, 84), then south down
  x ~ -7 over the middle crossing to (-5, 17) by 2220: **~230 m for a 93 m gap**; killed at 2232.
- Suspects, ruled by removal, not by reading: a closed or danger-costed west crossing, a stale route from the attack_move, the planner's
  heuristic or the tactical query's cost terms, a firing-position goal far from the target (engage's `firing_position.gd`: ask, don't edit).
- **C47.3:** manoeuvre's no-progress watchdog will call `Pathing.reroute(crew, reason)`. Write it FIRST (a stub that re-plans is fine),
  commit, and tell the orchestrator so it can be merged early as a checkpoint.
- **C47.8:** mapkit's blast doors need the route to respect a door open/shut by tick. Not before R3.

## Backlog (in order)

1. **R0 the seam:** `Pathing.reroute(crew, reason)` stub + its test; message the orchestrator the green hash (checkpoint for manoeuvre).
2. **R1 the trace (Status first, then message the orchestrator):** for Hunters_4 from tick 1461 to 2232: every route the planner
   produced (when, from what goal, its cost by term), the shortest drivable path's length at each re-plan, and why the chosen one beat it.
   Name the cause.
3. **R2 the fix, ON, with an `=off` escape:** the smallest change that makes the chosen route no longer than ~1.3x the shortest drivable
   path unless a named, real reason (a closed crossing, a wall of enemy fire he'd see) costs it; a new order re-plans at once. Symmetric
   (C47.9). Tests first: his Locks geometry (unit), a crossing choice on Crossing and Gorge, a Terminus street route unchanged.
4. **R3 Bar R**, filed BEFORE any number on 12501-12548: deciding = route length / shortest-drivable ratio on order (his class of order:
   attack across a gap), time to reach range; guards = deaths en route (danger costs exist for a reason), all-in, the street lines,
   manoeuvre's and orders' probes. Native twin first if the cost runs in C++ (C47.6). Ships ON; name the green hash.
5. **R4 his acceptance read:** Locks replay on the shipped tree: Hunters_4's driven metres and time to range.
6. **R5 doors (C47.8):** the planner reads `BlastDoors.is_open(id, tick)` (mapkit's API; stub it until theirs lands); a route through a
   door that will shut before the crew gets there is not taken.

## Don't touch

movement / traffic (manoeuvre), `game/control/**` (orders), gunnery / firing_position (engage), `native/**`, `game/camera/**`,
`arenas/**` and `game/arena/**` (mapkit), `tests/baselines/**`.

## How to verify

`make remote T=check` on builder3 (read `>> remote: make check exited <N>` and `N passed, M failed`, never an exit code through a
pipe); `make quick-remote` to iterate (`QUICK_BASE=<your last green>`); `make replay-match RECORDING=...` and `make playtest-report
RECORDING=...` on his four recordings; screenshots at desktop and phone aspect, looked at. Every number with its commit, machine,
workload and n. **No local Godot runs** except a lock-held laptop budget read (C47.1: seven sessions on a 7 GB laptop).

## Waiting on the lead

Nothing at launch. If a bar fails, write in player terms what he would see ON v OFF and message the orchestrator the same hour.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### 2026-10-30 ~17:30 — R0 GREEN (merge: ba53581f7), R1 DONE: the cause is the brain's RETREAT, not the route

- **R0 GREEN: ba53581f7**, builder3, `make check exited 0`, 3520 passed / 0 failed, 28 targets ALL JUDGED. Orchestrator told.
- **R1 cause (his Locks, Hunters_4), builder3, code ba53581f7 + the trace tooling, staged from his census:**
  1. **The 40 m drive north and the ~5 s dither at (-75,95) are `TankBrain` RETREAT**, not a route: hull 15/220 (7 %) under the
     under-orders critical line with threats in sight, so RETREAT 0.99 beats his attack; `withdraw_point` hands the crew a move_to
     ~20 m from the threats, over and over (north, away from his target). The element's slot for it stayed right (south, by
     Lances_3) the whole time. Alone, "after it alone: straight at it" took for ~1 s, then RETREAT took it back (staged tick 668).
     Brain scoring = engage's (C47.3); sent to the orchestrator as a request.
  2. **The route takes the short way:** over 298 re-plans in three runs, the driven route was at most **1.036x** the navmesh shortest
     to its goal. From his click spot (-82.7,62.3), shortest to Lances_3 = **135 m via the WEST bridge** (lock 145 m). From
     (-77,95), where the retreat left it, west 176.6 v lock 181.4 (a near tie); it took the lock because Lances_3 stood at x ~ -10
     then, and Lances_3 then drove 35 m west. (`tests/route/test_route_locks_probe.gd`, ROUTE_PROBE lines.)
  - **Why staged:** the plain replay leaves his match at ~12 s (divergence.py FAIL, first crew over 3 m at s 20), so
    `make route-trace ... STAGE_TICK=T` places every crew from his census row at T (hull, shield; missing = destroyed), re-issues
    his standing orders and shifts later ones. What it shows is what the code does from his positions, not his match.
- **R2 as written already holds** (route <= 1.3x shortest on every re-plan); proposed to the orchestrator: R2 = guard tests only
  (his Locks geometry, Crossing/Gorge crossing choice, Terminus unchanged), then R5. Waiting on its ruling for whether a retreat's
  direction under his order is route's or engage's.

### 2026-10-30 ~17:00 — R0 done (check pending), R1 tracing

**Plan (backlog order):** R0 seam -> R1 trace (`make route-trace`, new) -> R2 fix ON + `=off` -> R3 Bar R (filed before numbers,
seeds 12501-12548) -> R4 his Locks read -> R5 doors (stub `BlastDoors.is_open` until mapkit's lands).

**element_plan.gd functions route claims (C47 ownership line):** `_route_step` (the covered-route waypoint choice) and, through it,
`game/tactics/covered_route.gd`'s `CoveredRoute.choose` (nobody else's brief names it; claimed here, orchestrator told). Anything in
element.gd's transit route (`Element` ~1087-1304, nobody's) goes to the orchestrator as a request first.

- **R0 DONE:** `Pathing.reroute(crew: Node, reason: StringName) -> bool` at **ba53581f7** (`game/ai/pathing.gd`): clears the mover's
  `_path_goal` (the next `_next_waypoint` sees a goal it was never planned for = an event re-plan, GDScript and drive_native.cpp
  alike), `_repath_left = 0`, `native_stale |= STALE_ALL`; counts `Pathing.reroutes[reason]`; false with no live mover.
  `tests/test_pathing_reroute.gd` 2/0 (builder3, ba53581f7, `native test`, native built). Full check on ba53581f7: running.
- **R1 tooling:** `make route-trace RECORDING= ROUTE_CREWS= [REPLAY_SECONDS=]` (`mk/route.mk`, `tests/route/route_replay.gd`, a subclass
  of `tests/replay_orders.gd`, unchanged): ROUTE_TRACE rows on every change of a crew's order / drive goal / navmesh route / element
  route, with the shortest drivable length to the same goal and to the target.
- **Infrastructure note:** a fresh builder3 folder over the laptop's uplink crawled (219 of 804 MB in 22 min with seven streams
  syncing). Seeded server-side from `~/tank_squad/godot` (7 s); then rsync sends only the diff.

**Questions for the lead:** none yet. **Requests to other streams:** none yet.

