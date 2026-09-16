class_name TankMotion
extends RefCounted
## Pure movement math for tanks, kept free of nodes so it can be unit tested
## headless and reused later by AI planners ("where will I be in 2 seconds?").
##
## K3 (round 3): `predict(state, throttle, turn, ticks)` rolls a hull forward without a scene. A motion state is a
## plain Dictionary: position (Vector3), forward (flat unit Vector3), speed (m/s along forward, negative in reverse),
## velocity (Vector3, m/s), plus the unit's locomotion numbers (see state_for). Headings are unit vectors turned by
## small-angle steps and renormalized (`√` only, no per-tick trig: _agents/determinism.md guideline 4).

## The physics tick length the simulation runs at (`--fixed-fps 60`).
const TICK_SECONDS := 1.0 / 60.0


## Next hull speed (m/s) after one tick. Forward and reverse have separate caps.
static func next_speed(speed: float, throttle: float, max_forward: float, max_reverse: float,
		acceleration: float, delta: float) -> float:
	var target := throttle * (max_forward if throttle >= 0.0 else max_reverse)
	return move_toward(speed, target, acceleration * delta)


## Like next_speed, but shedding speed (toward zero or through it) uses `braking` instead of `acceleration`.
static func next_speed_braking(speed: float, throttle: float, max_forward: float, max_reverse: float,
		acceleration: float, braking: float, delta: float) -> float:
	var target := throttle * (max_forward if throttle >= 0.0 else max_reverse)
	var slowing := absf(target) < absf(speed) or target * speed < 0.0
	return move_toward(speed, target, (braking if slowing else acceleration) * delta)


## Turret yaw (radians, relative to the hull) that points at `local_target`,
## a point already expressed in the hull's local space. Godot's forward is -Z.
static func yaw_toward(local_target: Vector3) -> float:
	return atan2(-local_target.x, -local_target.z)


## Rotate `current` toward `target` by at most `rate * delta`, taking the short
## way around the circle.
static func step_yaw(current: float, target: float, rate: float, delta: float) -> float:
	return rotate_toward(current, target, rate * delta)


## A motion state for a unit type at a pose (K3). `forward` is flattened and normalized.
static func state_for(unit_id: String, position: Vector3, forward: Vector3, speed: float = 0.0) -> Dictionary:
	var flat := Vector3(forward.x, 0.0, forward.z).normalized()
	var stat := func(key: String, fallback: Variant) -> Variant: return Units.stat(unit_id, key, fallback)
	return {"position": position, "forward": flat, "speed": speed, "velocity": flat * speed,
			"locomotion": String(stat.call("locomotion", "tracks")),
			"max_forward_speed": float(stat.call("max_forward_speed", 9.0)),
			"max_reverse_speed": float(stat.call("max_reverse_speed", 4.0)),
			"hull_turn_rate_deg": float(stat.call("hull_turn_rate_deg", 80.0)),
			"acceleration_mps2": float(stat.call("acceleration_mps2", 14.0)),
			"braking_mps2": float(stat.call("braking_mps2", 14.0)),
			"min_turn_radius_m": float(stat.call("min_turn_radius_m", 0.0)),
			"lateral_grip": float(stat.call("lateral_grip", 1.0))}


## The motion state of a live tank (simulating peer: exact speed; clients: estimated).
static func state_of(tank: Tank) -> Dictionary:
	var state := state_for(tank.unit_id, tank.global_position, -tank.global_basis.z, tank.speed())
	state["velocity"] = tank.estimated_velocity
	state["max_forward_speed"] = tank.max_forward_speed
	state["max_reverse_speed"] = tank.max_reverse_speed
	state["hull_turn_rate_deg"] = rad_to_deg(tank.hull_turn_rate)
	return state


## Poses after each of the next `ticks` ticks holding `throttle` (-1..1) and `turn` (-1 left .. 1 right).
## Pure: `state` is not modified. Ignores collisions (walls, other hulls).
static func predict(state: Dictionary, throttle: float, turn: float, ticks: int) -> Array:
	var poses: Array = []
	var current := state.duplicate()
	for i in maxi(ticks, 0):
		step_in_place(current, throttle, turn, TICK_SECONDS)
		poses.append({"position": current["position"], "forward": current["forward"], "speed": current["speed"],
				"velocity": current["velocity"]})
	return poses


## One tick of driving: returns a new state (the input is not modified).
static func step(state: Dictionary, throttle: float, turn: float, delta: float) -> Dictionary:
	var next := state.duplicate()
	step_in_place(next, throttle, turn, delta)
	return next


## X4: a turn command with (almost) no throttle is a multi-point turn on wheels: short legs at this fraction of full
## throttle per unit of turn, alternating forward and reverse every CREEP_LEG_TICKS while yawing the commanded way (turn
## is the hull's yaw in either gear), so tank-style "turn in place" steering rotates a car near its spot instead of
## stalling or driving off in a circle. The first leg keeps the direction of travel (backward when already reversing
## faster than CREEP_REVERSE_SPEED). State keys: creep_dir (-1, 0, 1) and creep_ticks.
const WHEEL_CREEP_THROTTLE := 0.5
const CREEP_REVERSE_SPEED := 0.5
const CREEP_LEG_TICKS := 30


