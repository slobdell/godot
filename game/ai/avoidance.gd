class_name Avoidance
extends RefCounted
## X3 (round 6): local avoidance that resolves — ORCA, optimal reciprocal collision avoidance (van den Berg, Guy, Lin,
## Manocha 2011; the algorithm behind the RVO2 library, ported here to GDScript over the ground plane's (x, z)).
##
## Every moving unit wants a velocity (toward its next waypoint). For each of its k nearest neighbours — friend AND
## enemy — the set of velocities that would bring the two within their combined radius inside TIME_HORIZON is a
## velocity obstacle; ORCA turns each one into a half-plane of allowed velocities, and each unit takes HALF the
## avoiding (`responsibility` 0.5) on the assumption the other takes the other half. That reciprocity is what stops the
## two-units-mirroring-each-other dance: both step aside a little, to their own right-hand side of the encounter, and
## never both the same way. A neighbour that is not driving anywhere (arrived, parked) takes none of it, so the mover
## takes all of it (responsibility 1). The allowed region is solved as a small 2D linear program for the velocity
## closest to the preferred one; when the constraints leave nothing (a crowd), the least-violating velocity is taken.
##
## Deterministic by construction (invariant 7): a fixed neighbour count, neighbours ordered by distance then name, no
## wall clock, `dt` = the fixed tick. Cheap by construction: one neighbour table per tick for the whole match (a
## uniform grid), and a unit with nobody within NEIGHBOUR_RADIUS does no ORCA work at all.

## Look this far ahead for collisions (seconds). Longer is smoother and more conservative; shorter lets a crowd pack.
const TIME_HORIZON := 2.0
## Neighbours considered, nearest first (fixed: invariant 7).
const MAX_NEIGHBOURS := 6
## ...within this distance (flat metres, centre to centre).
const NEIGHBOUR_RADIUS := 14.0
## Grid cell for the neighbour table (metres): at least NEIGHBOUR_RADIUS / 2 so a query walks a 5x5 block at most.
const CELL := 8.0
## A hull's avoidance radius: the mean of its half-width and half-length, plus this margin (metres). A circle can't
## fit a 2.4 x 3.8 box; the mean is the usual compromise for elongated vehicles, and the margin keeps paint off paint.
const RADIUS_MARGIN := 0.25
const EPSILON := 0.00001

## The shared per-tick table: [key, names, xs, zs, vxs, vzs, radii, still, grid]. Built by the first mover each tick
## (every controller runs before any tank moves, so all of them see this tick's positions).
static var _table_key := ""
static var _names := PackedStringArray()
static var _xs := PackedFloat32Array()
static var _zs := PackedFloat32Array()
static var _vxs := PackedFloat32Array()
static var _vzs := PackedFloat32Array()
static var _radii := PackedFloat32Array()
static var _still: Array[bool] = []
static var _grid := {}
static var _index := {}
static var _radius_by_unit := {}

## Measurement only (make ai-perf): units that ran the solver, and ticks the chosen velocity differed from the wish.
static var solved := 0
static var deflected := 0


## A hull's avoidance radius by unit type (cached: the catalog doesn't change mid-match).
static func radius_of(unit_id: String) -> float:
	if not _radius_by_unit.has(unit_id):
		var size: Variant = Units.stat(unit_id, "hull_size", [2.4, 1.6, 3.8])
		_radius_by_unit[unit_id] = (float(size[0]) + float(size[2])) / 4.0 + RADIUS_MARGIN
	return float(_radius_by_unit[unit_id])


## Build (once per tick) the table of every living hull under `tanks_root`.
static func refresh(tanks_root: Node) -> void:
	var key := "%d:%d" % [tanks_root.get_instance_id(), Engine.get_physics_frames()]
	if key == _table_key:
		return
	_table_key = key
	_names = PackedStringArray()
	_xs = PackedFloat32Array()
	_zs = PackedFloat32Array()
	_vxs = PackedFloat32Array()
	_vzs = PackedFloat32Array()
	_radii = PackedFloat32Array()
	_still.clear()
	_grid = {}
	_index = {}
	for child in tanks_root.get_children():
		var tank := child as Tank
		if tank == null or not tank.is_alive():
			continue
		var i := _names.size()
		var p := tank.global_position
		_names.append(String(tank.name))
		_xs.append(p.x)
		_zs.append(p.z)
		_vxs.append(tank.estimated_velocity.x)
		_vzs.append(tank.estimated_velocity.z)
		_radii.append(radius_of(tank.unit_id))
		var mover := Movement.of(tank)
		_still.append(mover == null or not mover.is_under_way())
		_index[String(tank.name)] = i
		var cell := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		_add_to_cell(cell, i)


