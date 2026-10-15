class_name PlannerHeuristic
extends RefCounted
## Round 30 (planner P2): **the free-space cost to a pose, tabled per hull class** — hybrid-A*'s standard non-holonomic
## heuristic. A Dijkstra over the same leg lattice as the planner (three locks, two gears, legs of 2–16 m, the time
## cost and the cusp cost) run BACKWARDS from the goal pose over a window of the goal's frame, with no obstacles, at
## TABLE_CELL_M × TABLE_BINS resolution; cached per (radius, speeds, cusp seconds). The planner reads it as
## `max(core, table)`: the core bound knows distance and heading, the table knows that a 90° turn ending within 4 m
## of where it began costs two cusps in the open (`test_a_packed_line` spent 2500–4000 expansions learning that).
##
## Built once per hull class per process (~1–2 s in GDScript on builder0; the native port would do it in ms, or ship
## the tables). Deterministic: a fixed expansion order, integer keys.

const TABLE_CELL_M := 2.0
const TABLE_BINS := 12            # 30 degrees
const TABLE_HALF_M := 32.0
const TABLE_LEGS: Array[float] = [2.0, 4.0, 8.0, 16.0]
const TABLE_SUB_M := 2.0
const STEERS: Array[float] = [-1.0, 0.0, 1.0]

static var _tables := {}
static var last_build_ms := 0.0


## The table for a request's hull (built on first use).
static func table_for(req: PlanRequest) -> PackedFloat32Array:
	var key := "%.2f|%.2f|%.2f|%.2f" % [req.radius, req.v_fwd, req.v_rev, req.cusp_seconds()]
	if _tables.has(key):
		return _tables[key]
	var started := Time.get_ticks_usec()
	var table := _build(maxf(req.radius, 0.5), maxf(req.v_fwd, 0.1), maxf(req.v_rev, 0.1), req.cusp_seconds())
	last_build_ms = (Time.get_ticks_usec() - started) / 1000.0
	_tables[key] = table
	return table


static func _n() -> int:
	return int(TABLE_HALF_M * 2.0 / TABLE_CELL_M)


## Index of (x, z, theta, leaving gear) in the goal's frame (the goal at the origin heading +x), or -1 off the window.
static func _index(x: float, z: float, th: float, gear: int) -> int:
	var n := _n()
	var ix := int(floor((x + TABLE_HALF_M) / TABLE_CELL_M))
	var iz := int(floor((z + TABLE_HALF_M) / TABLE_CELL_M))
	if ix < 0 or iz < 0 or ix >= n or iz >= n:
		return -1
	var ib := int(floor(fposmod(th, TAU) / TAU * TABLE_BINS)) % TABLE_BINS
	return ((ix * n + iz) * TABLE_BINS + ib) * 2 + (1 if gear > 0 else 0)


## The tabled seconds from a pose (in the GOAL's frame: dx, dz along/across the goal heading, th relative) arriving
## there with `gear_in`, to the goal; INF off the window or unreached. Charges a cusp if the leaving gear differs.
static func lookup(table: PackedFloat32Array, dx: float, dz: float, th: float, gear_in: int, cusp_s: float) -> float:
	var best := INF
	for leaving: int in [1, -1]:
		var i := _index(dx, dz, th, leaving)
		if i < 0:
			return INF
		var v := table[i]
		if v == INF:
			continue
		if gear_in != 0 and leaving != gear_in:
			v += cusp_s
		if v < best:
			best = v
	return best


## Dijkstra from the goal over reversed legs: leaving state s with forward-time gear g on lock st and arriving at t is,
## backwards, moving from t with (-g, -st) to s; charged as the forward-time leg (its gear's speed) plus a cusp when
## the forward-time gear changes between consecutive legs.
static func _build(radius: float, v_fwd: float, v_rev: float, cusp_s: float) -> PackedFloat32Array:
	var n := _n()
	var size := n * n * TABLE_BINS * 2
	var table := PackedFloat32Array()
	table.resize(size)
	table.fill(INF)
	# Node arrays (a node is a continuous pose; the table cell is its key).
	var nx := PackedFloat32Array()
	var nz := PackedFloat32Array()
	var nfx := PackedFloat32Array()
	var nfz := PackedFloat32Array()
	var nth := PackedFloat32Array()
	var ng := PackedFloat32Array()
	var ngear := PackedInt32Array()   # the forward-time gear of the leg leaving this pose toward the goal (0 at the goal)
	var hf := PackedFloat32Array()
	var hid := PackedInt32Array()
	var closed := {}
	# The goal pose itself: at the origin heading +x, both "leaving gears" cost 0 (nothing leaves it).
	for gear: int in [1, -1]:
		nx.append(0.0); nz.append(0.0); nfx.append(1.0); nfz.append(0.0); nth.append(0.0); ng.append(0.0); ngear.append(gear)
		Planner._heap_push(hf, hid, 0.0, nx.size() - 1)
	while hf.size() > 0:
		var cur := Planner._heap_pop(hf, hid)
		var key := _index(nx[cur], nz[cur], nth[cur], ngear[cur])
		if key < 0 or closed.has(key):
			continue
		closed[key] = true
		table[key] = ng[cur]
		var px := nx[cur]
		var pz := nz[cur]
		var pfx := nfx[cur]
		var pfz := nfz[cur]
		var pth := nth[cur]
		var pg := ng[cur]
		var pgear := ngear[cur]
		for gear: int in [1, -1]:
			var leg_cost_per_m := 1.0 / (v_fwd if gear > 0 else v_rev)
			var cusp := pgear != 0 and gear != pgear
			for steer in STEERS:
				var x := px
				var z := pz
				var fx := pfx
				var fz := pfz
				var th := pth
				var dth := -TABLE_SUB_M * steer / radius   # backwards in time the heading unwinds
				var swept := 0.0
				var next_end := 0
				while swept < TABLE_LEGS[-1] - 0.001:
					if steer != 0.0:
						var tx := fx - fz * dth
						var tz := fz + fx * dth
						var inv := 1.0 / sqrt(tx * tx + tz * tz)
						fx = tx * inv
						fz = tz * inv
						th += dth
					x -= fx * TABLE_SUB_M * gear   # backwards: undo the move
					z -= fz * TABLE_SUB_M * gear
					swept += TABLE_SUB_M
					if next_end < TABLE_LEGS.size() and swept >= TABLE_LEGS[next_end] - 0.001:
						next_end += 1
						var k := _index(x, z, th, gear)
						if k < 0:
							break
						if closed.has(k):
							continue
						var g := pg + swept * leg_cost_per_m + (cusp_s if cusp else 0.0)
						if g >= table[k]:
							continue
						table[k] = g  # provisional (the pop makes it final)
						nx.append(x); nz.append(z); nfx.append(fx); nfz.append(fz); nth.append(th); ng.append(g); ngear.append(gear)
						Planner._heap_push(hf, hid, g, nx.size() - 1)
	return table
