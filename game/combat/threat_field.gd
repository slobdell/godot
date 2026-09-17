class_name ThreatField
extends RefCounted
## L2 (round 4, combat X1): **where the bullets are**. A coarse grid over the arena holding "incoming fire
## density": every round that resolves stamps the cells it flew through (or burst in), and the whole field fades.
##
## Why a grid and not per-round geometry: suppression is about VOLUME over an AREA, and everything that wants to
## know about it asks the same two questions — "how much fire is falling here?" and "does this path cross a wall
## of bullets?". A grid answers both in constant time per query, costs one stamp per round instead of a
## rounds x units sweep every tick, and scales to the 30-a-side armies round 4 is aiming at. Match keeps one
## field per team, indexed by the team being shot AT (so `threat_field(team)` is that team's INCOMING fire).
##
## Deterministic: stamps are pure float math in a fixed order and decay is counted in physics ticks, never
## seconds off a clock ([determinism.md](../../_agents/determinism.md)). Suppression must never read the wall clock.
##
## Consumers (contract L2 in _agents/workstreams.md): ai (avoid beaten zones, suppress on purpose), doctrine
## (support-by-fire drills), audio (cues). They go through `Match.threat_field` / `Match.is_beaten_zone`.

## Cell size in meters. 6 m is about two hull lengths: fine enough that a lane reads as a lane, coarse enough that
## a 240 m arena is 40 x 40 cells (1600 floats per team).
const CELL_SIZE := 6.0
## Fire fades with a half-life of this many seconds once the guns stop. A crew is still under fire for a beat
## after the last round: shorter than this and a stream of machine-gun bullets flickers instead of holding a lane.
const HALF_LIFE_SECONDS := 1.0
## Densities below this read as exactly 0, so "the lane is clear" is never float dust (and decay() can stop early).
const EPSILON := 0.0005
## Stamps march along a round's path in steps of CELL_SIZE x this, so no cell on the line is skipped.
const MARCH_FRACTION := 0.5

var cell_size := CELL_SIZE
var cols := 0
var rows := 0
## World position of the grid's lower-left corner (x, z minimum).
var origin := Vector3.ZERO
## Fire density per cell, row-major (index = row * cols + col). Float32: this is a heat map, not an accountant.
var density := PackedFloat32Array()
## CP1 (round 5): the cells holding any fire, so decay() touches those instead of all ~1,700 cells of both teams'
## grids every 3 ticks. Same arithmetic per cell, so the field (and the sim) is bit-identical to the full sweep.
var _active := PackedInt32Array()
var _is_active := PackedByteArray()


func _init(half_size: float, p_cell_size: float = CELL_SIZE) -> void:
	cell_size = p_cell_size
	# One cell of margin each way, so a round that resolves just outside the wall still marks the ground inside.
	cols = int(ceil(half_size * 2.0 / cell_size)) + 2
	rows = cols
	origin = Vector3(-half_size - cell_size, 0.0, -half_size - cell_size)
	density.resize(cols * rows)
	_is_active.resize(cols * rows)


## The cell holding `point`, or -1 when it lies outside the grid.
func index_of(point: Vector3) -> int:
	var col := int(floor((point.x - origin.x) / cell_size))
	var row := int(floor((point.z - origin.z) / cell_size))
	if col < 0 or col >= cols or row < 0 or row >= rows:
		return -1
	return row * cols + col


## Fire density at a spot (0 = nothing is falling there).
func at(point: Vector3) -> float:
	var index := index_of(point)
	return density[index] if index >= 0 else 0.0


## One cell's worth of fire (a hit, a single impact).
func stamp_point(point: Vector3, weight: float) -> void:
	var index := index_of(point)
	if index >= 0:
		density[index] += weight
		_mark(index)


