class_name SelectionSquads
extends RefCounted
## Round 19 (orders, C19.1). The lead: *"I selected 2 squads and right clicked a point on the map - the resultant
## indicator dots for all the units was all over the map, and a bunch of vehicles just basically ran off to the middle of
## the map."* A selection is read as the SQUADS in it, never as one heap of vehicles: two squads ordered together stay
## two squads, each in its own formation, and arrive side by side at the point he clicked. Pure: no input, no drawing.
##
## A squad here is what the player thinks of as one: a living element he gave a task to, or else a control group (the
## number key he selects it with), in either case wholly inside the selection and no bigger than
## Formations.MAX_MEMBERS. `split` finds them; `row` lays several of them abreast at one click.

## Between two squads standing side by side, edge vehicle to edge vehicle, as well as each squad's own frontage:
## one doctrine spacing (the "open" ground's 14 m), so the gap between squads reads as the gap within one.
const GAP_M := 14.0
## The spacing a squad's footprint is measured at when it has no element yet to say its own pitch.
const SPACING_M := 14.0
## Round 23 (orders O1, decided by the lead at the launch): two squads in COLUMN side by side stand this far apart,
## centre line to centre line. A column has no frontage, so `row` laid two files one GAP_M (14 m) apart and on his
## Sumps match the two files, snaking at road speed, came within 5 m of each other (round 22, question 1). A column
## is therefore given a lane of its own: `width` reads it as COLUMN_GAP_M - GAP_M wide (7 m to each side of its
## file), so two columns' files sit 28 m apart, a column beside a line keeps the lane's half plus the gap from the
## line's edge vehicle, and every other shape stands exactly where it did. Read by nobody else; his eye refines it.
const COLUMN_GAP_M := 28.0
## COLUMN_GAP_M as the probes can set it (`--column-gap=14`: the before-arm, on the same build). Never set by the game.
static var column_gap_m := COLUMN_GAP_M


## `alive(name) -> bool`, `position(name) -> Vector3`.
## {"squads": [{"number": int (its control group, or 0), "units": Array[String], "element": Element or null}],
##  "loose": Array[String]} for the living `units`. Squads come out in the order found; `row` decides who stands where.
##
## 1. The SMALLEST control group of at most MAX_MEMBERS whose living members are all selected (lowest number on a
##    tie): a group dealt one squad each (1, 2) beats a group the player saved over both (Ctrl+3), so the squads come
##    back out of it. Its element rides along when the element is exactly those units (else the next task re-forms
##    it: the units a direct order took out of it are back in the squad he selected).
## 2. Then an element whose living members are all selected and still free (no bigger than a squad): one formed
##    from a selection that is no group, or a squad dealt out of an oversized group.
## 3. Then a whole group bigger than a squad, dealt into squads of at most MAX_MEMBERS west to east, sharing the
##    group's number (so they share its formation too).
## 4. Everything else is loose: units in no squad of the selection (part of a squad, or in no group at all).
static func split(units: Array, groups: ControlGroups, elements: Elements, alive: Callable, position: Callable) -> Dictionary:
	var living: Array[String] = []
	for unit_name: Variant in units:
		if bool(alive.call(String(unit_name))) and not living.has(String(unit_name)):
			living.append(String(unit_name))
	var squads: Array = []
	var taken := {}
	var free := func(n: String) -> bool: return living.has(n) and not taken.has(n)
	var oversized: Array = []  # [number, living members] of whole groups too big to be one squad
	if groups != null:
		var whole: Array = []  # [size, number, living members] of every group wholly inside the selection
		for number in groups.numbers():
			var members := _living(groups.members(number), alive)
			if not members.is_empty() and members.all(free):
				whole.append([members.size(), number, members])
		whole.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		for entry: Array in whole:
			var members: Array[String] = entry[2]
			if not members.all(free):
				continue
			if members.size() > Formations.MAX_MEMBERS:
				oversized.append([int(entry[1]), members])
				continue
			for member in members:
				taken[member] = true
			squads.append({"number": int(entry[1]), "units": members, "element": _element_exactly(elements, members, alive)})
	if elements != null:
		for unit_name in living:
			if taken.has(unit_name):
				continue
			var element := elements.of(unit_name)
			if element == null:
				continue
			var members := _living(_names(element.members()), alive)
			if members.is_empty() or members.size() > Formations.MAX_MEMBERS or not members.all(free):
				continue
			for member in members:
				taken[member] = true
			squads.append({"number": _group_exactly(groups, members, alive), "units": members, "element": element})
	for entry: Array in oversized:
		var members: Array[String] = []
		for member: String in entry[1]:
			if not taken.has(member):
				members.append(member)
		if members.is_empty():
			continue
		for member in members:
			taken[member] = true
		for piece in deal(members, position):
			squads.append({"number": int(entry[0]), "units": piece, "element": null})
	var loose: Array[String] = []
	for unit_name in living:
		if not taken.has(unit_name):
			loose.append(unit_name)
	return {"squads": squads, "loose": loose}


