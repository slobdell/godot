class_name CoverTables
extends RefCounted
## A3 (research catalogue row A3, scale round 9): **cover measured over a hull's own length, not at its centre
## point.** The query this replaces asks "is the point where this vehicle's centre is within 45 m of something tall
## enough?", which is why yard's cover score for the 14 m War Rig is **0.00 while its 12 m score is 0.99** -- a step
## function at 12.19 m, the length of `container_40`, with nothing in between. The cliff is an artefact of the
## QUERY, not of the maps (game_design.md *Ruling: the War Rig stays at 14 m*), and after S1 it stops being the
## rig's problem: six hulls are now over 6.5 m, and pit's score already halves at 7.0 m.
##
## REPLACES: centre-point cover registration (`TacticalQuery.hull_hidden`'s consumer side and
## `arena_report.hull_cover_reach`'s definition). Invariant 0c: this is a replacement, not an addition -- the point
## sample is kept printed BESIDE the fraction for one round (lesson 49: report the split alongside, never instead
## of) and then goes.
##
## HOW IT IS O(1) IN HULL LENGTH. Three layers, all built once when an arena is built, all integer:
##
##   `_blocked[cell]`        1 where something at or above eye level stands. Read from the layout's own obstacle
##                           list, never copied.
##   `_shadow[k][cell]`      for each of K = 8 canonical viewing directions, 1 if a blocker stands within
##                           COVER_REACH_M of this cell ALONG direction k -- i.e. if a watcher over there is
##                           looking through something. One sweep per direction: a running distance-to-blocker
##                           carried back along each line.
##   `_prefix[k][family]`    a running count of `_shadow[k]` along each of the four line families (E, NE, N, NW).
##
## A hull is a chord: a segment of `length` centred on the vehicle, along its heading. Its occluded fraction from a
## watcher is `_prefix[k][family][end] - _prefix[k][family][start-1]` over the chord's cell count -- **two lookups
## and a subtraction, the same work at 2.93 m and at 14.0 m**, and exact integer arithmetic with no reduction order
## to depend on (combat asked for that in a test, not a comment: `tests/test_arena_cover_tables.gd`).
##
## WHAT IT APPROXIMATES, stated because combat's thresholds sit directly on it:
##   * **heading, to 8 directions.** A hull is read as lying along the nearest 45 deg.
##   * **the watcher's direction, to 8 directions**, and the watcher is treated as being at infinity along it: the
##     question asked is "is there a blocker within COVER_REACH_M that way", not "is the blocker between us". A
##     watcher standing closer than the blocker is therefore read as blocked. That is the same assumption
##     `arena_report`'s 45 m reach already makes, made explicit.
##   * **position, to CELL_M.** This term does NOT scale with hull length, so it is a larger fraction of a Rat Rod
##     (2.93 m, 2 cells) than of a War Rig (14.0 m, 8 cells). `worst_case_error()` reports both terms.

## Metres per cell. 2.0 m is a compromise: the shortest hull in the catalog is 2.93 m, so a smaller cell buys
## resolution where it is most needed, and the tables are K x 4 arrays of the whole grid.
const CELL_M := 2.0
## The canonical directions, in order: +X, +X+Z, +Z, -X+Z, -X, -X-Z, -Z, +X-Z.
const HEADINGS := 8
## How far away a prop still counts as cover. `arena_report.TERRAIN_RADIUS`, and the number every existing cover
## figure on this project was measured with.
const COVER_REACH_M := 45.0
## tan(22.5 deg): the boundary between "along an axis" and "along a diagonal" when a direction is quantised.
## Used instead of atan2 on purpose -- trig does not agree across builds (trip-up 52) and this is two multiplies
## and a comparison.
const DIAGONAL_TAN := 0.41421356237

## Cell steps for each of the eight directions, in grid coordinates.
const STEPS := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]

var _n := 0            ## cells per side
var _origin := 0.0     ## world metres at cell 0's centre, on both axes
var _blocked: PackedByteArray = PackedByteArray()
var _shadow: Array = []   ## [k] -> PackedByteArray
var _prefix: Array = []   ## [k][family] -> PackedInt32Array
var _built := false


