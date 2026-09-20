class_name PlacementProbe
extends RefCounted
## What actually moves a hull off its spawn placement, frame by frame (feel, round 9).
##
## Built during the `spawns_clear_of_itself` investigation, where three streams each had a hypothesis and none of
## them could be settled by reading code: the replica `sync_position` lerp, a formation writing units into wedge
## slots, and depenetration between the failing pairs. **All three were wrong**, and each was eliminated by a
## number this probe printed rather than by an argument:
##
##   - `simulate=true` on every unit and on the Match, so `Tank._process`'s `if not simulate:` replica branch never
##     runs. The negative control is the strong part: `sync_position` sat 90 m from `placed`, so had that lerp been
##     live the units would have crossed the map, not nudged 1.5 m.
##   - The first lateral jump is ~1.5 m in one tick while `|v|` is 0.20 m/s. At 30 Hz velocity can carry a hull
##     0.0067 m, so the motion is ~200x what the hull's own speed explains: something ASSIGNS the position.
##   - The pairs move TOWARD each other while also sharing a push in +z -- a squeeze alone cancels in z, a carry
##     alone cancels in x. Getting both is what a whole-scene permutation looks like, and it is why every
##     single-cause hypothesis half-fitted.
##
## The cause (squad/combat): on tick 1 every physics BODY is still at the jittered spawn grid position while every
## NODE is in the deploy layout, because Node3D transform notifications batch to the end of the process frame and
## `reset_physics_interpolation()` fixes what is DRAWN, not what is there. The solver spends its first frames
## resolving overlaps that exist only in its own copy of the world.
##
## Keep this. The next person to doubt a placement will want the table, and the lesson it carries is that a scene
## which has not come to rest reports positions that are a snapshot of something still moving -- `settled` and
## `ran out of frames` are different conditions and must be reported as such.
##
## Usage, from a TestCase (`self` supplies `wait_physics_frames`):
##
##     var rows := await PlacementProbe.trace(self, game_match, ["Green_S2_2", "Green_S2_3"], 6)
##     PlacementProbe.print_table(rows)


## One row per frame per watched unit: {frame, name, unit_id, position, delta, speed}. Frame 0 is the placement
## itself, captured before any physics frame runs, with a zero delta.
static func trace(case: Object, game_match: Object, names: Array, frames: int) -> Array:
	var watched: Array = []
	for tank in game_match.tanks_by_name().values():
		if names.is_empty() or names.has(String(tank.name)):
			watched.append(tank)
	var rows: Array = []
	var last := {}
	for tank in watched:
		last[tank] = tank.global_position as Vector3
		rows.append({"frame": 0, "name": String(tank.name), "unit_id": String(tank.unit_id),
				"position": tank.global_position as Vector3, "delta": Vector3.ZERO,
				"speed": (tank.velocity as Vector3).length()})
	for frame in range(1, frames + 1):
		await case.wait_physics_frames(1)
		for tank in watched:
			var now: Vector3 = tank.global_position
			rows.append({"frame": frame, "name": String(tank.name), "unit_id": String(tank.unit_id),
					"position": now, "delta": now - (last[tank] as Vector3),
					"speed": (tank.velocity as Vector3).length()})
			last[tank] = now
	return rows


## The replica state a `simulate=true` unit must be ignoring. Printing this is what killed the `sync_position`
## hypothesis: the lerp is gated on `not simulate`, and the gap between `sync_position` and the placement is large
## enough that a live lerp could not have produced a small displacement.
static func replica_state(game_match: Object, names: Array) -> Array:
	var rows: Array = []
	for tank in game_match.tanks_by_name().values():
		if names.is_empty() or names.has(String(tank.name)):
			rows.append({"name": String(tank.name), "simulate": tank.simulate,
					"sync_position": tank.sync_position as Vector3, "placed": tank.global_position as Vector3})
	return rows


static func print_table(rows: Array) -> void:
	for row: Dictionary in rows:
		var d: Vector3 = row["delta"]
		print("PLACEMENT frame%-3d %-12s %-10s dx%+7.3f dz%+7.3f  |v| %5.2f  at %s"
				% [row["frame"], row["name"], row["unit_id"], d.x, d.z, row["speed"], row["position"]])


static func print_replica(rows: Array) -> void:
	for row: Dictionary in rows:
		print("PLACEMENT %-12s simulate=%s sync_position=%s placed=%s"
				% [row["name"], row["simulate"], row["sync_position"], row["placed"]])
