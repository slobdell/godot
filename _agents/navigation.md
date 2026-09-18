# Navigation: how a unit gets where it is sent

> Owned by the **nav** stream (round 6). The contract is **N1** in [workstreams.md](workstreams.md); this file is the
> architecture behind it, written as it is built. The lead's question *"are we using A\*?"* — yes: Godot's
> `NavigationServer3D` runs A* over the navigation polygons baked from the arena's collision at startup
> (`Pathing.find_path`). What was missing in round 5 was everything about *other units*.

## The layers

```
 squad / control / a brain's hop        "be here"          Movement.request(unit, to, opts)   (or a move_to order)
   └─ OrderController (the composer)    one per unit       orders, reflexes → a TankCommand every tick
        ├─ Movement (game/ai/movement.gd)   nav            route, avoidance, right-of-way, unstick, the N1 reading
        │    ├─ Pathing        A* over the navmesh (NavigationServer3D)
        │    └─ Steering       heading error → throttle, turn (tracks; wheels by pure pursuit)
        └─ firing half                      combat         moves to game/ai/gunnery.gd after CP4 lands on main
   Tank._drive → TankMotion (the plant) → move_and_slide
```

## N1, the Movement API

| Call | Meaning |
|---|---|
| `Movement.request(unit, to, opts)` | Drive the Tank `unit` to `to`. `opts`: `arrive_radius`, `pace` (0.2..1), `facing`, `priority`, `reverse`, `direct`. Replaces the move order (a `move_to` on its controller); the weapon order is untouched. |
| `Movement.state(unit)` | `{"phase", "eta_s", "remaining_m", "path_points", "blocked_by", "goal", "stalled_s"}`, or `{}` for a hull nothing drives (the player's own tank in `make run`, a client's copy). |
| `Movement.eta(unit, to)` | Seconds to drive there: the navmesh route at `ETA_CRUISE_SHARE` (0.85) of top speed, plus the pivot onto the route at the hull's turn rate. Straight line while the navmesh isn't ready. |
| `Movement.cancel(unit)` | Stop where it stands. |
| `Movement.of(unit)` | The unit's mover (or null) — for code in nav's own paths. |

**Phases.** `arrived` — no move order, or steering has nothing left to do inside the arrive radius. `pathing` — a
route is wanted but the navmesh has not synced yet. `driving` — under way and making progress. `blocked` — no progress
(0.5 m closer along the route than its best) for `BLOCKED_SECONDS` (2 s); `blocked_by` names the cause: **the name of
the nearest hull ahead** within 8 m (friend or enemy), else `"no_path"` when the route ends more than 3 m short of the
goal, else `"terrain"`. `yielding` — reserved for right-of-way (X4).

**The guarantee:** a unit with a destination arrives or reports `blocked` with a reason. It never stands still
silently. (Round 5's brains declared a stalled move *complete* from 12 m away — `TankBrain.ORDER_STALL_ARRIVE`. That
goes in its own measured commit once squad's precedence fixes are on main, at the orchestrator's request.)

**Determinism.** Everything a decision reads is per tick: stall counts in ticks (`_step` under a controller stride),
`delta` = the fixed tick. The blocker scan walks `tanks_root` in scene order and keeps the nearest, strictly, so ties
go to the first in that order — which is the same on every run of one build. No wall clock.

## Where things live

| File | What |
|---|---|
| `game/ai/movement.gd` | N1, and the per-unit mover: `_next_waypoint` (repath every 1 s or when the goal moves 1 m), `_around_fire` (step round a beaten zone), `_around_friends` (round 5's single-friend sidestep, brains only; X3 replaces it), `unstick` (blind reverse), progress and phase. |
| `game/ai/order_controller.gd` | The composer: orders, reflexes, the controller stride, and (until the gunnery split) the firing half. Keeps `stalled_ticks`, `_wheel_radius()`, `FIRE_LOOKAHEAD` as forwarders for the brains and tests that read them. |
| `game/ai/pathing.gd` | `find_path`, `is_ready`. |
| `game/ai/steering.gd` | The P controller for tracks and pure pursuit for wheels. |

## Measuring

`make nav-maze` (arena's, `tests/arena/maze_probe.gd`) is the acceptance instrument: it only watches positions, so it
keeps meaning the same thing whatever nav rewrites. Note it drives plain `OrderController`s, not brains — round 5's
`_around_friends` never ran in it.
