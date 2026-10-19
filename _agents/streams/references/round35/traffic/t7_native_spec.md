# T7 (C35.8): the native mirror spec (traffic → native)

The GDScript is the reference; mirror it line by line, as `15b1523da` did T6b. Everything sits under the `underfire` switch
(`Traffic.DEFAULT_OFF` = `["underfire"]` on the stream; OFF = main bit for bit). Commit: see the hash named with this file in
traffic's Status (`game/ai/movement.gd`, the block headed "Round 35 (traffic T7, C35.8 …)").

## What changed v T6b (your `15b1523da` / `pair/native-underfire-b`)

1. **`ask(asker, from, direction, via)`**
   - First line after `native_stale |= STALE_ALL`: `pass_offer = 0.0` (a new instance var, float).
   - T6b's `if under_fire(): underfire_refusals += 1; return false` becomes:
     ```
     if under_fire() and via != "behind":
         side = _pass_lane(asker, from, direction)
         if side != 0.0: underfire_refusals += 1; pass_offer = side; return false
         underfire_gives += 1            # and fall through to the give-way as today
     ```
   - The battery rule still runs first (unchanged).
2. **`_begin_yield(other, from, direction, via)`**: T6b's gate becomes
   `if via == "self" and under_fire() and _pass_lane(other, from, direction) != 0.0: underfire_holds += 1; _yield_unfit_last = false; return false`
   (only the self call from `_negotiate` is gated; ask()'s calls are not).
3. **`_negotiate`** (negotiate_body):
   - Right after `if not i_give_way and mover.ask(...): return` add
     `if not i_give_way and _pass_start(name, mover.pass_offer, my_way): return`.
   - The swap block is restructured (same semantics for the ask):
     ```
     if i_give_way and yield_fit_on() and _yield_unfit_last:
         if mover.ask(me, here, my_way, "swap"): yield_swaps += 1; (shorter count as before)
         else: _pass_start(name, mover.pass_offer, my_way)
     ```
4. **New: `_pass_lane(passer, from, direction) -> float`** (0 = no lane, else ±1). No navmesh ready → 0. `way` = direction
   normalised, `across` = (−way.y, way.x); `first` = +1 if across·(from − here) ≥ 0 else −1; `lateral` = radius_of(me) +
   radius_of(passer) + YIELD_LINE_MARGIN; `beyond` = (hull_box(me)[2] + hull_box(passer)[2]) · 0.5 + PASS_BEYOND_M (2.0);
   `Avoidance.refresh`; for side in [first, −first]: P = here + across·side·lateral (y 0), Q = P + way·beyond; skip if
   (P − from)·way ≤ 0; skip unless `_pass_wheels_ok(passer, P)` and `_pass_clear(P)` and `_pass_clear(Q)`; return side if
   `_pass_swept(map, passer, [from_flat, P, Q])`.
   - `_pass_wheels_ok`: `_ahead_of_wheels`' arithmetic at the PASSER's pose and the passer's wheel_radius (0 → true).
   - `_pass_clear(point)`: every `Avoidance.neighbours(me, point)` row not the passer with sqrt(d) < radius_of(passer) +
     _radii[row] → false.
   - `_pass_swept`: frame = `_kturn_frame(passer)`; start = `_outline_offs(map, frame, passer flat pos, passer heading)`; each
     leg a→b (skip < 0.01 m): heading = leg normalised, steps = max(1, ceil(len / PASS_STEP_M 2.0)); for i in 1..steps:
     `_outline_ok(map, frame, a.lerp(b, i/steps), heading, start)` false → false. (`NavNative::outline_ok` is the same bits.)
5. **New: `_pass_start(refuser, side, way) -> bool`**: false if side 0, way ~0 or refuser == `_pass_failed_by`; true (no
   change) if already `_pass_by == refuser`; else set `_pass_by`, `_pass_side`, `_pass_way` (normalised),
   `_pass_left = PASS_MAX_S (6.0) · TICK_RATE`, `passes += 1`, true.
6. **New: `_pass_point() -> Vector3`** (INF = none), called from `_avoid` only: refuser looked up; `_pass_left -= step`; dead or
   missing → end (no timeout); `_pass_left ≤ 0` → end with timeout (`passes_timeout += 1`, `_pass_failed_by = _pass_by`);
   half = hull_box(refuser)[2]/2; along = (me − refuser)·_pass_way; along ≥ half → `passes_done += 1`, `_pass_failed_by = ""`,
   end; else `pass_ticks += step` and return refuser + across·side·(r(refuser) + r(me) + YIELD_LINE_MARGIN) + _pass_way·ahead,
   ahead = 0 if along < −half else half + hull_box(me)[2]/2 + PASS_BEYOND_M.
7. **`_avoid(waypoint, …, held)`**: in the T1 hold branch, `if _pass_by != "": _pass_end()` before using the hold; after the hold
   block, `if not held and _pass_by != "": lane = _pass_point(); if lane != INF: waypoint = lane` — before `to`/`distance`.
8. **Counters** (statics, in `route_arms` and `reset_route_arms`): `underfire_gives`, `passes`, `passes_done`, `passes_timeout`,
   `pass_ticks`. Instance state: `pass_offer`, `_pass_by`, `_pass_side`, `_pass_way`, `_pass_left`, `_pass_failed_by` (the
   census reads `_pass_by` for its pass-contact count, so keep it written on the GDScript object or tell me the native name).

## Twin cases worth forcing (yard_open; `tests/test_traffic_underfire.gd` has the stagings)
Open ground refusal with offer; a third hull in both lanes (gives); the crossing neck (gives); `via == "behind"` (gives); (b)
hold with the other passing forward v the other going away (no hold); a pass ended abreast; a pass timed out and not restarted.
