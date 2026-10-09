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
## Which table is loaded: [root instance id, physics frame] for a tick's table, [-1, -1] for one loaded by a test.
## Round 16 (A5): two ints, compared every call by every mover, instead of a String formatted for each comparison.
static var _table_root := -1
static var _table_frame := -1
static var _names := PackedStringArray()
static var _xs := PackedFloat32Array()
static var _zs := PackedFloat32Array()
static var _vxs := PackedFloat32Array()
static var _vzs := PackedFloat32Array()
static var _radii := PackedFloat32Array()
## Round 10 (nav item 4): each hull's half-width, half-length and flat heading, for the oriented radius.
static var _half_w := PackedFloat32Array()
static var _half_l := PackedFloat32Array()
static var _fxs := PackedFloat32Array()
static var _fzs := PackedFloat32Array()
static var _still: Array[bool] = []
static var _grid := {}
static var _index := {}
static var _radius_by_unit := {}

## Measurement only (make ai-perf): units that ran the solver, and ticks the chosen velocity differed from the wish.
static var solved := 0
static var deflected := 0


## Round 10 (nav item 4): **the seventh disc site, oriented.** `radius_of` is `(w + l) / 4 + margin`, one number for
## every direction: 4.58 m for the War Rig (3.32 × 14) against a real half-width of 1.66 m — too wide ABEAM (two rigs
## side by side in a 16 m street are kept 9.2 m apart centre to centre) and too narrow END-ON (nose to tail they may
## close to 9.2 m when their boxes need 14). With the arm on, each neighbour pair's combined radius is the two boxes'
## SUPPORT distances along the line between their centres, `hw·|d·right| + hl·|d·forward|` for each, plus both
## margins: 3.82 m abeam and 14.5 m end-on for two rigs. Clearance tier: STATIC FOOTPRINT (B5), measured along the
## line of approach; still a disc per pair, so ORCA's geometry is untouched.
##
## OPT-IN (`--nav-off=oriented` turns it ON) until its falsifier says (the defile dispersion and the yard oscillation
## share must not worsen). Arm counter: `oriented_pairs`.
static var oriented_pairs := 0


static func oriented_on() -> bool:
	return Movement.switched_off("oriented")


## The combined avoidance radius of rows `a` and `b` along the unit direction `d` from a to b.
static func pair_radius(a: int, b: int, d: Vector2) -> float:
	return _support(a, d) + _support(b, d) + 2.0 * RADIUS_MARGIN


static func _support(i: int, d: Vector2) -> float:
	var forward := Vector2(_fxs[i], _fzs[i])
	var right := Vector2(-forward.y, forward.x)
	return _half_w[i] * absf(d.dot(right)) + _half_l[i] * absf(d.dot(forward))


## A hull's avoidance radius by unit type (cached: the catalog doesn't change mid-match).
static func radius_of(unit_id: String) -> float:
	if not _radius_by_unit.has(unit_id):
		# One accessor, shared with movement.gd: an unknown id is an error naming the id, and the fallback is
		# Units.DEFAULT's live box rather than a pre-CP2 literal frozen in three files.
		var size: Array = Movement.hull_box(unit_id)
		_radius_by_unit[unit_id] = (float(size[0]) + float(size[2])) / 4.0 + RADIUS_MARGIN
	return float(_radius_by_unit[unit_id])


## Round 16 (A5): a hull's half-width and half-length by unit type, cached like radius_of (the catalog doesn't change
## mid-match; the same floats the per-tick table computed from Movement.hull_box every tick for every hull).
static var _halves_by_unit := {}


static func _halves_of(unit_id: String) -> Vector2:
	var known: Variant = _halves_by_unit.get(unit_id)
	if known == null:
		var box: Array = Movement.hull_box(unit_id)
		known = Vector2(float(box[0]) * 0.5, float(box[2]) * 0.5)
		_halves_by_unit[unit_id] = known
	return known


