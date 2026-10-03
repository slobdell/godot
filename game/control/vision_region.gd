class_name VisionRegion
extends RefCounted
## L4: the ground a set of units can currently see, as the union of their sight discs (centre on the ground,
## radius = the unit's `sight_radius`). Pure math, so the camera's fitting and clamping are testable without a
## screen and cost nothing to re-derive each frame.
##
## The camera uses it twice (control X1): `bounds()` gives the four ground corners that must fit on screen for the
## view never to reach past the force's collective horizon (the zoom-out cap that stops the unearned god view),
## and `clamp_point` keeps a free "look" camera over ground the team can actually see.

## A clamped point lands this fraction inside the rim rather than exactly on it. Exactly on it is a coin toss:
## `contains` asks for distance <= radius, and the same arithmetic rounds differently on different machines, so
## `contains(clamp_point(p))` came out false on a loaded builder0 and true here. The invariant matters - the
## camera re-clamps its focus every frame, and a focus the region disowns would be nudged for ever.
const RIM_INSET := 1.0 - 1e-4

## [{"center": Vector3 (y = 0), "radius": float}], in the order the units were added. Read-only: built on first read
## from the arrays below (round 16, hud H4: the camera builds a region every frame and almost never reads this).
var discs: Array:
	get:
		if _discs.size() != _r.size():
			_discs.clear()
			for i in _r.size():
				_discs.append({"center": Vector3(_cx[i], 0.0, _cz[i]), "radius": _r[i]})
		return _discs
var _discs: Array = []
## The discs themselves: centre x and z (the centres' own float32 values) and radius, in the order added.
var _cx := PackedFloat64Array()
var _cz := PackedFloat64Array()
var _r := PackedFloat64Array()


## The region a set of Tanks can see (dead and freed ones are skipped).
static func of(tanks: Array) -> VisionRegion:
	var region := VisionRegion.new()
	for node in tanks:
		var tank := node as Tank
		if tank == null or not is_instance_valid(tank) or not tank.is_alive():
			continue
		region.add(tank.global_position, tank.sight_radius)
	return region


func add(center: Vector3, radius: float) -> void:
	var flat := Vector3(center.x, 0.0, center.z)  # float32, as the Dictionary's Vector3 held it
	_cx.append(flat.x)
	_cz.append(flat.z)
	_r.append(maxf(radius, 0.0))


func is_empty() -> bool:
	return _r.is_empty()


## Whether some unit has this ground spot inside its sight radius (height is ignored).
func contains(point: Vector3) -> bool:
	for i in _r.size():
		if Vector2(point.x - _cx[i], point.z - _cz[i]).length() <= _r[i]:
			return true
	return false


## `point` when it is seen, else just inside the rim of the disc whose rim is closest to it. `contains` always
## holds for what this returns.
func clamp_point(point: Vector3) -> Vector3:
	var flat := Vector3(point.x, 0.0, point.z)
	if is_empty() or contains(point):
		return flat
	var best := flat
	var best_gap := INF
	for i in _r.size():
		var center := Vector3(_cx[i], 0.0, _cz[i])
		var radius := _r[i]
		var away := Vector2(point.x - center.x, point.z - center.z)
		var gap := away.length() - radius
		if gap < best_gap:
			best_gap = gap
			var toward := away.normalized() if away.length() > 0.001 else Vector2.RIGHT
			best = center + Vector3(toward.x, 0.0, toward.y) * radius * RIM_INSET
	return best


## The four ground corners of the region's bounding box: a camera that shows these shows the whole region.
func bounds() -> Array:
	if is_empty():
		return []
	var box := AABB(Vector3(_cx[0], 0.0, _cz[0]), Vector3.ZERO)
	for i in _r.size():
		var center := Vector3(_cx[i], 0.0, _cz[i])
		var radius := _r[i]
		box = box.expand(center + Vector3(radius, 0.0, radius))
		box = box.expand(center - Vector3(radius, 0.0, radius))
	var corners: Array = []
	for x in [box.position.x, box.end.x]:
		for z in [box.position.z, box.end.z]:
			corners.append(Vector3(x, 0.0, z))
	return corners


## The middle of the region's bounding box (Vector3.ZERO when empty).
func center() -> Vector3:
	var corners := bounds()
	if corners.is_empty():
		return Vector3.ZERO
	return ((corners[0] as Vector3) + (corners[3] as Vector3)) / 2.0
