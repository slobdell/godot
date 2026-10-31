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

### 2026-10-30 ~17:55 — R6 DONE: the route takes the short way, both sides; the excess metres are the drive's

**R6 (R47.12), `make route-census`, builder3, native on, 48 CPU v CPU fights on fresh 12501-12548 (150 s, six dealt maps, factions
rotated), 8d1e09e8f (+ crossing-12531 re-run at the instrument fix, same fight), table:
`_agents/streams/references/round47/route/route_census_12501-12548.txt`.**
- **THE ROUTE (the first route the drive plans v the navmesh's shortest to that goal), 2661 travel legs >= 15 m: p50 1.000,
  p99 1.005, max 1.057; 1 leg over 1.05x, 0 over 1.3x.** Green max 1.018, rust max 1.057 (a 16.6 v 15.7 m leg). No class, map or
  side is taken the long way. **R6 finds nothing for route: that is the finding.**
- **Where the metres go instead:** over all travel legs, driven v start-to-end shortest p50 1.068, p90 1.600, 12.7 % over 1.5x,
  16.2 % excess. Most of it is a goal that MOVED during the leg (a slot riding with its squad: 1797 such legs, excess 17.9 %;
  goal still: 11.8 %). For legs that ARRIVED at a goal that stayed put (741), THE DRIVE (driven v planned): p50 0.949 (the
  carrot cuts corners), p90 1.295, 9.7 % over 1.3x, 5.0 % over 1.5x, 3.5 % of metres reversed, 725 s held (yielding/blocked).
  By class (arrived, goal still; n / p90 / over 1.5x / reversed / held s a leg): scout 341 / 1.258 / 4.4 % / 3.2 % / 0.5;
  ifv 134 / 1.216 / 4.5 % / 3.3 % / 0.9; tank 98 / 1.226 / 4.1 % / 2.5 % / 0.9; lancer 44 / 1.231 / 4.5 % / 4.2 % / 1.5;
  artillery 43 / 1.441 / 9.3 % / 9.0 % / 5.3; gang_support 16 / 1.889 / 31.2 % / 3.8 % / 2.8. **The worst drives** (crossing
  s12543 Rust_Burners_1 145 v 80 m, 25 m reversed; locks s12515 Green_Eyes_5 74 v 26 m; crossing s12501 Rust_Guns_2 law_artillery
  93 v 53 m, 39 s held; full list in the table) are reversing, held and re-planning on a route that was the shortest:
  manoeuvre's (drive/traffic), offered to the orchestrator for relay. Artillery and the gang support truck drive the worst.
- **Instrument checks:** 47 of 48 fights ended at the same second in two runs (4d09268e8, 8d1e09e8f): the census doesn't move the
  game. One fight (crossing-12531) lost its census loop to a bug of mine in run 2 (`goal0` read before set; fixed, re-run: the
  same 121.2 s, 86 legs).

### 2026-10-30 ~17:50 — R2a DONE, R2b DROPPED (R47.12), R5 GDScript side DONE, R6 census running

- **Rulings (orchestrator, R47.12, main 6ac03cd4b):** RETREAT beating his order = engage's E7 (and `withdraw_point` stays engage's);
  R2b dropped (measured first, see below); R3 moot (nothing ships from route for his case); R4 waits on E7; R6 new (the census).
- **R2a DONE** (`tests/test_pathing_crossings.gd`, 7/0 builder3): his Locks click 135.2 m over the west bridge (lock 144.6 forced);
  Crossing west 152.3 / east 153.5 over their own bridges (other 365 m); Gorge west 74.4 / east 86.7 over the near neck; Terminus
  south approach -> plaza 86.0 m = straight. A future cost term that sends a crew round the long way fails these first.
- **R2b DROPPED, by measure:** along his attack (his census, ticks 1710-2220; `tests/route/test_route_locks_probe.gd`
  ROUTE_ALONG, builder3) the lock was the shortest crossing at every tick but 1800-1830 (177.0 west v 181.2 lock, while the
  retreat still had it parked on the north quay); from 1860 on the lock led by 4-125 m though Lances_3 drifted 35 m west.
  Movement already re-plans a sliding goal at 10 % of the remaining route (GOAL_TUBE_SHARE).
- **R5 (doors) GDScript side DONE at 5972e1369** (`game/ai/planner/route_doors.gd` RouteDoors, `Pathing.find_path`/`query`):
  a door = ONE NavigationLink3D across its wall on its OWN nav layer bit, `RouteDoors.register(id, position)` returns it
  (`1 << (8 + slot)`, 24 slots); Pathing asks with layer 1 | the doors open NOW and at the crew's estimated arrival (straight
  metres to the door / (top speed x 0.85)); open/shut from mapkit's `BlastDoors.is_open(id, tick)` once that class exists (looked
  up by name), else `RouteDoors.is_open_fn` (empty = open). `--route-off=doors`: every door reads open. No door registered: mask 1
  (= the engine default), the native path as before (byte-identical). `tests/test_pathing_doors.gd` 5/0 (an unregistered link
  is never used; open = through it, the short way; shut = round by a crossing; shuts before arrival = not taken; off = taken);
  `FILTER=pathing` 16/0 with native built, builder3.
  - **For mapkit:** put each door's link on exactly the layer `RouteDoors.register(&"<id>", <link middle>)` returns (no other bit);
    `BlastDoors.is_open(id: StringName, tick: int) -> bool` static, the id as registered.
- **R6 census:** `make route-census` (tests/route/route_census.gd + route_census_table.py): CPU v CPU fights, both sides, every
  crew leg's driven metres v the navmesh's shortest start to end, by side / class / arena / brain option, with goal-moved and
  re-plans per leg. Dev read (7001-7002, 60 s, builder3, 4d09268e8^): 105 travel legs >= 15 m, p50 1.077, excess 11-12 % of
  metres. The 48-fight run on 12501-12548 (150 s, all six dealt maps): running.

**Requests to other streams:**
- **native (C47.6, for doors to work in his default game):** the native route queries ignore doors (they ask layer 1 only, so
  they never route through a door, the safe default). Three sites need the mask: `pathing_native.cpp` `pathing_query` (line ~97)
  and `pathing_find_path` (~117), and `drive_native.cpp` `path_query` (~1817, the native drive's own re-plan). Smallest change:
  when `RouteDoors.doors` is non-empty, pass `navigation_layers = RouteDoors.mask(node, from)` (a GDScript call, only on door
  arenas; else 1, today's). Then Pathing can drop its `not RouteDoors.any()` step-aside (pathing.gd lines 15 and 37). Twin:
  `tests/test_pathing_doors.gd`'s five poses with native on must give the same routes.

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

