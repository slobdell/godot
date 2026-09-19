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
## A deck narrower than this leaves no navmesh once the 2 m agent radius has eaten both sides. The maze's tight
## gate is the precedent: 7 m physical gives 3 m of drivable corridor, which is single-file but real.
const MIN_DECK_M := 7.0


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


## The RIM around one carving footprint, as boxes, with a gap wherever a bridge deck crosses it.
## Returns [[centre_x, centre_z, width, depth], ...] for boxes RIM_HEIGHT tall.
static func rim_slabs(entry: Dictionary, terrain: Array) -> Array:
	var box := bounds(entry)
	var out: Array = []
	var decks: Array = []
	for other: Dictionary in terrain:
		if is_deck(String(other["kind"])):
			decks.append(bounds(other))
	# North and south edges run along x; east and west along z. Each is split by the decks that cross it.
	for side in [0, 1]:
		var z: float = box[1] - RIM_THICKNESS / 2.0 if side == 0 else box[3] + RIM_THICKNESS / 2.0
		for span: Array in _spans(box[0], box[2], decks, true):
			out.append([(span[0] + span[1]) / 2.0, z, span[1] - span[0], RIM_THICKNESS])
	for side in [0, 1]:
		var x: float = box[0] - RIM_THICKNESS / 2.0 if side == 0 else box[2] + RIM_THICKNESS / 2.0
		for span: Array in _spans(box[1], box[3], decks, false):
			out.append([x, (span[0] + span[1]) / 2.0, RIM_THICKNESS, span[1] - span[0]])
	return out


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
