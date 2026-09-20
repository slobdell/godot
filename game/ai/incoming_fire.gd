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
const HORIZON_TICKS := SimClock.TICK_RATE * 5 / 4
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
		if seconds <= 0.0 or seconds * SimClock.TICK_RATE > HORIZON_TICKS:
			continue
		var miss := (offset - flat_velocity * seconds).length()
		if miss > DANGER_RADIUS:
			continue
		var copy := entry.duplicate()
		copy["eta_ticks"] = int(entry.get("eta_ticks", roundi(seconds * SimClock.TICK_RATE)))
		copy["miss"] = miss
		result.append(copy)
	return result


## Before K2: live enemy shells under Match/Shells.
static func _from_shells(game_match: Node, unit: Node3D) -> Array:
	var result: Array = []
	var team := int(unit.get("team"))
	for entry: Array in AiTickCache.rounds(game_match as Match):
		if int(entry[2]) != team:
			result.append({"position": entry[0], "velocity": entry[1], "damage_estimate": Match.BASE_DAMAGE})
	return result


## How many rounds are on their way at `unit` (the for_unit() filter) without building the list: the cheap per-tick
## trigger for a dodge think.
static func count_for(game_match: Node, unit: Node3D) -> int:
	if game_match is Match and unit is Tank:
		return _count_in_flight(game_match as Match, unit as Tank)
	if game_match.has_method("incoming_projectiles"):
		return for_unit(game_match, unit).size()
	var here := Vector3(unit.global_position.x, 0.0, unit.global_position.z)
	var team := int(unit.get("team"))
	var count := 0
	for entry: Array in AiTickCache.rounds(game_match as Match):
		if int(entry[2]) == team:
			continue
		var velocity: Vector3 = entry[1]
		var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
		var offset := here - Vector3((entry[0] as Vector3).x, 0.0, (entry[0] as Vector3).z)
		var seconds := offset.dot(flat_velocity) / maxf(flat_velocity.length_squared(), 1.0)
		if seconds > 0.0 and seconds * SimClock.TICK_RATE <= HORIZON_TICKS and (offset - flat_velocity * seconds).length() <= DANGER_RADIUS:
			count += 1
	return count


## count_for on a real match without building any dictionaries (round-5 X1): Match.incoming_projectiles' filter (not my
## own round, ahead of the round within its remaining range plus my hull, passing within the hull's half-diagonal plus
## Match.INCOMING_MARGIN) followed by for_unit's (HORIZON_TICKS, DANGER_RADIUS), over the tick's shared shell columns.
## Must count exactly what for_unit(...).size() counts: tests/test_ai_perf_equivalence.gd holds it to that.
static var _hull_by_unit := {}


static func _count_in_flight(game_match: Match, unit: Tank) -> int:
	if not unit.is_alive():
		return 0
	var shells := AiTickCache.flight(game_match)
	var xs: PackedFloat32Array = shells["x"]
	if xs.is_empty():
		return 0
	var zs: PackedFloat32Array = shells["z"]
	var dir_x: PackedFloat32Array = shells["dir_x"]
	var dir_z: PackedFloat32Array = shells["dir_z"]
	var vxs: PackedFloat32Array = shells["vx"]
	var vzs: PackedFloat32Array = shells["vz"]
	var reach: PackedFloat64Array = shells["reach"]
	var shooters: PackedStringArray = shells["shooter"]
	# ROUND 9 (combat, in squad's file by squad's own offer -- review and take, replace or revert): the cached
	# `radius` was `Vector2(w, l).length() / 2`, a DISC, and it was used on BOTH axes below -- once to extend a
	# shell's reach along its travel, once as the perpendicular limit. For a War Rig (3.32 x 14.00 m) that disc is
	# 7.19 m against a 1.66 m half-width, and the error is not a constant: 4.3x abeam, 1.03x end-on. So the crew
	# over-reported shells crossing its flank and under-reported nothing, which is the shape that makes a gang pack
	# with a rig in the middle the worst case. Both axes now go through `Units.hull_reach_along`, which is the same
	# projection `Match` uses, so one flag (`--tune=match.hull_disc=1`) flips every consumer and both axes together.
	#
	# The cache holds the (half width, half length) PAIR instead of one radius: `PROFILES` is never written and
	# `hull_size` is authored, so id -> hull is a process constant.
	var half: Vector2 = _hull_by_unit.get(unit.unit_id, Vector2.ZERO)
	if half == Vector2.ZERO:
		half = Units.hull_half_extents(Units.stat(unit.unit_id, "hull_size"))
		_hull_by_unit[unit.unit_id] = half
	var forward := -unit.global_basis.z
	var name := String(unit.name)
	var here_x := unit.global_position.x
	var here_z := unit.global_position.z
	var count := 0
	for i in xs.size():
		# Match.incoming_projectiles, in Vector2 math on the same float values.
		var offset := Vector2(here_x, here_z) - Vector2(xs[i], zs[i])
		var direction := Vector2(dir_x[i], dir_z[i])
		var along := offset.dot(direction)
		var flat_direction := Vector3(direction.x, 0.0, direction.y)
		if along <= 0.0 or along > reach[i] + Units.hull_reach_of(half, forward, flat_direction):
			continue
		if shooters[i] == name or Units.hull_distance_of(half, forward, unit.global_position,
				Vector3(xs[i], 0.0, zs[i]), flat_direction) > Match.INCOMING_MARGIN:
			continue
		# for_unit's own filter, on the round's flat velocity.
		var flat := Vector3(vxs[i], 0.0, vzs[i])
		var speed_squared := flat.length_squared()
		if speed_squared < 1.0:
			continue
		var offset3 := Vector3(here_x - xs[i], 0.0, here_z - zs[i])
		var seconds := offset3.dot(flat) / speed_squared
		if seconds <= 0.0 or seconds * SimClock.TICK_RATE > HORIZON_TICKS:
			continue
		if (offset3 - flat * seconds).length() > DANGER_RADIUS:
			continue
		count += 1
	return count


## Where a unit at `here` driving at `velocity` would be closest to a round (position, velocity), and how close (meters),
## within `seconds`. Dot products only.
static func closest_approach(here: Vector3, velocity: Vector3, round_position: Vector3, round_velocity: Vector3, seconds: float) -> float:
	var offset := Vector3(here.x - round_position.x, 0.0, here.z - round_position.z)
	var relative := Vector3(velocity.x - round_velocity.x, 0.0, velocity.z - round_velocity.z)
	var speed_squared := relative.length_squared()
	var t := 0.0 if speed_squared < 1e-6 else clampf(-offset.dot(relative) / speed_squared, 0.0, seconds)
	return (offset + relative * t).length()
