class_name CityBlock
extends Node3D
## `prop.block` (feel, round 7): a playable city block, the lit skyline on the horizon made into buildings you can
## drive between. The lead: "a cityscape type map would be good, but I would just need to get it to match the theme and
## consistency of our gladiator environment", and "chamfered edges even though they're fairly subtle gives the
## attention to detail to bring the game to life" (the HUD's cyber frames).
##
## Parameterised, not sculpted: `setup(obstacle)` reads the layout's `size` [w, h, d] (m) and optional `tiers` (1-3),
## `setback` (m per tier), `neon` (a colour name or "#hex") and `seed`, and builds one mesh with two surfaces (facade,
## neon band): two draw calls, whatever its size.
##
## Collision is Arena's one box of `size` (ArenaKit `block`), and the art keeps to it where it matters: at ground level
## the building fills its footprint exactly, and every setback starts above SHOP_HEIGHT, well over the 1.3 m sight ray,
## so what blocks a hull and a shot is what you see. Visual only.

## The ground floor (shopfronts): full footprint, always.
const SHOP_HEIGHT := 4.2
## The corners' cut, in plan (m): subtle, like the HUD frames' chamfers.
const CHAMFER := 0.8
## Each roof's edge rolls in by this much (m), at 45 degrees.
const BEVEL := 0.3
## A tier never gets narrower than this (m).
const MIN_WIDTH := 6.0
const NEON_BAND := Vector2(0.25, 0.06)  # height, how far it stands off the wall (m)
const SHADER := preload("res://game/theme/fx/shaders/city_block.gdshader")
const DEFAULT_SIZE := Vector3(40.0, 24.0, 40.0)

var size := DEFAULT_SIZE
var mesh_instance := MeshInstance3D.new()
static var _material: ShaderMaterial


func _init() -> void:
	name = "CityBlock"
	mesh_instance.name = "Mesh"
	add_child(mesh_instance)


func _ready() -> void:
	if mesh_instance.mesh == null:
		setup({})


func setup(obstacle: Dictionary) -> void:
	var wanted: Variant = obstacle.get("size")
	size = Vector3(float(wanted[0]), float(wanted[1]), float(wanted[2])) if wanted is Array and wanted.size() == 3 else DEFAULT_SIZE
	var seed_value := int(obstacle.get("seed", hash(str(obstacle.get("position", [0, 0])))))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tiers := clampi(int(obstacle.get("tiers", 1 + rng.randi() % 3)), 1, 3)
	var setback := float(obstacle.get("setback", rng.randf_range(2.0, 4.0)))
	var neon := CityBlock.neon_color(obstacle.get("neon", ""), rng)
	mesh_instance.mesh = CityBlock.build(size, tiers, setback, neon, rng.randf())
	mesh_instance.set_surface_override_material(0, CityBlock.facade_material())
	CityBlock.patch_show()


## S6 (the arena light show, `_agents/lighting.md`): the facade is a fixture. Every block registers the ONE material
## they all share, so the show costs a single uniform write for the whole bank -- and they still breathe on eight
## different clocks, because the per-block phase is the seed already in each vertex's COLOR.g. Adding a block adds
## no draw call, no light and no per-frame cost. A no-op on a headless peer, where there is no show.
static func patch_show() -> void:
	var show := Show.get_instance()
	if show != null:
		show.add_fixture(&"city_block", CityBlock.facade_material())


static func facade_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material


## A colour a layout asked for but that is neither an HTML code nor a known name. Improbable on purpose: it is the
## sentinel `Color.from_string` hands back, and nothing should ever equal it.
const UNRESOLVED := Color(0.1234567, 0.7654321, 0.1111111, 0.9876543)


## A block's neon band colour: what the layout asked for, or a signage colour when it asked for nothing.
##
## Round 9 (found by show): this honoured ONLY strings beginning with "#", so every colour NAME a layout used fell
## straight through to a random pick from the SIGNAGE palette -- and `arenas/terminus.json` asks for "cyan" on four
## blocks and "magenta" on four. **All eight were drawing amber, warm white, red or violet**, stable only because
## the pick is seeded. That is not merely the wrong colour: `NeonSigns.COLORS` contains **red**, which this game
## uses as a SIGNAL (beacons, alarms), and a near-white, which is not in the palette at all -- so the bug was
## putting the two things art_direction.md rules out for architecture onto eight buildings on the lead's city map.
##
## A name that does not resolve is now LOUD and DETERMINISTIC rather than a silent random pick, which is how this
## survived a whole round: a colour someone typed on purpose must never be answered with a dice roll. The hard
## rejection belongs in `Arena.validate()` with the other unknown-key checks (arena's file, scale's this round).
static func neon_color(wanted: Variant, rng: RandomNumberGenerator) -> Color:
	if wanted is String and not String(wanted).is_empty():
		var text := String(wanted)
		var resolved := Color.from_string(text, UNRESOLVED)
		if resolved != UNRESOLVED:
			return resolved
		push_warning("city block neon '%s' is neither an HTML code nor a known colour name" % text)
		return NeonSigns.COLORS[0]
	var palette: Array = NeonSigns.COLORS
	return palette[rng.randi() % palette.size()]


