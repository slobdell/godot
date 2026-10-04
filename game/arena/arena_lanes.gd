class_name ArenaLanes
extends RefCounted
## R4 (round 10): **streets are lanes.** Every lane a layout declares keeps a continuous DRIVABLE width of at least
## twice the roster's widest hull after the navmesh bake has eaten both kerbs, and every place a hull turns (a lane's
## own bends, and every point where two lanes cross) clears the design vehicle's corner cut. Pure measurement over a
## layout's colliders; no nodes. The assertion is `tests/test_arena_lanes.gd`; `tools/arena_report.py` prints the
## same table for the page.
##
## The lead's words (game_design.md *Round 10 direction*): "there streets are blocked with these shipping containers
## so there's almost no passageway." His acceptance is driving squads through the Terminus streets.
##
## CLEARANCE VOCABULARY (B5): the collider boxes read here are STATIC FOOTPRINTS; the lane bar is a SWEPT TRAVEL
## RIBBON (two hulls abreast); the corner radius is a TURNING ENVELOPE used on the move (C5), not the spin-in-place
## half-diagonal the spawn grid needs.
##
## Everything a hull cannot drive through counts, not only what blocks sight: a 0.9 m barricade stops a hull as
## surely as a container does. That is the one deliberate difference from `arena_report.corridor_widths()`, which
## measures a sightline question with tall boxes only.

## Metres between width samples along a lane.
const SAMPLE_STEP_M := 1.0
## How far each side of the lane a width probe looks before it calls the ground open.
const REACH_M := 60.0
## The turn certified at every crossing of two lanes: a right angle, whatever the crossing's own angle. At a crossing
## a hull may turn onto the other street either way, and one of the two turns is always a right angle or sharper; a
## turn sharper than a right angle AT a junction is a three-point manoeuvre in road-design practice, not a movement
## a junction is certified for (a 20° crossing would otherwise demand a 160° hairpin around its vertex). A lane's
## OWN bends are certified at their authored angle.
const JUNCTION_TURN_DEG := 90.0
## Layouts whose lanes are REPORTED, not asserted: maps the lead has not complained about, whose short lanes are a
## Status line rather than a redesign (arena brief item 5; the table is in arenas.md). Every other layout -- the
## Terminus and every NEW map (terrain's, R9) -- is asserted by default, so a map cannot opt out by being new.
## Fixtures (`Arena.is_fixture`) are never asserted: the maze's serpentines are single-file on purpose.
## Read by `tests/test_arena_lanes.gd` and by `tools/arena_report.py` (which parses this literal: keep it one).
const REPORT_ONLY := ["boneyard", "boulevard", "pit", "yard"]
## Where the terrain probe (water, pits) steps, when a layout carries terrain.
const TERRAIN_PROBE_M := 0.25


## The bar, READ from its owners (Invariant 0: never a copy): the roster's widest hull from `Units`, the bake radius
## from the arena scene's own NavigationMesh (what nav reads live).
## {widest_hull, widest_hull_m, bake_radius_m, drivable_bar_m, physical_bar_m, rig, rig_min_turn_m}
static func bar() -> Dictionary:
	var widest_id := ""
	var widest := 0.0
	var rig_id := ""
	var rig_turn := 0.0
	for unit_id: String in Units.ids():
		var profile: Dictionary = Units.profile(unit_id)
		var width := float(profile["hull_size"][0])
		if width > widest:
			widest = width
			widest_id = unit_id
		var turn := float(profile.get("min_turn_radius_m", 0.0))
		if turn > rig_turn:
			rig_turn = turn
			rig_id = unit_id
	var bake := bake_radius()
	return {"widest_hull": widest_id, "widest_hull_m": widest, "bake_radius_m": bake,
			"drivable_bar_m": 2.0 * widest, "physical_bar_m": 2.0 * widest + 2.0 * bake,
			"rig": rig_id, "rig_min_turn_m": rig_turn}


