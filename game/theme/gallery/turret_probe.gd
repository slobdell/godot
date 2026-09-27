extends SceneTree
## `make turret-probe` (feel, round 10, R5): where each unit's turret ring IS on its drawn hull, measured from the mesh
## as the game fits it (a real Tank, so the art is at the box's size), in the Tank node's frame (x right, y up, +z
## REAR). Prints one TURRET_PROBE line per unit and writes <json>:
##   box        the collider (hull_size)
##   pivot      today's Turret position; turret_art / weapon_art: those parts' drawn AABBs (tank frame)
##   above_hull round 11 (fleet): TurretFit.measure -- the share of what turns with the turret that is drawn above the
##              hull under it, and the lowest turning point's height over (+) or under (-) the hull
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
			# Round 11: ONE process frame is not enough. DozerPart._fit_to_hull scales and LIFTS every mounted part
			# on a deferred call, so a probe that measures after a single frame reads a half-fitted rig -- the hull
			# at its final size and the gun still where the mesh put it. That is how this probe came to report the
			# War Rig's gun 0.175 m INSIDE the tanker while the render plainly showed it hanging in the air.
			# tests/test_theme_unit_scale.gd already waits two PHYSICS frames for exactly this reason.
			await physics_frame
			await physics_frame
			var entry := {
				"box": Units.stat(unit_id, "hull_size"),
				"pivot": _v(tank.turret.position),
				"turret_art": _aabb(_bounds(tank, tank.get_node("Turret/TurretVisual"))),
				"weapon_art": _aabb(_bounds(tank, tank.get_node("Turret/WeaponVisual"))),
				"hull_art": _aabb(_bounds(tank, tank.get_node("HullVisual"))),
				"roof": _roof(tank, tank.get_node("HullVisual")),
				"gun_cut": not FactionArt.gun_cut(unit_id).is_empty(),
				"gun_pivot": _gun_pivot(tank),
				"above_hull": TurretFit.measure(tank),
				"seat_gap": TurretFit.seat_gap(tank),
				"gun_seat": TurretFit.gun_seat(tank),
			}
			report[unit_id] = entry
			print("TURRET_PROBE %s box=%s pivot=%s turret_art=%s weapon_art=%s gun_pivot=%s hull_art=%s" % [unit_id,
					entry["box"], entry["pivot"], entry["turret_art"], entry["weapon_art"], entry["gun_pivot"], entry["hull_art"]])
			var fit: Dictionary = entry["above_hull"]
			print("TURRET_PROBE_ABOVE %s points=%d above=%.0f%% lowest=%+.2f m" % [unit_id, fit["points"],
					float(fit["above"]) * 100.0, fit["lowest"]])
			var seat: Dictionary = entry["seat_gap"]
			var gun: Dictionary = entry["gun_seat"]
			if bool(gun.get("has_gun", false)):
				print("TURRET_PROBE_GUN %s air=%+.3f m at %s (hull under that point %+.3f; %d points measured, %d over nothing)" % [
						unit_id, gun.get("air", 0.0), gun.get("at", Vector3.ZERO), gun.get("under", 0.0),
						gun.get("measured", 0), gun.get("floating", 0)])
				print("TURRET_PROBE_AIR %s over_nothing=%.0f%% of the gun's drawn points have no hull in their own column" % [
						unit_id, float(gun.get("over_nothing", 0.0)) * 100.0])
			if int(seat["measured"]) > 0:
				print("TURRET_PROBE_SEAT %s gap=%+.3f m (nearest hull within %d cells, %d of %d points)" % [unit_id,
						seat["gap"], TurretFit.REACH_CELLS, seat["measured"], seat["points"]])
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


## A gun cut out of the hull (FactionArt.GUN_CUTS) yaws about its own GunPivot: where that is in the tank frame, so the
## simulated pivot (turret_mount x/z) can be put under it. [] when the unit has none.
func _gun_pivot(tank: Node3D) -> Array:
	var pivots := tank.find_children("GunPivot", "Node3D", true, false)
	if pivots.is_empty():
		return []
	return _v(tank.to_local((pivots[0] as Node3D).global_position))
