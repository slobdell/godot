class_name ClassMark
extends RefCounted
## Fleet round 15, F2: a CLASS LAMP, so a tank and an IFV read apart from his camera (garage's tour, in a player's
## words: *"My tanks and IFVs look the same in the fight."*).
##
## `make class-look` (builder0, 72 m, FOV 35, pitch 21) measured which pairs are alike: the Condemned bus and garbage
## truck (silhouette IoU 0.89 from BEHIND, which is how he follows his squad; the IFV's barrel makes it as long as the
## bus, 9.92 vs 9.70 m drawn) and Law's Assault Gun and Retired APC (IoU 0.87, and both the same dark blue: mean lit
## colours 6.9 apart). The Gangs (0.16) and the Syndicate (0.51) read apart by shape and are left alone. A marking
## cannot change a shape; at night, at 24 px a metre, a LIGHT is what the eye picks out first, from every side.
##
## So the IFVs of those two pairs carry rotating amber beacons on the roof -- a pair at the rear (seen from behind and
## from either side) and one forward (seen from the front) -- and their tanks carry none: "the one with the amber
## lights is the IFV". Amber because it is neither team colour (cyan/magenta stay friend-or-foe), because it is the
## Condemned's hazard amber, and because a garbage truck wears amber beacons anyway. Lamps are exaggerated about two
## times a real beacon (a real one is ~6 px at 72 m), each with an additive flare that sweeps as the lamp turns.
##
## Art only: no collider, nothing the simulation reads. Free: no generation. Measured before/after with
## `make class-look` (lit_difference) and at his pose with `make formation-shots`.

## unit id -> lamp spots, each [x, z] as a fraction of the hull's DRAWN width and length in the tank's frame (x right,
## z back: -0.5 is the nose, +0.5 the tail). The height is the drawn roof under the spot (`roof_height`).
const MARKS := {
	"ifv": [[-0.28, 0.40], [0.28, 0.40], [0.0, -0.30]],
	"law_ifv": [[-0.28, 0.36], [0.28, 0.36], [0.0, -0.22]],
}
const LAMP_RADIUS_M := 0.28
const LAMP_HEIGHT_M := 0.38
const FLARE_SIZE_M := 2.4
## How far round a spot the roof is searched for its highest point (metres, ground plane).
const ROOF_SEARCH_M := 0.3
const DOME_SHADER := preload("res://game/theme/roster/class_beacon.gdshader")
const FLARE_SHADER := preload("res://game/theme/roster/class_beacon_flare.gdshader")

## `--no-class-mark` (or `CLASS_MARK=off` in the environment: `CLASS_MARK=off make skirmish`) draws the IFVs unmarked:
## the before arm of `make class-look`, and his A/B in play.
static var enabled := not LaunchFlags.from_environment().has("no-class-mark") \
		and OS.get_environment("CLASS_MARK") != "off"
## unit id -> Array of lamp bases in the tank's frame (the roof scan runs once per unit class, not per vehicle).
static var _bases: Dictionary = {}
static var _dome_material: ShaderMaterial
static var _flare_material: ShaderMaterial


static func has_mark(unit_id: String) -> bool:
	return MARKS.has(unit_id)


## Put the unit's lamps on `hull_part` (the hull's dozer part, already fitted to its box). `tank` is its Tank.
static func dress(hull_part: Node3D, tank: Node3D, unit_id: String) -> void:
	if not enabled or not MARKS.has(unit_id) or tank == null:
		return
	var hull_visual := hull_part.get_parent() as Node3D
	if hull_visual == null:
		return
	if not _bases.has(unit_id):
		_bases[unit_id] = _find_bases(hull_part, tank, unit_id)
	var to_part := _relative(hull_part, tank).affine_inverse()
	var i := 0
	for base: Vector3 in _bases[unit_id]:
		var lamp := _lamp()
		lamp.name = "ClassBeacon%d" % i
		hull_part.add_child(lamp)
		lamp.transform = Transform3D(Basis(), to_part * base)
		# The part may be scaled; a lamp keeps its size in metres.
		var scale := _relative(hull_part, tank).basis.get_scale()
		lamp.scale = Vector3(1.0 / scale.x, 1.0 / scale.y, 1.0 / scale.z)
		i += 1


static func _find_bases(hull_part: Node3D, tank: Node3D, unit_id: String) -> Array:
	var box := _drawn_bounds(hull_part, tank)
	var result: Array = []
	for spot: Array in MARKS[unit_id]:
		var x: float = box.get_center().x + float(spot[0]) * box.size.x
		var z: float = box.get_center().z + float(spot[1]) * box.size.z
		var y := roof_height(hull_part, Vector2(x, z), tank)
		if is_finite(y):
			result.append(Vector3(x, y, z))
	return result


## The highest drawn point of `node`'s meshes within ROOF_SEARCH_M of `at` (x, z in the tank's frame), in the tank's
## frame; INF when nothing is drawn there. `tank` defaults to `node`'s Tank ancestor.
static func roof_height(node: Node, at: Vector2, tank: Node3D = null) -> float:
	if tank == null:
		tank = node.get_parent() as Node3D
		while tank != null and not (tank is Tank):
			tank = tank.get_parent() as Node3D
	var best := -INF
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible or String(mesh_instance.name).begins_with("Class"):
			continue
		if mesh_instance is ShieldEffect:
			continue
		var to_tank := _relative(mesh_instance, tank)
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v in vertices:
				var p := to_tank * v
				if Vector2(p.x - at.x, p.z - at.y).length() <= ROOF_SEARCH_M and p.y > best:
					best = p.y
	return best if best > -INF else INF


static func _drawn_bounds(node: Node, tank: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible or mesh_instance is ShieldEffect:
			continue
		var box := _relative(mesh_instance, tank) * mesh_instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## `node`'s transform in `ancestor`'s frame, by the parent chain (valid before the tank is placed in the world).
static func _relative(node: Node, ancestor: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


## One lamp: an amber dome whose lit side turns, and a flare that flashes as it faces the camera.
static func _lamp() -> Node3D:
	if _dome_material == null:
		_dome_material = ShaderMaterial.new()
		_dome_material.shader = DOME_SHADER
		_flare_material = ShaderMaterial.new()
		_flare_material.shader = FLARE_SHADER
	var lamp := Node3D.new()
	var dome := MeshInstance3D.new()
	dome.name = "ClassDome"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = LAMP_RADIUS_M * 0.8
	cylinder.bottom_radius = LAMP_RADIUS_M
	cylinder.height = LAMP_HEIGHT_M
	cylinder.radial_segments = 10
	cylinder.rings = 1
	dome.mesh = cylinder
	dome.material_override = _dome_material
	dome.position.y = LAMP_HEIGHT_M / 2.0
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(dome)
	var flare := MeshInstance3D.new()
	flare.name = "ClassFlare"
	var quad := QuadMesh.new()
	quad.size = Vector2(FLARE_SIZE_M, FLARE_SIZE_M)
	flare.mesh = quad
	flare.material_override = _flare_material
	flare.position.y = LAMP_HEIGHT_M * 0.6
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(flare)
	return lamp
