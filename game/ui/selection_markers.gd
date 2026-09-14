class_name SelectionMarkers
extends Node3D
## C2/C5: flat rings on the ground under vehicles, drawn in 3D with depth testing so a vehicle always
## covers its own ring (the old 2D circles were painted over the models).
##   selected squad     a bright ring in the team color; the commander's ring is gold
##   our other units    a faint thin team-colored ring (so "whose is it" reads at a glance)
##   enemies in sight   a faint enemy-colored ring (never for enemies hidden by the fog)
## The command stream owns what is shown when; colors come from GameTheme.ui (art owns the palette).

## Ring radius as a multiple of the vehicle's longest hull side.
const RADIUS_FACTOR := 0.75
## Just above the fog-of-war plane (0.08 m) so fog never tints the ring.
const HEIGHT := 0.12
const SELECTED_ALPHA := 0.95
const IDLE_ALPHA := 0.4
const ENEMY_ALPHA := 0.45

var game_match: Match
var map: TacticalMap
var team := Match.Team.GREEN

var _rings := {}  # tank name → MeshInstance3D
var _materials := {}  # key → StandardMaterial3D
static var _mesh_thick: ArrayMesh
static var _mesh_thin: ArrayMesh


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	refresh()


## What each ring shows, as data (tests read this): tank name → {"kind", "visible"}.
func state() -> Dictionary:
	var result := {}
	for tank_name in _rings:
		var ring := _rings[tank_name] as MeshInstance3D
		result[tank_name] = {"kind": ring.get_meta("kind", ""), "visible": ring.visible}
	return result


func refresh() -> void:
	if game_match == null:
		return
	var seen := {}
	var selected: Squad = map.selected() if map != null else null
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null:
			continue
		var tank_name := String(tank.name)
		seen[tank_name] = true
		var ring := _ring_for(tank)
		var kind := ""
		if tank.is_alive():
			if tank.team == team:
				if selected != null and selected.roster.has(tank_name):
					kind = "commander" if selected.commander == tank_name else "selected"
				else:
					kind = "friendly"
			elif game_match.is_visible_to(team, tank):
				kind = "enemy"
		ring.visible = kind != ""
		if kind == "":
			continue
		if ring.get_meta("kind", "") != kind:
			ring.set_meta("kind", kind)
			ring.mesh = _thin_mesh() if kind == "friendly" or kind == "enemy" else _thick_mesh()
			ring.material_override = _material(kind)
		var hull: Array = Units.stat(tank.unit_id, "hull_size")
		var radius := maxf(float(hull[0]), float(hull[2])) * RADIUS_FACTOR
		ring.global_position = Vector3(tank.global_position.x, HEIGHT, tank.global_position.z)
		ring.scale = Vector3(radius, 1.0, radius)
	for tank_name in _rings.keys():
		if not seen.has(tank_name):
			(_rings[tank_name] as Node).queue_free()
			_rings.erase(tank_name)


func _ring_for(tank: Tank) -> MeshInstance3D:
	var tank_name := String(tank.name)
	if _rings.has(tank_name):
		return _rings[tank_name]
	var ring := MeshInstance3D.new()
	ring.name = "Ring_" + tank_name
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_rings[tank_name] = ring
	return ring


func _material(kind: String) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind]
	var color: Color
	match kind:
		"commander":
			color = Color(GameTheme.ui["commander"], SELECTED_ALPHA)
		"selected":
			color = Color(GameTheme.ui["friendly"], SELECTED_ALPHA)
		"friendly":
			color = Color(GameTheme.ui["friendly"], IDLE_ALPHA)
		_:
			color = Color(GameTheme.ui["enemy"], ENEMY_ALPHA)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.disable_fog = true
	_materials[kind] = material
	return material


static func _thick_mesh() -> ArrayMesh:
	if _mesh_thick == null:
		_mesh_thick = annulus(0.84, 1.0)
	return _mesh_thick


static func _thin_mesh() -> ArrayMesh:
	if _mesh_thin == null:
		_mesh_thin = annulus(0.93, 1.0)
	return _mesh_thin


## A flat ring in the XZ plane (unit outer radius).
static func annulus(inner: float, outer: float, segments := 40) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for i in segments + 1:
		var angle := TAU * i / segments
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		vertices.append(direction * outer)
		vertices.append(direction * inner)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	return mesh
