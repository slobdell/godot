class_name ArenaTerrain
extends RefCounted
## Ground that cannot be driven on but can be fired over (arena, round 7): water, pits, and the bridges across them.
##
## The lead: *"We need water or pits — these would be elements that units could not cross but they could still fire
## over. Useful for setting up kill zones. i.e. we could have a map that required crossing some bridges to get to
## the other side."*
##
## **This is geometry, not a new mechanic**, and that was measured before it was built
## (`make water-probe`, _agents/streams/references/arena/water-carve-2026-09-19.json): navigation is baked from
## collision shapes in the `navigation_source` group, while sight is a physics ray at `Perception.EYE_HEIGHT`
## (1.3 m). So ground that is simply absent from the bake is unwalkable, and carries nothing to stop a ray.
##
## Three pieces per footprint, and each is load-bearing:
##   1. the FLOOR is built as the arena rectangle MINUS every water/pit, PLUS every bridge deck, in
##      `navigation_source` — the hole in the navmesh *is* the impassability;
##   2. a RIM (`RIM_HEIGHT`, 0.9 m) around each footprint, deliberately NOT a navigation source: its whole job is
##      physical. 0.9 m is `barricade`'s height, which the kit already documents as stopping a hull but not an eye
##      or a gun, so a unit shoved at the water is stopped without anything blocking fire across it.
##      **The rim is CUT where a bridge crosses** — the probe's first bridge run reported a crossing blocked by its
##      own safety rail. A bridge is a hole in the water *and* a hole in the rim.
##   3. a deep FLOOR PAN under each footprint, also not a navigation source: belt and braces, so nothing can leave
##      the world even if it somehow gets past the rim.
##
##   4. RAILS along every deck side that borders water (round 10, terrain): without them a hull shoved sideways on a
##      bridge left the deck and spent the rest of the match in the pan. Same height class as the rim.
##
## **Rims and rails are navigation sources (round 10, R3).** Round 7 kept them out of the bake, so the mesh reached
## the water's edge plus one agent radius -- 0.8 m past the rim's outer face -- and a route along a bank put the
## widest hull's side onto the rim. In the bake, the mesh stops an agent radius short of them like any other wall.
## The floor, the rims, the rails and the pans are built by `build()`; `Arena._build_terrain()` only calls it.
##
## **Footprints are axis-aligned rectangles, and v1 has no rotation.** The floor is cut by exact rectangle
## decomposition over the footprints' own edges (see `slabs()`), which is cheap and exact for axis-aligned input
## and would need a real polygon clipper otherwise. A diagonal river is worth having; it is not worth a clipper
## before anyone has played a straight one.

## kind -> how it is built. `carves` is the whole point; `deck` restores floor instead of removing it.
const KINDS := {
	"water": {"carves": true, "deck": false, "pan_depth": 3.0},
	"pit": {"carves": true, "deck": false, "pan_depth": 8.0},
	"bridge": {"carves": false, "deck": true, "pan_depth": 0.0},
}
## The lip that stops a hull. Matches ArenaKit's `barricade`: below Perception.EYE_HEIGHT (1.3 m), so it never
## blocks a sightline or a shell, and above what a hull can climb.
const RIM_HEIGHT := 0.9
const RIM_THICKNESS := 1.2
## The rails on a deck's water sides: as tall as the rim they continue (stops a hull, below the 1.3 m eye line) and
## thin, because every centimetre of rail is a centimetre of deck the roadway loses.
const RAIL_HEIGHT := 0.9
const RAIL_THICKNESS := 0.5
## R4 (round 10): a bridge is a LANE, and a lane keeps **2 x the widest hull's width** drivable after the bake
## radius: 8.14 m, the Syndicate artillery at 4.07 m (arena's `ArenaLanes.bar()` reads the same catalog live; when
## CP2 lands this should read it too). `tests/test_terrain_mechanism.gd` reads `Units.PROFILES` and fails if a wider
## hull lands -- it did exactly that against round 10's first figure, 6.64 m from the War Rig.
const LANE_DRIVABLE_M := 8.14
## The navmesh agent radius the bake erodes each side by (`arena.tscn`'s NavigationMesh; the test reads it).
const BAKE_RADIUS_M := 2.0
## The narrowest deck `Arena.validate()` accepts: R4's drivable width, plus the bake radius and a rail each side.
## Round 7's 7.0 m left 3 m of single-file deck -- the maze's tight gate, which is a test fixture, not a bridge.
const MIN_DECK_M := LANE_DRIVABLE_M + 2.0 * BAKE_RADIUS_M + 2.0 * RAIL_THICKNESS
## How far past a footprint's edge a deck must reach to count as crossing that edge.
const EDGE_EPSILON := 0.01


