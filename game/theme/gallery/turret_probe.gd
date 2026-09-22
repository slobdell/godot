extends SceneTree
## `make turret-probe` (feel, round 10, R5): where each unit's turret ring IS on its drawn hull, measured from the mesh
## as the game fits it (a real Tank, so the art is at the box's size), in the Tank node's frame (x right, y up, +z
## REAR). Prints one TURRET_PROBE line per unit and writes <json>:
##   box        the collider (hull_size)
##   pivot      today's Turret position; turret_art / weapon_art: those parts' drawn AABBs (tank frame)
##   roof       the hull art's top along its length: [z, max y over the centre strip |x| <= STRIP_M] every BIN_M
## The ring is chosen from these plus the side-on frames (`make facing-audit`), and written as `turret_mount` with the
## derivation beside it. Headless is fine: it reads mesh arrays, it renders nothing.
## Flags: --turret-probe-json=<abs path> [--turret-probe-units=a,b]

const BIN_M := 0.25
const STRIP_M := 0.6


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	GameTheme.use("cyberpunk")
	var only := Array(flags.text("turret-probe-units").split(",", false))
	var report := {}
	var tank_scene := load("res://game/tank/tank.tscn") as PackedScene
	for faction in ["condemned", "gangs", "law", "syndicate"]:
		for unit_id: String in Units.roster(faction):
			if not only.is_empty() and not only.has(unit_id):
				continue
			var tank: Tank = tank_scene.instantiate()
			tank.set("unit_id", unit_id)
			tank.set("simulate", false)
			root.add_child(tank)
			await process_frame
			var entry := {
				"box": Units.stat(unit_id, "hull_size"),
				"pivot": _v(tank.turret.position),
				"turret_art": _aabb(_bounds(tank, tank.get_node("Turret/TurretVisual"))),
				"weapon_art": _aabb(_bounds(tank, tank.get_node("Turret/WeaponVisual"))),
				"hull_art": _aabb(_bounds(tank, tank.get_node("HullVisual"))),
				"roof": _roof(tank, tank.get_node("HullVisual")),
				"gun_cut": not FactionArt.gun_cut(unit_id).is_empty(),
			}
			report[unit_id] = entry
			print("TURRET_PROBE %s box=%s pivot=%s turret_art=%s hull_art=%s" % [unit_id, entry["box"], entry["pivot"],
					entry["turret_art"], entry["hull_art"]])
			tank.free()
	var path := flags.text("turret-probe-json", "")
	if path != "":
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("TURRET_PROBE_DONE")
	quit()


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


func _aabb(box: AABB) -> Dictionary:
	return {"min": _v(box.position), "max": _v(box.end)} if box.size != Vector3.ZERO else {}


## Every mesh vertex under `node`, in the tank's frame. GunPivot subtrees (a gun cut out of the hull) are skipped so the
## roof is the hull's, not the gun lying on it.
func _points(tank: Node3D, node: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	var to_tank := tank.global_transform.affine_inverse()
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null or not instance.is_visible_in_tree() or instance is ShieldEffect:
			continue
		var skip := false
		var up: Node = instance
		while up != null and up != node:
			if String(up.name) == "GunPivot":
				skip = true
			up = up.get_parent()
		if skip:
			continue
		var xform := to_tank * instance.global_transform
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				out.append(xform * p)
	return out


func _bounds(tank: Node3D, node: Node) -> AABB:
	var points := _points(tank, node)
	if points.is_empty():
		return AABB()
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	return box


func _roof(tank: Node3D, node: Node) -> Array:
	var bins := {}
	for p in _points(tank, node):
		if absf(p.x) > STRIP_M:
			continue
		var key := int(floor(p.z / BIN_M))
		bins[key] = maxf(float(bins.get(key, -INF)), p.y)
	var keys := bins.keys()
	keys.sort()
	var out: Array = []
	for key: int in keys:
		out.append([snappedf((key + 0.5) * BIN_M, 0.01), snappedf(float(bins[key]), 0.01)])
	return out
