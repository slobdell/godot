class_name SelectionMarkers
extends Node3D
## C2/C5: flat rings on the ground under vehicles, drawn in 3D with depth testing so a vehicle always
## covers its own ring (the old 2D circles were painted over the models).
##   selected squad     a bright ring in the team color; the commander's ring is gold; the focused unit's white
##   our other units    a faint thin team-colored ring (so "whose is it" reads at a glance)
##   enemies in sight   a faint enemy-colored DASHED ring (never for enemies hidden by the fog); the dashes
##                      tell friend from foe without relying on color (accessibility)
##   inspected enemy    a bright enemy-colored ring (round 3: clicking an enemy inspects it)
## Round 3 (RtsControls): set `selection` and the rings follow it (per unit, no commander); `map` is the legacy
## squad-grammar TacticalMap.
## The command stream owns what is shown when; colors come from GameTheme.ui (art owns the palette).

## Ring radius as a multiple of the vehicle's longest hull side.
const RADIUS_FACTOR := 0.75
## Just above the fog-of-war plane (0.08 m) so fog never tints the ring.
const HEIGHT := 0.12
const SELECTED_ALPHA := 0.95
const IDLE_ALPHA := 0.4
const ENEMY_ALPHA := 0.7

var game_match: Match
var map: TacticalMap
## Round 3: the player's unit selection (takes precedence over `map`).
var selection: Selection
## Tests without fog of war: every enemy counts as seen.
var reveal_all := false
var team := Match.Team.GREEN

## Round 5 (X4, CP1): one MultiMesh per ring kind, not a mesh per vehicle (render counted 61 separate draws at 30 a side).
const KINDS := ["selected", "friendly", "enemy", "inspected", "commander", "focused"]

var _layers := {}  # kind → MultiMeshInstance3D
var _rings := {}  # tank name → {"kind", "visible", "position"}
var _materials := {}  # key → StandardMaterial3D
static var _mesh_thick: ArrayMesh
static var _mesh_thin: ArrayMesh
static var _mesh_dashed: ArrayMesh


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Placed every rendered frame at where vehicles are drawn (Shown), so not interpolated again.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(_delta: float) -> void:
	refresh()


## What each ring shows, as data (tests read this): tank name → {"kind", "visible", "position"}. A ring that is hidden
## keeps the last kind it showed.
func state() -> Dictionary:
	return _rings.duplicate(true)


## The MultiMeshInstance3D that draws every ring of `kind` (created on first use).
func layer(kind: String) -> MultiMeshInstance3D:
	if _layers.has(kind):
		return _layers[kind]
	var instance := MultiMeshInstance3D.new()
	instance.name = "Rings_" + kind
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The rings are placed every rendered frame at where the vehicles are drawn (Shown), so physics interpolation must
	# be off on the instance *and* its MultiMesh: interpolating them again would lag them a tick behind the vehicles,
	# and writing instance transforms outside _physics_process warns when the MultiMesh is interpolated (30 Hz tick).
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	instance.material_override = _material(kind)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	if "physics_interpolation_quality" in multimesh:
		multimesh.physics_interpolation_quality = MultiMesh.INTERP_QUALITY_FAST
	if "physics_interpolated" in multimesh:
		multimesh.physics_interpolated = false
	multimesh.mesh = _dashed_mesh() if kind == "enemy" else (_thin_mesh() if kind == "friendly" else _thick_mesh())
	instance.multimesh = multimesh
	add_child(instance)
	_layers[kind] = instance
	return instance


func refresh() -> void:
	if game_match == null:
		return
	var seen := {}
	var placed := {}  # kind → Array[Transform3D]
	var selected: Squad = map.selected() if map != null else null
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null:
			continue
		var tank_name := String(tank.name)
		seen[tank_name] = true
		var kind := ""
		if tank.is_alive():
			if selection != null:
				if tank.team == team:
					kind = "selected" if selection.units.has(tank_name) else "friendly"
				elif selection.inspected == tank_name and (reveal_all or game_match.is_visible_to(team, tank)):
					kind = "inspected"
				elif reveal_all or game_match.is_visible_to(team, tank):
					kind = "enemy"
			elif tank.team == team:
				if selected != null and selected.roster.has(tank_name):
					kind = "commander" if selected.commander == tank_name else "selected"
					if map.focused_unit == tank_name:
						kind = "focused"
				else:
					kind = "friendly"
			elif game_match.is_visible_to(team, tank):
				kind = "enemy"
		var ring: Dictionary = _rings.get_or_add(tank_name, {"kind": "", "visible": false, "position": Vector3.ZERO})
		ring["visible"] = kind != ""
		if kind == "":
			continue
		ring["kind"] = kind
		var hull: Array = Units.stat(tank.unit_id, "hull_size")
		var radius := maxf(float(hull[0]), float(hull[2])) * RADIUS_FACTOR
		var at := Shown.ground(tank) + Vector3.UP * HEIGHT
		ring["position"] = at
		(placed.get_or_add(kind, []) as Array).append(Transform3D(Basis.from_scale(Vector3(radius, 1.0, radius)), at))
	for tank_name in _rings.keys():
		if not seen.has(tank_name):
			_rings.erase(tank_name)
	for kind: String in KINDS:
		var transforms: Array = placed.get(kind, [])
		if transforms.is_empty() and not _layers.has(kind):
			continue
		var multimesh := layer(kind).multimesh
		if multimesh.instance_count < transforms.size():
			multimesh.instance_count = transforms.size() + 8  # grow in steps: resizing reallocates the buffer
		multimesh.visible_instance_count = transforms.size()
		for i in transforms.size():
			multimesh.set_instance_transform(i, transforms[i])


func _material(kind: String) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind]
	var color: Color
	match kind:
		"commander":
			color = Color(GameTheme.ui["commander"], SELECTED_ALPHA)
		"focused":
			color = Color(1, 1, 1, SELECTED_ALPHA)
		"selected":
			color = Color(GameTheme.ui["friendly"], SELECTED_ALPHA)
		"friendly":
			color = Color(GameTheme.ui["friendly"], IDLE_ALPHA)
		"inspected":
			color = Color(GameTheme.ui["enemy"], SELECTED_ALPHA)
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


static func _dashed_mesh() -> ArrayMesh:
	if _mesh_dashed == null:
		_mesh_dashed = annulus(0.9, 1.0, 48, 12)
	return _mesh_dashed


## A flat ring in the XZ plane (unit outer radius); with `dashes` > 0, that many gaps break it up.
static func annulus(inner: float, outer: float, segments := 40, dashes := 0) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for i in segments:
		if dashes > 0 and (i * dashes / segments) % 2 == 1:
			continue  # a gap
		var a := TAU * i / segments
		var b := TAU * (i + 1) / segments
		var da := Vector3(cos(a), 0.0, sin(a))
		var db := Vector3(cos(b), 0.0, sin(b))
		vertices.append_array([da * outer, db * outer, da * inner, db * outer, db * inner, da * inner])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
