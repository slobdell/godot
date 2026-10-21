# S1 stallnet — native's mirror (C36.3; Bar S1 in `_agents/streams/manoeuvre.md` Status)

GDScript: `stream/manoeuvre` `dbe6ed396`, `game/ai/movement.gd` `_unstick` / `_stall_net_holds` / `stall_net_on`.

## What changed in `Movement._unstick` (the tail after `pressing_escape`)

```gdscript
var pinned_on := _honest_blocker(order) if unstick_back_on() else null
var honest := pinned_on != null
var reading := ctl.tank.real_velocity if honest else ctl.tank.estimated_velocity
var pressing := Manoeuvre.stall_throttle(self, cmd, order) > 0.5          # evaluated ONCE per tick, as before
if pressing and honest and reading.length() >= STUCK_SPEED and _stall_net_holds():
    return                                                                 # the clock holds: no add, no reset
if pressing and reading.length() < STUCK_SPEED:
    if _stuck_time == 0.0:
        _stuck_from = ctl.tank.global_position                             # NEW member (Vector3)
    _stuck_time += delta
    ... unchanged (honest fire -> _escape_begin; blind fire) ...
else:
    _stuck_time = 0.0

func _stall_net_holds() -> bool:
    if _stuck_time <= 0.0 or _flat_distance(ctl.tank.global_position, _stuck_from) > STUCK_NET_M:
        return false
    stall_net_holds += ctl._step                                           # Movement static, counts in BOTH arms
    return stall_net_on()                                                  # STALL_NET_DEFAULT != switched_off("stallnet")
```

## The mirror (native's paths)

1. `exec_fields.h`: `_stuck_from` (Vector3) on the mover view, read and written like `_stuck_time`.
2. `native_drive.gd` config: `STALL_NET_DEFAULT` (via `get_script_constant_map().get(..., null)`, a ready flag as W1c's) and
   `STUCK_NET_M` (Movement const 0.5).
3. `drive_native.cpp` unstick tail (~1730): the hold before the `< STUCK_SPEED` branch, `_stuck_from` set when the clock starts
   from 0, `stall_net_holds` += step on Movement's statics (as `unstick_fires`). `_flat_distance` = x/z only.
4. `tests/native/mover_state.gd`: `_stuck_from` in the per-mover state, `static:Movement.stall_net_holds` in the statics.

## The pair's lines

- `tests/test_manoeuvre_stall_net.gd::test_the_native_path_matches_gdscript_in_the_default_arm` (first fire, fires, holds
  equal): on base's tree that is the base arm, on ON's tree (STALL_NET_DEFAULT true) the ON arm.
- Drive twins bit for bit (the new member and static included); sim-baseline 13 maps unmoved with the default false.
