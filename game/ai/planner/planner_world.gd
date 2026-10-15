class_name PlannerWorld
extends RefCounted
## Round 30 (planner P2): **what a plan may not drive through**, as the search queries it.
##
## Two kinds of obstacle, two different tests:
##   - WALLS, through a clearance field `clearance(x, z)` = metres from (x, z) to the nearest wall face (0 or less
##     inside one). The field is filled LAZILY on a CELL_M grid: a cell is computed the first time it is read, by
##     `_wall_distance` (exact rectangles here; `PlannerNavWorld` overrides it with the navmesh: bake radius minus the
##     distance off the mesh, which is `Movement._outline_offs`' arithmetic). Samples are BILINEAR between cell
##     centres: exact along a flat face, an overestimate of at most ~0.1 m at a convex corner (a chord over a convex
##     cone), which SAMPLE_SLACK_M covers. The grid is the reason the search is affordable: an outline point costs
##     four lookups, not a distance to every rectangle.
##   - OTHER HULLS, as oriented boxes, tested against the planning hull's box by the separating-axis test (four axes,
##     no trig). A disc would make a 14 m rig a 7 m wall across a street (P0 §5.2).
##
## `footprint(...)` is the one call the search makes per pose: the least wall clearance over the hull's outline
## (INF when nothing is near), or -1.0 when a point is inside the margin and deeper than it started (the k-turn's
## own rule: a nose parked against a face may not get deeper, so a wedged start is plannable), or -1.0 on a hull overlap.
##
## Deterministic: a Dictionary keyed by an integer cell id, filled in whatever order the search asks, read by key only.

const CELL_M := 0.5
const SAMPLE_SLACK_M := 0.15
## Another hull's box is grown by this on every side (the k-turn's `HULL_MARGIN_M` is 1.0 on a disc; a box needs less).
const HULL_MARGIN_M := 0.5
## Cells more than this from any wall read as "open" without a distance (the field is only needed near walls).
const FAR_M := 50.0

## Wall rectangles: [cx, cz, half_x, half_z, fx, fz] (an oriented box: `f` its long-axis direction, unit).
var walls: Array = []
## Other hulls: [cx, cz, fx, fz, half_w, half_l, name].
var hulls: Array = []
## The lazy field: a window of cells round `prepare`'s centre (a PackedFloat32Array indexed by cell, UNSET until read;
## outside the window a Dictionary, so a query off the window still answers). UNSET is tested with `<`, never `==`:
## a float32 does not round-trip the literal (the first run read every cell as -1e30 of clearance).
const UNSET := -1.0e30
const UNSET_BELOW := -1.0e29
var _field := PackedFloat32Array()
var _field_x0 := 0
var _field_z0 := 0
var _field_n := 0
var _spill := {}


## An axis-aligned wall box from its min and max corners.
func add_wall_box(x0: float, z0: float, x1: float, z1: float) -> void:
	walls.append([(x0 + x1) * 0.5, (z0 + z1) * 0.5, absf(x1 - x0) * 0.5, absf(z1 - z0) * 0.5, 1.0, 0.0])
	forget()


## An oriented wall box: centre, half extents along its heading and across it, heading as a unit vector.
func add_wall_oriented(cx: float, cz: float, half_along: float, half_across: float, fx: float, fz: float) -> void:
	var f := Vector2(fx, fz).normalized()
	walls.append([cx, cz, half_along, half_across, f.x, f.y])
	forget()


## Another hull as an oriented box (half_w across, half_l along its forward).
func add_hull(cx: float, cz: float, fx: float, fz: float, half_w: float, half_l: float, hull_name := "") -> void:
	var f := Vector2(fx, fz).normalized()
	hulls.append([cx, cz, f.x, f.y, half_w, half_l, hull_name])


## Round 31 (CP-P0): the world as the C++ planner takes it: the wall rectangles and the hull boxes flat, as doubles
## (PackedFloat64Array: the values here arrive unchanged). PlannerNavWorld adds the navigation map and the bake radius.
func native_view() -> Dictionary:
	var flat_walls := PackedFloat64Array()
	for wall: Array in walls:
		for v: float in wall:
			flat_walls.append(v)
	var flat_hulls := PackedFloat64Array()
	for hull: Array in hulls:
		for i in 6:
			flat_hulls.append(float(hull[i]))
	return {"walls": flat_walls, "hulls": flat_hulls}


## Drop every cached cell (the walls changed).
func forget() -> void:
	_field.fill(UNSET)
	_spill.clear()


## Size the cell window round (cx, cz) with `half` metres each way (the search's horizon plus the hull's reach).
func prepare(cx: float, cz: float, half: float) -> void:
	_field_n = int(ceil(half * 2.0 / CELL_M)) + 3
	_field_x0 = int(floor((cx - half) / CELL_M)) - 1
	_field_z0 = int(floor((cz - half) / CELL_M)) - 1
	_field.resize(_field_n * _field_n)
	_field.fill(UNSET)
	_spill.clear()


