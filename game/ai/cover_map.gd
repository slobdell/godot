class_name CoverMap
extends RefCounted
## The arena's cover, as pure 2D geometry for AI reasoning (_agents/unit_ai.md §2, §4): oriented boxes seen
## from above, a line-of-sight test against them, and the static tactical points around them that position
## queries (TacticalQuery) start from.
##
## Why not physics raycasts: decisions must be testable on hand-built situations without a scene, and a
## few dozen boxes in a grid are cheaper than engine rays from GDScript. The world is flat and every
## obstacle today is 3 m tall; a feature lower than EYE_HEIGHT doesn't block sight (hull-down cover, later).
##
## Source: rules' `Arena.cover_features()` (contract C4) when the arena has it; until then the collision
## boxes under the arena's Obstacles node.
##
## DETERMINISM: line-of-sight answers are computed from positions quantized to QUANTUM meters and memoized
## under those quantized keys, so an answer never depends on which brain asked first.

const EYE_HEIGHT := Perception.EYE_HEIGHT
## Broadphase cell size (meters).
const CELL := 12.0
## Line-of-sight inputs snap to this grid (meters).
const QUANTUM := 0.5
## Tactical points ring each feature at these clearances (meters from its faces)...
const RING_CLEARANCES := [3.5, 7.5]
## ...every this many meters along the ring.
const RING_SPACING := 3.0
## A point must be at least this far outside every feature for a tank to sit there.
const STAND_CLEARANCE := 2.6
## Tactical points stay this far inside the drivable limit.
const EDGE := Match.DRIVABLE_LIMIT - 2.0
## Features grow by up to this much in queries; the grid indexes them with it.
const MAX_GROW := 4.0
const MEMO_LIMIT := 60000

## [{"center": Vector2, "axis": Vector2 (unit local x in world x/z), "half": Vector2 (half width, half
##   length), "height": float, "type": String}]
var features: Array[Dictionary] = []
## Static tactical points (x, z) and the feature each one rings.
var points := PackedVector2Array()
var point_feature := PackedInt32Array()

## Measurement counters (not used by decisions).
static var los_queries := 0
static var los_computed := 0

var _grid := {}
var _memo := {}
var _stamp := PackedInt32Array()
var _stamp_id := 0

static var _cached: CoverMap
static var _cached_arena_id := 0


## The cover map for the arena `node` plays in (built once per arena instance).
static func of(node: Node) -> CoverMap:
	var arena := find_arena(node)
	if arena == null:
		if _cached == null or _cached_arena_id != 0:
			_cached = CoverMap.from_features([])
			_cached_arena_id = 0
		return _cached
	if _cached == null or _cached_arena_id != arena.get_instance_id():
		_cached = CoverMap.from_arena(arena)
		_cached_arena_id = arena.get_instance_id()
	return _cached


## The arena root: the parent of the navigation sources (see game/arena/arena.gd).
static func find_arena(node: Node) -> Node:
	if node == null or not node.is_inside_tree():
		return null
	for source in node.get_tree().get_nodes_in_group("navigation_source"):
		return source.get_parent()
	return null


## Cover features from the arena: the C4 contract when present, else its Obstacles collision boxes.
static func from_arena(arena: Node) -> CoverMap:
	if arena.has_method("cover_features"):
		return CoverMap.from_features(arena.call("cover_features"))
	var list: Array = []
	var root := arena.get_node_or_null("Obstacles")
	for shape_node in _box_shapes(root if root != null else arena):
		var box := shape_node.shape as BoxShape3D
		var xform := shape_node.global_transform
		var size := box.size * xform.basis.get_scale()
		if root == null and (size.x > 100.0 or size.z > 100.0):
			continue  # the ground and perimeter walls are not cover
		var axis := Vector2(xform.basis.x.x, xform.basis.x.z).normalized()
		list.append({"position": Vector2(xform.origin.x, xform.origin.z), "size": Vector2(size.x, size.z),
				"axis": axis, "height": xform.origin.y + size.y / 2.0, "type": String(shape_node.get_parent().name)})
	return CoverMap.from_features(list)


static func _box_shapes(root: Node) -> Array[CollisionShape3D]:
	var found: Array[CollisionShape3D] = []
	for child in root.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			found.append(child)
		found.append_array(_box_shapes(child))
	return found


