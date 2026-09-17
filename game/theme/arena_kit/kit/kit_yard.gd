class_name KitYard
extends Node3D
## Draws the arena kit's small props for a viewport (round 5, arena's M2 layouts inside render's M1 budget): barricade
## runs, floodlight towers, signs on posts and wrecks. Every kind is ONE MultiMesh, so a map with 28 barricades costs
## the same draws as a map with one:
##   barricade   concrete jersey barrier with a reflective strip        lit + neon surface   2 draws
##   floodlight  concrete footing, steel mast, lamp head                 lit + neon surface   2 draws
##   sign_post   the post under a sign                                   lit surface          1 draw
##   sign        a neon tube sign naming the arena (kit_signs.png)       additive quad        1 draw
##   pool        painted light on the floor under lamps and signs         additive splat       1 draw
##   wreck       the approved Meshy husk (prop_wreck.glb), fit to its box its own surfaces     1-2 draws
## No real lights, no per-prop `_process`: lamps and signs light the floor with the pool splats. Visual only; collision
## is Arena's. Kit props (kit_prop.gd) register instances here and remove them when they leave the tree.

const SIGN_SHADER := preload("res://game/theme/arena_kit/ads/neon_sign.gdshader")
const SIGN_ATLAS := preload("res://game/theme/arena_kit/kit/kit_signs.png")
const WRECK_MODEL := "res://game/theme/arena_kit/generated/prop_wreck.glb"
## Rows of kit_signs.png (tools/assets/build_kit_signs.py NAMES): a layout's `sign` key → row; anything else → the last.
const SIGN_CELLS := ["boneyard", "boulevard", "pit", "yard", "foundry", "furnace", "scrapyard", "death_race"]
const SIGN_SIZE := Vector2(6.0, 1.5)
## ArenaKit.PROPS sizes these visuals are built to (x, height, z).
const BARRICADE := Vector3(6.0, 0.9, 0.8)
const FLOODLIGHT := Vector3(2.4, 3.0, 2.4)
const WRECK := Vector3(3.2, 2.0, 6.4)
const MAST_HEIGHT := 15.0
const SIGN_HEIGHT := 6.0
const KINDS := ["barricade", "floodlight", "sign_post", "sign", "pool", "wreck"]
## Warm sodium-white for lamps: venue light, never a team color.
const LAMP := Color(1.0, 0.86, 0.62)

var _entries := {}  # id → [kind, Transform3D, Color]
var _next_id := 1
var _dirty := false
var _draws := {}  # kind → MultiMeshInstance3D


## The yard of `node`'s viewport, created on first use.
static func for_node(node: Node) -> KitYard:
	var viewport := node.get_viewport() if node.is_inside_tree() else (Engine.get_main_loop() as SceneTree).root
	if viewport.has_meta("kit_yard"):
		var existing: Variant = viewport.get_meta("kit_yard")
		if is_instance_valid(existing):
			return existing
	var yard := KitYard.new()
	yard.name = "KitYard"
	viewport.set_meta("kit_yard", yard)
	viewport.add_child.call_deferred(yard)
	return yard


## `data`: the instance color (sign and pool tint; ignored by opaque kinds); alpha = intensity for pools, atlas row for signs.
func add(kind: String, xform: Transform3D, data := Color.WHITE) -> int:
	assert(KINDS.has(kind), "unknown kit kind %s" % kind)
	var id := _next_id
	_next_id += 1
	_entries[id] = [kind, xform, data]
	_mark()
	return id


func remove(id: int) -> void:
	if _entries.erase(id):
		_mark()


func count(kind: String) -> int:
	return _entries.values().filter(func(e: Array) -> bool: return e[0] == kind).size()


## MultiMeshInstance3Ds drawing `kind` (tests: one per kind, however many props).
func draws_of(kind: String) -> int:
	return 1 if _draws.has(kind) else 0


func entries_of(kind: String) -> Array:
	return _entries.values().filter(func(e: Array) -> bool: return e[0] == kind)