## Build from a layout dictionary (the same `obstacles` list the collision bodies are built from -- read, never
## copied). Safe to call on an empty layout: every query then returns 0.0.
static func build(layout: Dictionary) -> CoverTables:
	var tables := CoverTables.new()
	tables._build(layout)
	return tables


func is_built() -> bool:
	return _built


func cell_count() -> int:
	return _n


func _build(layout: Dictionary) -> void:
	var half: float = float(layout.get("half_size", 120.0))
	if half <= 0.0:
		return
	_n = int(ceil(2.0 * half / CELL_M)) + 1
	_origin = -half
	_blocked = PackedByteArray()
	_blocked.resize(_n * _n)
	for entry: Dictionary in layout.get("obstacles", []):
		var size := Arena.obstacle_size(entry)
		if size.y < Perception.EYE_HEIGHT:
			continue  # a low obstacle does not block a look (arena_report's own rule)
		_mark(entry, size)
	_shadow = []
	_prefix = []
	for k in HEADINGS:
		_shadow.append(_sweep_shadow(k))
	for k in HEADINGS:
		var families: Array = []
		for family in 4:
			families.append(_sweep_prefix(_shadow[k], family))
		_prefix.append(families)
	_built = true


## 1 into every cell whose centre lies inside this obstacle's rotated footprint.
func _mark(entry: Dictionary, size: Vector3) -> void:
	var at := Vector2(float(entry["position"][0]), float(entry["position"][1]))
	var yaw := deg_to_rad(float(entry.get("rotation_deg", 0.0)))
	var half_w := size.x / 2.0
	var half_d := size.z / 2.0
	var reach := maxf(half_w, half_d) + CELL_M
	var lo := _cell_of(at.x - reach, at.y - reach)
	var hi := _cell_of(at.x + reach, at.y + reach)
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			if cx < 0 or cz < 0 or cx >= _n or cz >= _n:
				continue
			var world := Vector2(_origin + cx * CELL_M, _origin + cz * CELL_M) - at
			var local := world.rotated(-yaw)
			if absf(local.x) <= half_w and absf(local.y) <= half_d:
				_blocked[cz * _n + cx] = 1


