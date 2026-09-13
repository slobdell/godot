class_name TankMotion
extends RefCounted
## Pure movement math for tanks, kept free of nodes so it can be unit tested
## headless and reused later by AI planners ("where will I be in 2 seconds?").


## Next hull speed (m/s) after one tick. Forward and reverse have separate caps.
static func next_speed(speed: float, throttle: float, max_forward: float, max_reverse: float,
		acceleration: float, delta: float) -> float:
	var target := throttle * (max_forward if throttle >= 0.0 else max_reverse)
	return move_toward(speed, target, acceleration * delta)


## Turret yaw (radians, relative to the hull) that points at `local_target`,
## a point already expressed in the hull's local space. Godot's forward is -Z.
static func yaw_toward(local_target: Vector3) -> float:
	return atan2(-local_target.x, -local_target.z)


## Rotate `current` toward `target` by at most `rate * delta`, taking the short
## way around the circle.
static func step_yaw(current: float, target: float, rate: float, delta: float) -> float:
	return rotate_toward(current, target, rate * delta)
