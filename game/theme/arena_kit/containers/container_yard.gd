class_name ContainerYard
extends Node3D
## Draws every shipping container in a viewport (assets X1): one MultiMesh per kind, however many are placed, so an arena
## of container walls costs two draw calls (plus shadows). Container props (container_prop.gd) register their stacked
## containers here and remove them when they leave the tree. Visual only.
##
## Looks: `look(position, level, options)` packs paint, stencil, rust, and doors into INSTANCE_CUSTOM for
## container.gdshader. Seeded by position, so an arena always shows the same containers; a faction narrows the palette
## and stencils (game_design.md, The arena kit), and a layout obstacle can name any of them.

## Kind → length in meters (ISO 668: 20 ft = 6.058 m, 40 ft = 12.192 m).
const KINDS := {"container_20": 6.06, "container_40": 12.19}
const SHADER := preload("res://game/theme/arena_kit/containers/container.gdshader")
const TEXTURES := {
	"surface_tex": preload("res://game/theme/arena_kit/containers/container_surface.png"),
	"detail_tex": preload("res://game/theme/arena_kit/containers/container_detail.png"),
	"stencil_tex": preload("res://game/theme/arena_kit/containers/container_stencils.png"),
}
## Paints real container fleets wear, dulled for the night arena (never saturated: art_direction.md). Shader palette order.
const PAINTS := {
	"oxide": Color("#5f302a"), "steel_blue": Color("#3a5466"), "green": Color("#34473a"), "orange": Color("#8a5130"),
	"grey": Color("#5e6164"), "navy": Color("#232c3c"), "ivory": Color("#a39d8f"), "hazard": Color("#957a2e"),
	"cream": Color("#99968b"), "teal": Color("#30504e"), "brown": Color("#4e3322"), "black": Color("#1b1b1d"),
}
## Stencil atlas cells (tools/assets/build_containers.py STENCILS, same order).
const STENCILS := ["code", "prison", "evidence", "impound", "aquacorp", "organ_futures", "gang_tag", "hazard"]
## Who owns the yard: palette, stencils, and rust range [min, max].
const FACTIONS := {
	"mixed": {"paints": [0, 1, 2, 3, 4, 8, 9, 10], "stencils": [0, 0, 0, 1, 2, 4, 5, 6, 7], "rust": [0.1, 0.6]},
	"condemned": {"paints": [7, 4, 0, 11], "stencils": [1, 7, 0], "rust": [0.45, 0.85]},
	"law": {"paints": [5, 4, 8], "stencils": [2, 3], "rust": [0.25, 0.55]},
	"syndicate": {"paints": [6, 11], "stencils": [4, 5], "rust": [0.0, 0.06]},
	"gangs": {"paints": [0, 3, 10, 2], "stencils": [6, 6, 0], "rust": [0.55, 0.95]},
}
const DOORS := {"closed": 0.0, "ajar": 0.33, "open": 1.0}

var _entries := {}  # id → [kind, Transform3D, Color]
var _next_id := 1
var _dirty := false
var _draws := {}  # kind → MultiMeshInstance3D
var _material: ShaderMaterial


## The yard of `node`'s viewport, created on first use.
static func for_node(node: Node) -> ContainerYard:
	var viewport := node.get_viewport() if node.is_inside_tree() else (Engine.get_main_loop() as SceneTree).root
	if viewport.has_meta("container_yard"):
		var existing: Variant = viewport.get_meta("container_yard")
		if is_instance_valid(existing):
			return existing
	var yard := ContainerYard.new()
	yard.name = "ContainerYard"
	viewport.set_meta("container_yard", yard)
	viewport.add_child.call_deferred(yard)
	return yard


func add(kind: String, xform: Transform3D, look_data: Color) -> int:
	assert(KINDS.has(kind), "unknown container kind %s" % kind)
	var id := _next_id
	_next_id += 1
	_entries[id] = [kind, xform, look_data]
	_mark()
	return id


func remove(id: int) -> void:
	if _entries.erase(id):
		_mark()


func count(kind: String) -> int:
	return _entries.values().filter(func(e: Array) -> bool: return e[0] == kind).size()


