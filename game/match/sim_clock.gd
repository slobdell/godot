class_name SimClock
extends RefCounted
## THE simulation's tick rate, in one place (round 5: the move to a 30 Hz tick, _agents/sim_tick_rate.md).
##
## Every duration the simulation counts in physics ticks is written in terms of TICK_RATE: a hard `60` meaning "one
## second" silently doubles every duration the moment the rate changes. Write `SimClock.TICK_RATE * 12` for twelve
## seconds of ticks, `SimClock.ticks(0.75)` at runtime, and `SimClock.TICK_RATE / 10` for a cadence of a tenth of a
## second (constant expressions can't call functions). `project.godot`'s physics_ticks_per_second must equal
## TICK_RATE (a test checks), and every headless target runs `--fixed-fps` at it (make's SIM_HZ).
##
## Decisions never read the wall clock (trip-up 28): durations are counted in ticks, and this is only the exchange rate.
##
## Round 5: 30 Hz, with `physics_interpolation` on so motion still renders smoothly, and
## `max_physics_steps_per_frame` at 3 so a slow frame can never spiral into running eight ticks to catch up. 30 Hz is
## the FLOOR, not a waypoint: control's K1 guarantee ("an order takes effect within 100 ms") is exactly 3 ticks here.

const TICK_RATE := 30
const TICK_SECONDS := 1.0 / TICK_RATE


## Whole ticks for `seconds` (at least one for any positive duration).
static func ticks(seconds: float) -> int:
	return maxi(1, roundi(seconds * TICK_RATE)) if seconds > 0.0 else 0


## Seconds for `tick_count` ticks.
static func seconds(tick_count: float) -> float:
	return tick_count / TICK_RATE