## A group too big to be one squad, dealt into ceil(n / MAX_MEMBERS) squads as even as they come, west to east (then
## north to south), so each piece is a cluster of neighbours rather than every other vehicle.
static func deal(members: Array[String], position: Callable) -> Array:
	var placed: Array = []
	for unit_name in members:
		var p: Vector3 = position.call(unit_name)
		placed.append([p.x, p.z, unit_name])
	placed.sort()
	var pieces := ceili(float(members.size()) / Formations.MAX_MEMBERS)
	var result: Array = []
	var from := 0
	for i in pieces:
		var size := (members.size() - from) / (pieces - i) + (1 if (members.size() - from) % (pieces - i) > 0 else 0)
		var piece: Array[String] = []
		for j in range(from, from + size):
			piece.append(String(placed[j][2]))
		piece.sort()
		result.append(piece)
		from += size
	return result


## Round 22 (orders O1b). The lead: two squads of three ordered into lines "were criss-crossed in terms of current
## position versus what they were trying to achieve ... the vehicles were all basically bumping each other": the
## survivors of two squads stood interleaved, `row` laid the two squads side by side, and each three drove through the
## other to reach its line. Once the body's anchors are laid (`row` or `ranks`, any verb with a point), if any two
## vehicles of DIFFERENT squads would cross on the way (each driving straight to its own squad's anchor), the
## vehicles are dealt to the anchors afresh: each anchor takes as many vehicles as the squad laid there, by the least
## total straight-line driving, which crosses no two paths (swapping the ends of two crossing paths is always shorter).
## Only the squads that cross are dealt, among their own places (a knot of them: a crosses b, b crosses c). Squads
## whose paths cross nobody's come back untouched (the same dictionaries, elements and all), so squads standing
## apart are never reshuffled. A dealt piece keeps the NUMBER of the squad laid on its anchor (his number keys, its
## formation and its name stay as he made them: the control groups are not rewritten); it has no element, so the order
## forms one for exactly those vehicles, and the next order he gives a group re-forms it from the group.
## `anchors[i]` is squad i's anchor; `position(name) -> Vector3`. Returns the squads in the same order, a dealt one
## marked "dealt": true.
static func untangle(squads: Array, anchors: Array[Vector3], position: Callable) -> Array:
	if squads.size() < 2 or anchors.size() < squads.size():
		return squads
	# A deal inside one knot can, rarely, cross a squad outside it: a second pass deals that knot too.
	var result := squads
	for attempt in 3:
		var next := _untangle_once(result, anchors, position)
		if next == result:
			break
		result = next
	return result


