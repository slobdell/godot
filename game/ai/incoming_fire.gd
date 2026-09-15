class_name IncomingFire
extends RefCounted
## Round-3 X3: projectiles that may hit a unit, for dodging. Contract K2: `Match.incoming_projectiles(unit)` returns
## [{position, velocity, eta_ticks, damage_estimate}] once combat ships it (CP2); until then this reads the match's
## Shells container itself. Either way brains get the same shape plus "miss" (the closest the round passes to the
## unit's current position if the unit stood still, meters).
##
## Portable: closest approach is dot products only (_agents/determinism.md). Shells are read in scene order (spawn
## order), which is the same on every run.

## Rounds arriving later than this aren't worth reacting to yet (ticks).
const HORIZON_TICKS := 75
## ...nor rounds that would pass farther than this from where the unit is now (meters).
const DANGER_RADIUS := 6.0


static func for_unit(game_match: Node, unit: Node3D) -> Array:
	var raw: Array = []
	if game_match.has_method("incoming_projectiles"):
		raw = game_match.call("incoming_projectiles", unit)
	else:
		raw = _from_shells(game_match, unit)
	var result: Array = []
	var here := Vector3(unit.global_position.x, 0.0, unit.global_position.z)
	for entry: Dictionary in raw:
		var position: Vector3 = entry["position"]
		var velocity: Vector3 = entry["velocity"]
		var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
		var speed_squared := flat_velocity.length_squared()
		if speed_squared < 1.0:
			continue
		var offset := here - Vector3(position.x, 0.0, position.z)
		var seconds := offset.dot(flat_velocity) / speed_squared
		if seconds <= 0.0 or seconds * 60.0 > HORIZON_TICKS:
			continue
		var miss := (offset - flat_velocity * seconds).length()
		if miss > DANGER_RADIUS:
			continue
		var copy := entry.duplicate()
		copy["eta_ticks"] = int(entry.get("eta_ticks", roundi(seconds * 60.0)))
		copy["miss"] = miss
		result.append(copy)
	return result


## Before K2: live enemy shells under Match/Shells.
static func _from_shells(game_match: Node, unit: Node3D) -> Array:
	var shells := game_match.get_node_or_null("Shells")
	var result: Array = []
	if shells == null:
		return result
	var team := int(unit.get("team"))
	for node in shells.get_children():
		var shell := node as Shell
		if shell == null or shell.team == team or not shell.is_physics_processing():
			continue
		result.append({"position": shell.global_position, "velocity": shell.direction * Shell.SPEED,
				"damage_estimate": Match.BASE_DAMAGE})
	return result


## Where a unit at `here` driving at `velocity` would be closest to a round (position, velocity), and how close (meters),
## within `seconds`. Dot products only.
static func closest_approach(here: Vector3, velocity: Vector3, round_position: Vector3, round_velocity: Vector3, seconds: float) -> float:
	var offset := Vector3(here.x - round_position.x, 0.0, here.z - round_position.z)
	var relative := Vector3(velocity.x - round_velocity.x, 0.0, velocity.z - round_velocity.z)
	var speed_squared := relative.length_squared()
	var t := 0.0 if speed_squared < 1e-6 else clampf(-offset.dot(relative) / speed_squared, 0.0, seconds)
	return (offset + relative * t).length()
