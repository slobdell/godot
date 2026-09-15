class_name FireLanes
extends RefCounted
## Line-of-fire reasoning (_agents/unit_ai.md §4): which friendlies a shot would pass through or splash.
## Friendly fire is on in round 2 (rules), so a brain must never put a shell through a teammate; until rules
## ship it, a teammate still eats the shell. Pure math on positions; `for_shot` adapts to rules' C4 query
## (`Match.friendlies_in_line_of_fire`) when the Match has it.

## Half a hull's length (a friend crossing side-on shows its length) plus a little: a friend whose center is
## this close to the line of fire is in the way.
const HULL_HALF_WIDTH := 2.0
## Spread margin: this many standard deviations of the weapon's (moving) spread, at the friend's distance.
const SPREAD_SIGMAS := 2.0
## Rounds that fly past the aim point keep going: friends this far beyond it still count.
const OVERSHOOT := 3.0
## Arcing rounds: friends within splash radius plus this many standard deviations of scatter.
const SCATTER_SIGMAS := 2.0


## Names of friends (Array of {"name", "position", "velocity"?}) a direct-fire shot from `muzzle` toward `aim`
## could hit. With a `shell_speed` (0 = hitscan), a moving friend is also checked where it will be when the
## shell passes it, so a friend about to cross the lane counts.
static func in_line(muzzle: Vector3, aim: Vector3, friends: Array, spread_deg := 0.0, shell_speed := 0.0) -> Array:
	var result: Array = []
	var line := Vector2(aim.x - muzzle.x, aim.z - muzzle.z)
	var length := line.length()
	if length < 0.01:
		return result
	var along_unit := line / length
	# Small-angle: tan(x) ≈ x for spreads of a few degrees (no library trig, _agents/determinism.md).
	var spread := deg_to_rad(spread_deg) * SPREAD_SIGMAS
	for friend: Dictionary in friends:
		var now := Vector2(friend["position"].x - muzzle.x, friend["position"].z - muzzle.z)
		var spots := [now]
		var velocity: Vector3 = friend.get("velocity", Vector3.ZERO)
		if shell_speed > 0.0 and velocity.length_squared() > 0.01:
			var flight := maxf(now.dot(along_unit), 0.0) / shell_speed
			spots.append(now + Vector2(velocity.x, velocity.z) * flight)
		for offset: Vector2 in spots:
			var along := offset.dot(along_unit)
			if along < 1.0 or along > length + OVERSHOOT:
				continue
			if absf(offset.cross(along_unit)) <= HULL_HALF_WIDTH + along * spread:
				result.append(friend["name"])
				break
	return result


## Names of friends an arcing round aimed at `aim` could splash.
static func in_splash(aim: Vector3, friends: Array, splash_radius: float, scatter_sigma: float) -> Array:
	var result: Array = []
	var reach := splash_radius + SCATTER_SIGMAS * scatter_sigma + HULL_HALF_WIDTH
	for friend: Dictionary in friends:
		if Vector2(friend["position"].x - aim.x, friend["position"].z - aim.z).length() <= reach:
			result.append(friend["name"])
	return result


## Friends `shooter`'s shot at `aim` endangers right now (`tanks_root`: Match/Tanks): rules' C4 query when
## the Match has it, else our own geometry on the living teammates.
static func for_shot(tanks_root: Node, shooter: Tank, aim: Vector3) -> Array:
	if tanks_root == null:
		return []
	var game_match := tanks_root.get_parent() as Match
	if game_match != null and game_match.has_method("friendlies_in_line_of_fire"):
		return (game_match.call("friendlies_in_line_of_fire", shooter, aim) as Array).map(
				func(friend: Variant) -> String: return String(friend.name) if friend is Node else String(friend))
	var weapon := shooter.weapon
	var arcing: bool = weapon["kind"] == Weapons.Kind.ARC
	var muzzle := shooter.global_position
	# Cheap reject: only friends near the burst, or within the line's length of the muzzle, matter.
	var center := aim if arcing else muzzle
	var limit := float(weapon.get("splash_radius", 0.0)) + 20.0 if arcing else muzzle.distance_to(aim) + OVERSHOOT + HULL_HALF_WIDTH
	var friends: Array = []
	var team_tanks: Array = AiTickCache.team_tanks(game_match, shooter.team) if game_match != null else tanks_root.get_children()
	for node in team_tanks:
		var friend := node as Tank
		if friend == null or friend == shooter or friend.team != shooter.team or not friend.is_alive():
			continue
		if friend.global_position.distance_to(center) > limit:
			continue
		friends.append({"name": String(friend.name), "position": friend.global_position, "velocity": friend.estimated_velocity})
	if friends.is_empty():
		return []
	if arcing:
		var sigma := float(weapon.get("scatter", 0.0)) + float(weapon.get("scatter_per_meter", 0.0)) * muzzle.distance_to(aim)
		return in_splash(aim, friends, float(weapon.get("splash_radius", 0.0)), sigma)
	var moving := clampf(absf(shooter.speed()) / maxf(shooter.max_forward_speed, 0.1), 0.0, 1.0)
	var spread := float(weapon.get("spread_deg", 0.0)) * (1.0 + Match.MOVING_SPREAD_FACTOR * moving)
	return in_line(muzzle, aim, friends, spread, Shell.SPEED if weapon["kind"] == Weapons.Kind.PROJECTILE else 0.0)
