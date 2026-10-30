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