## Build from feature dictionaries: "position" (Vector2/Vector3/[x, z]), "size" ([width, length] or
## [width, height, length], Vector2/Vector3), rotation as "axis" (Vector2), "rotation" (radians about +Y) or
## "rotation_deg", optional "height" (default 3) and "type".
static func from_features(list: Array) -> CoverMap:
	var map := CoverMap.new()
	for entry: Dictionary in list:
		var position := _flat(entry.get("position", Vector2.ZERO))
		var size_value: Variant = entry.get("size", [1.0, 1.0])
		var size := Vector2.ONE
		match typeof(size_value):
			TYPE_VECTOR2:
				size = size_value
			TYPE_VECTOR3:
				size = Vector2(size_value.x, size_value.z)
			TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
				size = Vector2(float(size_value[0]), float(size_value[size_value.size() - 1]))
		var axis := Vector2.RIGHT
		if entry.has("axis"):
			axis = (entry["axis"] as Vector2).normalized()
		else:
			var angle := deg_to_rad(float(entry["rotation_deg"])) if entry.has("rotation_deg") else float(entry.get("rotation", 0.0))
			# Basis(UP, angle).x seen from above. The one trig call in the AI's geometry: once per obstacle at arena
			# load, on layout data (listed in _agents/determinism.md's inventory).
			axis = Vector2(cos(angle), -sin(angle))
		map.features.append({"center": position, "axis": axis, "half": size / 2.0,
				"height": float(entry.get("height", 3.0)), "type": String(entry.get("type", ""))})
	map._index()
	map._build_points()
	return map


static func _flat(value: Variant) -> Vector2:
	match typeof(value):
		TYPE_VECTOR3:
			return Vector2(value.x, value.z)
		TYPE_VECTOR2:
			return value
		TYPE_ARRAY:
			return Vector2(float(value[0]), float(value[value.size() - 1]))
	return Vector2.ZERO


# ---- Queries -----------------------------------------------------------------------

## True if nothing blocks sight between two world points (eye height to eye height). Memoized.
func clear_line(a: Vector3, b: Vector3) -> bool:
	los_queries += 1
	var qa := Vector2i(roundi(a.x / QUANTUM), roundi(a.z / QUANTUM))
	var qb := Vector2i(roundi(b.x / QUANTUM), roundi(b.z / QUANTUM))
	if qb.x < qa.x or (qb.x == qa.x and qb.y < qa.y):
		var swap := qa
		qa = qb
		qb = swap
	var key := Vector4i(qa.x, qa.y, qb.x, qb.y)
	var known: Variant = _memo.get(key)
	if known != null:
		return known
	los_computed += 1
	var clear := not blocked(Vector2(qa) * QUANTUM, Vector2(qb) * QUANTUM)
	if _memo.size() >= MEMO_LIMIT:
		_memo.clear()
	_memo[key] = clear
	return clear


## True if a sight-blocking feature crosses the flat segment a→b.
func blocked(a: Vector2, b: Vector2) -> bool:
	for index in _features_along(a, b):
		var feature: Dictionary = features[index]
		if float(feature["height"]) >= EYE_HEIGHT and segment_hits(index, a, b, 0.0):
			return true
	return false


## True if the flat segment a→b crosses feature `index` grown by `grow` meters.
func segment_hits(index: int, a: Vector2, b: Vector2, grow: float) -> bool:
	var feature: Dictionary = features[index]
	var center: Vector2 = feature["center"]
	var axis: Vector2 = feature["axis"]
	var across := Vector2(-axis.y, axis.x)
	var half: Vector2 = feature["half"]
	var pa := a - center
	var pb := b - center
	var la := Vector2(pa.dot(axis), pa.dot(across))
	var d := Vector2(pb.dot(axis), pb.dot(across)) - la
	var t0 := 0.0
	var t1 := 1.0
	for k in 2:
		var extent := half[k] + grow
		if absf(d[k]) < 1e-9:
			if absf(la[k]) > extent:
				return false
			continue
		var ta := (-extent - la[k]) / d[k]
		var tb := (extent - la[k]) / d[k]
		if ta > tb:
			var swap := ta
			ta = tb
			tb = swap
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return true


## True if the flat segment a→b (a driving path) crosses any feature grown by `grow` meters.
func path_blocked(a: Vector2, b: Vector2, grow: float) -> bool:
	for index in _features_along(a, b):
		if segment_hits(index, a, b, grow):
			return true
	return false


