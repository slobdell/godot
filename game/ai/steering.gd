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


# ---- Wheels (K3 locomotion "wheels", round-3 X2) ------------------------------------------------------------------

## Wheels turn by curvature, not in place: yaw rate = speed × turn ÷ minimum turning radius (combat's TankMotion), in
## the direction of `turn` in either gear.
## A wheeled unit backs up (three-point turn) while its point is inside the turning circle on that side (no forward
## turn reaches it), and keeps backing until the point is this far outside it (hysteresis, meters).
const WHEELS_CIRCLE_MARGIN := 1.5
## Heading error for full lock: beyond pure pursuit's gentle arc, swing onto the point, then drive straight.
const WHEELS_FULL_LOCK_DEG := 45.0
## Throttle while backing up in a three-point turn, and the least throttle in a hard forward turn (it must roll to turn).
const WHEELS_REVERSE_THROTTLE := 0.6
const WHEELS_MIN_THROTTLE := 0.35


## Vector2(throttle, turn) for a wheeled hull driving to `target`: pure pursuit (the circle through here and the point,
## tangent to the heading, has curvature 2·sin(error)/distance), easing off in hard turns, and a three-point turn when
## the point is behind and close. `speed` (signed m/s) keeps a turn going the way it started.
static func drive_toward_wheels(position: Vector3, forward: Vector3, target: Vector3, arrive_radius: float,
		min_turn_radius: float, speed: float, remaining_distance: float = -1.0) -> Vector2:
	return _wheels(position, forward, target, arrive_radius, min_turn_radius, speed, remaining_distance, 1.0)


## Like drive_toward_wheels, backing toward `target` with the nose kept away from it (front armor toward the threat).
static func reverse_toward_wheels(position: Vector3, forward: Vector3, target: Vector3, arrive_radius: float,
		min_turn_radius: float, speed: float, remaining_distance: float = -1.0) -> Vector2:
	return _wheels(position, forward, target, arrive_radius, min_turn_radius, speed, remaining_distance, -1.0)


## `gear` +1 drives nose first, -1 tail first. Rotating the hull swings the tail the same way as the nose, so the turn rule
## measured from the tail is the same one (as for tracks in reverse_toward).
static func _wheels(position: Vector3, forward: Vector3, target: Vector3, arrive_radius: float, min_turn_radius: float,
		speed: float, remaining_distance: float, gear: float) -> Vector2:
	var to_target := Vector3(target.x - position.x, 0.0, target.z - position.z)
	var distance := to_target.length()
	if distance <= arrive_radius:
		return Vector2.ZERO
	var slow_for := remaining_distance if remaining_distance >= 0.0 else distance
	var heading := Vector3(forward.x, 0.0, forward.z).normalized() * gear
	# Positive error = the point is to the LEFT (counter-clockwise), which needs turn < 0.
	var error := heading.signed_angle_to(to_target, Vector3.UP)
	var radius := maxf(min_turn_radius, 0.5)
	# The turning circle on the point's side: centered a radius off the hull toward it.
	var left := Vector3(heading.z, 0.0, -heading.x)
	var side := 1.0 if error >= 0.0 else -1.0
	var from_center := (Vector3(position.x, 0.0, position.z) + left * side * radius).distance_to(Vector3(target.x, 0.0, target.z))
	var backing := speed * gear < -0.5
	if from_center < radius or (backing and from_center < radius + WHEELS_CIRCLE_MARGIN):
		# Unreachable going forward: roll the other way at full lock toward the point's side (the hull yaws toward it).
		return Vector2(-WHEELS_REVERSE_THROTTLE * gear, -side)
	# Pure pursuit (the arc through the point, tangent to the heading), or full lock while far off the nose.
	var pursuit := -2.0 * sin(error) / distance * radius
	var swing := -error / deg_to_rad(WHEELS_FULL_LOCK_DEG)
	var turn := clampf(pursuit if absf(pursuit) > absf(swing) else swing, -1.0, 1.0)
	var throttle := clampf(slow_for / SLOW_RADIUS, WHEELS_MIN_THROTTLE, 1.0) * (1.0 - 0.25 * absf(turn))
	return Vector2(maxf(throttle, WHEELS_MIN_THROTTLE) * gear, turn)
