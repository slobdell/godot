# S2a h1bside — native's mirror (Bar S2a in `_agents/streams/manoeuvre.md` Status)

GDScript: `stream/manoeuvre` `a1b7f7e59`, `game/ai/movement.gd` (search "S2a"). Default OFF (`H1B_SIDE_DEFAULT`).

## What stays GDScript (no mirror)

`_h1b_gives_up` → `_h1b_side(friend)` → `_side_point` / `_side_clear` run inside `_escape_begin`, which the native unstick
already calls back. They SET the new members below; the native drive only has to READ them.

## New members (exec_fields)

`_side_to` (Vector3, INF = none), `_side_left` (float), `_side_stand` (bool), `_side_friend` (Object/Tank, may be freed),
`_side_friend_at` (Vector3), `_side_goal` (Vector3). `reset()` clears `_side_to` (INF) and `_side_stand` (false).

## The two reads to mirror

1. **drive(), right after `routed := aim if direct else _next_waypoint(aim, delta)`:**
   ```gdscript
   var side := _side_waypoint(delta)       # decrements _side_left; ends (sets _side_to INF) when _side_left <= 0, within
   if side != Vector3.INF:                 # SIDE_REACHED_M (2.0) of _side_to, or _side_over()
       routed = side
   ```
2. **`_unstick`, first thing (before the `_esc_stage` branch):**
   ```gdscript
   if _side_stand:
       if _side_over(): _side_stand = false
       else: cmd.throttle = 0.0; cmd.turn = 0.0; _stuck_time = 0.0; return
   ```
   `_side_over()` = friend null / freed / dead, OR friend moved > H1B_MOVED_M (0.5) from `_side_friend_at`, OR
   `_flat_distance(_goal, _side_goal) > NEW_GOAL_JUMP` (3.0).

Config: `H1B_SIDE_DEFAULT` (ready flag as W1c's), `SIDE_REACHED_M`. Counters are ManoeuvreCensus statics written in GDScript
only (h1b_side_steps / h1b_side_stands).

## The pair's lines

`tests/test_manoeuvre_h1b_side.gd::test_the_native_path_matches_gdscript_in_the_default_arm` (fires, pass time, end position
within 0.05 m, both stages); drive twins with the new members; sim-baseline unmoved with the default false.
Traffic's T9 half-lengths fix rides in the same pair (the orchestrator's ruling; traffic sends its hash and its mirror line).