## Metres from (x, z) to the nearest wall face, bilinear between the lazily computed cell centres, less the sampling
## slack. Negative inside a wall. INF when no walls are known near.
func clearance(x: float, z: float) -> float:
	var gx := x / CELL_M
	var gz := z / CELL_M
	var ix := int(floor(gx))
	var iz := int(floor(gz))
	var tx := gx - float(ix)
	var tz := gz - float(iz)
	var c00 := _cell(ix, iz)
	var c10 := _cell(ix + 1, iz)
	var c01 := _cell(ix, iz + 1)
	var c11 := _cell(ix + 1, iz + 1)
	if c00 >= FAR_M and c10 >= FAR_M and c01 >= FAR_M and c11 >= FAR_M:
		return INF
	var a := c00 + (c10 - c00) * tx
	var b := c01 + (c11 - c01) * tx
	return a + (b - a) * tz - SAMPLE_SLACK_M


func _cell(ix: int, iz: int) -> float:
	var cx := ix - _field_x0
	var cz := iz - _field_z0
	if cx >= 0 and cz >= 0 and cx < _field_n and cz < _field_n:
		var i := cx * _field_n + cz
		var v := _field[i]
		if v > UNSET_BELOW:
			return v
		# Round 31 (P6): stored, then READ BACK, so a cell is the same float32 on its first read as on every later one
		# (the C++ keeps a navmesh's cells across plans; a value that depended on which read was first could not be
		# held to the GDScript by the twin test).
		_field[i] = _wall_distance((float(ix) + 0.5) * CELL_M, (float(iz) + 0.5) * CELL_M)
		return _field[i]
	var key := (ix + 1048576) * 2097152 + (iz + 1048576)
	var known: Variant = _spill.get(key)
	if known != null:
		return known
	var narrowed := PackedFloat32Array([_wall_distance((float(ix) + 0.5) * CELL_M, (float(iz) + 0.5) * CELL_M)])
	_spill[key] = narrowed[0]  # a float32, as the window's cells are
	return narrowed[0]


## The exact distance from a point to the nearest wall rectangle's boundary (negative inside). Overridden by a navmesh
## world. FAR_M when there are no walls.
func _wall_distance(x: float, z: float) -> float:
	var best := FAR_M
	for wall: Array in walls:
		var fx := float(wall[4])
		var fz := float(wall[5])
		var dx := x - float(wall[0])
		var dz := z - float(wall[1])
		var along := dx * fx + dz * fz
		var across := -dx * fz + dz * fx
		var ox := absf(along) - float(wall[2])
		var oz := absf(across) - float(wall[3])
		var d: float
		if ox > 0.0 and oz > 0.0:
			d = sqrt(ox * ox + oz * oz)
		else:
			d = maxf(ox, oz)  # inside on one axis: the signed distance to the nearer face (negative when inside both)
		if d < best:
			best = d
	return best


## The least wall clearance along each SIDE of a hull box at a pose (front, right, back, left), by a sphere walk: a
## point with clearance `c` covers the side for `c - margin` either way, so the walk steps by that and never misses a
## wall corner between samples (ten fixed points let a block corner through between the quarter points of a 14 m
## side). In the open one read per corner covers a side; near a wall the walk densifies to CELL_M. A side whose walk
## meets a point under `margin` reads that point's clearance (the least found), so the caller can apply the start rule.
func side_clearances(x: float, z: float, fx: float, fz: float, half_w: float, half_l: float, margin: float) -> PackedFloat32Array:
	var rx := -fz
	var rz := fx
	var out := PackedFloat32Array()
	out.resize(4)
	# corners: front-right, back-right, back-left, front-left
	var frx := x + fx * half_l + rx * half_w
	var frz := z + fz * half_l + rz * half_w
	var brx := x - fx * half_l + rx * half_w
	var brz := z - fz * half_l + rz * half_w
	var blx := x - fx * half_l - rx * half_w
	var blz := z - fz * half_l - rz * half_w
	var flx := x + fx * half_l - rx * half_w
	var flz := z + fz * half_l - rz * half_w
	out[0] = _walk(flx, flz, frx, frz, margin)   # front
	out[1] = _walk(frx, frz, brx, brz, margin)   # right
	out[2] = _walk(brx, brz, blx, blz, margin)   # back
	out[3] = _walk(blx, blz, flx, flz, margin)   # left
	return out


## The least clearance along the segment a -> b, sampled where the last sample's clearance stops guaranteeing the
## margin. Stops early at the first point under the margin (returns it).
func _walk(ax: float, az: float, bx: float, bz: float, margin: float) -> float:
	var dx := bx - ax
	var dz := bz - az
	var length := sqrt(dx * dx + dz * dz)
	var least := INF
	var t := 0.0
	while true:
		var c := clearance(ax + dx * (t / length), az + dz * (t / length)) if length > 0.0 else clearance(ax, az)
		if c < least:
			least = c
		if c < margin:
			return least
		if t >= length:
			return least
		t += maxf(c - margin, CELL_M)
		if t > length:
			t = length
	return least