## The beaten zone of one direct-fire round: every cell between the muzzle and where the round stopped.
func stamp_segment(from: Vector3, to: Vector3, weight: float) -> void:
	var span := Vector2(to.x - from.x, to.z - from.z)
	var length := span.length()
	if length < 0.01:
		stamp_point(from, weight)
		return
	var step := cell_size * MARCH_FRACTION
	var steps := int(length / step) + 1
	var last := -1
	for i in steps + 1:
		var travelled := minf(length, float(i) * step)
		var spot := Vector3(from.x + span.x / length * travelled, 0.0, from.z + span.y / length * travelled)
		var index := index_of(spot)
		if index >= 0 and index != last:
			density[index] += weight
			_mark(index)
		last = index


## A burst: every cell whose center lies within `radius` of the landing point.
func stamp_burst(center: Vector3, radius: float, weight: float) -> void:
	var min_col := maxi(0, int(floor((center.x - radius - origin.x) / cell_size)))
	var max_col := mini(cols - 1, int(floor((center.x + radius - origin.x) / cell_size)))
	var min_row := maxi(0, int(floor((center.z - radius - origin.z) / cell_size)))
	var max_row := mini(rows - 1, int(floor((center.z + radius - origin.z) / cell_size)))
	for row in range(min_row, max_row + 1):
		for col in range(min_col, max_col + 1):
			var spot := cell_center(col, row)
			if Vector2(spot.x - center.x, spot.z - center.z).length() <= radius:
				density[row * cols + col] += weight
				_mark(row * cols + col)


func cell_center(col: int, row: int) -> Vector3:
	return Vector3(origin.x + (col + 0.5) * cell_size, 0.0, origin.z + (row + 0.5) * cell_size)


## Fade every cell by `ticks` physics ticks' worth of decay (HALF_LIFE_SECONDS).
func decay(ticks: int) -> void:
	if ticks <= 0:
		return
	var factor := pow(0.5, float(ticks) / 60.0 / HALF_LIFE_SECONDS)
	var kept := 0
	for n in _active.size():
		var i := _active[n]
		var value := density[i] * factor
		if value > EPSILON:
			density[i] = value
			_active[kept] = i
			kept += 1
		else:
			density[i] = 0.0
			_is_active[i] = 0
	_active.resize(kept)


func _mark(index: int) -> void:
	if _is_active[index] == 0:
		_is_active[index] = 1
		_active.append(index)


## The worst fire anywhere along a path: "would this move take me through a wall of bullets?".
func peak_along(from: Vector3, to: Vector3) -> float:
	var worst := 0.0
	for value in _samples_along(from, to):
		worst = maxf(worst, value)
	return worst


## The average fire along a path: how much of the trip is exposed (a long crawl through light fire can be worse
## than a short dash through heavy fire).
func mean_along(from: Vector3, to: Vector3) -> float:
	var samples := _samples_along(from, to)
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for value in samples:
		total += value
	return total / samples.size()


func _samples_along(from: Vector3, to: Vector3) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var span := Vector2(to.x - from.x, to.z - from.z)
	var length := span.length()
	if length < 0.01:
		samples.append(at(from))
		return samples
	var step := cell_size * MARCH_FRACTION
	var steps := int(length / step) + 1
	var last := -1
	for i in steps + 1:
		var travelled := minf(length, float(i) * step)
		var spot := Vector3(from.x + span.x / length * travelled, 0.0, from.z + span.y / length * travelled)
		var index := index_of(spot)
		if index != last:
			samples.append(density[index] if index >= 0 else 0.0)
		last = index
	return samples


## Total fire on the board (tests and readouts).
func total() -> float:
	var sum := 0.0
	for value in density:
		sum += value
	return sum


## Cells with fire in them, for debug overlays and measurements: [{position, density}], strongest first.
func hot_cells(limit := 12) -> Array:
	var found: Array = []
	for i in density.size():
		if density[i] > EPSILON:
			found.append({"position": cell_center(i % cols, i / cols), "density": density[i]})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["density"]) > float(b["density"]))
	return found.slice(0, limit)