# ---- M6 (maps, round 18): the turning pocket --------------------------------------------------------------------
#
# The width bar cannot see a CORNER. Round 17 (yard): a 20 ft box slid flush against a Terminus block, turned 4 deg,
# put its corner 14 cm into a 17.56 m avenue -- the 12.14 m bar passed it -- and a 14 m rig's planned back-and-fill
# planted into it, because the k-turn outline (`Movement.KTURN_OUTLINE`) samples a hull's side at quarter lengths and a
# corner between two samples is invisible to it. A square box flush to the same kerb did not: its face is a flat the
# samples land on. So a TOOTH is a collider point that pokes past its own kerb on BOTH sides within one outline gap:
# along a lane's kerb (each side, every TOOTH_STEP_M), a local minimum of the free distance from the lane line whose
# kerb rises by more than TOOTH_DEPTH_M within half an outline gap either side. The SMALLER of the two rises must be
# under the bake radius: a pillar or a wall end that stands out by more than the bake radius on both sides is carved
# out of the navmesh visibly and is an obstacle, not a pocket; a square box's end rises on one side only (its face is
# flat on the other) and is not a tooth. Only within reach of the lane line (the physical bar) -- out past that no
# hull's side passes.

## Metres between kerb samples (finer than the outline gap so a corner is never stepped over).
const TOOTH_STEP_M := 0.25
## How far past its kerb a corner may stand before it is a tooth. Round 17's guard allowed a lane 10 cm of narrowing.
const TOOTH_DEPTH_M := 0.10


## The widest gap between two samples of the k-turn outline along a hull's side, for the longest hull in the roster:
## READ from `Movement.KTURN_OUTLINE` (half-lengths) and `Units` (hull_size[2] is the length), never copied.
static func outline_gap_m() -> float:
	var longest := 0.0
	for unit_id: String in Units.ids():
		longest = maxf(longest, float(Units.profile(unit_id)["hull_size"][2]))
	var along: Array[float] = []
	for sample: Vector2 in Movement.KTURN_OUTLINE:
		if absf(sample.y) > 0.5:
			along.append(sample.x)
	along.sort()
	var gap := 0.0
	for i in range(1, along.size()):
		gap = maxf(gap, along[i] - along[i - 1])
	return gap * longest / 2.0


## Every tooth along every declared lane: [{lane, at: Vector2, kerb_m, depth_m}] (`kerb_m` = the tooth's distance from
## the lane line; `depth_m` = the smaller of its two rises).
static func teeth(data: Dictionary, the_bar: Dictionary = {}) -> Array:
	if the_bar.is_empty():
		the_bar = bar()
	var boxes := _boxes(data)
	var perimeter := Arena.perimeter(data)
	var half_gap := outline_gap_m() / 2.0
	var k := maxi(1, int(round(half_gap / TOOTH_STEP_M)))
	var reach := float(the_bar["physical_bar_m"])
	var bake := float(the_bar["bake_radius_m"])
	var out: Array = []
	for lane: Dictionary in data.get("lanes", []):
		var points: Array = lane["points"]
		for i in range(1, points.size()):
			var a := Vector2(points[i - 1][0], points[i - 1][1])
			var b := Vector2(points[i][0], points[i][1])
			var leg := a.distance_to(b)
			if leg < 2.0 * half_gap:
				continue
			var along := (b - a) / leg
			var n := int(leg / TOOTH_STEP_M)
			for side: float in [1.0, -1.0]:
				var normal := Vector2(-along.y, along.x) * side
				var free := PackedFloat32Array()
				for s in n + 1:
					free.append(_free(data, boxes, perimeter, a + along * (s * TOOTH_STEP_M), normal))
				var s := k
				while s <= n - k:
					var here := free[s]
					var lowest := here <= reach
					for q in range(s - k, s + k + 1):
						lowest = lowest and free[q] >= here
					var rise := minf(free[s - k] - here, free[s + k] - here)
					if lowest and rise > TOOTH_DEPTH_M and rise <= bake:
						out.append({"lane": String(lane["name"]), "at": a + along * (s * TOOTH_STEP_M) + normal * here,
								"kerb_m": here, "depth_m": rise})
						s += k
					s += 1
	return out


## The navmesh bake's agent radius as `arena.tscn` declares it (the region's NavigationMesh resource).
static func bake_radius() -> float:
	var scene: Node = (load("res://game/arena/arena.tscn") as PackedScene).instantiate()
	var region := scene.get_node("Navigation") as NavigationRegion3D
	var radius := region.navigation_mesh.agent_radius
	scene.free()
	return radius


