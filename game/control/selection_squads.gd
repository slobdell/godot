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
## rear slot. Ranks are as even as they come with the front one the fullest (5 = 3 + 2 when three fit, else 2 + 2 + 1),
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
	for size in rank_sizes(blocks.size(), slot_width):
		for k in size:
			var aside := (float(k) - (size - 1) * 0.5) * (slot_width + GAP_M)
			slots.append(flat_click + across * aside - heading * behind)
		behind += slot_depth + GAP_M
	var centers: Array[Vector3] = []
	for block: Dictionary in blocks:
		var c: Vector3 = block["center"]
		centers.append(Vector3(c.x, 0.0, c.z))
	var given := _assign(centers, slots, heading, across)
	var result: Array[Vector3] = []
	for i in blocks.size():
		result.append(slots[given[i]])
	return result


## How many blocks stand in each rank, front first: the fewest ranks in which no rank holds more than MAX_ABREAST
## blocks or is wider than MAX_FRONTAGE_M at `slot_width` each, dealt as evenly as they come, the front ranks fuller.
static func rank_sizes(count: int, slot_width: float) -> Array[int]:
	var sizes: Array[int] = []
	if count <= 0:
		return sizes
	var ranks_needed := count
	for r in range(ceili(float(count) / MAX_ABREAST), count + 1):
		var widest := ceili(float(count) / r)
		if widest * slot_width + (widest - 1) * GAP_M <= MAX_FRONTAGE_M:
			ranks_needed = r
			break
	for r in ranks_needed:
		sizes.append(count / ranks_needed + (1 if r < count % ranks_needed else 0))
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
## assignment whose two paths cross can always be uncrossed for less, so the winner crosses none). Beyond: front ranks
## to the blocks furthest forward, each rank left to right as they stand.
static func _assign(centers: Array[Vector3], slots: Array[Vector3], heading: Vector3, across: Vector3) -> Array[int]:
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
	var order: Array = []
	for i in n:
		order.append([-centers[i].dot(heading), i])
	order.sort()
	best.resize(n)
	var j := 0
	while j < n:
		# the slots of one rank share their distance behind the click
		var rank_end := j
		while rank_end < n and absf(slots[rank_end].dot(heading) - slots[j].dot(heading)) < 0.01:
			rank_end += 1
		var members: Array = []
		for k in range(j, rank_end):
			var i := int(order[k][1])
			members.append([centers[i].dot(across), i])
		members.sort()
		for k in members.size():
			best[int(members[k][1])] = j + k
		j = rank_end
	return best


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


## How wide a squad stands across its heading in `shape` (metres between its outermost hulls' centres).
static func width(shape: String, count: int, spacing := SPACING_M) -> float:
	if count <= 1:
		return 0.0
	if not TacticsFormation.NAMES.has(shape):
		shape = TacticsFormation.auto(count, "move")
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