## INSTANCE_CUSTOM per kind: a sign's atlas row and flicker seed (neon_sign.gdshader), a pool's intensity (splat.gdshader).
static func custom_data(kind: String, data: Color, index: int) -> Color:
	if kind == "sign":
		return Color((data.a + 0.01) / SIGN_CELLS.size(), index * 0.137, 0, 0)
	return Color(data.a, 0, 0, 0)


static func sign_cell(sign_name: String) -> int:
	var index := SIGN_CELLS.find(sign_name.to_lower())
	return index if index >= 0 else SIGN_CELLS.size() - 1


func _mark() -> void:
	if not _dirty:
		_dirty = true
		flush.call_deferred()


## Rebuilds the MultiMeshes now (normally deferred to the end of the frame).
func flush() -> void:
	_dirty = false
	for kind in KINDS:
		var entries := entries_of(kind)
		if entries.is_empty() and not _draws.has(kind):
			continue
		var draw: MultiMeshInstance3D = _draws.get(kind)
		if draw == null:
			draw = _new_draw(kind)
			if draw == null:
				continue
			add_child(draw)
			_draws[kind] = draw
		var multimesh := draw.multimesh
		multimesh.instance_count = entries.size()
		var bounds := AABB()
		var local := multimesh.mesh.get_aabb().grow(1.0)
		for i in entries.size():
			var xform: Transform3D = entries[i][1]
			multimesh.set_instance_transform(i, xform)
			if multimesh.use_colors:
				multimesh.set_instance_color(i, entries[i][2])
			if multimesh.use_custom_data:
				multimesh.set_instance_custom_data(i, KitYard.custom_data(kind, entries[i][2], i))
			var box := xform * local
			bounds = box if i == 0 else bounds.merge(box)
		draw.custom_aabb = bounds
		draw.visible = entries.size() > 0


func _new_draw(kind: String) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var draw := MultiMeshInstance3D.new()
	draw.name = kind
	match kind:
		"barricade":
			multimesh.mesh = KitYard.barricade_mesh()
		"floodlight":
			multimesh.mesh = KitYard.floodlight_mesh()
		"sign_post":
			multimesh.mesh = KitYard.sign_post_mesh()
		"sign":
			var quad := QuadMesh.new()
			quad.size = SIGN_SIZE
			var material := ShaderMaterial.new()
			material.shader = SIGN_SHADER
			material.set_shader_parameter("atlas", SIGN_ATLAS)
			material.set_shader_parameter("cells", float(SIGN_CELLS.size()))
			quad.material = material
			multimesh.mesh = quad
			multimesh.use_colors = true
			multimesh.use_custom_data = true
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"pool":
			var plane := PlaneMesh.new()
			plane.size = Vector2.ONE
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.get_mesh_arrays())
			var splat := ShaderMaterial.new()
			splat.shader = TracerSystem.SPLAT_SHADER
			mesh.surface_set_material(0, splat)
			multimesh.mesh = mesh
			multimesh.use_colors = true
			multimesh.use_custom_data = true
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"wreck":
			var mesh := KitYard.wreck_mesh()
			if mesh == null:
				return null
			multimesh.mesh = mesh
	draw.multimesh = multimesh
	return draw


static func barricade_mesh() -> ArrayMesh:
	var b := ColorMeshBuilder.new()
	var concrete := Color(0.46, 0.45, 0.42)
	var length := BARRICADE.x
	# The jersey profile in three steps: a wide foot, the sloped waist, the narrow top.
	b.box(Vector3(length, 0.28, 0.8), Vector3(0, 0.14, 0), concrete.darkened(0.12))
	b.box(Vector3(length, 0.34, 0.5), Vector3(0, 0.45, 0), concrete)
	b.box(Vector3(length, 0.28, 0.24), Vector3(0, 0.76, 0), concrete.lightened(0.05))
	# Joints between the 2 m sections, and grime at the foot.
	for x in [-1.0, 1.0]:
		b.box(Vector3(0.05, 0.62, 0.52), Vector3(x, 0.45, 0), concrete.darkened(0.45))
	# A reflective strip on both faces: catches the eye from the tactical camera without a light.
	for side in [-1.0, 1.0]:
		b.glow_box(Vector3(length - 0.3, 0.06, 0.02), Vector3(0, 0.66, side * 0.13), Color(1.0, 0.62, 0.18) * 0.55)
	return b.commit()