## Transforms of `kind` whose ground position lies within `radius` of `point` (tests, galleries).
func transforms_near(kind: String, point: Vector3, radius: float) -> Array[Transform3D]:
	var found: Array[Transform3D] = []
	for entry: Array in _entries.values():
		var origin: Vector3 = (entry[1] as Transform3D).origin
		if entry[0] == kind and Vector2(origin.x - point.x, origin.z - point.z).length() <= radius:
			found.append(entry[1])
	return found


func _mark() -> void:
	if not _dirty:
		_dirty = true
		flush.call_deferred()


## Rebuilds the MultiMeshes now (normally deferred to the end of the frame).
func flush() -> void:
	_dirty = false
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		for texture in TEXTURES:
			_material.set_shader_parameter(texture, TEXTURES[texture])
		var palette := PackedVector3Array()
		for color: Color in PAINTS.values():
			palette.append(Vector3(color.r, color.g, color.b))
		while palette.size() < 16:
			palette.append(Vector3(0.3, 0.3, 0.3))
		_material.set_shader_parameter("palette", palette)
		_material.set_shader_parameter("hinge_z", ContainerMesh.WIDTH / 2.0 + ContainerMesh.HINGE_OUTSET)
	for kind in KINDS:
		var entries := _entries.values().filter(func(e: Array) -> bool: return e[0] == kind)
		if entries.is_empty() and not _draws.has(kind):
			continue
		var draw: MultiMeshInstance3D = _draws.get(kind)
		if draw == null:
			draw = MultiMeshInstance3D.new()
			draw.name = kind
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_custom_data = true
			var mesh := ContainerMesh.build(KINDS[kind])
			mesh.surface_set_material(0, _material)
			multimesh.mesh = mesh
			draw.multimesh = multimesh
			add_child(draw)
			_draws[kind] = draw
		var multimesh := draw.multimesh
		multimesh.instance_count = entries.size()
		var bounds := AABB()
		for i in entries.size():
			var xform: Transform3D = entries[i][1]
			multimesh.set_instance_transform(i, xform)
			multimesh.set_instance_custom_data(i, entries[i][2])
			var box := xform * AABB(Vector3(-KINDS[kind] / 2.0 - 1.5, 0, -ContainerMesh.WIDTH), Vector3(KINDS[kind] + 3.0, ContainerMesh.HEIGHT, ContainerMesh.WIDTH * 2.0))
			bounds = box if i == 0 else bounds.merge(box)
		draw.custom_aabb = bounds
		draw.visible = entries.size() > 0


## INSTANCE_CUSTOM for the container at `level` (0 = on the ground) of a stack at `position`. Options (a layout
## obstacle's optional keys): faction (FACTIONS), paint (PAINTS name), stencil (STENCILS name), rust (0..1),
## doors (DOORS name; only the ground container can open).
static func look(position: Vector3, level: int, options: Dictionary) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([snappedf(position.x, 0.01), snappedf(position.z, 0.01), level, String(options.get("faction", "mixed"))])
	var faction: Dictionary = FACTIONS.get(String(options.get("faction", "mixed")), FACTIONS["mixed"])
	var paints: Array = faction["paints"]
	var stencils: Array = faction["stencils"]
	var paint: int = paints[rng.randi() % paints.size()]
	var stencil: int = stencils[rng.randi() % stencils.size()]
	var rust := rng.randf_range(faction["rust"][0], faction["rust"][1])
	if options.has("paint") and PAINTS.has(options["paint"]):
		paint = PAINTS.keys().find(options["paint"])
	if options.has("stencil") and STENCILS.has(options["stencil"]):
		stencil = STENCILS.find(options["stencil"])
	if options.has("rust"):
		rust = clampf(float(options["rust"]), 0.0, 1.0)
	var doors := float(DOORS.get(String(options.get("doors", "closed")), 0.0)) if level == 0 else 0.0
	return Color((paint + 0.5) / 16.0, (stencil + 0.5) / 8.0, rust, doors)


static func paint_of(look_data: Color) -> int:
	return int(look_data.r * 16.0)


static func stencil_of(look_data: Color) -> int:
	return int(look_data.g * 8.0)
