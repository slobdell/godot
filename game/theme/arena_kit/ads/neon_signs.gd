class_name NeonSigns
extends RefCounted
## Neon tube signs for the grandstands (assets stretch): every sign in the venue is one MultiMesh of quads over one
## atlas (neon_signs.png, `make assets-ads`). Colors are the arena's warm and violet neon, never the team cyan or
## magenta (game_design.md: faction and venue lighting must not read as a team). Visual only.

const SHADER := preload("res://game/theme/arena_kit/ads/neon_sign.gdshader")
const ATLAS := preload("res://game/theme/arena_kit/ads/neon_signs.png")
## Atlas rows: AQUACORP, ORGAN FUTURES, SYNDICATE LIFE, LIVE FROM THE PIT (tools/assets/build_ads.py NEON_SIGNS).
const CELLS := 4
const SIZE := Vector2(16.0, 2.0)
const COLORS := [Color("#ffb13b"), Color("#ffe8c8"), Color("#ff3b30"), Color("#b45cff")]


## One draw for every sign: placements are [{transform: Transform3D (the quad faces -Z), cell: int, color: Color}].
static func build(placements: Array) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = SIZE
	# QuadMesh faces +Z; flip it so a sign placed with the stands' basis faces the arena (-Z) and reads left to right.
	quad.center_offset = Vector3.ZERO
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("atlas", ATLAS)
	material.set_shader_parameter("cells", float(CELLS))
	quad.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	FxMultiMesh.resize(multimesh, placements.size())
	var bounds := AABB()
	for i in placements.size():
		var xform: Transform3D = placements[i]["transform"] * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		multimesh.set_instance_transform(i, xform)
		multimesh.set_instance_color(i, placements[i]["color"])
		multimesh.set_instance_custom_data(i, Color((int(placements[i]["cell"]) % CELLS + 0.01) / float(CELLS), float(i) * 0.137, 0, 0))
		var box := AABB(xform.origin - Vector3(9, 2, 9), Vector3(18, 4, 18))
		bounds = box if i == 0 else bounds.merge(box)
	var instance := MultiMeshInstance3D.new()
	instance.name = "NeonSigns"
	instance.multimesh = multimesh
	FxMultiMesh.never_interpolated(instance)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = bounds
	# Headless renderers don't keep MultiMesh instance data: tests and tools read the placements from here.
	instance.set_meta("placements", placements)
	return instance