## Every declared lane's narrowest width. `data` is a NORMALIZED layout (`Arena.load_layout(name)["layout"]`).
## [{name, narrowest_physical_m, narrowest_drivable_m, at: Vector2, samples, pass, throat: {normal, along, left_m,
## right_m}}] -- the throat is the narrowest cross-section: from `at`, `left_m` along `normal` and `right_m` against it.
static func measure(data: Dictionary, the_bar: Dictionary = {}) -> Array:
	if the_bar.is_empty():
		the_bar = bar()
	var boxes := _boxes(data)
	var perimeter := Arena.perimeter(data)
	var results: Array = []
	for lane: Dictionary in data.get("lanes", []):
		var points: Array = lane["points"]
		var narrowest := INF
		var at := Vector2.ZERO
		var throat := {}
		var samples := 0
		for i in range(1, points.size()):
			var a := Vector2(points[i - 1][0], points[i - 1][1])
			var b := Vector2(points[i][0], points[i][1])
			var leg := a.distance_to(b)
			if leg < 1e-6:
				continue
			var along := (b - a) / leg
			var normal := Vector2(-along.y, along.x)
			var steps := maxi(1, int(ceil(leg / SAMPLE_STEP_M)))
			for s in range(steps + 1):
				var p := a + along * (leg * s / steps)
				var left := _free(data, boxes, perimeter, p, normal)
				var right := _free(data, boxes, perimeter, p, -normal)
				var width := left + right
				samples += 1
				if width < narrowest:
					narrowest = width
					at = p
					throat = {"normal": normal, "along": along, "left_m": left, "right_m": right}
		var drivable := narrowest - 2.0 * float(the_bar["bake_radius_m"])
		results.append({"name": String(lane["name"]), "narrowest_physical_m": narrowest,
				"narrowest_drivable_m": drivable, "at": at, "samples": samples, "throat": throat,
				"pass": drivable >= float(the_bar["drivable_bar_m"]) - 0.001})
	return results


## C5: every turn a lane asks for, against the design vehicle's corner cut. A car-like hull following two legs that
## meet at exterior angle Δψ on an arc of its minimum radius R cuts inside the vertex by R·(sec(Δψ/2) − 1), so the
## clear disc it needs around the vertex is r_eff = r_a + R·(sec(Δψ/2) − 1), with r_a the lane bar's own
## half-width (physical_bar / 2: a hull plus its neighbour's room plus the bake). The corners are a lane's own bends
## and every crossing of two lanes (certified for JUNCTION_TURN_DEG).
## [{where, lanes, delta_deg, r_eff_m, clearance_m, pass}]
static func corners(data: Dictionary, the_bar: Dictionary = {}) -> Array:
	if the_bar.is_empty():
		the_bar = bar()
	var boxes := _boxes(data)
	var perimeter := Arena.perimeter(data)
	var r_a := float(the_bar["physical_bar_m"]) / 2.0
	var turn := float(the_bar["rig_min_turn_m"])
	var found: Array = []
	var lanes: Array = data.get("lanes", [])
	for lane: Dictionary in lanes:
		var pts: Array = lane["points"]
		for i in range(1, pts.size() - 1):
			var p0 := Vector2(pts[i - 1][0], pts[i - 1][1])
			var p1 := Vector2(pts[i][0], pts[i][1])
			var p2 := Vector2(pts[i + 1][0], pts[i + 1][1])
			var delta := rad_to_deg(absf((p1 - p0).angle_to(p2 - p1)))
			if delta < 1.0:
				continue
			found.append({"where": p1, "lanes": [String(lane["name"])], "delta_deg": delta})
	for i in lanes.size():
		for j in range(i + 1, lanes.size()):
			for hit: Dictionary in _crossings(lanes[i], lanes[j]):
				found.append(hit)
	var out: Array = []
	for corner: Dictionary in found:
		var delta_rad := deg_to_rad(float(corner["delta_deg"]))
		var r_eff := r_a + turn * (1.0 / cos(delta_rad / 2.0) - 1.0) if delta_rad < PI - 0.01 else INF
		var clearance := clearance_at(data, boxes, perimeter, corner["where"])
		corner["r_eff_m"] = r_eff
		corner["clearance_m"] = clearance
		corner["pass"] = clearance >= r_eff - 0.001
		out.append(corner)
	return out