static func floodlight_mesh() -> ArrayMesh:
	var b := ColorMeshBuilder.new()
	var concrete := Color(0.42, 0.41, 0.39)
	var steel := Color(0.26, 0.27, 0.29)
	# The footing gameplay collides with: a tall concrete block with hazard bands.
	b.box(FLOODLIGHT, Vector3(0, FLOODLIGHT.y / 2.0, 0), concrete)
	for y in [0.35, 2.55]:
		b.box(Vector3(FLOODLIGHT.x + 0.02, 0.22, FLOODLIGHT.z + 0.02), Vector3(0, y, 0), Color(0.62, 0.48, 0.12))
	# The lattice mast (too thin to be cover) and the lamp head, lamps facing -Z.
	b.cylinder(0.32, 0.18, MAST_HEIGHT - FLOODLIGHT.y, Transform3D(Basis.IDENTITY, Vector3(0, FLOODLIGHT.y + (MAST_HEIGHT - FLOODLIGHT.y) / 2.0, 0)), steel, 6)
	b.box(Vector3(4.2, 1.3, 0.5), Vector3(0, MAST_HEIGHT + 0.4, 0), steel.darkened(0.3))
	for i in 4:
		b.glow_box(Vector3(0.85, 0.9, 0.08), Vector3(-1.5 + i * 1.0, MAST_HEIGHT + 0.4, -0.27), LAMP * 1.6)
	return b.commit()


static func sign_post_mesh() -> ArrayMesh:
	var b := ColorMeshBuilder.new()
	var steel := Color(0.24, 0.24, 0.26)
	b.box(Vector3(0.9, 0.4, 0.9), Vector3(0, 0.2, 0), Color(0.4, 0.39, 0.37))
	b.box(Vector3(0.28, SIGN_HEIGHT, 0.28), Vector3(0, SIGN_HEIGHT / 2.0, 0), steel)
	b.box(Vector3(SIGN_SIZE.x + 0.3, SIGN_SIZE.y + 0.3, 0.12), Vector3(0, SIGN_HEIGHT + SIGN_SIZE.y / 2.0, 0.1), steel.darkened(0.5))
	return b.commit()


## The approved wreck model's mesh, turned so its long axis is z and scaled to WRECK (render fits the husk to its box).
static func wreck_mesh() -> ArrayMesh:
	if not ResourceLoader.exists(WRECK_MODEL):
		return null
	var scene := (load(WRECK_MODEL) as PackedScene).instantiate()
	var source: MeshInstance3D = null
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		source = node as MeshInstance3D
		break
	if source == null or source.mesh == null:
		scene.free()
		return null
	var aabb := source.mesh.get_aabb()
	var turn := Basis.IDENTITY if aabb.size.z >= aabb.size.x else Basis(Vector3.UP, PI / 2.0)
	var turned: AABB = Transform3D(turn, Vector3.ZERO) * aabb
	var scale := Vector3(WRECK.x / turned.size.x, WRECK.y / turned.size.y, WRECK.z / turned.size.z)
	# Keep the husk's proportions within 25%: a stretched car reads as wrong before a slightly small one does.
	var xz := minf(scale.x, scale.z)
	scale = Vector3(xz, clampf(scale.y, xz * 0.75, xz * 1.25), xz)
	var fit := Transform3D(Basis.from_scale(scale) * turn, Vector3.ZERO)
	var bottom := (fit * aabb).position.y
	fit.origin = Vector3(-(fit * aabb).get_center().x, -bottom, -(fit * aabb).get_center().z)
	var mesh := ArrayMesh.new()
	var source_mesh := source.mesh
	for surface in source_mesh.get_surface_count():
		var arrays := source_mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		for v in vertices.size():
			vertices[v] = fit * vertices[v]
		for n in normals.size():
			normals[n] = (fit.basis.inverse().transposed() * normals[n]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		if not normals.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = normals
		# Tangents would need re-deriving under a non-uniform scale; the husk reads fine on its normals alone.
		arrays[Mesh.ARRAY_TANGENT] = null
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface, source.get_active_material(surface))
	scene.free()
	return mesh