static func _untangle_once(squads: Array, anchors: Array[Vector3], position: Callable) -> Array:
	var starts := {}
	var paths: Array = []  # [squad index, start, anchor]
	for i in squads.size():
		for unit_name: String in squads[i]["units"]:
			var p: Vector3 = position.call(unit_name)
			starts[unit_name] = Vector3(p.x, 0.0, p.z)
			paths.append([i, starts[unit_name], anchors[i]])
	# Squads whose vehicles cross, joined into groups (a crosses b, b crosses c: one group); only those are dealt,
	# among their own places, so a squad that crosses nobody keeps its vehicles.
	var family: Array[int] = []
	for i in squads.size():
		family.append(i)
	var crossed := false
	for a in paths.size():
		for b in range(a + 1, paths.size()):
			var i := int(paths[a][0])
			var j := int(paths[b][0])
			if i == j or _root(family, i) == _root(family, j):
				continue
			if Geometry2D.segment_intersects_segment(_xz(paths[a][1]), _xz(paths[a][2]), _xz(paths[b][1]), _xz(paths[b][2])) != null:
				family[_root(family, i)] = _root(family, j)
				crossed = true
	if not crossed:
		return squads
	var result := squads.duplicate()
	var groups := {}  # root -> [squad indices]
	for i in squads.size():
		var root := _root(family, i)
		if not groups.has(root):
			groups[root] = []
		(groups[root] as Array).append(i)
	for members: Array in groups.values():
		if members.size() < 2:
			continue
		var names: Array[String] = []
		var from: Array[Vector3] = []
		var seats: Array[Vector3] = []
		var seat_squad: Array[int] = []
		for i: int in members:
			for unit_name: String in squads[i]["units"]:
				names.append(unit_name)
				from.append(starts[unit_name])
				seats.append(Vector3(anchors[i].x, 0.0, anchors[i].z))
				seat_squad.append(i)
		var given := least_total(from, seats)
		var pieces := {}
		for i: int in members:
			pieces[i] = [] as Array[String]
		for k in names.size():
			(pieces[seat_squad[given[k]]] as Array[String]).append(names[k])
		for i: int in members:
			var piece: Array[String] = pieces[i]
			piece.sort()
			var own: Array = (squads[i]["units"] as Array).duplicate()
			own.sort()
			if ",".join(piece) == ",".join(PackedStringArray(own)):
				continue
			result[i] = {"number": int(squads[i].get("number", 0)), "units": piece, "element": null, "dealt": true}
	return result


static func _root(family: Array[int], i: int) -> int:
	while family[i] != i:
		i = family[i]
	return i


## Whether two paths of different squads cross. `paths` = [[squad index, from, to]].
static func _any_cross(paths: Array) -> bool:
	for a in paths.size():
		for b in range(a + 1, paths.size()):
			if int(paths[a][0]) == int(paths[b][0]):
				continue
			var hit: Variant = Geometry2D.segment_intersects_segment(_xz(paths[a][1]), _xz(paths[a][2]), _xz(paths[b][1]),
					_xz(paths[b][2]))
			if hit != null:
				return true
	return false


