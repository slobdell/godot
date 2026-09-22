class_name TerrainVisual
extends Node3D
## The `arena.terrain` slot (terrain stream, round 10): what water, pits and bridges LOOK like. The lead asked for
## them twice and the mechanism has existed since round 7 (`ArenaTerrain`), but nothing drew them, so there was
## nothing to see -- which is the literal reason he said it never materialised.
##
## `setup(terrain)` receives the layout's `terrain` list once at load (`ArenaTerrain.build`). Every surface is built
## from the SAME geometry the colliders are: the kerbs from `ArenaTerrain.rim_slabs`, the bridge rails from
## `rail_slabs`, so what a hull stops against is exactly what the player sees (R3's rule, by construction).
##
## Five surface kinds, ONE draw call each whatever the map holds, no lights, no textures (R9):
##   water  interior-mapped channel: walls, a still dark surface reflecting the venue's neon (`water.gdshader`)
##   pit    the same trace, deep, black, a red glow at the bottom (the kill zone's floor)
##   kerb   the rim, concrete with an emissive lip; hazard stripes around a pit (`kerb.gdshader`)
##   deck   the bridge roadway in kit steel, the container palette, a tread and kerb strips
##   rail   the bridge rails, 0.9 m -- below the 1.3 m eye line, like the rim they continue
## Visual only: nothing here collides, and the sim never reads it (pre-registered: the sim baseline does not move).

const WATER_SHADER := preload("res://game/theme/arena_kit/terrain/water.gdshader")
const KERB_SHADER := preload("res://game/theme/arena_kit/terrain/kerb.gdshader")
## Just above the arena floor plane (y = 0), under everything a unit could stand on. The deck sits above it.
const SURFACE_Y := 0.03
const DECK_TOP := 0.07
## The container palette (ArenaKit containers): gunmetal plate, rust-orange steel, hazard yellow.
const PLATE := Color(0.16, 0.17, 0.18)
const STEEL := Color(0.45, 0.2, 0.09)
const HAZARD := Color(0.95, 0.68, 0.05)
const RAIL_POST_PITCH := 2.4
const MAX_DECKS := 8
const MAX_WET := 16

var water: MeshInstance3D
var pits: MeshInstance3D
var kerbs: MeshInstance3D
var deck: MeshInstance3D
var rails: MeshInstance3D


func setup(terrain: Array) -> void:
	for child in get_children():
		child.free()
	var deck_rects: Array = []
	for entry: Dictionary in terrain:
		if ArenaTerrain.is_deck(String(entry["kind"])):
			deck_rects.append(ArenaTerrain.bounds(entry))
	var water_material := _trace_material(false, deck_rects)
	_wet_uniform(water_material, terrain, "water")
	var pit_material := _trace_material(true, deck_rects)
	_wet_uniform(pit_material, terrain, "pit")
	water = _surface("Water", _footprint_quads(terrain, "water", deck_rects), water_material)
	pits = _surface("Pits", _footprint_quads(terrain, "pit", deck_rects), pit_material)
	kerbs = _surface("Kerbs", _kerb_mesh(terrain), _kerb_material())
	deck = _surface("Decks", _deck_mesh(deck_rects), _steel_material(0.35))
	rails = _surface("Rails", _rail_mesh(terrain), _steel_material(0.55))


## Draw calls this visual costs: one per non-empty surface kind (the R9 budget is one per kind).
func draw_calls() -> int:
	var count := 0
	for part: MeshInstance3D in [water, pits, kerbs, deck, rails]:
		if part != null and part.mesh != null:
			count += part.mesh.get_surface_count()
	return count