## Build (once per tick) the table of every living hull under `tanks_root`.
static func refresh(tanks_root: Node) -> void:
	var root := tanks_root.get_instance_id()
	var frame := Engine.get_physics_frames()
	if root == _table_root and frame == _table_frame:
		return
	_table_root = root
	_table_frame = frame
	TickProfile.ensure(tanks_root)  # measurement only: a no-op unless --native-tick-profile=A,B
	if BrainSwitches.native and _gather_native(tanks_root):
		if BrainSwitches.native and BrainSwitches.native_record:
			_fill_record(tanks_root)
		return
	_gd_stale = false
	_names = PackedStringArray()
	_xs = PackedFloat32Array()
	_zs = PackedFloat32Array()
	_vxs = PackedFloat32Array()
	_vzs = PackedFloat32Array()
	_radii = PackedFloat32Array()
	_half_w = PackedFloat32Array()
	_half_l = PackedFloat32Array()
	_fxs = PackedFloat32Array()
	_fzs = PackedFloat32Array()
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
		if BrainSwitches.avoid_halves:
			var halves: Vector2 = _halves_of(tank.unit_id)
			_half_w.append(halves.x)
			_half_l.append(halves.y)
		else:
			var box: Array = Movement.hull_box(tank.unit_id)
			_half_w.append(float(box[0]) * 0.5)
			_half_l.append(float(box[2]) * 0.5)
		var heading := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
		_fxs.append(heading.x)
		_fzs.append(heading.y)
		var mover := Movement.of(tank)
		_still.append(mover == null or not mover.is_under_way())
		_index[String(tank.name)] = i
		var cell := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		_add_to_cell(cell, i)
	_load_native()
	if BrainSwitches.native and BrainSwitches.native_record:
		_fill_record(tanks_root)


## Round 24 (native): the table gathered by the C++ (TankNative.avoidance_gather: the same hulls, order and widths as
## the build below; 578 usec a tick of GDScript at 50 v 50, `bfc00f53` builder0). The GDScript columns are then stale
## until a GDScript reader asks (`_ensure_gd`: neighbours, is_still, the GDScript solve, movement.gd's readers, which
## all go through neighbours first). Only while the `native` master switch is on: `--brains-off=native` (the
## reference run) builds it in GDScript below, which also loads the native table (`_load_native`).
static var _gd_stale := false
## unit id -> PackedFloat64Array[radius_of, half width, half length] (the GDScript statics the C++ cannot call).
static var _unit_rows := {}


static func _gather_native(tanks_root: Node) -> bool:
	var missing: PackedStringArray = NativeBridge.impl.avoidance_gather(tanks_root, Movement._registry, _unit_rows)
	if not missing.is_empty():
		for unit_id in missing:
			var halves: Vector2 = _halves_of(unit_id)
			_unit_rows[unit_id] = PackedFloat64Array([radius_of(unit_id), halves.x, halves.y])
		missing = NativeBridge.impl.avoidance_gather(tanks_root, Movement._registry, _unit_rows)
	_gd_stale = missing.is_empty()
	return _gd_stale


## The GDScript columns from the native table, the first time a GDScript reader asks after a native gather.
static func _ensure_gd() -> void:
	if not _gd_stale:
		return
	_gd_stale = false
	var columns: Dictionary = NativeBridge.impl.avoidance_columns()
	_names = columns["names"]
	_xs = columns["xs"]
	_zs = columns["zs"]
	_vxs = columns["vxs"]
	_vzs = columns["vzs"]
	_radii = columns["radii"]
	_half_w = columns["half_w"]
	_half_l = columns["half_l"]
	_fxs = columns["fxs"]
	_fzs = columns["fzs"]
	var still: PackedByteArray = columns["still"]
	_still.clear()
	_grid = {}
	_index = {}
	for i in _names.size():
		_still.append(still[i] != 0)
		_index[_names[i]] = i
		_add_to_cell(Vector2i(floori(_xs[i] / CELL), floori(_zs[i] / CELL)), i)


## Round 24 (native, N3a): the per-tank record and the contacts tables, filled here because this is the one place that
## already walks every hull once a tick (the record's neighbour set is this table's). Priced by the in-run A/B
## (`AB_SWITCH=native_record`) and by its own profile part.
static func _fill_record(tanks_root: Node) -> void:
	var lap := Time.get_ticks_usec() if OrderController.profiling else 0
	NativeRecord.fill(tanks_root)
	NativeRecord.fill_contacts(tanks_root.get_parent() as Match)
	if OrderController.profiling:
		OrderController.add_part("native.fill", Time.get_ticks_usec() - lap)


## Round 23 (native, N1): the same columns, once a tick, to the native table (native/src/avoidance.cpp), which
## `solve` routes to while BrainSwitches.native is on. Loaded whenever the library is there, not only while the switch
## is on: the in-run A/B flips the switch between ticks and must find this tick's table either way.
static func _load_native() -> void:
	if not NativeBridge.available:
		return
	var still := PackedByteArray()
	still.resize(_still.size())
	for i in _still.size():
		still[i] = 1 if _still[i] else 0
	NativeBridge.impl.avoidance_load(_names, _xs, _zs, _vxs, _vzs, _radii, _half_w, _half_l, _fxs, _fzs, still)


## Packed arrays are values (trip-up 48): append to a copy and put it back.
static func _add_to_cell(cell: Vector2i, i: int) -> void:
	var members: PackedInt32Array = _grid.get(cell, PackedInt32Array())
	members.append(i)
	_grid[cell] = members