static func is_kind(kind: String) -> bool:
	return KINDS.has(kind)


static func carves(kind: String) -> bool:
	return bool(KINDS[kind]["carves"])


static func is_deck(kind: String) -> bool:
	return bool(KINDS[kind]["deck"])


## A terrain entry's rectangle as [min_x, min_z, max_x, max_z].
static func bounds(entry: Dictionary) -> PackedFloat32Array:
	var rect: Array = entry["rect"]
	var half_w := float(rect[2]) / 2.0
	var half_d := float(rect[3]) / 2.0
	return PackedFloat32Array([float(rect[0]) - half_w, float(rect[1]) - half_d,
			float(rect[0]) + half_w, float(rect[1]) + half_d])


static func overlaps(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


## The FLOOR: the arena square minus every carving footprint, plus every bridge deck, as axis-aligned boxes.
##
## Exact rectangle decomposition rather than a grid: collect every footprint edge as a cut line, which turns the
## arena into a small grid of cells whose solidity is constant within each cell, then merge neighbouring solid
## cells back into runs. With a handful of footprints that is a ~10x10 grid and a few dozen boxes, computed at
## load. A 0.5 m raster would be ~230,000 cells for the same answer, and the arena already has a loading problem.
##
## Returns [[centre_x, centre_z, width, depth], ...].
static func slabs(half_size: float, terrain: Array) -> Array:
	var cuts_x := {-half_size: true, half_size: true}
	var cuts_z := {-half_size: true, half_size: true}
	var holes: Array = []
	var decks: Array = []
	for entry: Dictionary in terrain:
		var box := bounds(entry)
		for value in [box[0], box[2]]:
			cuts_x[clampf(value, -half_size, half_size)] = true
		for value in [box[1], box[3]]:
			cuts_z[clampf(value, -half_size, half_size)] = true
		if carves(String(entry["kind"])):
			holes.append(box)
		elif is_deck(String(entry["kind"])):
			decks.append(box)
	var xs := cuts_x.keys()
	var zs := cuts_z.keys()
	xs.sort()
	zs.sort()

	# Solidity per cell: solid unless a hole covers it, and solid again if a deck covers it.
	var solid: Array = []
	for i in range(xs.size() - 1):
		var column: Array = []
		var mid_x: float = (xs[i] + xs[i + 1]) / 2.0
		for j in range(zs.size() - 1):
			var mid_z: float = (zs[j] + zs[j + 1]) / 2.0
			var keep := true
			for hole: PackedFloat32Array in holes:
				if mid_x > hole[0] and mid_x < hole[2] and mid_z > hole[1] and mid_z < hole[3]:
					keep = false
					break
			if not keep:
				for deck: PackedFloat32Array in decks:
					if mid_x > deck[0] and mid_x < deck[2] and mid_z > deck[1] and mid_z < deck[3]:
						keep = true
						break
			column.append(keep)
		solid.append(column)

	# Merge along z, then merge identical runs along x: a floor with one river comes out as a handful of boxes
	# rather than one per cell.
	var out: Array = []
	var used: Array = []
	for i in range(xs.size() - 1):
		used.append([])
		for j in range(zs.size() - 1):
			used[i].append(false)
	for i in range(xs.size() - 1):
		for j in range(zs.size() - 1):
			if not solid[i][j] or used[i][j]:
				continue
			var j_end := j
			while j_end + 1 < zs.size() - 1 and solid[i][j_end + 1] and not used[i][j_end + 1]:
				j_end += 1
			var i_end := i
			while i_end + 1 < xs.size() - 1 and _run_matches(solid, used, i_end + 1, j, j_end):
				i_end += 1
			for ii in range(i, i_end + 1):
				for jj in range(j, j_end + 1):
					used[ii][jj] = true
			var x0: float = xs[i]
			var x1: float = xs[i_end + 1]
			var z0: float = zs[j]
			var z1: float = zs[j_end + 1]
			out.append([(x0 + x1) / 2.0, (z0 + z1) / 2.0, x1 - x0, z1 - z0])
	return out


static func _run_matches(solid: Array, used: Array, column: int, j: int, j_end: int) -> bool:
	for jj in range(j, j_end + 1):
		if not solid[column][jj] or used[column][jj]:
			return false
	return true


## The RIM around one carving footprint, as boxes, with a gap wherever a bridge deck crosses THAT edge.
## Returns [[centre_x, centre_z, width, depth], ...] for boxes RIM_HEIGHT tall.
##
## Round 10: a deck cuts an edge only if it reaches ACROSS the edge's line into the footprint. Round 7 cut wherever
## a deck overlapped the edge along its own axis, so on a map with two rivers each one had a gap at the OTHER
## river's bridge -- a hole in the rim onto open water, found by the first map with more than one footprint.
##
## And an edge is cut where ANOTHER carved footprint lies beyond it: a river built from several rectangles (a
## dog-leg, the Crossing's S) is one body of water, and round 7 stood a rim across it at every join -- a wall in the
## middle of the river, drawn as a kerb.
static func rim_slabs(entry: Dictionary, terrain: Array) -> Array:
	var box := bounds(entry)
	var out: Array = []
	var decks: Array = []
	var wet: Array = []
	for other: Dictionary in terrain:
		if is_deck(String(other["kind"])):
			decks.append(bounds(other))
		elif carves(String(other["kind"])) and other != entry:
			wet.append(bounds(other))
	# North and south edges run along x; east and west along z. Each is split by the decks that cross it.
	for side in [0, 1]:
		var line: float = box[1] if side == 0 else box[3]
		var z: float = line - RIM_THICKNESS / 2.0 if side == 0 else line + RIM_THICKNESS / 2.0
		var crossing: Array = []
		for deck: PackedFloat32Array in decks:
			if _crosses(deck[1], deck[3], line, side == 0):
				crossing.append(deck)
		for other: PackedFloat32Array in wet:
			if _beyond(other[1], other[3], line, side == 0):
				crossing.append(other)
		for span: Array in _spans(box[0], box[2], crossing, true):
			out.append([(span[0] + span[1]) / 2.0, z, span[1] - span[0], RIM_THICKNESS])
	for side in [0, 1]:
		var line: float = box[0] if side == 0 else box[2]
		var x: float = line - RIM_THICKNESS / 2.0 if side == 0 else line + RIM_THICKNESS / 2.0
		var crossing: Array = []
		for deck: PackedFloat32Array in decks:
			if _crosses(deck[0], deck[2], line, side == 0):
				crossing.append(deck)
		for other: PackedFloat32Array in wet:
			if _beyond(other[0], other[2], line, side == 0):
				crossing.append(other)
		for span: Array in _spans(box[1], box[3], crossing, false):
			out.append([x, (span[0] + span[1]) / 2.0, RIM_THICKNESS, span[1] - span[0]])
	return out


## Does a deck spanning `lo`..`hi` on one axis cross a footprint edge at `line`? It must reach the line from
## outside (or start on it) and continue INTO the footprint: `low_side` is true for the footprint's min edge,
## where the inside is above the line.
static func _crosses(lo: float, hi: float, line: float, low_side: bool) -> bool:
	if low_side:
		return lo <= line + EDGE_EPSILON and hi > line + EDGE_EPSILON
	return hi >= line - EDGE_EPSILON and lo < line - EDGE_EPSILON


## Does a footprint spanning `lo`..`hi` on one axis cover the ground just OUTSIDE an edge at `line`? (`low_side`:
## the edge is the min edge, so outside is below the line.)
static func _beyond(lo: float, hi: float, line: float, low_side: bool) -> bool:
	var probe := line - EDGE_EPSILON * 10.0 if low_side else line + EDGE_EPSILON * 10.0
	return lo < probe and hi > probe


## The RAILS on one deck: a box RAIL_HEIGHT tall along each side of the deck that borders carved ground, standing
## ON the deck (inside its rectangle), over the stretch where the ground beside it is water or pit, extended by
## RIM_THICKNESS at each end (clipped to the deck) so it closes the gap the rim's cut leaves at the bank.
## Returns [[centre_x, centre_z, width, depth], ...]. A deck side that meets floor gets no rail.
static func rail_slabs(deck_entry: Dictionary, terrain: Array) -> Array:
	var deck := bounds(deck_entry)
	var holes: Array = []
	var others: Array = []
	for other: Dictionary in terrain:
		if carves(String(other["kind"])):
			holes.append(bounds(other))
		elif is_deck(String(other["kind"])) and other != deck_entry:
			others.append(bounds(other))
	var out: Array = []
	# The two sides running along z (at the deck's min and max x), then the two running along x.
	for side in [0, 1]:
		var x_edge: float = deck[0] - EDGE_EPSILON * 10.0 if side == 0 else deck[2] + EDGE_EPSILON * 10.0
		var x: float = deck[0] + RAIL_THICKNESS / 2.0 if side == 0 else deck[2] - RAIL_THICKNESS / 2.0
		for span: Array in _wet_spans(deck[1], deck[3], holes, others, x_edge, false):
			out.append([x, (span[0] + span[1]) / 2.0, RAIL_THICKNESS, span[1] - span[0]])
	for side in [0, 1]:
		var z_edge: float = deck[1] - EDGE_EPSILON * 10.0 if side == 0 else deck[3] + EDGE_EPSILON * 10.0
		var z: float = deck[1] + RAIL_THICKNESS / 2.0 if side == 0 else deck[3] - RAIL_THICKNESS / 2.0
		for span: Array in _wet_spans(deck[0], deck[2], holes, others, z_edge, true):
			out.append([(span[0] + span[1]) / 2.0, z, span[1] - span[0], RAIL_THICKNESS])
	return out


## Along a deck side (`from`..`to` on the side's own axis, with the ground just outside it at `across` on the other
## axis), the stretches where that ground is carved and not another deck, each extended by RIM_THICKNESS and
## clipped to `from`..`to`, overlapping stretches merged.
static func _wet_spans(from: float, to: float, holes: Array, decks: Array, across: float, along_x: bool) -> Array:
	var wet: Array = []
	for hole: PackedFloat32Array in holes:
		var a_lo: float = hole[1] if along_x else hole[0]
		var a_hi: float = hole[3] if along_x else hole[2]
		if across <= a_lo or across >= a_hi:
			continue
		var lo: float = hole[0] if along_x else hole[1]
		var hi: float = hole[2] if along_x else hole[3]
		var covering: Array = []
		for d: PackedFloat32Array in decks:
			var d_lo: float = d[1] if along_x else d[0]
			var d_hi: float = d[3] if along_x else d[2]
			if across > d_lo and across < d_hi:
				covering.append(d)
		for span: Array in _spans(maxf(lo, from), minf(hi, to), covering, along_x):
			if span[1] > span[0]:
				wet.append([maxf(from, span[0] - RIM_THICKNESS), minf(to, span[1] + RIM_THICKNESS)])
	wet.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var merged: Array = []
	for span: Array in wet:
		if not merged.is_empty() and span[0] <= merged[-1][1]:
			merged[-1][1] = maxf(merged[-1][1], span[1])
		else:
			merged.append(span.duplicate())
	return merged


## `from`..`to` along one axis, minus the stretches the decks occupy on that axis.
static func _spans(from: float, to: float, decks: Array, along_x: bool) -> Array:
	var blocked: Array = []
	for deck: PackedFloat32Array in decks:
		var lo: float = deck[0] if along_x else deck[1]
		var hi: float = deck[2] if along_x else deck[3]
		if hi > from and lo < to:
			blocked.append([maxf(lo, from), minf(hi, to)])
	blocked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array = []
	var cursor := from
	for span: Array in blocked:
		if span[0] > cursor:
			out.append([cursor, span[0]])
		cursor = maxf(cursor, span[1])
	if cursor < to:
		out.append([cursor, to])
	return out


## Build a layout's terrain into `arena`: the carved floor into `ground` (whose stock slab is disabled), then the
## rims, rails and pans as bodies of their own, then the `arena.terrain` art if the theme has it. `half` is how far
## the floor reaches (the arena bound plus the ground margin). Called once at load by `Arena._build_terrain()`.
static func build(arena: Node3D, terrain: Array, half: float, ground: StaticBody3D, ground_thickness: float) -> void:
	if terrain.is_empty():
		return
	# The stock Ground is one slab covering everything; a carved layout replaces it wholesale.
	if ground != null:
		var stock := ground.get_node_or_null("Collision") as CollisionShape3D
		if stock != null:
			stock.disabled = true
		for slab: Array in slabs(half, terrain):
			ground.add_child(_shape(Vector3(slab[0], -ground_thickness / 2.0, slab[1]),
					Vector3(slab[2], ground_thickness, slab[3])))
	var rims := StaticBody3D.new()
	rims.name = "TerrainRims"
	var rails := StaticBody3D.new()
	rails.name = "TerrainRails"
	var pans := StaticBody3D.new()
	pans.name = "TerrainPans"
	# R3: in the bake, so a route keeps an agent radius off them. The pans stay out: they are below the floor.
	rims.add_to_group("navigation_source")
	rails.add_to_group("navigation_source")
	for entry: Dictionary in terrain:
		if is_deck(String(entry["kind"])):
			for slab: Array in rail_slabs(entry, terrain):
				rails.add_child(_shape(Vector3(slab[0], RAIL_HEIGHT / 2.0, slab[1]), Vector3(slab[2], RAIL_HEIGHT, slab[3])))
			continue
		if not carves(String(entry["kind"])):
			continue
		for slab: Array in rim_slabs(entry, terrain):
			rims.add_child(_shape(Vector3(slab[0], RIM_HEIGHT / 2.0, slab[1]), Vector3(slab[2], RIM_HEIGHT, slab[3])))
		var depth := float(KINDS[entry["kind"]]["pan_depth"])
		var rect: Array = entry["rect"]
		pans.add_child(_shape(Vector3(rect[0], -depth - ground_thickness / 2.0, rect[1]),
				Vector3(rect[2], ground_thickness, rect[3])))
	arena.add_child(rims)
	arena.add_child(rails)
	arena.add_child(pans)
	# Only if the theme has the slot: VisualSlot pushes an engine error for a slot the theme lacks, and an arena
	# that errors because its water has no art is worse than water with no art. Same guard the kit props use.
	if GameTheme.slots.has("arena.terrain"):
		var dressing := VisualSlot.new()
		dressing.name = "TerrainVisual"
		dressing.slot = "arena.terrain"
		arena.add_child(dressing)
		dressing.invoke("setup", [terrain])


static func _shape(at: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	return shape
