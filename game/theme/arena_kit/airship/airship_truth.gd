class_name AirshipTruth
extends RefCounted
## What the broadcast airship can visibly fly into, measured off what is DRAWN -- the ground truth `make airship-report`
## and `tests/test_theme_ad_airship.gd` hold the flight against. It deliberately shares no geometry with
## `AirshipFlight`: the solids come from the kit's own meshes (not the flight's `DRAWN` table), the hull from its own
## generated mesh rasterised cell by cell (not the flight's two-part model), and point-in-footprint from
## `ArenaKit.distance_to_footprint` (not the flight's separating-axis test). If the flight's model is ever too
## optimistic, this is what notices.

## The hull's underside is rasterised on a grid of this many metres.
const CELL := 1.0

static var _underside := {}


## Everything drawn on `layout` as rotated boxes: [{centre: Vector2, half: Vector2 (x, z), yaw (rad), top, type}] --
## the layout's obstacles and non-colliding props, each grown to the kit mesh that draws it. Anything lower than the
## tallest hull could not touch the airship and is left out.
static func drawn_solids(layout: Dictionary) -> Array:
	var drawn := {"floodlight": KitYard.floodlight_mesh().get_aabb(), "sign": KitYard.sign_post_mesh().get_aabb(),
			"ad_screen": AirshipTruth.scene_bounds("res://game/theme/arena_kit/prop_ad_screen.tscn")}
	var runtime := Arena.normalize(layout)
	var entries: Array = runtime.get("obstacles", []).duplicate()
	for prop: Dictionary in runtime.get("props", []):
		if ArenaKit.is_kit(String(prop["type"])) and not ArenaKit.collides(String(prop["type"])):
			var copy := prop.duplicate(true)
			var size := ArenaKit.size_of(prop)
			copy["size"] = [size.x, size.y, size.z]
			entries.append(copy)
	var out: Array = []
	for entry: Dictionary in entries:
		var size := Arena.obstacle_size(entry)
		var type := String(entry.get("type", ""))
		var half := Vector2(size.x, size.z) * 0.5
		var top := size.y
		if drawn.has(type):
			var box: AABB = drawn[type]
			half = Vector2(maxf(half.x, maxf(absf(box.position.x), absf(box.end.x))),
					maxf(half.y, maxf(absf(box.position.z), absf(box.end.z))))
			top = maxf(top, box.end.y)
		if top < SyndicateAdAirship.HULL_CLEARANCE - 0.5:
			continue
		out.append({"centre": Vector2(float(entry["position"][0]), float(entry["position"][1])), "half": half,
				"yaw": deg_to_rad(float(entry.get("rotation_deg", 0.0))), "top": top, "type": type})
	return out


## The standing geometry of a prop scene, in its own frame. Flat decals (the light a screen throws on the floor, a
## 34 x 22 m quad) are not something to hit and are left out.
static func scene_bounds(path: String) -> AABB:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	# The ad screen builds its geometry in _ready; call the builder the same way the tree would.
	if node.has_method("_build"):
		node.call("_build")
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		var box := AirshipTruth.to_root(instance, node) * instance.mesh.get_aabb()
		if box.size.y < 0.05:
			continue
		result = box if first else result.merge(box)
		first = false
	node.free()
	return result


static func to_root(node: Node3D, root: Node) -> Transform3D:
	var into := Transform3D.IDENTITY
	var walk: Node = node
	while walk != root and walk != null:
		into = (walk as Node3D).transform * into
		walk = walk.get_parent()
	return into


## The hull's UNDERSIDE as drawn: the generated mesh rasterised onto a CELL grid in the node's frame (x across, z
## along, +z aft), keeping the lowest point over each cell, at SCALE. {Vector2i: lowest y relative to the centre}.
static func underside() -> Dictionary:
	if not _underside.is_empty():
		return _underside
	var node := (load(SyndicateAdAirship.MESH) as PackedScene).instantiate() as Node3D
	var cells := {}
	var scaled := Transform3D(Basis.from_scale(Vector3.ONE * SyndicateAdAirship.SCALE), Vector3.ZERO)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		var into := scaled * AirshipTruth.to_root(instance, node)
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var indexed := not index.is_empty()
			var count := index.size() if indexed else verts.size()
			for t in range(0, count, 3):
				var a := into * verts[index[t] if indexed else t]
				var b := into * verts[index[t + 1] if indexed else t + 1]
				var c := into * verts[index[t + 2] if indexed else t + 2]
				# Sample each triangle finely enough that no cell under it is skipped.
				var n := int(ceil(maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a))) / (CELL * 0.5))) + 1
				for i in n + 1:
					for j in n + 1 - i:
						var point := a + (b - a) * (float(i) / n) + (c - a) * (float(j) / n)
						var key := Vector2i(floori(point.x / CELL), floori(point.z / CELL))
						cells[key] = minf(float(cells.get(key, INF)), point.y)
	node.free()
	_underside = cells
	return cells


## How deep into `solid` the hull is with its centre at `at`, `centre_y` up, turned to `heading`: the most the solid's
## top stands above the underside of any hull cell over its footprint, the float at the bottom of its travel. <= 0 is
## clear. A cell counts as over the solid when its centre is within half a cell's diagonal of the footprint, so the
## grid errs toward reporting a touch.
static func intrusion(at: Vector2, heading: float, centre_y: float, solid: Dictionary) -> float:
	var hull_reach := Vector2(SyndicateAdAirship.BEAM, SyndicateAdAirship.LENGTH).length() * 0.5
	if at.distance_to(solid["centre"]) > hull_reach + (solid["half"] as Vector2).length() + CELL:
		return -INF
	var across := Vector2(cos(heading), -sin(heading))
	var aft := Vector2(sin(heading), cos(heading))
	var size := Vector3((solid["half"] as Vector2).x * 2.0, 0.0, (solid["half"] as Vector2).y * 2.0)
	var yaw_deg := rad_to_deg(float(solid["yaw"]))
	var top := float(solid["top"])
	var worst := -INF
	var cells := AirshipTruth.underside()
	for key: Vector2i in cells:
		var bottom := centre_y + float(cells[key]) - SyndicateAdAirship.FLOAT_RISE_TOTAL
		if top - bottom <= worst:
			continue
		var point := at + across * ((key.x + 0.5) * CELL) + aft * ((key.y + 0.5) * CELL)
		if ArenaKit.distance_to_footprint(point, solid["centre"], size, yaw_deg) <= CELL * 0.71:
			worst = top - bottom
	return worst