func _surface(label: String, mesh: ArrayMesh, material: Material) -> MeshInstance3D:
	if mesh == null:
		return null
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## Every footprint of `kind` as upward quads, minus the decks over it. Each quad carries its WHOLE footprint's box in
## UV/UV2, so the shader's trace meets the footprint's own walls even from a quad beside a bridge.
func _footprint_quads(terrain: Array, kind: String, deck_rects: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for entry: Dictionary in terrain:
		if String(entry["kind"]) != kind:
			continue
		var box := ArenaTerrain.bounds(entry)
		for cell: PackedFloat32Array in _minus(box, deck_rects):
			_quad(tool, cell, box)
			any = true
	return tool.commit() if any else null


## A rectangle minus a set of rectangles, as rectangles: cut on every edge inside it, keep the cells no deck covers.
func _minus(box: PackedFloat32Array, holes: Array) -> Array:
	var xs := {box[0]: true, box[2]: true}
	var zs := {box[1]: true, box[3]: true}
	for hole: PackedFloat32Array in holes:
		for v: float in [hole[0], hole[2]]:
			if v > box[0] and v < box[2]:
				xs[v] = true
		for v: float in [hole[1], hole[3]]:
			if v > box[1] and v < box[3]:
				zs[v] = true
	var xk := xs.keys()
	var zk := zs.keys()
	xk.sort()
	zk.sort()
	var out: Array = []
	for i in xk.size() - 1:
		for j in zk.size() - 1:
			var mx: float = (xk[i] + xk[i + 1]) / 2.0
			var mz: float = (zk[j] + zk[j + 1]) / 2.0
			var covered := false
			for hole: PackedFloat32Array in holes:
				if mx > hole[0] and mx < hole[2] and mz > hole[1] and mz < hole[3]:
					covered = true
					break
			if not covered:
				out.append(PackedFloat32Array([xk[i], zk[j], xk[i + 1], zk[j + 1]]))
	return out


func _quad(tool: SurfaceTool, cell: PackedFloat32Array, box: PackedFloat32Array) -> void:
	var corners := [Vector3(cell[0], SURFACE_Y, cell[1]), Vector3(cell[2], SURFACE_Y, cell[1]),
			Vector3(cell[2], SURFACE_Y, cell[3]), Vector3(cell[0], SURFACE_Y, cell[3])]
	for index: int in [0, 1, 2, 0, 2, 3]:
		tool.set_normal(Vector3.UP)
		tool.set_uv(Vector2(box[0], box[1]))
		tool.set_uv2(Vector2(box[2], box[3]))
		tool.add_vertex(corners[index])


func _trace_material(pit: bool, deck_rects: Array) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("is_pit", pit)
	var depth := float(ArenaTerrain.KINDS["pit" if pit else "water"]["pan_depth"])
	material.set_shader_parameter("depth", depth)
	var packed := PackedVector4Array()
	for rect: PackedFloat32Array in deck_rects.slice(0, MAX_DECKS):
		packed.append(Vector4(rect[0], rect[1], rect[2], rect[3]))
	while packed.size() < MAX_DECKS:
		packed.append(Vector4.ZERO)
	material.set_shader_parameter("decks", packed)
	material.set_shader_parameter("deck_count", mini(deck_rects.size(), MAX_DECKS))
	return material


## Every footprint of `kind` for the shader's union trace, so a river of several rectangles has no wall at a join.
func _wet_uniform(material: ShaderMaterial, terrain: Array, kind: String) -> void:
	var packed := PackedVector4Array()
	for entry: Dictionary in terrain:
		if String(entry["kind"]) == kind and packed.size() < MAX_WET:
			var b := ArenaTerrain.bounds(entry)
			packed.append(Vector4(b[0], b[1], b[2], b[3]))
	var count := packed.size()
	while packed.size() < MAX_WET:
		packed.append(Vector4.ZERO)
	material.set_shader_parameter("wet", packed)
	material.set_shader_parameter("wet_count", count)


func _kerb_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = KERB_SHADER
	return material


func _steel_material(roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.metallic = 0.55
	material.roughness = roughness
	# `_box` winds its side faces by hand; drawing both sides costs nothing on boxes this small and cannot vanish.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## The kerbs: every rim box, tagged pit (COLOR.r = 1) or water (0) for the one shared kerb shader.
func _kerb_mesh(terrain: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for entry: Dictionary in terrain:
		if not ArenaTerrain.carves(String(entry["kind"])):
			continue
		var tag := Color(1, 0, 0) if String(entry["kind"]) == "pit" else Color(0, 0, 0)
		for slab: Array in ArenaTerrain.rim_slabs(entry, terrain):
			_box(tool, Vector3(slab[0], ArenaTerrain.RIM_HEIGHT / 2.0, slab[1]),
					Vector3(slab[2], ArenaTerrain.RIM_HEIGHT, slab[3]), tag)
			any = true
	return tool.commit() if any else null


## A bridge roadway: a steel plate a few centimetres proud of the floor, cross-tread every metre and a rust-orange
## kerb strip down each side, so the deck reads as a structure laid across the channel, not as a painted stripe.
func _deck_mesh(deck_rects: Array) -> ArrayMesh:
	if deck_rects.is_empty():
		return null
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rect: PackedFloat32Array in deck_rects:
		var w: float = rect[2] - rect[0]
		var d: float = rect[3] - rect[1]
		var centre := Vector3((rect[0] + rect[2]) / 2.0, DECK_TOP / 2.0, (rect[1] + rect[3]) / 2.0)
		_box(tool, centre, Vector3(w, DECK_TOP, d), PLATE)
		# Tread bars across the direction of travel (the longer axis is the crossing).
		var along_z := d >= w
		var length := d if along_z else w
		var bars := int(length / 1.0)
		for i in bars:
			var offset := -length / 2.0 + (i + 0.5) * length / bars
			var at := centre + (Vector3(0, DECK_TOP / 2.0 + 0.01, offset) if along_z else Vector3(offset, DECK_TOP / 2.0 + 0.01, 0))
			var size := Vector3(w - 1.4, 0.02, 0.12) if along_z else Vector3(0.12, 0.02, d - 1.4)
			_box(tool, at, size, PLATE.lightened(0.18))
		# Hazard chevrons at both ends, where the deck meets the bank: the mouth of the crossing.
		for end: float in [-1.0, 1.0]:
			var at := centre + (Vector3(0, DECK_TOP / 2.0 + 0.015, end * (d / 2.0 - 0.5)) if along_z
					else Vector3(end * (w / 2.0 - 0.5), DECK_TOP / 2.0 + 0.015, 0))
			var size := Vector3(w - 1.2, 0.02, 0.6) if along_z else Vector3(0.6, 0.02, d - 1.2)
			_box(tool, at, size, HAZARD)
	return tool.commit()


## The rails, from `ArenaTerrain.rail_slabs` (the colliders' own boxes): posts, a top rail in hazard yellow, a mid
## rail and a kick plate in the container's rust orange. All under 0.9 m.
func _rail_mesh(terrain: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	var h := ArenaTerrain.RAIL_HEIGHT
	for entry: Dictionary in terrain:
		if not ArenaTerrain.is_deck(String(entry["kind"])):
			continue
		for slab: Array in ArenaTerrain.rail_slabs(entry, terrain):
			any = true
			var along_z: bool = float(slab[3]) >= float(slab[2])
			var length: float = slab[3] if along_z else slab[2]
			var thick: float = slab[2] if along_z else slab[3]
			var centre := Vector3(slab[0], 0.0, slab[1])
			_rail_run(tool, centre, along_z, length, h - 0.06, 0.12, thick, HAZARD)
			_rail_run(tool, centre, along_z, length, h * 0.5, 0.08, thick * 0.6, STEEL)
			_rail_run(tool, centre, along_z, length, DECK_TOP + 0.12, 0.24, thick * 0.8, STEEL)
			var posts := maxi(2, int(length / RAIL_POST_PITCH) + 1)
			for i in posts:
				var offset := -length / 2.0 + 0.1 + i * (length - 0.2) / float(posts - 1)
				var at := centre + (Vector3(0, h / 2.0, offset) if along_z else Vector3(offset, h / 2.0, 0))
				_box(tool, at, Vector3(thick * 0.7, h, 0.14) if along_z else Vector3(0.14, h, thick * 0.7), STEEL)
	return tool.commit() if any else null


## One horizontal member of a rail, `length` along the rail at height `y`.
func _rail_run(tool: SurfaceTool, centre: Vector3, along_z: bool, length: float, y: float, height: float,
		depth_m: float, color: Color) -> void:
	var size := Vector3(depth_m, height, length) if along_z else Vector3(length, height, depth_m)
	_box(tool, centre + Vector3(0, y, 0), size, color)


## An axis-aligned box into `tool`, six faces with flat normals and one vertex colour.
func _box(tool: SurfaceTool, centre: Vector3, size: Vector3, color: Color) -> void:
	var half := size / 2.0
	var faces := [
		[Vector3.UP, Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)],
		[Vector3.DOWN, Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, -1, -1)],
		[Vector3.RIGHT, Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, -1)],
		[Vector3.LEFT, Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(-1, -1, 1)],
		[Vector3.BACK, Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, -1, 1)],
		[Vector3.FORWARD, Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, -1)],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var quad := [centre + (face[1] as Vector3) * half, centre + (face[2] as Vector3) * half,
				centre + (face[3] as Vector3) * half, centre + (face[4] as Vector3) * half]
		for index: int in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(normal)
			tool.set_color(color)
			tool.add_vertex(quad[index])
