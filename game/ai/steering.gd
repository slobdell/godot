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
## `remaining_distance` (when ≥ 0) is the distance left along a whole path: the
## tank then slows for the path's end, not for every intermediate waypoint.
static func drive_toward(position: Vector3, forward: Vector3, target: Vector3,
		arrive_radius: float, remaining_distance: float = -1.0) -> Vector2:
	var to_target := Vector3(target.x - position.x, 0.0, target.z - position.z)
	var distance := to_target.length()
	if distance <= arrive_radius:
		return Vector2.ZERO
	var slow_for := remaining_distance if remaining_distance >= 0.0 else distance
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	# Positive error = target is to the LEFT (counter-clockwise), which needs turn < 0.
	var error := flat_forward.signed_angle_to(to_target, Vector3.UP)
	var turn := clampf(-error / deg_to_rad(FULL_TURN_ERROR_DEG), -1.0, 1.0)
	var throttle := 0.0
	if absf(error) < deg_to_rad(TURN_IN_PLACE_DEG):
		throttle = cos(error) * clampf(slow_for / SLOW_RADIUS, 0.35, 1.0)
	return Vector2(throttle, turn)


## Like drive_toward, but BACKING toward `target` with the front still facing away
## from it (and so, usually, toward the threat). Slower (reverse speed), but it
## keeps the thick front armor forward. Playtest #2 showed that turning around to
## retreat exposes the rear (×1.5 damage).
static func reverse_toward(position: Vector3, forward: Vector3, target: Vector3,
		arrive_radius: float, remaining_distance: float = -1.0) -> Vector2:
	var to_target := Vector3(target.x - position.x, 0.0, target.z - position.z)
	var distance := to_target.length()
	if distance <= arrive_radius:
		return Vector2.ZERO
	var slow_for := remaining_distance if remaining_distance >= 0.0 else distance
	var backward := -Vector3(forward.x, 0.0, forward.z).normalized()
	# Hull rotation swings the back exactly as it swings the front, so the turn
	# rule is the same as drive_toward's, just measured from the back.
	var error := backward.signed_angle_to(to_target, Vector3.UP)
	var turn := clampf(-error / deg_to_rad(FULL_TURN_ERROR_DEG), -1.0, 1.0)
	var throttle := 0.0
	if absf(error) < deg_to_rad(TURN_IN_PLACE_DEG):
		throttle = -cos(error) * clampf(slow_for / SLOW_RADIUS, 0.35, 1.0)
	return Vector2(throttle, turn)