## Packed arrays are values (trip-up 48): append to a copy and put it back.
static func _add_to_cell(cell: Vector2i, i: int) -> void:
	var members: PackedInt32Array = _grid.get(cell, PackedInt32Array())
	members.append(i)
	_grid[cell] = members


## Tests: load the table directly. `rows` = [[name, x, z, vx, vz, radius, still], ...].
static func load_rows(rows: Array) -> void:
	_table_key = "rows"
	_names = PackedStringArray()
	_xs = PackedFloat32Array()
	_zs = PackedFloat32Array()
	_vxs = PackedFloat32Array()
	_vzs = PackedFloat32Array()
	_radii = PackedFloat32Array()
	_still.clear()
	_grid = {}
	_index = {}
	for row: Array in rows:
		var i := _names.size()
		_names.append(String(row[0]))
		_xs.append(float(row[1]))
		_zs.append(float(row[2]))
		_vxs.append(float(row[3]))
		_vzs.append(float(row[4]))
		_radii.append(float(row[5]))
		_still.append(bool(row[6]))
		_index[String(row[0])] = i
		var cell := Vector2i(floori(float(row[1]) / CELL), floori(float(row[2]) / CELL))
		_add_to_cell(cell, i)


## Up to MAX_NEIGHBOURS table rows within NEIGHBOUR_RADIUS of (x, z), nearest first, ties by name; `me` excluded.
static func neighbours(me: String, x: float, z: float) -> Array:
	var found: Array = []
	var reach_sq := NEIGHBOUR_RADIUS * NEIGHBOUR_RADIUS
	var span := ceili(NEIGHBOUR_RADIUS / CELL)
	var cx := floori(x / CELL)
	var cz := floori(z / CELL)
	for gx in range(cx - span, cx + span + 1):
		for gz in range(cz - span, cz + span + 1):
			var cell: Variant = _grid.get(Vector2i(gx, gz))
			if cell == null:
				continue
			for i: int in cell:
				var dx := _xs[i] - x
				var dz := _zs[i] - z
				var d := dx * dx + dz * dz
				if d < reach_sq and _names[i] != me:
					found.append([d, _names[i], i])
	found.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and String(a[1]) < String(b[1])))
	if found.size() > MAX_NEIGHBOURS:
		found.resize(MAX_NEIGHBOURS)
	return found


## Is row `name` in this tick's table standing still (nothing to drive to)? False for unknown names.
static func is_still(name: String) -> bool:
	var i: Variant = _index.get(name)
	return i != null and _still[int(i)]


## The velocity (x, z) to drive this tick: the one closest to `preferred` that keeps clear of every neighbour for
## TIME_HORIZON, assuming movers share the avoiding. `dt` is the fixed tick.
static func solve(me: String, position: Vector2, velocity: Vector2, preferred: Vector2, max_speed: float,
		radius: float, dt: float) -> Vector2:
	var near := neighbours(me, position.x, position.y)
	if near.is_empty():
		return preferred
	solved += 1
	var inv_horizon := 1.0 / TIME_HORIZON
	var points: Array[Vector2] = []
	var directions: Array[Vector2] = []
	for entry: Array in near:
		var i: int = entry[2]
		var relative_position := Vector2(_xs[i] - position.x, _zs[i] - position.y)
		var other_velocity := Vector2(_vxs[i], _vzs[i])
		var relative_velocity := velocity - other_velocity
		var distance_sq := relative_position.length_squared()
		var combined := radius + _radii[i]
		var combined_sq := combined * combined
		var direction: Vector2
		var u: Vector2
		if distance_sq > combined_sq:
			# No collision yet: the obstacle is the truncated cone; project onto its cut-off circle or a leg.
			var w := relative_velocity - relative_position * inv_horizon
			var w_length_sq := w.length_squared()
			var dot1 := w.dot(relative_position)
			if dot1 < 0.0 and dot1 * dot1 > combined_sq * w_length_sq:
				var w_length := sqrt(w_length_sq)
				var unit_w := w / w_length
				direction = Vector2(unit_w.y, -unit_w.x)
				u = unit_w * (combined * inv_horizon - w_length)
			else:
				var leg := sqrt(distance_sq - combined_sq)
				if _det(relative_position, w) > 0.0:
					direction = Vector2(relative_position.x * leg - relative_position.y * combined,
							relative_position.x * combined + relative_position.y * leg) / distance_sq
				else:
					direction = -Vector2(relative_position.x * leg + relative_position.y * combined,
							-relative_position.x * combined + relative_position.y * leg) / distance_sq
				u = direction * relative_velocity.dot(direction) - relative_velocity
		else:
			# Already overlapping: get out within one tick.
			var inv_dt := 1.0 / dt
			var w := relative_velocity - relative_position * inv_dt
			var w_length := w.length()
			var unit_w := w / w_length if w_length > EPSILON else Vector2(0.0, 1.0)
			if distance_sq < 0.01:
				# Two hulls on the same spot (a respawn, an overfull spawn line): the geometry gives both the same way
				# out, so they never part. The name decides who goes which way — each exactly opposite the other.
				unit_w = Vector2(1.0, 0.0) if me < _names[i] else Vector2(-1.0, 0.0)
				w_length = 0.0
			direction = Vector2(unit_w.y, -unit_w.x)
			u = unit_w * (combined * inv_dt - w_length)
		var share := 1.0 if _still[i] else 0.5
		points.append(velocity + u * share)
		directions.append(direction)
	var holder: Array = [Vector2.ZERO]
	var failed := _program2(points, directions, max_speed, preferred, false, holder)
	var result: Vector2 = holder[0]
	if failed < points.size():
		result = _program3(points, directions, failed, max_speed, result)
	if result.distance_squared_to(preferred) > 0.01:
		deflected += 1
	return result


