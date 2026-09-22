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
## The band reserved at the very top of a block for roof clutter (m). It is taken OUT of the structural tiers
## rather than added on top, so a block is exactly as tall as its layout says and the mesh stays inside the
## collision box -- the contract this file opens with ("what blocks a hull and a shot is what you see"). Control's
## camera lift put these roofs on screen constantly and they were the one surface in the frame carrying no
## information at all: 8 blocks x 40 x 40 m is 16.3% of the Terminus's plan area (feel, 2026-09-20).
const ROOF_CLUTTER_H := 1.6
## Roof clutter's own `COLOR.r` tag, between the shopfront's 0.5 and the roof's 1.0, so the shader can shade it as
## dark plant instead of treating every vertical face as a lit parapet edge.
##
## **0.8, not 0.75, and the difference matters.** Vertex colours may be 8-bit, and the shader's band for clutter is
## `part < 0.85` sitting above the shopfronts' `part < 0.75`. A 0.75 tag quantises to 191/255 = 0.7490, which is
## BELOW its own band's floor, so every duct on every roof would have shaded as a shopfront -- silently, and only
## in whatever build quantised. 0.8 is 204/255 exactly and sits clear of both edges.
const PART_CLUTTER := 0.8
const NEON_BAND := Vector2(0.25, 0.06)  # height, how far it stands off the wall (m)
const SHADER := preload("res://game/theme/fx/shaders/city_block.gdshader")
const DEFAULT_SIZE := Vector3(40.0, 24.0, 40.0)
## The tier counts `build` can actually draw; `honours_tiers()` asks about them and `setup` clamps to them.
const MIN_TIERS := 1
const MAX_TIERS := 3

## S6 (round 10, per-window addressing; show's carve-out): the narrowest and widest bay a block draws (m). The bay
## is chosen per block and reaches the shader in COLOR.a as an 8-bit code, so the CPU and the GPU agree on where
## every window is -- the shader used to derive it from a sin() hash, which float32 and float64 disagree about.
const BAY_MIN := 3.0
const BAY_SPAN := 1.5

var size := DEFAULT_SIZE
var mesh_instance := MeshInstance3D.new()
static var _material: ShaderMaterial
## This block's index in the show's window grid (COLOR.b), or -1 on a peer with no show.
var block_index := -1
## This block's bay width (m): BAY_MIN + BAY_SPAN * code / 255.
var bay_m := BAY_MIN
var _grid: ShowWindowGrid
var _tiers := 1
var _setback := 0.0


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
	var tiers := clampi(int(obstacle.get("tiers", 1 + rng.randi() % 3)), MIN_TIERS, MAX_TIERS)
	var setback := float(obstacle.get("setback", rng.randf_range(2.0, 4.0)))
	var neon := CityBlock.neon_color(obstacle.get("neon", ""), rng)
	var seed01 := rng.randf()
	# Drawn AFTER every value the look already used, so adding it moved no block's tiers, setback, neon or seed.
	var bay_code := rng.randi_range(0, 255)
	bay_m = CityBlock.bay_of(bay_code)
	_tiers = tiers
	_setback = setback
	var show := Show.get_instance()
	if show != null and _grid == null:
		attach_windows(show.window_grid())
	mesh_instance.mesh = CityBlock.build(size, tiers, setback, neon, seed01, maxi(block_index, 0), bay_code)
	mesh_instance.set_surface_override_material(0, CityBlock.facade_material())
	CityBlock.patch_show()
	if _grid != null and block_index >= 0:
		_grid.add_block(block_index, CityBlock.windows_of(size, tiers, setback, bay_m, _placement(obstacle)))


## Join a window grid: claim an index (it goes into the mesh's COLOR.b, so call before the mesh is built). Public so a
## headless test can hand a block a grid without a running show.
func attach_windows(grid: ShowWindowGrid) -> void:
	_grid = grid
	block_index = grid.claim_block() if grid != null else -1


## The fixture's per-window primitive: how many windows this block has.
func window_count() -> int:
	return _grid.window_count(block_index) if _grid != null and block_index >= 0 else 0


## The fixture's per-window primitive: set this block's window `i` to `value` (0..1). `palette` 0 keeps the block's
## own colour; 1..3 is magenta, cyan, amber. Takes effect on the next frame the show flushes the grid.
func set_window(i: int, value: float, palette := 0) -> bool:
	if _grid == null or block_index < 0:
		return false
	return _grid.set_window(_grid.index_of(block_index, i), value, palette)


## Where the block stands in the world: its node's transform once in the tree, the layout's otherwise.
func _placement(obstacle: Dictionary) -> Transform3D:
	if is_inside_tree():
		return global_transform
	var at: Variant = obstacle.get("position", [0.0, 0.0])
	var yaw := deg_to_rad(float(obstacle.get("rotation_deg", 0.0)))
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(float(at[0]), 0.0, float(at[1])))


