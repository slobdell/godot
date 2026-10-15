class_name PlannerExecutor
extends RefCounted
## Round 30 (planner P3): **the harness that drives a PackedPlan's legs through the plant**, line for line the rule the
## k-turn executor uses today (`Movement._planned_reverse` / `_kturn_start_leg`), so the lab compares the PLAN, not a
## different driver: `throttle = THROTTLE * gear`, `turn = steer`; a leg's distance counts from where the hull starts
## rolling in the leg's gear (the roll-out of the last leg is not progress); the leg ends when what is left is within
## the stopping distance in that gear (so the next leg's opposite throttle brakes the hull to rest at the planned end);
## a leg that is not driven in `metres * SECONDS_PER_M + 1 s` (+ the braking from a roll the other way) is aborted, as
## is one making no progress for STALL_S while asked to move. Not reached in play (C30.4): this is the P4 diff.
##
## What differs from today's executor, and why (P4 findings): (1) a leg BRAKES ON ITS OWN LOCK with the opposite
## throttle until the hull has all but stopped, THEN the next leg's gear and steer begin — today's k-turn starts the
## next leg's throttle at once, which works because its legs share one lock; with a steer per leg the braking metres
## would be turned the wrong way; (2) the last leg brakes the same way then commands zero/zero — throttle 0 with the
## lock still on is the plant's CREEP (0.5 throttle forward), which is how a face plan's last leg rolls on today;
## (3) the stopping distance is the discrete plant's, v^2/2b - v*dt/2 (the first braking tick already moves slower):
## today's v^2/2b stops a rig at 8.4 m/s 0.14 m short of its leg; (4) a leg's `driven` is the ARC the hull has
## travelled (the sum of each tick's displacement), not the chord from where it began: today's `_flat_distance(here,
## _kturn_from)` is the chord, 3 % short on a 10 m back-and-fill leg and 16 % short on a 24 m arc (the lab's first
## run over-drove every long leg by 10-13 degrees of heading).

const BRAKE_TO_SPEED := 0.3

## The throttle is the plan's (PlanRequest.throttle_fwd / _rev: the k-turn's 0.7, lowered under a hull's yaw cap).
const SECONDS_PER_M := 1.5               # Movement.KTURN_SECONDS_PER_M
const ROLLING_SPEED := 0.3               # Movement.KTURN_ROLLING_SPEED
const STALL_S := 2.0
const STALL_M := 0.15

var plan: PackedPlan
var tank: Tank
var brake := 8.0
var accel := 8.0
var leg_index := -1
var gear := 0
var steer := 0.0
var left_m := 0.0
var from := Vector3.ZERO
var driven := 0.0
var last := Vector3.ZERO
var rolling := true
var timeout := 0.0
var stall := 0.0
var stall_from := Vector3.ZERO
var done := false
var aborted := false
var reason := ""
var legs_driven := 0
var cusps := 0
var seconds := 0.0
var braking := false


## Round 31 (CP-P1): the executor's state as a Dictionary and back (PlannerSeam.capture / restore for the twin
## harnesses: an executor copied this way drives on exactly as the original would). The plan is shared (never mutated).
const STATE_KEYS: Array[String] = ["brake", "accel", "leg_index", "gear", "steer", "left_m", "from", "driven", "last", "rolling",
		"timeout", "stall", "stall_from", "done", "aborted", "reason", "legs_driven", "cusps", "seconds", "braking"]


func to_state() -> Dictionary:
	var state := {"plan": plan, "tank": tank}
	for key in STATE_KEYS:
		state[key] = get(key)
	return state


static func from_state(state: Dictionary) -> PlannerExecutor:
	var e := PlannerExecutor.new()
	e.plan = state["plan"]
	e.tank = state["tank"]
	for key in STATE_KEYS:
		e.set(key, state[key])
	return e


func start(p_plan: PackedPlan, p_tank: Tank) -> void:
	plan = p_plan
	tank = p_tank
	brake = maxf(float(Units.stat(tank.unit_id, "braking_mps2", 8.0)), 0.1)
	accel = maxf(float(Units.stat(tank.unit_id, "acceleration_mps2", 8.0)), 0.1)
	leg_index = -1
	done = plan.legs.is_empty()
	aborted = false
	reason = "" if not done else "no legs"
	legs_driven = 0
	cusps = 0
	seconds = 0.0
	if not done:
		_begin(0)