## One tick of driving, updating `state` in place (the Tank keeps one state and steps it every physics tick).
##   tracks: the hull turns at hull_turn_rate_deg whatever the speed (a pivot at a standstill); no sideways slide.
##   wheels: yaw rate = |speed| / turning radius (speed at the start of the tick; full lock = min_turn_radius_m), capped
##     at hull_turn_rate_deg, so a car can't turn standing still. `turn` is the way the HULL should yaw in either gear:
##     in reverse the wheels steer opposite to get it (a driver's inverted steering, done for the brain). Momentum: the
##     velocity is split along the new heading, the sideways part keeps sliding and lateral_grip kills that fraction of
##     it each tick (1 = carve, lower = drift), and the forward part accelerates or brakes.
##   hover (L3, round 4, the Syndicate): swings to face at hull_turn_rate_deg at ANY speed, because nothing needs
##     traction to do it, but nothing grips the ground either, so momentum carries exactly as it does on wheels.
##     The result is a hull that can face one way and travel another: it strafes, and it drifts through a turn.
static func step_in_place(state: Dictionary, throttle: float, turn: float, delta: float) -> void:
	var throttle_c := clampf(throttle, -1.0, 1.0)
	var turn_c := clampf(turn, -1.0, 1.0)
	var forward: Vector3 = state["forward"]
	var speed := float(state["speed"])
	var velocity: Vector3
	var max_rate := deg_to_rad(float(state["hull_turn_rate_deg"]))
	if String(state["locomotion"]) == "wheels":
		var creep := WHEEL_CREEP_THROTTLE * absf(turn_c)
		if absf(throttle_c) < creep:
			var direction := int(state.get("creep_dir", 0))
			var leg := int(state.get("creep_ticks", 0))
			if direction == 0:
				direction = -1 if throttle_c < 0.0 or (throttle_c == 0.0 and speed < -CREEP_REVERSE_SPEED) else 1
				leg = 0
			elif leg >= CREEP_LEG_TICKS:
				direction = -direction
				leg = 0
			state["creep_dir"] = direction
			state["creep_ticks"] = leg + 1
			throttle_c = creep * direction
		else:
			state["creep_dir"] = 0
			state["creep_ticks"] = 0
		var radius := maxf(float(state["min_turn_radius_m"]), 0.1)
		var yaw_rate := clampf(absf(speed) * turn_c / radius, -max_rate, max_rate)
		forward = turn_heading(forward, yaw_rate * delta)
		var right := Vector3(-forward.z, 0.0, forward.x)
		var carried: Vector3 = state["velocity"]
		var along := next_speed_braking(carried.dot(forward), throttle_c, float(state["max_forward_speed"]),
				float(state["max_reverse_speed"]), float(state["acceleration_mps2"]), float(state["braking_mps2"]), delta)
		var sideways := carried.dot(right)
		sideways -= sideways * clampf(float(state["lateral_grip"]) * delta * 60.0, 0.0, 1.0)
		speed = along
		velocity = forward * along + right * sideways
	elif String(state["locomotion"]) == "hover":
		forward = turn_heading(forward, turn_c * max_rate * delta)
		var right := Vector3(-forward.z, 0.0, forward.x)
		var carried: Vector3 = state["velocity"]
		var along := next_speed_braking(carried.dot(forward), throttle_c, float(state["max_forward_speed"]),
				float(state["max_reverse_speed"]), float(state["acceleration_mps2"]), float(state["braking_mps2"]), delta)
		var sideways := carried.dot(right)
		sideways -= sideways * clampf(float(state["lateral_grip"]) * delta * 60.0, 0.0, 1.0)
		speed = along
		velocity = forward * along + right * sideways
	else:
		forward = turn_heading(forward, turn_c * max_rate * delta)
		speed = next_speed_braking(speed, throttle_c, float(state["max_forward_speed"]), float(state["max_reverse_speed"]),
				float(state["acceleration_mps2"]), float(state["braking_mps2"]), delta)
		velocity = forward * speed
	state["forward"] = forward
	state["speed"] = speed
	state["velocity"] = Vector3(velocity.x, 0.0, velocity.z)
	state["position"] = (state["position"] as Vector3) + velocity * delta


## `forward` (a flat unit vector) turned clockwise seen from above (to the RIGHT) by `radians` (negative = left).
## A small-angle step renormalized: exact to ~radians³/3 per call, which at ≤ 3° per tick is far below a millimeter.
static func turn_heading(forward: Vector3, radians: float) -> Vector3:
	if radians == 0.0:
		return forward
	var right := Vector3(-forward.z, 0.0, forward.x)
	return (forward + right * radians).normalized()