static func bay_of(code: int) -> float:
	return BAY_MIN + BAY_SPAN * float(clampi(code, 0, 255)) / 255.0


## Every window the shader draws on a block: [{facade, row, column, centre}], with `row` and `column` in the SHADER's
## terms (storey = floor(y / 3.6), world bay column = floor(along / bay)), so [method ShowWindowGrid.texel_of] lands on
## the texel the fragment reads. Only the flat faces of the storey tiers carry windows (the chamfers are 0.8 m wide;
## the shopfronts and roofs have none). Pure.
static func windows_of(block_size: Vector3, tiers: int, setback: float, bay: float, placement: Transform3D) -> Array:
	var out := []
	var list := tiers_of(block_size, tiers, setback)
	for t in range(1, list.size()):
		var poly: PackedVector2Array = list[t][0]
		var y0: float = list[t][1]
		var y1: float = list[t][2]
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var edge := b - a
			if absf(edge.x) > 0.001 and absf(edge.y) > 0.001:
				continue  # a chamfer
			var mid := (a + b) * 0.5
			var local_normal := Vector3(mid.x, 0.0, mid.y)
			local_normal = Vector3(signf(local_normal.x), 0.0, 0.0) if absf(edge.x) < 0.001 else Vector3(0.0, 0.0, signf(local_normal.z))
			var normal := (placement.basis * local_normal).normalized()
			var facade := ShowWindowGrid.facade_of(normal)
			var wa := placement * Vector3(a.x, 0.0, a.y)
			var wb := placement * Vector3(b.x, 0.0, b.y)
			var along_z := facade <= 1
			var lo := minf(wa.z, wb.z) if along_z else minf(wa.x, wb.x)
			var hi := maxf(wa.z, wb.z) if along_z else maxf(wa.x, wb.x)
			var fixed := wa.x if along_z else wa.z
			for column in range(floori(lo / bay) - 1, ceili(hi / bay) + 1):
				var along := (float(column) + (ShowWindowGrid.PANE_X.x + ShowWindowGrid.PANE_X.y) * 0.5) * bay
				if along < lo or along > hi:
					continue
				for row in range(floori(y0 / ShowWindowGrid.FLOOR_M), ceili(y1 / ShowWindowGrid.FLOOR_M) + 1):
					var y := (float(row) + (ShowWindowGrid.PANE_Y.x + ShowWindowGrid.PANE_Y.y) * 0.5) * ShowWindowGrid.FLOOR_M
					if y < y0 or y > y1:
						continue
					var centre := Vector3(fixed, y, along) if along_z else Vector3(along, y, fixed)
					out.append({"facade": facade, "row": row, "column": column, "centre": centre})
	return out


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
## A name that does not resolve is DETERMINISTIC rather than a silent random pick, which is how this survived a
## whole round: a colour someone typed on purpose must never be answered with a dice roll.
##
## **Where the LOUD half lives, and why it is not here.** This runs once per block per build, so a warning here
## would fire eight times on the Terminus and say nothing the first one did not. The rejection belongs where a
## layout is *read*, once: `Arena.validate()`, beside the other unknown-key checks (arena's file, scale's this
## round), using `CityBlock.resolves()` below. **A second reason, found the hard way:** `tests/run_tests.gd`'s
## `ErrorCollector` ignores `_error_type`, so a `push_warning` is captured as an engine error and **fails any test
## that exercises the path** -- which is exactly what the determinism test does. A product warning that no test may
## provoke is a warning in the wrong place.
static func neon_color(wanted: Variant, rng: RandomNumberGenerator) -> Color:
	if wanted is String and not String(wanted).is_empty():
		var resolved := Color.from_string(String(wanted), UNRESOLVED)
		return resolved if resolved != UNRESOLVED else NeonSigns.COLORS[0]
	var palette: Array = NeonSigns.COLORS
	return palette[rng.randi() % palette.size()]


## Whether a layout's `neon` value names a colour at all: an HTML code or a known name. For `Arena.validate()`, so
## a typo is rejected ONCE when the layout is read rather than absorbed eight times when the blocks are built.
## Whether `build` can draw the tier count a layout asks for, WITHOUT clamping it. `setup` clamps -- it must draw
## something for any input -- but a clamp is silent, so a layout asking for 4 storeys gets 3 and nobody is told;
## that is how two Terminus blocks ended up shorter and flatter than their layout asks for. Asking for nothing is
## legal and means "seed me one". Kept beside `resolves()` because it is the same question about a different key.
static func honours_tiers(wanted: Variant) -> bool:
	if wanted == null:
		return true
	if not (wanted is int or wanted is float):
		return false
	return int(wanted) == clampi(int(wanted), MIN_TIERS, MAX_TIERS)


static func resolves(wanted: Variant) -> bool:
	if not (wanted is String) or String(wanted).is_empty():
		return true  # asking for nothing is legal: the block gets a seeded signage colour
	return Color.from_string(String(wanted), UNRESOLVED) != UNRESOLVED


