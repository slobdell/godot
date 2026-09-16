class_name VisionRegion
extends RefCounted
## L4: the ground a set of units can currently see, as the union of their sight discs (centre on the ground,
## radius = the unit's `sight_radius`). Pure math, so the camera's fitting and clamping are testable without a
## screen and cost nothing to re-derive each frame.
##
## The camera uses it twice (control X1): `bounds()` gives the four ground corners that must fit on screen for the
## view never to reach past the force's collective horizon (the zoom-out cap that stops the unearned god view),
## and `clamp_point` keeps a free "look" camera over ground the team can actually see.

## [{"center": Vector3 (y = 0), "radius": float}], in the order the units were added.
var discs: Array = []


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
	discs.append({"center": Vector3(center.x, 0.0, center.z), "radius": maxf(radius, 0.0)})


func is_empty() -> bool:
	return discs.is_empty()


## Whether some unit has this ground spot inside its sight radius (height is ignored).
func contains(point: Vector3) -> bool:
	for disc: Dictionary in discs:
		var center: Vector3 = disc["center"]
		if Vector2(point.x - center.x, point.z - center.z).length() <= float(disc["radius"]):
			return true
	return false


## `point` when it is seen, else the nearest point on the rim of the disc whose rim is closest to it.
func clamp_point(point: Vector3) -> Vector3:
	var flat := Vector3(point.x, 0.0, point.z)
	if is_empty() or contains(point):
		return flat
	var best := flat
	var best_gap := INF
	for disc: Dictionary in discs:
		var center: Vector3 = disc["center"]
		var radius := float(disc["radius"])
		var away := Vector2(point.x - center.x, point.z - center.z)
		var gap := away.length() - radius
		if gap < best_gap:
			best_gap = gap
			var toward := away.normalized() if away.length() > 0.001 else Vector2.RIGHT
			best = center + Vector3(toward.x, 0.0, toward.y) * radius
	return best


## The four ground corners of the region's bounding box: a camera that shows these shows the whole region.
func bounds() -> Array:
	if is_empty():
		return []
	var box := AABB(discs[0]["center"], Vector3.ZERO)
	for disc: Dictionary in discs:
		var center: Vector3 = disc["center"]
		var radius := float(disc["radius"])
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