func _begin(index: int) -> void:
	var leg := plan.legs[index]
	var next_gear := int(leg.x)
	if gear != 0 and next_gear != gear:
		cusps += 1
	leg_index = index
	gear = next_gear
	steer = leg.y
	left_m = leg.z
	from = tank.global_position
	last = from
	driven = 0.0
	timeout = leg.z * SECONDS_PER_M + 1.0
	rolling = tank.speed() * gear > -ROLLING_SPEED
	if not rolling:
		timeout += absf(tank.speed()) / brake
	stall = 0.0
	stall_from = from
	braking = false
	legs_driven += 1


## Brake now when the leg would otherwise overshoot by more than it now falls short: the discrete plant's braking
## distance from the speed NOW is v^2/2b - v*dt/2; one tick later the hull has moved v'*dt and brakes from v' (the
## next speed, accelerating or at its cap), so the decision flips somewhere inside that increment, and taking it when
## the shortfall is under half the increment ends a leg within a quarter tick's travel of its metres either way.
func _stopping() -> float:
	var v := tank.speed() * float(gear)
	if v < 0.0:
		return 0.0
	var top := float(Units.stat(tank.unit_id, "max_forward_speed" if gear > 0 else "max_reverse_speed", 9.0)) * (plan.throttle_fwd if gear > 0 else plan.throttle_rev)
	var v_next := minf(v + accel * SimClock.TICK_SECONDS, top)
	var stop_now := v * v / (2.0 * brake) - v * SimClock.TICK_SECONDS * 0.5
	var stop_next := v_next * v_next / (2.0 * brake) - v_next * SimClock.TICK_SECONDS * 0.5
	var increment := v_next * SimClock.TICK_SECONDS + stop_next - stop_now
	return stop_now + increment * 0.5


## The command for this tick, or a stop when the plan is finished or aborted.
func tick(delta: float) -> TankCommand:
	if done or aborted:
		return TankCommand.new(0.0, 0.0, tank.global_position + Vector3(0, 0, -20))
	seconds += delta
	var here := tank.global_position
	if not rolling:
		if tank.speed() * gear > ROLLING_SPEED:
			rolling = true
		from = here
	elif tank.speed() * gear > 0.0:
		driven += Vector2(here.x - last.x, here.z - last.z).length()
	last = here
	timeout -= delta
	stall += delta
	if stall >= STALL_S:
		if Vector2(here.x - stall_from.x, here.z - stall_from.z).length() < STALL_M:
			aborted = true
			reason = "stalled on leg %d" % (leg_index + 1)
			return TankCommand.new(0.0, 0.0, here + Vector3(0, 0, -20))
		stall = 0.0
		stall_from = here
	var throttle := plan.throttle_fwd if gear > 0 else plan.throttle_rev
	if braking:
		if tank.speed() * float(gear) > BRAKE_TO_SPEED:
			return TankCommand.new(-throttle * float(gear), steer, here + Vector3(0, 0, -20))  # on the lock: the arc continues
		if leg_index + 1 < plan.legs.size():
			_begin(leg_index + 1)
			var next_throttle := plan.throttle_fwd if gear > 0 else plan.throttle_rev
			return TankCommand.new(next_throttle * float(gear), steer, here + Vector3(0, 0, -20))
		done = true
		reason = "done"
		return TankCommand.new(0.0, 0.0, here + Vector3(0, 0, -20))
	if driven + _stopping() >= left_m:
		braking = true
		return TankCommand.new(-throttle * float(gear), steer, here + Vector3(0, 0, -20))
	if timeout <= 0.0:
		aborted = true
		reason = "timeout on leg %d" % (leg_index + 1)
		return TankCommand.new(0.0, 0.0, here + Vector3(0, 0, -20))
	return TankCommand.new(throttle * float(gear), steer, here + Vector3(0, 0, -20))