## The tiers' outlines and heights, bottom first: [[footprint (x, z) polygon, y from, y to], ...]. The first two (the
## shopfronts and the first storeys) fill the whole footprint; later tiers step in by `setback`. Pure, for tests and
## for anything that needs a block's silhouette without its mesh.
static func tiers_of(block_size: Vector3, tiers: int, setback: float) -> Array:
	var result := []
	var top := maxf(block_size.y, SHOP_HEIGHT + 3.0)
	# The topmost roof stops short so its clutter fits under the block's authored height instead of poking through
	# the collision box. A block with no room to spare keeps its full height and simply gets no clutter.
	var structural := maxf(top - ROOF_CLUTTER_H, SHOP_HEIGHT + 2.0)
	result.append([outline(block_size.x, block_size.z, 0.0), 0.0, SHOP_HEIGHT])
	var span := (structural - SHOP_HEIGHT) / tiers
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
##
## COLOR.b is the block's index in the show's window grid and COLOR.a its bay code, both as exact 8-bit steps (k/255),
## because vertex colours may be stored 8-bit.
static func build(block_size: Vector3, tiers: int, setback: float, neon: Color, seed01: float, index := 0,
		bay_code := 0) -> ArrayMesh:
	var b := float(clampi(index, 0, 255)) / 255.0
	var a := float(clampi(bay_code, 0, 255)) / 255.0
	var building := SurfaceTool.new()
	building.begin(Mesh.PRIMITIVE_TRIANGLES)
	var list := tiers_of(block_size, tiers, setback)
	for i in list.size():
		var poly: PackedVector2Array = list[i][0]
		var y0: float = list[i][1]
		var y1: float = list[i][2]
		var part := 0.5 if i == 0 else 0.0  # vertex colours may be 8-bit: tags stay in 0..1
		_walls(building, poly, y0, y1, Color(part, seed01, b, a))
		# A tier's roof: the bevel rolling in, then a flat cap (the next tier stands on it).
		var inner := _shrink(poly, BEVEL)
		_walls_between(building, poly, inner, y1, y1 + BEVEL, Color(1.0, seed01, b, a))
		_cap(building, inner, y1 + BEVEL, Color(1.0, seed01, b, a))
		if i == list.size() - 1:
			_roof_clutter(building, inner, y1 + BEVEL, block_size.y + BEVEL, seed01, b, a)
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


## Plant on the topmost roof: housings, ducts and a tank, in the band reserved by `ROOF_CLUTTER_H`. Appended to the
## SAME SurfaceTool as the building, so it shares the facade surface and costs **no additional draw call and no
## additional material** -- a block is still the two surfaces its docstring promises, whatever is on its roof.
##
## Everything is derived from the block's own seed, so a given block always wears the same roof, and everything is
## placed inside `_shrink(poly, EDGE)` and capped at `ceiling` so nothing overhangs the parapet or breaks the
## collision box.
static func _roof_clutter(tool: SurfaceTool, poly: PackedVector2Array, y: float, ceiling: float, seed01: float,
		b := 0.0, a := 0.0) -> void:
	var room := ceiling - y
	if room < 0.3:
		return  # a block too short to have reserved a band gets no clutter rather than a crushed one
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed01)
	var field := _shrink(poly, 2.2)
	if field.size() < 3:
		return
	var bounds := _bounds(field)
	var colour := Color(PART_CLUTTER, seed01, b, a)
	# Enough to read as a working roof at the lifted camera, few enough to stay cheap: ~10 triangles each.
	for n in 7:
		var w := rng.randf_range(2.0, 5.0)
		var d := rng.randf_range(2.0, 4.5)
		var h := minf(rng.randf_range(0.5, 1.0) * room, room)
		var centre := Vector2(rng.randf_range(bounds.position.x + w * 0.5, bounds.end.x - w * 0.5),
				rng.randf_range(bounds.position.y + d * 0.5, bounds.end.y - d * 0.5))
		if not Geometry2D.is_point_in_polygon(centre, field):
			continue
		_box(tool, centre, Vector2(w, d), y, y + h, colour)


## An axis-aligned box from `y0` to `y1`, four walls and a cap. Reuses the wall/cap builders so the winding and
## normals match the rest of the mesh.
static func _box(tool: SurfaceTool, centre: Vector2, extent: Vector2, y0: float, y1: float, colour: Color) -> void:
	var half := extent * 0.5
	var poly := PackedVector2Array([centre + Vector2(-half.x, -half.y), centre + Vector2(half.x, -half.y),
			centre + Vector2(half.x, half.y), centre + Vector2(-half.x, half.y)])
	_walls(tool, poly, y0, y1, colour)
	_cap(tool, poly, y1, colour)


static func _bounds(poly: PackedVector2Array) -> Rect2:
	var result := Rect2(poly[0], Vector2.ZERO)
	for point in poly:
		result = result.expand(point)
	return result


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