## The least wall clearance over the outline at (x, z, f), or -1.0 if a side comes under `margin` AND more than 0.05 m
## deeper than that side was at the start (`start`, from side_clearances at the start pose: a nose parked against a
## face may not get deeper), or -1.0 if the hull box overlaps another hull's.
func footprint(x: float, z: float, fx: float, fz: float, half_w: float, half_l: float, margin: float,
		start: PackedFloat32Array) -> float:
	var sides := side_clearances(x, z, fx, fz, half_w, half_l, margin)
	var least := INF
	for i in 4:
		var c := sides[i]
		if c < margin and c < start[i] - 0.05:
			return -1.0
		if c < least:
			least = c
	if not hulls.is_empty() and _hull_overlap(x, z, fx, fz, half_w, half_l, HULL_MARGIN_M):
		return -1.0
	return least


## Does the box (x, z, f, half_w, half_l) overlap any other hull's box grown by `grow`? Separating axes: this box's two
## and the other's two.
func _hull_overlap(x: float, z: float, fx: float, fz: float, half_w: float, half_l: float, grow: float) -> bool:
	for hull: Array in hulls:
		var ox := float(hull[0])
		var oz := float(hull[1])
		var ofx := float(hull[2])
		var ofz := float(hull[3])
		var ohw := float(hull[4]) + grow
		var ohl := float(hull[5]) + grow
		var dx := ox - x
		var dz := oz - z
		# A quick reject on the bounding discs.
		var reach := half_l + ohl + half_w + ohw
		if dx * dx + dz * dz > reach * reach:
			continue
		if _separated(dx, dz, fx, fz, half_l, half_w, ofx, ofz, ohl, ohw):
			continue
		return true
	return false


## True when some axis separates box A (at the origin, forward fa, half extents la along / wa across) from box B
## (centre offset d, forward fb, lb / wb).
static func _separated(dx: float, dz: float, fax: float, faz: float, la: float, wa: float,
		fbx: float, fbz: float, lb: float, wb: float) -> bool:
	# Axes: A's forward, A's right, B's forward, B's right.
	var axes := [Vector2(fax, faz), Vector2(-faz, fax), Vector2(fbx, fbz), Vector2(-fbz, fbx)]
	var a_f := Vector2(fax, faz)
	var a_r := Vector2(-faz, fax)
	var b_f := Vector2(fbx, fbz)
	var b_r := Vector2(-fbz, fbx)
	var d := Vector2(dx, dz)
	for axis: Vector2 in axes:
		var ra := la * absf(axis.dot(a_f)) + wa * absf(axis.dot(a_r))
		var rb := lb * absf(axis.dot(b_f)) + wb * absf(axis.dot(b_r))
		if absf(d.dot(axis)) > ra + rb:
			return true
	return false


## Is (x, z) inside a wall or a hull box (for the ASCII drawing)?
func is_wall(x: float, z: float) -> bool:
	return _wall_distance(x, z) <= 0.0


func is_hull(x: float, z: float) -> bool:
	for hull: Array in hulls:
		var dx := x - float(hull[0])
		var dz := z - float(hull[1])
		var fx := float(hull[2])
		var fz := float(hull[3])
		var along := dx * fx + dz * fz
		var across := -dx * fz + dz * fx
		if absf(along) <= float(hull[5]) and absf(across) <= float(hull[4]):
			return true
	return false


## The exact least distance from the outline of a hull box at a pose to any wall face (tests: the ground truth the
## planner's sampled field must respect). Negative = a point inside a wall.
func exact_outline_clearance(x: float, z: float, fx: float, fz: float, half_w: float, half_l: float, step_m := 0.25) -> float:
	var least := INF
	var rx := -fz
	var rz := fx
	var along_n := maxi(2, int(ceil(half_l * 2.0 / step_m)))
	var across_n := maxi(1, int(ceil(half_w * 2.0 / step_m)))
	for i in along_n + 1:
		var a := -1.0 + 2.0 * float(i) / float(along_n)
		for c: float in [1.0, -1.0]:
			least = minf(least, _wall_distance(x + fx * a * half_l + rx * c * half_w, z + fz * a * half_l + rz * c * half_w))
	for j in range(1, across_n):
		var c := -1.0 + 2.0 * float(j) / float(across_n)
		for a: float in [1.0, -1.0]:
			least = minf(least, _wall_distance(x + fx * a * half_l + rx * c * half_w, z + fz * a * half_l + rz * c * half_w))
	return least


## Does the hull box at a pose overlap another hull's box, exactly (no margin)? Tests' ground truth.
func exact_hull_overlap(x: float, z: float, fx: float, fz: float, half_w: float, half_l: float) -> bool:
	return _hull_overlap(x, z, fx, fz, half_w, half_l, 0.0)