## The tiers' outlines and heights, bottom first: [[footprint (x, z) polygon, y from, y to], ...]. The first two (the
## shopfronts and the first storeys) fill the whole footprint; later tiers step in by `setback`. Pure, for tests and
## for anything that needs a block's silhouette without its mesh.
static func tiers_of(block_size: Vector3, tiers: int, setback: float) -> Array:
	var result := []
	var top := maxf(block_size.y, SHOP_HEIGHT + 3.0)
	result.append([outline(block_size.x, block_size.z, 0.0), 0.0, SHOP_HEIGHT])
	var span := (top - SHOP_HEIGHT) / tiers
	for i in tiers:
		var inset := setback * i
		var w := maxf(block_size.x - 2.0 * inset, MIN_WIDTH)
		var d := maxf(block_size.z - 2.0 * inset, MIN_WIDTH)
		result.append([outline(w, d, 0.0), SHOP_HEIGHT + span * i, SHOP_HEIGHT + span * (i + 1)])
	return result


## A w x d rectangle centred on the origin with its corners chamfered by CHAMFER (shrunk by `inset`), counter-clockwise
## seen from above (x right, z down the screen).
static func outline(w: float, d: float, inset: float) -> PackedVector2Array:
	var hx := w / 2.0 - inset
	var hz := d / 2.0 - inset
	var c := minf(CHAMFER, minf(hx, hz) * 0.5)
	return PackedVector2Array([Vector2(-hx + c, -hz), Vector2(hx - c, -hz), Vector2(hx, -hz + c), Vector2(hx, hz - c),
			Vector2(hx - c, hz), Vector2(-hx + c, hz), Vector2(-hx, hz - c), Vector2(-hx, -hz + c)])


## The block's mesh: surface 0 the building (facade, shopfronts, bevels and roofs; COLOR.r says which, COLOR.g the
## block's seed for the shader), surface 1 the neon band over the shopfronts.
static func build(block_size: Vector3, tiers: int, setback: float, neon: Color, seed01: float) -> ArrayMesh:
	var building := SurfaceTool.new()
	building.begin(Mesh.PRIMITIVE_TRIANGLES)
	var list := tiers_of(block_size, tiers, setback)
	for i in list.size():
		var poly: PackedVector2Array = list[i][0]
		var y0: float = list[i][1]
		var y1: float = list[i][2]
		var part := 0.5 if i == 0 else 0.0  # vertex colours may be 8-bit: tags stay in 0..1
		_walls(building, poly, y0, y1, Color(part, seed01, 0.0))
		# A tier's roof: the bevel rolling in, then a flat cap (the next tier stands on it).
		var inner := _shrink(poly, BEVEL)
		_walls_between(building, poly, inner, y1, y1 + BEVEL, Color(1.0, seed01, 0.0))
		_cap(building, inner, y1 + BEVEL, Color(1.0, seed01, 0.0))
	var mesh := building.commit()
	var band := SurfaceTool.new()
	band.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ground: PackedVector2Array = list[0][0]
	_walls(band, _grow(ground, NEON_BAND.y), SHOP_HEIGHT - NEON_BAND.x - 0.1, SHOP_HEIGHT - 0.1, Color(1, 1, 1))
	band.commit(mesh)
	mesh.surface_set_material(1, CyberMaterials.neon(neon, 3.0, 0.05))
	return mesh


static func _walls(tool: SurfaceTool, poly: PackedVector2Array, y0: float, y1: float, color: Color) -> void:
	_walls_between(tool, poly, poly, y0, y1, color)


## Quads from `lower` at y0 up to `upper` at y1 (same vertex count), facing out.
static func _walls_between(tool: SurfaceTool, lower: PackedVector2Array, upper: PackedVector2Array, y0: float, y1: float,
		color: Color) -> void:
	for i in lower.size():
		var j := (i + 1) % lower.size()
		var a := Vector3(lower[i].x, y0, lower[i].y)
		var b := Vector3(lower[j].x, y0, lower[j].y)
		var c := Vector3(upper[j].x, y1, upper[j].y)
		var d := Vector3(upper[i].x, y1, upper[i].y)
		var normal := Vector3(a.x + b.x, 0.0, a.z + b.z).normalized()  # outward from the block's centre, in plan
		var slope := (d - a) if (d - a).length() > 0.001 else (c - b)
		var face := (b - a).cross(slope).normalized()
		if face.dot(normal) < 0.0:
			face = -face
		_tri(tool, a, b, c, face, color)
		_tri(tool, a, c, d, face, color)


static func _cap(tool: SurfaceTool, poly: PackedVector2Array, y: float, color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(poly)
	for k in range(0, indices.size(), 3):
		var tri := [poly[indices[k]], poly[indices[k + 1]], poly[indices[k + 2]]]
		var a := Vector3(tri[0].x, y, tri[0].y)
		var b := Vector3(tri[1].x, y, tri[1].y)
		var c := Vector3(tri[2].x, y, tri[2].y)
		_tri(tool, a, b, c, Vector3.UP, color)


## One triangle facing `normal`: Godot draws clockwise triangles as front faces, so the winding is chosen to suit.
static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	var order := [a, b, c] if (b - a).cross(c - a).dot(normal) < 0.0 else [a, c, b]
	for v: Vector3 in order:
		tool.set_color(color)
		tool.set_normal(normal)
		tool.add_vertex(v)


static func _shrink(poly: PackedVector2Array, amount: float) -> PackedVector2Array:
	var result := Geometry2D.offset_polygon(poly, -amount, Geometry2D.JOIN_MITER)
	return result[0] if not result.is_empty() and (result[0] as PackedVector2Array).size() == poly.size() else poly


static func _grow(poly: PackedVector2Array, amount: float) -> PackedVector2Array:
	var result := Geometry2D.offset_polygon(poly, amount, Geometry2D.JOIN_MITER)
	return result[0] if not result.is_empty() and (result[0] as PackedVector2Array).size() == poly.size() else poly