## For direction `k`: 1 where a blocker stands within COVER_REACH_M along k. Carried back along each line, so the
## whole grid costs one pass per direction.
func _sweep_shadow(k: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(_n * _n)
	var step: Vector2i = STEPS[k]
	var step_m := CELL_M if (step.x == 0 or step.y == 0) else CELL_M * sqrt(2.0)
	# Walk every line of this direction backwards (from its far end toward its start), carrying the distance to the
	# nearest blocker ahead.
	for start: Vector2i in _line_starts(-step):
		var at: Vector2i = start
		var distance := INF
		while at.x >= 0 and at.y >= 0 and at.x < _n and at.y < _n:
			var index: int = at.y * _n + at.x
			if _blocked[index] == 1:
				distance = 0.0
			else:
				distance += step_m
			out[index] = 1 if distance <= COVER_REACH_M else 0
			at -= step
	return out


## A running count of `field` along every line of one of the four families (0 = +X, 1 = +X+Z, 2 = +Z, 3 = -X+Z),
## inclusive of the cell itself.
func _sweep_prefix(field: PackedByteArray, family: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(_n * _n)
	var step: Vector2i = STEPS[family]
	for start: Vector2i in _line_starts(step):
		var at: Vector2i = start
		var running := 0
		while at.x >= 0 and at.y >= 0 and at.x < _n and at.y < _n:
			var index: int = at.y * _n + at.x
			running += field[index]
			out[index] = running
			at += step
	return out


## Every cell a line of direction `step` can start from: the grid edges it enters through.
func _line_starts(step: Vector2i) -> Array:
	var starts: Array = []
	for i in _n:
		if step.x > 0:
			starts.append(Vector2i(0, i))
		elif step.x < 0:
			starts.append(Vector2i(_n - 1, i))
		if step.y > 0 and step.x != 0:
			starts.append(Vector2i(i, 0))
		elif step.y < 0 and step.x != 0:
			starts.append(Vector2i(i, _n - 1))
		if step.x == 0:
			starts.append(Vector2i(i, 0 if step.y > 0 else _n - 1))
	return starts


func _cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(round((x - _origin) / CELL_M)), int(round((z - _origin) / CELL_M)))


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _n and cell.y < _n


## The canonical direction index nearest `flat` (a direction in world XZ), or -1 for a zero vector. No trig: two
## multiplies and a comparison, so it cannot disagree between builds the way atan2 does (trip-up 52).
static func direction_index(flat: Vector2) -> int:
	if flat.length_squared() < 1e-12:
		return -1
	var ax := absf(flat.x)
	var az := absf(flat.y)
	var diagonal := minf(ax, az) >= DIAGONAL_TAN * maxf(ax, az)
	if diagonal:
		if flat.x >= 0.0:
			return 1 if flat.y >= 0.0 else 7
		return 3 if flat.y >= 0.0 else 5
	if ax >= az:
		return 0 if flat.x >= 0.0 else 4
	return 2 if flat.y >= 0.0 else 6


## **THE QUERY** (combat's signature, contract A3). The fraction of a hull's own centreline chord that is occluded
## from `viewer`: 0.0 fully exposed, 1.0 fully covered.
##
##   `viewer`   where the threat is looking from (world)
##   `point`    the hull's centre (world)
##   `heading`  the hull's forward, flat; length ignored
##   `length`   the hull's length in metres (`Units.PROFILES[id].hull_size[2]`)
##
## Returns **0.0, never garbage**, for a hull off the table, outside the arena, or on an arena with no tables --
## and it does not push an error doing so: combat calls this per candidate, per query, per unit.
func cover_fraction(viewer: Vector3, point: Vector3, heading: Vector3, length: float) -> float:
	if not _built or length <= 0.0:
		return 0.0
	var view := direction_index(Vector2(viewer.x - point.x, viewer.z - point.z))
	var along := direction_index(Vector2(heading.x, heading.z))
	if view < 0 or along < 0:
		return 0.0
	var family := along % 4
	var step: Vector2i = STEPS[family]
	var step_m := CELL_M if (step.x == 0 or step.y == 0) else CELL_M * sqrt(2.0)
	var centre := _cell_of(point.x, point.z)
	if not _inside(centre):
		return 0.0
	# The chord, in whole cells. `round(length / step)` rather than `floor(length / 2 / step) * 2 + 1`: the latter
	# collapses every hull shorter than twice the cell to a SINGLE cell, which is the centre-point query this row
	# exists to replace -- the Rat Rod (2.93 m) and the whole light end of the roster would have got the old answer
	# under a new name. One cell is still the floor, because a hull shorter than a cell really is a point at this
	# resolution, and `worst_case_error()` says so instead of hiding it.
	var cells: int = maxi(1, int(round(length / step_m)))
	var first := centre - step * int(floor((cells - 1) / 2.0))
	var last := first + step * (cells - 1)
	if not _inside(first) or not _inside(last):
		return 0.0
	var prefix: PackedInt32Array = _prefix[view][family]
	var before := first - step
	var base: int = prefix[before.y * _n + before.x] if _inside(before) else 0
	var occluded: int = prefix[last.y * _n + last.x] - base
	return float(occluded) / float(cells)


## What the quantisation costs, for a hull of `length` metres, as a fraction of that length. Two terms, because
## they behave differently and combat's threshold sits on the sum:
##   `angular`  the chord is read along the nearest 45 deg, so its projected extent is short by
##              `1 - cos(22.5 deg)` at worst. A CONSTANT FRACTION of any hull length.
##   `grid`     the chord is sampled in whole CELL_M cells, so up to one cell of length is unaccounted for. A
##              CONSTANT IN METRES, and therefore a LARGER fraction for a short hull than for a long one.
## So the query is least precise on the Rat Rod, not on the War Rig -- which is the opposite of the intuition, and
## it is where a threshold will be tightest.
static func worst_case_error(length: float) -> Dictionary:
	var angular := 1.0 - cos(deg_to_rad(22.5))
	# One cell of chord is unaccounted for at worst, because the chord is a whole number of cells.
	var grid := CELL_M / maxf(length, 0.01)
	return {"angular": angular, "grid": grid, "total": angular + grid,
			"angular_m": angular * length, "grid_m": CELL_M}
