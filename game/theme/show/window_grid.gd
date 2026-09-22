class_name ShowWindowGrid
extends RefCounted
## S6, round 10: every window on every city block, addressable one at a time. The lead: *"basic primitives to adjust
## individual lights on the building"*. `_agents/lighting.md` section 4c.
##
## The windows are not meshes. They are drawn procedurally in `city_block.gdshader` (a bay grid in world metres), so
## there is nothing to make a MultiMesh of, and the brief's other option is the right one: **one texel per window in a
## small texture the shader samples.** The shader finds its own texel from what it already knows about the fragment
## (the block's index in COLOR.b, the facade from the world normal, the storey from the height, the bay from the
## distance along the facade), so a window needs no vertex data and no instance uniform, and the texture is the only
## thing the CPU ever writes.
##
## Layout of the texture (RGBA8, [constant COLS] wide):
## [codeblock]
##     x = bay column  (world column id, positive modulo COLS)
##     y = (block * FACADES + facade) * ROWS + storey   (storey = floor(y / FLOOR_M), modulo ROWS)
##     r = the window's own level, 0..1 (0 = nothing the CPU asked for; the programmes still run)
##     g = a palette override: 0 = the block's colour, otherwise 1..3 picks magenta / cyan / amber
## [/codeblock]
## All-zero is the identity, so an unwritten texture changes nothing, exactly like every other `show_` default.
##
## Cost: 32 x 1024 x 4 bytes = 128 KB, uploaded only on a frame where a window changed ([method flush]). Zero draw
## calls, zero lights, zero instance uniforms. Visual only: nothing here reads or writes the simulation.

## Bay columns per facade row. A 40 m facade at the narrowest bay (3 m) is 14 columns, so 32 never wraps on a block.
const COLS := 32
## Storeys per facade. 16 x 3.6 m = 57.6 m; the Terminus blocks are 24 m.
const ROWS := 16
## World-facing facades: +x, -x, +z, -z. A block is axis-aligned (rotation 0/90/180/270), like its collision box.
const FACADES := 4
const MAX_BLOCKS := 16
## The storey height the shader's window grid uses (city_block.gdshader, `world.y / 3.6`).
const FLOOR_M := 3.6
## Where a pane sits inside its bay and storey, as fractions (the shader's `pane` step()s).
const PANE_X := Vector2(0.22, 0.8)
const PANE_Y := Vector2(0.3, 0.78)

var image := Image.create(COLS, MAX_BLOCKS * FACADES * ROWS, false, Image.FORMAT_RGBA8)
var texture: ImageTexture
## Every window, in a stable order: block, then facade, then storey, then column.
## {block: int, facade: int, row: int, column: int, texel: Vector2i, centre: Vector3}
var windows: Array[Dictionary] = []
## block index -> [first window, count]
var _ranges := {}
var _next_block := 0
var _dirty := false
## Texel writes since the last flush, and uploads performed: the counters a test reads.
var writes_pending := 0
var uploads := 0
## Windows currently above zero. The shader skips the whole layer while this is 0 and no programme runs.
var lit := 0
var live: bool:
	get:
		return lit > 0


func _init() -> void:
	image.fill(Color(0, 0, 0, 0))
	texture = ImageTexture.create_from_image(image)


## Forget every block (a new arena). Indices start again at 0.
func clear() -> void:
	windows.clear()
	_ranges.clear()
	_next_block = 0
	image.fill(Color(0, 0, 0, 0))
	lit = 0
	_dirty = true


## The next free block index, or -1 when the grid is full (the block then draws exactly as it always did: its
## windows read texel row 0 of nothing, and the programmes still run on it).
func claim_block() -> int:
	if _next_block >= MAX_BLOCKS:
		return -1
	_next_block += 1
	return _next_block - 1


## Register a block's windows (from [method CityBlock.windows_of]). Replaces any earlier registration of `block`.
func add_block(block: int, list: Array) -> void:
	if block < 0 or block >= MAX_BLOCKS:
		return
	if _ranges.has(block):
		return  # a block registers once; its geometry does not change
	var first := windows.size()
	for entry: Dictionary in list:
		var window := entry.duplicate()
		window["block"] = block
		window["texel"] = texel_of(block, int(entry["facade"]), int(entry["row"]), int(entry["column"]))
		windows.append(window)
	_ranges[block] = [first, list.size()]


## The texel that holds (block, facade, storey, world column): the same arithmetic the shader does.
static func texel_of(block: int, facade: int, row: int, column: int) -> Vector2i:
	return Vector2i(posmod(column, COLS), (block * FACADES + facade) * ROWS + posmod(row, ROWS))


## Which facade a world-space normal faces: 0 = +x, 1 = -x, 2 = +z, 3 = -z. The shader's rule, including the tie.
static func facade_of(normal: Vector3) -> int:
	if absf(normal.x) > absf(normal.z):
		return 0 if normal.x > 0.0 else 1
	return 2 if normal.z > 0.0 else 3


## How many windows `block` has, or every block's when `block` is -1.
func window_count(block := -1) -> int:
	if block < 0:
		return windows.size()
	return int(_ranges.get(block, [0, 0])[1])


## The global index of `block`'s `i`th window, or -1.
func index_of(block: int, i: int) -> int:
	var range_: Array = _ranges.get(block, [0, 0])
	return int(range_[0]) + i if i >= 0 and i < int(range_[1]) else -1


## Set window `index` (global) to `value` (0..1), optionally with a palette override (0 = the block's colour).
## Returns false for an index that does not exist.
func set_window(index: int, value: float, palette := 0) -> bool:
	if index < 0 or index >= windows.size():
		return false
	var texel: Vector2i = windows[index]["texel"]
	var was := image.get_pixelv(texel).r > 0.0
	var level := clampf(value, 0.0, 1.0)
	image.set_pixelv(texel, Color(level, float(palette) / 255.0, 0.0, 0.0))
	lit += (1 if level > 0.0 else 0) - (1 if was else 0)
	_dirty = true
	writes_pending += 1
	return true


## The level window `index` was last set to.
func get_window(index: int) -> float:
	if index < 0 or index >= windows.size():
		return 0.0
	return image.get_pixelv(windows[index]["texel"]).r


## Every window back to zero (nothing the CPU asked for).
func clear_levels() -> void:
	image.fill(Color(0, 0, 0, 0))
	lit = 0
	_dirty = true


## Upload the texture if anything changed since the last call. One `ImageTexture.update` at most per frame, and none
## at all on a frame where no window was written -- which is every frame of the idle, because the idle programmes
## run in the shader.
func flush() -> bool:
	if not _dirty:
		return false
	texture.update(image)
	_dirty = false
	writes_pending = 0
	uploads += 1
	return true
