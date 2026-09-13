class_name Ballistics
extends RefCounted
## Aiming math shared by bots, the agent bridge, and (later) squad AI.


## Where to aim so a projectile of `projectile_speed` fired from `shooter` meets
## a target now at `target` moving at constant `target_velocity`.
## Solves |target + v·t − shooter| = speed·t for the smallest positive t.
## Falls back to the target's current position when no intercept exists.
static func lead_point(shooter: Vector3, target: Vector3, target_velocity: Vector3,
		projectile_speed: float) -> Vector3:
	var offset := target - shooter
	var a := target_velocity.dot(target_velocity) - projectile_speed * projectile_speed
	var b := 2.0 * offset.dot(target_velocity)
	var c := offset.dot(offset)
	var t := -1.0
	if absf(a) < 1e-6:
		if absf(b) > 1e-6:
			t = -c / b
	else:
		var discriminant := b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var root := sqrt(discriminant)
			for candidate in [(-b - root) / (2.0 * a), (-b + root) / (2.0 * a)]:
				if candidate > 0.0 and (t <= 0.0 or candidate < t):
					t = candidate
	if t <= 0.0:
		return target
	return target + target_velocity * t


## Horizontal angle (radians, ≥ 0) between `forward` and the direction from
## `origin` to `point`.
static func aim_error(origin: Vector3, forward: Vector3, point: Vector3) -> float:
	var flat_forward := Vector3(forward.x, 0.0, forward.z)
	var to_point := Vector3(point.x - origin.x, 0.0, point.z - origin.z)
	if flat_forward.length_squared() < 1e-8 or to_point.length_squared() < 1e-8:
		return 0.0
	return absf(flat_forward.signed_angle_to(to_point, Vector3.UP))