static func _det(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x


## RVO2 linearProgram1: the best point on line `n` within the speed circle and every earlier line. False = infeasible.
static func _program1(points: Array[Vector2], directions: Array[Vector2], n: int, radius: float, optimal: Vector2,
		direction_opt: bool, holder: Array) -> bool:
	var dot := points[n].dot(directions[n])
	var discriminant := dot * dot + radius * radius - points[n].length_squared()
	if discriminant < 0.0:
		return false
	var root := sqrt(discriminant)
	var t_left := -dot - root
	var t_right := -dot + root
	for i in n:
		var denominator := _det(directions[n], directions[i])
		var numerator := _det(directions[i], points[n] - points[i])
		if absf(denominator) <= EPSILON:
			if numerator < 0.0:
				return false
			continue
		var t := numerator / denominator
		if denominator >= 0.0:
			t_right = minf(t_right, t)
		else:
			t_left = maxf(t_left, t)
		if t_left > t_right:
			return false
	if direction_opt:
		if optimal.dot(directions[n]) > 0.0:
			holder[0] = points[n] + directions[n] * t_right
		else:
			holder[0] = points[n] + directions[n] * t_left
	else:
		var t := clampf(directions[n].dot(optimal - points[n]), t_left, t_right)
		holder[0] = points[n] + directions[n] * t
	return true


## RVO2 linearProgram2: the velocity closest to `optimal` satisfying every line. Returns the first line it failed on,
## or the line count when it satisfied them all; the answer is in holder[0].
static func _program2(points: Array[Vector2], directions: Array[Vector2], radius: float, optimal: Vector2,
		direction_opt: bool, holder: Array) -> int:
	if direction_opt:
		holder[0] = optimal * radius
	elif optimal.length_squared() > radius * radius:
		holder[0] = optimal.normalized() * radius
	else:
		holder[0] = optimal
	for i in points.size():
		if _det(directions[i], points[i] - (holder[0] as Vector2)) > 0.0:
			var before: Vector2 = holder[0]
			if not _program1(points, directions, i, radius, optimal, direction_opt, holder):
				holder[0] = before
				return i
	return points.size()


## RVO2 linearProgram3: when the constraints are infeasible (a crowd), the velocity that violates them least.
static func _program3(points: Array[Vector2], directions: Array[Vector2], begin: int, radius: float,
		result: Vector2) -> Vector2:
	var distance := 0.0
	for i in range(begin, points.size()):
		if _det(directions[i], points[i] - result) <= distance:
			continue
		var projected_points: Array[Vector2] = []
		var projected_directions: Array[Vector2] = []
		for j in i:
			var determinant := _det(directions[i], directions[j])
			var point: Vector2
			if absf(determinant) <= EPSILON:
				if directions[i].dot(directions[j]) > 0.0:
					continue
				point = (points[i] + points[j]) * 0.5
			else:
				point = points[i] + directions[i] * (_det(directions[j], points[i] - points[j]) / determinant)
			projected_points.append(point)
			projected_directions.append((directions[j] - directions[i]).normalized())
		var holder: Array = [result]
		if _program2(projected_points, projected_directions, radius, Vector2(-directions[i].y, directions[i].x), true,
				holder) < projected_points.size():
			holder[0] = result
		result = holder[0]
		distance = _det(directions[i], points[i] - result)
	return result