static func _xz(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


## The anchors several blocks stand on when one click orders them all: abreast across the line of approach (or across
## a heading he drew), each block's frontage plus GAP_M apart, centred on the click, in the left-to-right order they
## stand in now so that no two cross on the way. `blocks` = [{"center": Vector3, "width": float}]; returns one
## Vector3 per block in the same order. One block stands on the click itself.
static func row(blocks: Array, click: Vector3, facing: Variant = null, fallback_heading := Vector3.FORWARD) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var flat_click := Vector3(click.x, 0.0, click.z)
	if blocks.is_empty():
		return result
	if blocks.size() == 1:
		result.append(flat_click)
		return result
	var middle := Vector3.ZERO
	for block: Dictionary in blocks:
		middle += Vector3((block["center"] as Vector3).x, 0.0, (block["center"] as Vector3).z)
	middle /= blocks.size()
	var heading := _heading(blocks, flat_click, facing, fallback_heading)
	var across := Vector3(-heading.z, 0.0, heading.x)
	var order: Array = []
	for i in blocks.size():
		order.append([((blocks[i]["center"] as Vector3) - middle).dot(across), i])
	order.sort()
	var total := 0.0
	for block: Dictionary in blocks:
		total += float(block["width"])
	total += GAP_M * (blocks.size() - 1)
	result.resize(blocks.size())
	var cursor := -total * 0.5
	for entry: Array in order:
		var width := float(blocks[int(entry[1])]["width"])
		result[int(entry[1])] = flat_click + across * (cursor + width * 0.5)
		cursor += width + GAP_M
	return result


## Round 21 (orders, O1). Five squads abreast is not a body, it is a line across the map: the lead's 25 Rat Rods in
## five squads of five, each a vee at the gangs' 18 m pitch (≈ 65 m wide), laid by `row` came to ≈ 380 m, and the
## arena's clamp pinned the outer two at ±116 m on foundry; they drove 100 m sideways before turning toward his click
## and one crew ended `blocked/terrain` against the wall (round 20, recordings 14-59-04 and 18-38-40). So a rank holds
## at most MAX_ABREAST squads and at most MAX_FRONTAGE_M of them; the rest stand in ranks behind it.
##
## Three abreast, because a body of three is still read as one front with two flanks and a centre (the doctrine's own
## platoon of three elements); a fourth squad abreast only widens it.
const MAX_ABREAST := 3
## The widest one rank may be, edge squad's centre to edge squad's centre plus their half-widths: 200 m, so the
## body fits across the narrowest drivable middle we deal (foundry's ±116 m square, 232 m) with a crew's room to
## spare on each side, and a click anywhere but the outer 16 m keeps every squad where it was laid. Two of the gangs'
## 18 m vees (2 × 65 + 14 = 144 m) fit; three (222 m) do not, so five such squads stand 2-2-1; three wedges at
## the Law's 15 m (3 × 54 + 28 = 190 m) stand three abreast.
const MAX_FRONTAGE_M := 200.0
## Above this many blocks the left-to-right assignment is greedy rather than the exhaustive search (`_assign`).
const SEARCH_LIMIT := 6


## The anchors several blocks stand on when one click orders them all, as a BODY: one block on the click itself; two,
## `row` exactly as round 19 (his approved two-squad case); three or more, `row` while it fits a rank (MAX_ABREAST
## blocks, MAX_FRONTAGE_M wide), else ranks. The front rank stands across the click; each further rank one block's
## depth plus GAP_M behind the one before it, toward where they came from, so nobody drives past the click to reach a
## rear slot (the orchestrator's ruling after O1b tried the click at the body's centre: on an attack-move the front
## rank would drive a step PAST where he pointed, into contact he did not choose; a rear squad with a short way to go
## simply gets there first). Ranks are as even as they come with the front one the fullest (5 = 3 + 2 when three fit, else 2 + 2 + 1),
## each centred on the click's line. Every slot is as wide and as deep as the widest and deepest block, so no pick of
## a leader's own shape puts two squads on top of each other. Who stands where: the assignment that drives the least
## in total (straight-line metres from each block's centre to its slot), which is also the one whose straight paths
## never cross; ties go to the earlier block. `blocks` = [{"center": Vector3, "width": float, "depth": float}].
static func ranks(blocks: Array, click: Vector3, facing: Variant = null, fallback_heading := Vector3.FORWARD) -> Array[Vector3]:
	if blocks.size() <= 2 or _fits_one_rank(blocks):
		return row(blocks, click, facing, fallback_heading)
	var flat_click := Vector3(click.x, 0.0, click.z)
	var heading := _heading(blocks, flat_click, facing, fallback_heading)
	var across := Vector3(-heading.z, 0.0, heading.x)
	var slot_width := 0.0
	var slot_depth := 0.0
	for block: Dictionary in blocks:
		slot_width = maxf(slot_width, float(block["width"]))
		slot_depth = maxf(slot_depth, float(block.get("depth", 0.0)))
	var slots: Array[Vector3] = []
	var behind := 0.0
	var sizes := rank_sizes(blocks.size(), slot_width)
	var nest := nested_offsets(blocks)
	for r in sizes.size():
		var size := sizes[r]
		for k in size:
			var aside := (float(k) - (size - 1) * 0.5) * (slot_width + GAP_M)
			slots.append(flat_click + across * aside - heading * behind)
		if r + 1 < sizes.size():
			behind += rank_step(size, sizes[r + 1], slot_width, slot_depth, nest, _nest_clearance(blocks))
	var centers: Array[Vector3] = []
	for block: Dictionary in blocks:
		var c: Vector3 = block["center"]
		centers.append(Vector3(c.x, 0.0, c.z))
	var given := _assign(centers, slots)
	var result: Array[Vector3] = []
	for i in blocks.size():
		result.append(slots[given[i]])
	return result


## Round 22 (orders O3, the orchestrator's ruling (c)): ten of his gang vees in ranks of two were ~250 m deep, deeper
## than the floor behind a click 150 m from his base. When every block stands in the SAME shape (`offsets`: its slots
## across/behind its place, as TacticsFormation lays them), the rank behind steps back only as far as keeps every one of
## its slots `clear` metres from every slot of the rank in front (a vee's wings reach up beside the vee ahead of it),
## never further than the depth plus GAP_M it stepped before. Mixed or unknown shapes (AUTO: the leader picks) step
## back their depth plus GAP_M as round 21. Ten gang vees at 18 m: 26 m a rank instead of 50 m.
static func rank_step(front: int, rear: int, slot_width: float, slot_depth: float, offsets: Array, clear: float) -> float:
	var plain := slot_depth + GAP_M
	if offsets.is_empty():
		return plain
	var front_slots := _rank_slots(front, slot_width, offsets, 0.0)
	var step := 0.0
	while step < plain:
		var rear_slots := _rank_slots(rear, slot_width, offsets, step)
		var apart := true
		for p in front_slots:
			for q in rear_slots:
				if p.distance_to(q) < clear:
					apart = false
					break
			if not apart:
				break
		if apart:
			return step
		step += 0.5
	return plain


## Off only for the probe's before-arm (`--nest=off`: ranks step their depth plus a gap, as before round 22's ruling).
static var nest_ranks := true


## The shape every block shares, as slots (Array[Vector2]), or [] when any block has none or they differ. Blocks
## carry `shape`, `count` and `pitch_v` (their spacing across and along); the shared shape is laid at the largest
## pitch among them (squads of one faction differ by a hull floor here and there; the largest is the safe one).
static func nested_offsets(blocks: Array) -> Array:
	if not nest_ranks or blocks.is_empty() or not (blocks[0] as Dictionary).has("shape"):
		return []
	var shape := String(blocks[0]["shape"])
	var count := int(blocks[0]["count"])
	var pitch := Vector2.ZERO
	for block: Dictionary in blocks:
		if String(block.get("shape", "")) != shape or int(block.get("count", 0)) != count:
			return []
		var p: Vector2 = block.get("pitch_v", Vector2(SPACING_M, SPACING_M))
		pitch = Vector2(maxf(pitch.x, p.x), maxf(pitch.y, p.y))
	return TacticsFormation.offsets_at(shape, count, pitch)


## Nested ranks keep at least the blocks' own pitch between them (a rank never closer than a squad's own vehicles).
static func _nest_clearance(blocks: Array) -> float:
	var clear := GAP_M
	for block: Dictionary in blocks:
		var p: Vector2 = block.get("pitch_v", Vector2.ZERO)
		clear = maxf(clear, maxf(p.x, p.y))
	return clear


## One rank's slots in the body's own frame (x across, y behind the click).
static func _rank_slots(count: int, slot_width: float, offsets: Array, behind: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for k in count:
		var aside := (float(k) - (count - 1) * 0.5) * (slot_width + GAP_M)
		for offset: Vector2 in offsets:
			result.append(Vector2(aside + offset.x, behind + offset.y))
	return result


## How many blocks stand in each rank, front first: every rank as full as MAX_ABREAST and MAX_FRONTAGE_M allow at
## `slot_width` each, the rest in the rank behind. Round 22 (orders O3): ten Law wedges stand 3 + 3 + 3 + 1, three
## platoons on the click and a reserve (round 21 dealt evenly, which would be 3 + 3 + 2 + 2: the same depth with
## fewer guns arriving on his click first); five squads stand as in round 21 (3 + 2, or 2 + 2 + 1 for gang vees).
static func rank_sizes(count: int, slot_width: float) -> Array[int]:
	var sizes: Array[int] = []
	if count <= 0:
		return sizes
	var per := 1
	for abreast in range(MAX_ABREAST, 0, -1):
		if abreast * slot_width + (abreast - 1) * GAP_M <= MAX_FRONTAGE_M:
			per = abreast
			break
	var left := count
	while left > 0:
		sizes.append(mini(per, left))
		left -= per
	return sizes


## The same anchors moved together, as little as it takes, until the arena's clamp would leave every one where it is:
## a body laid near a wall slides inward whole rather than having its outer squads pushed onto their neighbours (the
## clamp alone pinned two of his five squads at x = ±116 m). `clamp(Vector3) -> Vector3`. Anchors the arena cannot
## hold all at once (a body wider than the map) are clamped one by one after the slide, as before.
static func fit_inside(anchors: Array[Vector3], clamp: Callable) -> Array[Vector3]:
	var shifted: Array[Vector3] = anchors.duplicate()
	for attempt in 4:
		var worst := Vector3.ZERO
		for p in shifted:
			var push: Vector3 = (clamp.call(p) as Vector3) - p
			push.y = 0.0
			if push.length() > worst.length():
				worst = push
		if worst.length() < 0.01:
			return shifted
		for i in shifted.size():
			shifted[i] += worst
	var result: Array[Vector3] = []
	for p in shifted:
		result.append(clamp.call(p))
	return result


static func _fits_one_rank(blocks: Array) -> bool:
	if blocks.size() > MAX_ABREAST:
		return false
	var total := GAP_M * (blocks.size() - 1)
	for block: Dictionary in blocks:
		total += float(block["width"])
	return total <= MAX_FRONTAGE_M


static func _heading(blocks: Array, flat_click: Vector3, facing: Variant, fallback_heading: Vector3) -> Vector3:
	var middle := Vector3.ZERO
	for block: Dictionary in blocks:
		middle += Vector3((block["center"] as Vector3).x, 0.0, (block["center"] as Vector3).z)
	middle /= maxf(blocks.size(), 1.0)
	if facing is Vector3 and (facing as Vector3).length() > 1e-6:
		return TacticsFormation.flat(facing)
	if (flat_click - middle).length() > 2.0:
		return TacticsFormation.flat(flat_click - middle)
	return TacticsFormation.flat(fallback_heading)


## slot index per block. Up to SEARCH_LIMIT blocks: every assignment, the least total straight-line driving wins (an
## assignment whose two paths cross can always be uncrossed for less, so the winner crosses none). Beyond (round 22:
## ten squads), the same least total by the Hungarian method: round 21's greedy deal (front ranks to the blocks
## furthest forward) sent the west squads of an abreast army to the front across the middle ones.
static func _assign(centers: Array[Vector3], slots: Array[Vector3]) -> Array[int]:
	var n := centers.size()
	var best: Array[int] = []
	if n <= SEARCH_LIMIT:
		var cost := []
		for i in n:
			var line := []
			for j in n:
				line.append(centers[i].distance_to(slots[j]))
			cost.append(line)
		var best_total := [INF]
		var current: Array[int] = []
		var used := []
		used.resize(n)
		used.fill(false)
		_search(cost, current, used, 0.0, best_total, best)
		return best
	return least_total(centers, slots)


## The assignment block -> slot with the least total straight-line distance (Hungarian method, O(n³)): slot index
## per block. Equal blocks and slots in number.
static func least_total(centers: Array[Vector3], slots: Array[Vector3]) -> Array[int]:
	var n := centers.size()
	# 1-based potentials u (rows = blocks), v (columns = slots); p[j] = the row matched to column j.
	var u := PackedFloat64Array()
	var v := PackedFloat64Array()
	var p := PackedInt32Array()
	var way := PackedInt32Array()
	u.resize(n + 1)
	v.resize(n + 1)
	p.resize(n + 1)
	way.resize(n + 1)
	u.fill(0.0)
	v.fill(0.0)
	p.fill(0)
	way.fill(0)
	for i in range(1, n + 1):
		p[0] = i
		var j0 := 0
		var minv := PackedFloat64Array()
		minv.resize(n + 1)
		minv.fill(INF)
		var used := []
		used.resize(n + 1)
		used.fill(false)
		while true:
			used[j0] = true
			var i0 := p[j0]
			var delta := INF
			var j1 := 0
			for j in range(1, n + 1):
				if used[j]:
					continue
				var cur := centers[i0 - 1].distance_to(slots[j - 1]) - u[i0] - v[j]
				if cur < minv[j]:
					minv[j] = cur
					way[j] = j0
				if minv[j] < delta:
					delta = minv[j]
					j1 = j
			for j in range(0, n + 1):
				if used[j]:
					u[p[j]] += delta
					v[j] -= delta
				else:
					minv[j] -= delta
			j0 = j1
			if p[j0] == 0:
				break
		while true:
			var j1 := way[j0]
			p[j0] = p[j1]
			j0 = j1
			if j0 == 0:
				break
	var result: Array[int] = []
	result.resize(n)
	for j in range(1, n + 1):
		if p[j] > 0:
			result[p[j] - 1] = j - 1
	return result


static func _search(cost: Array, current: Array[int], used: Array, total: float, best_total: Array, best: Array[int]) -> void:
	var n := cost.size()
	if total >= float(best_total[0]) - 1e-6:
		return
	if current.size() == n:
		best_total[0] = total
		best.assign(current)
		return
	var i := current.size()
	for j in n:
		if used[j]:
			continue
		used[j] = true
		current.append(j)
		_search(cost, current, used, total + float(cost[i][j]), best_total, best)
		current.pop_back()
		used[j] = false


## How wide a squad stands across its heading in `shape` (metres between its outermost hulls' centres); a column of
## two or more, which has none, is as wide as the lane that keeps two files COLUMN_GAP_M apart (round 23, O1).
static func width(shape: String, count: int, spacing := SPACING_M) -> float:
	if count <= 1:
		return 0.0
	if not TacticsFormation.NAMES.has(shape):
		shape = TacticsFormation.auto(count, "move")
	if shape == "column":
		return maxf(TacticsFormation.frontage(shape, count, spacing), column_gap_m - GAP_M)
	return TacticsFormation.frontage(shape, count, spacing)


## How deep a squad stands along its heading in `shape` (metres between its front and rear hulls' centres).
static func depth(shape: String, count: int, spacing := SPACING_M) -> float:
	if count <= 1:
		return 0.0
	if not TacticsFormation.NAMES.has(shape):
		shape = TacticsFormation.auto(count, "move")
	return TacticsFormation.depth(shape, count, spacing)


static func _living(names: Array[String], alive: Callable) -> Array[String]:
	var result: Array[String] = []
	for unit_name in names:
		if bool(alive.call(unit_name)):
			result.append(unit_name)
	return result


## The element whose living members are exactly `members`, or null.
static func _element_exactly(elements: Elements, members: Array[String], alive: Callable) -> Element:
	if elements == null or members.is_empty():
		return null
	var element := elements.of(members[0])
	if element == null:
		return null
	var living := _living(_names(element.members()), alive)
	if living.size() != members.size() or not living.all(func(n: String) -> bool: return members.has(n)):
		return null
	return element


static func _names(roster: Variant) -> Array[String]:
	var result: Array[String] = []
	for member: Variant in roster:
		result.append(String(member))
	return result


## The control group whose living members are exactly `members`, or 0.
static func _group_exactly(groups: ControlGroups, members: Array[String], alive: Callable) -> int:
	if groups == null:
		return 0
	for number in groups.numbers():
		var living := _living(groups.members(number), alive)
		if living.size() == members.size() and living.all(func(n: String) -> bool: return members.has(n)):
			return number
	return 0
