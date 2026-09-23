class_name ShowWindowEffects
extends RefCounted
## S6 round 10: the effects that need the CPU to address windows one at a time -- everything the shader cannot work
## out from a window's (storey, bay, facade) and one clock. `_agents/lighting.md` section 4c.
##
## Two today:
##   * **the capture fill**: an objective changing hands fills the block nearest it FLOOR BY FLOOR, one storey every
##     [constant FILL_STEP_S], holds, then fades. Texel writes into [ShowWindowGrid], one texture upload a frame.
##   * **the facing facade**: which (block, facade) looks at a point -- the last-stand strobe runs on the one facade
##     facing the losing base instead of on the whole city ([method Show.focus_pixels]).
## Visual only; frame time; reads positions, writes texels.

const FILL_STEP_S := 0.18
const FILL_HOLD_S := 1.4
const FILL_FADE_S := 1.2
## The venue's amber (palette 3 in the grid): a capture is an event in the building, not a team's colour -- the
## victory sweep stays the one team-coloured cue (art_direction.md).
const FILL_PALETTE := 3

## Running fills: {block: int, rows: Array[int] ascending, by_row: {row: [global window index]}, age: float}
var fills: Array[Dictionary] = []


## The block whose windows' centroid is nearest `at` (world x, z), or -1 on an empty grid.
static func nearest_block(grid: ShowWindowGrid, at: Vector2) -> int:
	var best := -1
	var best_d := INF
	var sums := {}
	for w: Dictionary in grid.windows:
		var c: Vector3 = w["centre"]
		var entry: Array = sums.get_or_add(int(w["block"]), [Vector2.ZERO, 0])
		entry[0] += Vector2(c.x, c.z)
		entry[1] += 1
	for block: int in sums:
		var centre: Vector2 = sums[block][0] / float(sums[block][1])
		var d := centre.distance_to(at)
		if d < best_d:
			best_d = d
			best = block
	return best


## (block, facade) of the facade that FACES `toward` and is nearest it: its outward normal points at the point and its
## windows' centroid is the closest such. Vector2i(-1, -1) when none faces it.
static func facing_facade(grid: ShowWindowGrid, toward: Vector2) -> Vector2i:
	const NORMALS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	var sums := {}
	for w: Dictionary in grid.windows:
		var c: Vector3 = w["centre"]
		var key := Vector2i(int(w["block"]), int(w["facade"]))
		var entry: Array = sums.get_or_add(key, [Vector2.ZERO, 0])
		entry[0] += Vector2(c.x, c.z)
		entry[1] += 1
	var best := Vector2i(-1, -1)
	var best_d := INF
	for key: Vector2i in sums:
		var centre: Vector2 = sums[key][0] / float(sums[key][1])
		var to := toward - centre
		if to.dot(NORMALS[key.y]) <= 0.0:
			continue
		var d := to.length()
		if d < best_d:
			best_d = d
			best = key
	return best


## Start a floor-by-floor fill on the block nearest `at`. Returns the block, or -1.
func start_fill(grid: ShowWindowGrid, at: Vector2) -> int:
	var block := nearest_block(grid, at)
	if block < 0:
		return -1
	var by_row := {}
	for i in grid.window_count(block):
		var index := grid.index_of(block, i)
		by_row.get_or_add(int(grid.windows[index]["row"]), []).append(index)
	var rows: Array = by_row.keys()
	rows.sort()
	for fill: Dictionary in fills:
		if fill["block"] == block:
			fills.erase(fill)  # a second capture restarts the block's fill rather than stacking two
			break
	fills.append({"block": block, "rows": rows, "by_row": by_row, "age": 0.0})
	return block


## How lit storey number `k` (0 = the lowest) of a fill is at `age` seconds, 0..1.
static func fill_level(k: int, storeys: int, age: float) -> float:
	var on_at := float(k) * FILL_STEP_S
	if age < on_at:
		return 0.0
	var fade_at := float(storeys) * FILL_STEP_S + FILL_HOLD_S
	if age < fade_at:
		return 1.0
	return clampf(1.0 - (age - fade_at) / FILL_FADE_S, 0.0, 1.0)


## Total length of a fill on a block with `storeys` storeys.
static func fill_life(storeys: int) -> float:
	return float(storeys) * FILL_STEP_S + FILL_HOLD_S + FILL_FADE_S


## Advance every fill by `delta` and write the windows whose level changed. Returns the texel writes made.
func advance(grid: ShowWindowGrid, delta: float) -> int:
	var writes := 0
	var finished: Array[Dictionary] = []
	for fill: Dictionary in fills:
		var before := float(fill["age"])
		var age := before + delta
		fill["age"] = age
		var rows: Array = fill["rows"]
		for k in rows.size():
			var was := fill_level(k, rows.size(), before) if before > 0.0 else -1.0
			var level := fill_level(k, rows.size(), age)
			if is_equal_approx(was, level):
				continue
			for index: int in fill["by_row"][rows[k]]:
				grid.set_window(index, level, FILL_PALETTE)
				writes += 1
		if age >= fill_life(rows.size()):
			finished.append(fill)
	for fill in finished:
		fills.erase(fill)
	return writes