## The radius of the clear disc at `p`: distance to the nearest collider footprint or to the wall.
static func clearance_at(data: Dictionary, boxes: Array, perimeter: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for box: Dictionary in boxes:
		best = minf(best, ArenaKit.distance_to_footprint(p, box["center"], box["size"], box["rotation_deg"]))
	for i in perimeter.size():
		var a := perimeter[i]
		var b := perimeter[(i + 1) % perimeter.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	if data.has("terrain"):
		# Rings of probes: the nearest carved point, to the probe's resolution.
		var r := TERRAIN_PROBE_M
		while r < best:
			for k in 32:
				var q := p + Vector2.from_angle(TAU * k / 32.0) * r
				if not Arena.contains(Vector3(q.x, 0.0, q.y), data):
					return r
			r += TERRAIN_PROBE_M
	return best


static func _crossings(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	var pa: Array = a["points"]
	var pb: Array = b["points"]
	for i in range(1, pa.size()):
		var a0 := Vector2(pa[i - 1][0], pa[i - 1][1])
		var a1 := Vector2(pa[i][0], pa[i][1])
		for j in range(1, pb.size()):
			var b0 := Vector2(pb[j - 1][0], pb[j - 1][1])
			var b1 := Vector2(pb[j][0], pb[j][1])
			var hit: Variant = Geometry2D.segment_intersects_segment(a0, a1, b0, b1)
			if hit == null:
				continue
			var angle := rad_to_deg(absf((a1 - a0).angle_to(b1 - b0)))
			var crossing := minf(angle, 180.0 - angle)
			if crossing < 1.0:
				continue  # the same street drawn twice (overlapping or parallel legs), not a junction
			var where: Vector2 = hit
			var dup := out.any(func(c: Dictionary) -> bool: return (c["where"] as Vector2).distance_to(where) < 0.5)
			if not dup:
				out.append({"where": where, "lanes": [String(a["name"]), String(b["name"])],
						"delta_deg": JUNCTION_TURN_DEG, "crossing_deg": crossing})
	return out


## Free ground from `p` along `dir` until a collider, the wall or carved terrain; capped at REACH_M.
static func _free(data: Dictionary, boxes: Array, perimeter: PackedVector2Array, p: Vector2, dir: Vector2) -> float:
	var reach := REACH_M
	for box: Dictionary in boxes:
		var t := _entry(box, p, dir, reach)
		if t >= 0.0:
			reach = minf(reach, t)
	reach = minf(reach, _exit(perimeter, p, dir, reach))
	if data.has("terrain"):
		var d := 0.0
		while d < reach:
			var q := p + dir * d
			if not Arena.contains(Vector3(q.x, 0.0, q.y), data):
				return d
			d += TERRAIN_PROBE_M
	return reach


## The ray p + t·dir's entry into the box (0 when p is inside), or −1 if it misses within `reach`.
static func _entry(box: Dictionary, p: Vector2, dir: Vector2, reach: float) -> float:
	var angle := deg_to_rad(float(box["rotation_deg"]))
	var c := cos(angle)
	var s := sin(angle)
	var d: Vector2 = p - box["center"]
	# Basis(UP, angle): the same local frame as ArenaKit.distance_to_footprint.
	var lp := Vector2(d.x * c - d.y * s, d.x * s + d.y * c)
	var ld := Vector2(dir.x * c - dir.y * s, dir.x * s + dir.y * c)
	var half := Vector2((box["size"] as Vector3).x / 2.0, (box["size"] as Vector3).z / 2.0)
	var t0 := 0.0
	var t1 := reach
	for axis in 2:
		var o := lp[axis]
		var v := ld[axis]
		if absf(v) < 1e-9:
			if absf(o) > half[axis]:
				return -1.0
			continue
		var ta := (-half[axis] - o) / v
		var tb := (half[axis] - o) / v
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return -1.0
	return t0


## Where the ray leaves the convex perimeter polygon (0 if p is already outside it).
static func _exit(perimeter: PackedVector2Array, p: Vector2, dir: Vector2, reach: float) -> float:
	if perimeter.is_empty():
		return reach
	if not Geometry2D.is_point_in_polygon(p, perimeter):
		return 0.0
	var best := reach
	for i in perimeter.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(p, p + dir * reach,
				perimeter[i], perimeter[(i + 1) % perimeter.size()])
		if hit != null:
			best = minf(best, p.distance_to(hit))
	return best


## Every collider's footprint: {center: Vector2, size: Vector3, rotation_deg}. Obstacles and colliding props, and
## (round 10, terrain's parity finding) the terrain's own colliders READ from `ArenaTerrain`: the rim around every
## carved footprint and the rails on every bridge deck. Carved ground itself is `Arena.contains`' answer (`_free`).
static func _boxes(data: Dictionary) -> Array:
	var out: Array = []
	for obstacle: Dictionary in data.get("obstacles", []):
		out.append({"center": Vector2(obstacle["position"][0], obstacle["position"][1]),
				"size": Arena.obstacle_size(obstacle), "rotation_deg": float(obstacle.get("rotation_deg", 0.0))})
	var terrain: Array = data.get("terrain", [])
	for entry: Dictionary in terrain:
		var kind := String(entry["kind"])
		if ArenaTerrain.carves(kind):
			for slab: Array in ArenaTerrain.rim_slabs(entry, terrain):
				out.append(_slab(slab, ArenaTerrain.RIM_HEIGHT))
		elif ArenaTerrain.is_deck(kind):
			for slab: Array in _rails(entry, terrain):
				out.append(_slab(slab, ArenaTerrain.RIM_HEIGHT))
	return out


## A bridge deck's rails, when the terrain code builds them (`ArenaTerrain.rail_slabs`, terrain's round-10 addition).
## Asked by name so this file does not depend on the order the two streams merge in; once terrain's branch is on
## main it always answers.
static func _rails(deck: Dictionary, terrain: Array) -> Array:
	var script := ArenaTerrain as Script
	for method: Dictionary in script.get_script_method_list():
		if String(method["name"]) == "rail_slabs":
			return script.call("rail_slabs", deck, terrain)
	return []


## An `ArenaTerrain` slab [centre_x, centre_z, width, depth] as a box.
static func _slab(slab: Array, height: float) -> Dictionary:
	return {"center": Vector2(slab[0], slab[1]), "size": Vector3(slab[2], height, slab[3]), "rotation_deg": 0.0}


## One line per lane and per corner, for logs and the report.
static func describe(data: Dictionary) -> PackedStringArray:
	var the_bar := bar()
	var lines := PackedStringArray()
	lines.append("LANE_BAR widest=%s %.2f m  bake=%.2f m  drivable bar=%.2f m  physical bar=%.2f m  rig=%s R_min=%.1f m" % [
			the_bar["widest_hull"], the_bar["widest_hull_m"], the_bar["bake_radius_m"], the_bar["drivable_bar_m"],
			the_bar["physical_bar_m"], the_bar["rig"], the_bar["rig_min_turn_m"]])
	for lane: Dictionary in measure(data, the_bar):
		lines.append("LANE %s %-22s narrowest %.2f m physical, %.2f m drivable at (%.0f, %.0f)  %s" % [
				data.get("name", "?"), lane["name"], lane["narrowest_physical_m"], lane["narrowest_drivable_m"],
				lane["at"].x, lane["at"].y, "ok" if lane["pass"] else "SHORT"])
	for tooth: Dictionary in teeth(data, the_bar):
		lines.append("TOOTH %s %-22s a corner %.2f m past its kerb, %.2f m from the lane line at (%.1f, %.1f)" % [
				data.get("name", "?"), tooth["lane"], tooth["depth_m"], tooth["kerb_m"], tooth["at"].x, tooth["at"].y])
	for corner: Dictionary in corners(data, the_bar):
		lines.append("CORNER %s %s at (%.0f, %.0f): Δψ %.0f°, r_eff %.2f m, clearance %.2f m  %s" % [
				data.get("name", "?"), " × ".join(corner["lanes"]), corner["where"].x, corner["where"].y,
				corner["delta_deg"], corner["r_eff_m"], corner["clearance_m"], "ok" if corner["pass"] else "SHORT"])
	return lines