## Tests: load the table directly. `rows` = [[name, x, z, vx, vz, radius, still], ...].
static func load_rows(rows: Array) -> void:
	_table_root = -1
	_table_frame = -1
	_gd_stale = false
	_names = PackedStringArray()
	_xs = PackedFloat32Array()
	_zs = PackedFloat32Array()
	_vxs = PackedFloat32Array()
	_vzs = PackedFloat32Array()
	_radii = PackedFloat32Array()
	_half_w = PackedFloat32Array()
	_half_l = PackedFloat32Array()
	_fxs = PackedFloat32Array()
	_fzs = PackedFloat32Array()
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
		# Optional oriented extents: [..., half_width, half_length, heading_x, heading_z]; a disc otherwise.
		var disc := maxf(float(row[5]) - RADIUS_MARGIN, 0.0)
		_half_w.append(float(row[7]) if row.size() > 10 else disc)
		_half_l.append(float(row[8]) if row.size() > 10 else disc)
		_fxs.append(float(row[9]) if row.size() > 10 else 0.0)
		_fzs.append(float(row[10]) if row.size() > 10 else -1.0)
		_still.append(bool(row[6]))
		_index[String(row[0])] = i
		var cell := Vector2i(floori(float(row[1]) / CELL), floori(float(row[2]) / CELL))
		_add_to_cell(cell, i)
	_load_native()


## Up to MAX_NEIGHBOURS table rows within NEIGHBOUR_RADIUS of (x, z), nearest first, ties by name; `me` excluded.
## `cap` (round 17 lever l17o, BrainLevers.orca_neighbours) asks for fewer; MAX_NEIGHBOURS by default.
static func neighbours(me: String, x: float, z: float, cap: int = MAX_NEIGHBOURS) -> Array:
	_ensure_gd()
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
					if BrainSwitches.avoid_neighbours:
						_insert_nearest(found, d, _names[i], i, cap)
					else:
						found.append([d, _names[i], i])
	if BrainSwitches.avoid_neighbours:
		return found
	found.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and String(a[1]) < String(b[1])))
	if found.size() > cap:
		found.resize(cap)
	return found


## Round 16 (A5): keep `found` the MAX_NEIGHBOURS nearest so far, in order, as each candidate arrives, instead of
## collecting every hull in reach and sorting them all with a lambda. The order (distance, then name) is strict and
## total (names are unique), so this returns exactly the list the sort-and-truncate did.
static func _insert_nearest(found: Array, d: float, name: String, i: int, cap: int = MAX_NEIGHBOURS) -> void:
	var at := found.size()
	while at > 0:
		var other: Array = found[at - 1]
		var other_d: float = other[0]
		if other_d < d or (other_d == d and String(other[1]) < name):
			break
		at -= 1
	if at >= cap:
		return
	found.insert(at, [d, name, i])
	if found.size() > cap:
		found.resize(cap)


## Is row `name` in this tick's table standing still (nothing to drive to)? False for unknown names.
static func is_still(name: String) -> bool:
	_ensure_gd()
	var i: Variant = _index.get(name)
	return i != null and _still[int(i)]


## The velocity (x, z) to drive this tick: the one closest to `preferred` that keeps clear of every neighbour for
## TIME_HORIZON, assuming movers share the avoiding. `dt` is the fixed tick.
static func solve(me: String, position: Vector2, velocity: Vector2, preferred: Vector2, max_speed: float,
		radius: float, dt: float, cap: int = MAX_NEIGHBOURS) -> Vector2:
	if BrainSwitches.native and BrainSwitches.native_avoid:
		# Round 23 (native, N1): neighbours + ORCA in C++ over this tick's table (native/src/avoidance.cpp), the same
		# bits; the GDScript below is the reference. The answer rides in x, y; z packs the counters
		# (neighbours solved against + 16 * oriented pairs) so the probes read the same numbers either way.
		var r: Vector3 = NativeBridge.impl.avoidance_solve(me, position, velocity, preferred, max_speed, radius, dt,
				cap, oriented_on())
		var packed := int(r.z)
		if packed == 0:
			return preferred
		solved += 1
		oriented_pairs += packed / 16
		var native_result := Vector2(r.x, r.y)
		if native_result.distance_squared_to(preferred) > 0.01:
			deflected += 1
		return native_result
	var near := neighbours(me, position.x, position.y, cap)  # (neighbours fills the GDScript columns: _ensure_gd)
	if near.is_empty():
		return preferred
	solved += 1
	var oriented := oriented_on()
	var mine: Variant = _index.get(me)
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
		if oriented and mine != null and distance_sq > 0.0001:
			combined = pair_radius(int(mine), i, relative_position / sqrt(distance_sq))
			oriented_pairs += 1
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
