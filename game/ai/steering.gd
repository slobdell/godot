class_name Steering
extends RefCounted
## Motor-level driving math (layer 1 in _agents/squad_ai_design.md): turn a goal
## point into throttle and turn. Pure, so it's unit tested without a scene.

## Heading error at which the tank turns at full rate.
const FULL_TURN_ERROR_DEG := 30.0
## Beyond this heading error, stop and turn in place instead of driving a wide arc.
const TURN_IN_PLACE_DEG := 70.0
## Start slowing down within this distance of the goal.
const SLOW_RADIUS := 8.0


## Vector2(throttle, turn) that drives a hull at `position` facing `forward`
## toward `target`. Returns zero once within `arrive_radius`.
static func drive_toward(position: Vector3, forward: Vector3, target: Vector3,
		arrive_radius: float) -> Vector2:
	var to_target := Vector3(target.x - position.x, 0.0, target.z - position.z)
	var distance := to_target.length()
	if distance <= arrive_radius:
		return Vector2.ZERO
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	# Positive error = target is to the LEFT (counter-clockwise), which needs turn < 0.
	var error := flat_forward.signed_angle_to(to_target, Vector3.UP)
	var turn := clampf(-error / deg_to_rad(FULL_TURN_ERROR_DEG), -1.0, 1.0)
	var throttle := 0.0
	if absf(error) < deg_to_rad(TURN_IN_PLACE_DEG):
		throttle = cos(error) * clampf(distance / SLOW_RADIUS, 0.35, 1.0)
	return Vector2(throttle, turn)