## True if `point` is inside any feature grown by `grow` meters (≤ MAX_GROW).
func inside_any(point: Vector2, grow: float) -> bool:
	var cell := Vector2i(floori(point.x / CELL), floori(point.y / CELL))
	for index: int in _grid.get(cell, PackedInt32Array()):
		var feature: Dictionary = features[index]
		var offset: Vector2 = point - (feature["center"] as Vector2)
		var axis: Vector2 = feature["axis"]
		var half: Vector2 = feature["half"]
		if absf(offset.dot(axis)) <= half.x + grow and absf(offset.dot(Vector2(-axis.y, axis.x))) <= half.y + grow:
			return true
	return false


## Indices of static tactical points within `radius` of `center`, nearest first (ties by index).
func points_near(center: Vector2, radius: float) -> PackedInt32Array:
	var pairs: Array = []
	var limit := radius * radius
	for i in points.size():
		var d := center.distance_squared_to(points[i])
		if d <= limit:
			pairs.append([d, i])
	pairs.sort()
	var result := PackedInt32Array()
	for pair in pairs:
		result.append(pair[1])
	return result


# ---- Building ------------------------------------------------------------------------

func _corners(index: int, grow: float) -> PackedVector2Array:
	var feature: Dictionary = features[index]
	var axis: Vector2 = feature["axis"]
	var across := Vector2(-axis.y, axis.x)
	var half: Vector2 = feature["half"] + Vector2(grow, grow)
	var center: Vector2 = feature["center"]
	return PackedVector2Array([center + axis * half.x + across * half.y, center - axis * half.x + across * half.y,
			center - axis * half.x - across * half.y, center + axis * half.x - across * half.y])


func _index() -> void:
	_grid.clear()
	for index in features.size():
		var corners := _corners(index, MAX_GROW)
		var low := corners[0]
		var high := corners[0]
		for corner in corners:
			low = low.min(corner)
			high = high.max(corner)
		for cx in range(floori(low.x / CELL), floori(high.x / CELL) + 1):
			for cz in range(floori(low.y / CELL), floori(high.y / CELL) + 1):
				var cell := Vector2i(cx, cz)
				var list: PackedInt32Array = _grid.get(cell, PackedInt32Array())
				list.append(index)
				_grid[cell] = list
	_stamp.resize(features.size())
	_stamp.fill(0)


## Feature indices in the cells a segment passes through (Amanatides-Woo traversal), each once, unordered.
func _features_along(a: Vector2, b: Vector2) -> PackedInt32Array:
	var found := PackedInt32Array()
	if features.is_empty():
		return found
	_stamp_id += 1
	var cell := Vector2i(floori(a.x / CELL), floori(a.y / CELL))
	var last := Vector2i(floori(b.x / CELL), floori(b.y / CELL))
	var direction := b - a
	var step := Vector2i(1 if direction.x > 0.0 else -1, 1 if direction.y > 0.0 else -1)
	var t_max := Vector2(INF, INF)
	var t_delta := Vector2(INF, INF)
	for k in 2:
		if absf(direction[k]) > 1e-9:
			var boundary := (cell[k] + (1 if step[k] > 0 else 0)) * CELL
			t_max[k] = (boundary - a[k]) / direction[k]
			t_delta[k] = CELL / absf(direction[k])
	var guard := 0
	while true:
		for index: int in _grid.get(cell, PackedInt32Array()):
			if _stamp[index] != _stamp_id:
				_stamp[index] = _stamp_id
				found.append(index)
		if cell == last or guard > 64:
			break
		guard += 1
		if t_max.x < t_max.y:
			cell.x += step.x
			t_max.x += t_delta.x
		else:
			cell.y += step.y
			t_max.y += t_delta.y
	return found


func _build_points() -> void:
	var seen := {}
	for index in features.size():
		for clearance: float in RING_CLEARANCES:
			var corners := _corners(index, clearance)
			for side in 4:
				var from := corners[side]
				var to := corners[(side + 1) % 4]
				var count := maxi(1, roundi(from.distance_to(to) / RING_SPACING))
				for s in count:
					_add_point(from.lerp(to, float(s) / count), index, seen)


func _add_point(point: Vector2, owner_index: int, seen: Dictionary) -> void:
	if absf(point.x) > EDGE or absf(point.y) > EDGE or inside_any(point, STAND_CLEARANCE):
		return
	var key := Vector2i(roundi(point.x / 1.5), roundi(point.y / 1.5))
	if seen.has(key):
		return
	seen[key] = true
	points.append(point)
	point_feature.append(owner_index)
