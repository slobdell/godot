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
##
## Round 37 (orders O3, his answer: "every vehicle with its own squad, PROVIDED contention is not worse"): under
## UNTANGLE_WHOLE the squads that cross keep their vehicles and swap PLACES instead: `untangle_whole` writes the chosen
## places into `anchors` (whole squads, each still under its own element) and returns the squads untouched.
## `--untangle=whole` (env UNTANGLE=whole); today's deal is the default.
static var UNTANGLE_WHOLE := OS.get_cmdline_user_args().has("--untangle=whole") or OS.get_environment("UNTANGLE") == "whole"
## Measurement: squads given another squad's place by untangle_whole, and knots it could not uncross, since start.
static var swapped_whole := 0
static var whole_still_crossed := 0


static func untangle(squads: Array, anchors: Array[Vector3], position: Callable) -> Array:
	if squads.size() < 2 or anchors.size() < squads.size():
		return squads
	if UNTANGLE_WHOLE:
		untangle_whole(squads, anchors, position)
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


## O3: the places of crossing squads permuted WHOLE: within each knot of squads whose vehicles' straight drives cross
## (the same knots `untangle` deals), every assignment of the knot's places to its squads is tried (a knot is at most five
## squads: 120) and the one with the fewest crossing pairs of vehicle drives between different squads wins, then the least
## total straight driving, then the order they had (stable). `anchors` is rewritten in place; returns the squads moved.
static func untangle_whole(squads: Array, anchors: Array[Vector3], position: Callable) -> int:
	var starts := {}
	for i in squads.size():
		for unit_name: String in squads[i]["units"]:
			var p: Vector3 = position.call(unit_name)
			starts[unit_name] = Vector3(p.x, 0.0, p.z)
	var family: Array[int] = []
	for i in squads.size():
		family.append(i)
	for i in squads.size():
		for j in range(i + 1, squads.size()):
			if _root(family, i) != _root(family, j) and _pair_crosses(squads[i]["units"], anchors[i], squads[j]["units"], anchors[j], starts) > 0:
				family[_root(family, i)] = _root(family, j)
	var groups := {}
	for i in squads.size():
		var root := _root(family, i)
		if not groups.has(root):
			groups[root] = []
		(groups[root] as Array).append(i)
	var moved := 0
	for members: Array in groups.values():
		if members.size() < 2:
			continue
		var places: Array[Vector3] = []
		for i: int in members:
			places.append(anchors[i])
		var best: Array = []
		var best_key := [INF, INF]
		for perm: Array in _permutations(members.size()):
			var crossings := 0
			var drive := 0.0
			for a in members.size():
				var at: Vector3 = places[perm[a]]
				for unit_name: String in squads[members[a]]["units"]:
					drive += _xz(starts[unit_name]).distance_to(_xz(at))
				for b in range(a + 1, members.size()):
					crossings += _pair_crosses(squads[members[a]]["units"], at, squads[members[b]]["units"], places[perm[b]], starts)
			if crossings < best_key[0] or (crossings == best_key[0] and drive < best_key[1] - 0.01):
				best_key = [crossings, drive]
				best = perm
		if best_key[0] > 0:
			whole_still_crossed += 1
		for a in members.size():
			if int(best[a]) != a:
				moved += 1
			anchors[members[a]] = places[best[a]]
	swapped_whole += moved
	return moved


## Round 37 (orders, R37.29; the lead's playtest 2026-10-21, Terminus: "the target waypoints for each squad was all over at
## far away places ... A bunch of units drove through streets ... I immediately lost control of the army"; design note
## references/round37/orders/group-click-column-note.md, approved). `--group-lay=column`: one click for several squads lays a
## COLUMN OF WEDGES along the approach, as wide as the ground there, instead of the open-ground body (`ranks`): the squad
## farthest along the approach (nearest the click) in front, the farthest back last; each rank as many squads abreast as its
## own clear width holds (at most MAX_ABREAST and MAX_FRONTAGE_M), centred in that width, re-read at the rank's own point so
## the column follows the street; narrower than a squad, single file on the approach line. Crossing squads swap places whole
## (no crew re-deal). OFF until its bar passes.
## Round 38 (orders G1, v2): "open ground" is no longer the scan reaching GROUP_SCAN_M (yard_open's walls stand inside 100 m
## and v1 changed 52 of its 96 rows, R37.38): today's body stands wherever every one of its places is already on the clear
## ground read at its own rank (`today`), and the column is laid only when one of them is not. The same lay serves a queued
## leg (each squad's block centred where its previous leg ends) and a gate.
static var GROUP_LAY := OS.get_cmdline_user_args().has("--group-lay=column") or OS.get_environment("GROUP_LAY") == "column"
## How far each side the corridor is read for a group click (wider than the gate's 60 m, so a wide street is not "open").
const GROUP_SCAN_M := 100.0
## Measurement: group clicks laid as a column (not open ground), since start.
static var columns_laid := 0
## Measurement (G1): group lays where today's body already stood on clear ground and was kept, since start.
static var bodies_kept := 0


## `width_at(point, across)` -> [left, right] clear metres (RtsControls.gate_width on the navmesh, GROUP_SCAN_M); `approach`
## the way the body comes in; `clamp(point)` -> point; `today` = the places the caller lays without the column (one per
## block); `path_back()` -> the drive from the click back to the body (navmesh points, click first); `reached(point)` ->
## whether the click reaches the point by ground without a long way round. The ranks stand straight back along the approach
## (the street he clicked) while each rank's point is on the map and `reached`; from the first that is not, back along the
## drive (G1: the column follows the road instead of stacking off the map). One anchor per block in `blocks`' order, or []
## when today's places all stand on clear ground. Pure.
## `passing`: a gate (a waypoint passed through): ranks step by the shape each squad travels in (`travel_depth`), not its halt.
static func column_lay(blocks: Array, click: Vector3, approach: Vector3, width_at: Callable, clamp: Callable,
		today: Array[Vector3] = [], path_back := Callable(), reached := Callable(), passing := false) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if blocks.size() < 2:
		return result
	var flat_click := Vector3(click.x, 0.0, click.z)
	var ahead := Vector3(approach.x, 0.0, approach.z).normalized()
	if ahead == Vector3.ZERO:
		ahead = Vector3.FORWARD
	var across := Vector3(-ahead.z, 0.0, ahead.x)
	var at_click: Array = width_at.call(flat_click, across)
	if today.is_empty():
		if float(at_click[0]) >= GROUP_SCAN_M - 0.01 and float(at_click[1]) >= GROUP_SCAN_M - 0.01:
			return result  # no body given: open = the scan reaches its limit both sides (v1)
	elif on_clear_ground(today, flat_click, ahead, width_at, at_click):
		bodies_kept += 1
		return result  # today's body already stands on the ground he clicked
	var widest := 0.0
	var deepest := 0.0
	for block: Dictionary in blocks:
		widest = maxf(widest, float(block["width"]))
		deepest = maxf(deepest, float(block.get("travel_depth", block.get("depth", 0.0))) if passing else column_depth(block))
	var straight := _back_line(PackedVector3Array(), flat_click, ahead)
	var road := _back_line(path_back.call() if path_back.is_valid() else PackedVector3Array(), flat_click, ahead)
	# Front to back: nearest the click first (farthest along the approach).
	var by_along: Array = []
	for i in blocks.size():
		by_along.append([_arc_of(straight, blocks[i]["center"]), i])
	by_along.sort()
	# A column longer than the ground behind it (off the map even along the road) is laid again with ranks closer, down
	# to half the step; at that the rest stand abreast in the last rank (dev read 4e25c1eab: two squads given one place).
	var step := deepest + GAP_M
	for attempt in COLUMN_SQUEEZES + 1:
		var laid := _lay_ranks(blocks, by_along, flat_click, ahead, straight, road, at_click, width_at, clamp, reached, widest,
				step * (1.0 - 0.5 * attempt / float(COLUMN_SQUEEZES)), attempt == COLUMN_SQUEEZES)
		if not laid.is_empty():
			result = laid
			break
	columns_laid += 1
	return result


## G1: how many times a column too long for the ground behind it is laid again with closer ranks.
const COLUMN_SQUEEZES := 4


## G1: the ranks of a column `step` metres apart, front to back in `by_along`'s order: straight back along the approach
## while reached, then along the road; [] when a rank would stand off the map (unless `last_try`: then the rest stand
## abreast in the last rank inside).
static func _lay_ranks(blocks: Array, by_along: Array, flat_click: Vector3, ahead: Vector3, straight: PackedVector3Array,
		road: PackedVector3Array, at_click: Array, width_at: Callable, clamp: Callable, reached: Callable, widest: float,
		step: float, last_try: bool) -> Array[Vector3]:
	var result: Array[Vector3] = []
	result.resize(blocks.size())
	var behind := 0.0
	var start := 0
	var on_road := false
	var last_inside := [flat_click, ahead]
	while start < by_along.size():
		var at := _walk_back(straight, behind)
		if start > 0 and not on_road:
			var p: Vector3 = at[0]
			on_road = (clamp.call(p) as Vector3).distance_to(p) > 1.0 or (reached.is_valid() and not bool(reached.call(p)))
		if on_road:
			at = _walk_back(road, behind)
			# Never past his click: where the road back first runs forward (round a block), the rank stands further back.
			var skipped := 0.0
			while (at[0] - flat_click).dot(ahead) > 0.0 and skipped < GROUP_SCAN_M * 3.0:
				skipped += RtsControls.GATE_STEP_M
				at = _walk_back(road, behind + skipped)
			behind += skipped
		var out_of_room := (clamp.call(at[0]) as Vector3).distance_to(at[0]) > 1.0
		if out_of_room and not last_try:
			return []
		if out_of_room:
			at = last_inside
		last_inside = at
		var point: Vector3 = at[0]
		var rank_ahead: Vector3 = at[1] if start > 0 else ahead
		var rank_across := Vector3(-rank_ahead.z, 0.0, rank_ahead.x)
		var sides: Array = at_click if start == 0 else _within_click(width_at.call(point, rank_across), at_click)
		var clear := minf(float(sides[0]) + float(sides[1]), MAX_FRONTAGE_M)
		var single := clear < widest
		var abreast := 1 if single else mini(MAX_ABREAST, maxi(1, int(floor((clear + GAP_M) / maxf(widest + GAP_M, 1.0)))))
		abreast = by_along.size() - start if out_of_room else mini(abreast, by_along.size() - start)
		single = single and abreast == 1
		# G1: a rank slides off the column's line only as far as keeps it on the clear ground (v1 centred it in the clear
		# width: 100 m of open bank one side pushed crossing's ranks 44 m aside into the arena's edge, where they piled up).
		var frontage := abreast * widest + (abreast - 1) * GAP_M
		var shift := 0.0 if single else clampf(0.0, -float(sides[0]) + frontage * 0.5, float(sides[1]) - frontage * 0.5)
		var centre := point + rank_across * shift
		var rank_members: Array = []
		for n in range(start, start + abreast):
			var i := int(by_along[n][1])
			var c: Vector3 = blocks[i]["center"]
			rank_members.append([Vector3(c.x - point.x, 0.0, c.z - point.z).dot(rank_across), i])
		rank_members.sort()
		for k in rank_members.size():
			var aside := (float(k) - (abreast - 1) * 0.5) * (widest + GAP_M)
			result[int(rank_members[k][1])] = clamp.call(centre + rank_across * aside)
		start += abreast
		behind += step
	return result


## G1: the column's line, flat, click first: the drive back to the body when it starts at the click, else the approach
## line straight back (one segment of GROUP_SCAN_M x 4; `_walk_back` extends the last segment beyond the end).
static func _back_line(path: PackedVector3Array, flat_click: Vector3, ahead: Vector3) -> PackedVector3Array:
	var line := PackedVector3Array([flat_click])
	if path.size() >= 2 and Vector3(path[0].x, 0.0, path[0].z).distance_to(flat_click) <= 4.0:
		for k in range(1, path.size()):
			var p := Vector3(path[k].x, 0.0, path[k].z)
			if p.distance_to(line[line.size() - 1]) > 0.5:
				line.append(p)
	if line.size() < 2:
		line.append(flat_click - ahead * GROUP_SCAN_M * 4.0)
	return line


## G1: the point `behind` metres back along `line` and the way ahead there (toward the click): [point, ahead].
static func _walk_back(line: PackedVector3Array, behind: float) -> Array:
	var left := behind
	for k in range(1, line.size()):
		var a := line[k - 1]
		var b := line[k]
		var length := a.distance_to(b)
		if left <= length or k == line.size() - 1:
			var back := (b - a).normalized()
			return [a + back * left, -back]
		left -= length
	return [line[0], Vector3.FORWARD]


## G1: how far back along `line` the point nearest `p` lies (the column's order: nearest the click first).
static func _arc_of(line: PackedVector3Array, p: Vector3) -> float:
	var flat := Vector3(p.x, 0.0, p.z)
	var best := INF
	var best_arc := 0.0
	var walked := 0.0
	for k in range(1, line.size()):
		var a := line[k - 1]
		var b := line[k]
		var seg := b - a
		var length := seg.length()
		var t := 0.0 if length < 0.001 else (flat - a).dot(seg) / (length * length)
		t = maxf(t, 0.0) if k == line.size() - 1 else clampf(t, 0.0, 1.0)
		var d := flat.distance_to(a + seg * t)
		if d < best:
			best = d
			best_arc = walked + t * length
		walked += length
	return best_arc


## G1: a rank's clear width kept inside the strip he clicked (the click's own width along the approach line): a rear rank
## on open ground behind a street spread three abreast 130 m wide at his Terminus click, places in other streets again.
static func _within_click(sides: Array, at_click: Array) -> Array:
	return [minf(float(sides[0]), float(at_click[0])), minf(float(sides[1]), float(at_click[1]))]


## G1: `crosses` that also stops at the arena's edge (Orders.clamp_to_arena would move the point): the column's width read
## must not count ground a place would be clamped off.
static func crosses_or_edge(crosses: Callable) -> Callable:
	return func(from: Vector3, to: Vector3) -> bool:
		var flat := Vector3(to.x, 0.0, to.z)
		return Orders.clamp_to_arena(flat).distance_to(flat) > 0.5 or bool(crosses.call(from, to))


## G1: how deep a block stands in a column rank: its formation depth, the AUTO all-round halt, and the halt it is priced
## to deploy in on the ground he clicked (`halt`, O3; a herringbone in a lane runs 30-45 m deep, and v1's ranks stepped by
## the formation depth: crossing 5 click stacked five herringbones ~20 m apart, contacts 432 -> 1416, dev read 942533413).
static func column_depth(block: Dictionary) -> float:
	var deepest := maxf(float(block.get("depth", 0.0)), float(block.get("halt_depth", 0.0)))
	if block.has("halt") and String(block["halt"]) != "":
		var pitch: Vector2 = block.get("pitch_v", Vector2(SPACING_M, SPACING_M))
		deepest = maxf(deepest, halt_footprint(String(block["halt"]), int(block.get("count", 1)), pitch.x).y)
	return deepest


## G1: whether every place in `places` stands inside the clear width read across `ahead` at its own rank (the point on
## the approach line through `click` level with it; behind the click only, a place past the click reads at the click) and
## inside the click's own width (the strip he clicked),
## within PLACE_SLACK_M (the scan's step). `at_click` = width_at's read at the click (reused). Reads are shared between places of one rank.
const PLACE_SLACK_M := 2.0  # the width scan steps 2 m (RtsControls.GATE_STEP_M)
static func on_clear_ground(places: Array[Vector3], click: Vector3, ahead: Vector3, width_at: Callable, at_click: Array) -> bool:
	var across := Vector3(-ahead.z, 0.0, ahead.x)
	var reads := {0: at_click}
	for at: Vector3 in places:
		var offset := Vector3(at.x - click.x, 0.0, at.z - click.z)
		var back := maxi(0, roundi(-offset.dot(ahead)))
		if not reads.has(back):
			reads[back] = _within_click(width_at.call(click - ahead * float(back), across), at_click)
		var sides: Array = reads[back]
		var aside := offset.dot(across)
		if aside < -float(sides[0]) - PLACE_SLACK_M or aside > float(sides[1]) + PLACE_SLACK_M:
			return false
	return true


## Crossing pairs between two squads' vehicle drives (each vehicle straight to its squad's place).
static func _pair_crosses(units_a: Array, at_a: Vector3, units_b: Array, at_b: Vector3, starts: Dictionary) -> int:
	var count := 0
	for a: String in units_a:
		for b: String in units_b:
			if Geometry2D.segment_intersects_segment(_xz(starts[a]), _xz(at_a), _xz(starts[b]), _xz(at_b)) != null:
				count += 1
	return count


## Every ordering of 0..n-1, the identity first (so a tie keeps the order they had).
static func _permutations(n: int) -> Array:
	if n <= 1:
		return [[0]] if n == 1 else [[]]
	var result: Array = []
	for rest: Array in _permutations(n - 1):
		for k in range(rest.size(), -1, -1):
			var perm := rest.duplicate()
			perm.insert(k, n - 1)
			result.append(perm)
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
			var step := maxf(rank_step(size, sizes[r + 1], slot_width, slot_depth, nest, _nest_clearance(blocks)), min_step(blocks))
			behind += halt_clear_step(step, size, sizes[r + 1], slot_width, blocks)
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


## Round 23 (orders O4): the least a rank may step, whatever the nest says: the deepest `halt_depth` among the blocks.
## An AUTO squad travels in a wedge (its nominal shape, which nests 26 m a rank at the gangs' 18 m) but HALTS in the
## shape its leader picks, the gangs' coil: a ring 36 m across, which overlapped the coil of the rank behind by 10 m
## and left one or two crews of fifty blocked outside their ring (measured, Status). The halt shape's depth is the
## floor on the step; a squad in a shape he picked carries none.
## R34.12b (planner's O5 probe: five squads, the back rank anchored on its own start): AUTO squads halt in their
## doctrine's hold shape (O3, block "halt"), deeper than they travel (a herringbone 54.8 m), and pricing a rank at that
## depth stepped the ranks ~69 m. Nesting is by HULL CLEARANCE (his correction 1): the step grows from `step` (the
## travel shape's) RANK_CLEAR_STEP_M at a time only until every halt seat of one rank stands at least HALT_CLEAR_M from
## every halt seat of the next, never past the deepest halt's depth plus GAP_M. Blocks without a "halt": `step`.
const HALT_CLEAR_M := 9.0
const RANK_CLEAR_STEP_M := 2.0


static func halt_clear_step(step: float, front: int, rear: int, slot_width: float, blocks: Array) -> float:
	var shape := ""
	var count := 0
	var pitch := SPACING_M
	var deepest := 0.0
	for block: Dictionary in blocks:
		if not block.has("halt"):
			continue
		var p: Vector2 = block.get("pitch_v", Vector2(SPACING_M, SPACING_M))
		var footprint := halt_footprint(String(block["halt"]), int(block.get("count", 1)), p.x)
		if footprint.y >= deepest:
			deepest = footprint.y
			shape = String(block["halt"])
			count = int(block.get("count", 1))
			pitch = p.x
	if shape == "":
		return step
	var seats := halt_offsets(shape, count, pitch)
	var limit := maxf(step, deepest + GAP_M)
	var at := step
	while at < limit:
		if _ranks_clear(front, rear, slot_width, seats, at):
			return at
		at += RANK_CLEAR_STEP_M
	return limit


## Whether `front` halts abreast and `rear` halts abreast `behind` metres back stand HALT_CLEAR_M clear of each other
## (seats in halt_offsets' frame: x across, y ahead; the body's y here is behind the click).
static func _ranks_clear(front: int, rear: int, slot_width: float, seats: Array[Vector2], behind: float) -> bool:
	for k in front:
		var a := (float(k) - (front - 1) * 0.5) * (slot_width + GAP_M)
		for j in rear:
			var b := (float(j) - (rear - 1) * 0.5) * (slot_width + GAP_M)
			for p in seats:
				for q in seats:
					if Vector2(a + p.x, -p.y).distance_to(Vector2(b + q.x, behind - q.y)) < HALT_CLEAR_M:
						return false
	return true


## A halt's seats in its own frame (x across to the right, y along the heading), memoised: TacticsFormation.place with
## `halt`, each seat led ElementPlan.FACE_LEAD toward its sector, as ElementPlan._group stands them.
static var _offset_memo := {}


static func halt_offsets(shape: String, count: int, spacing := SPACING_M) -> Array[Vector2]:
	var key := "%s:%d:%.2f" % [shape, count, spacing]
	if _offset_memo.has(key):
		return _offset_memo[key]
	var out: Array[Vector2] = []
	if count <= 1:
		out.append(Vector2.ZERO)
	else:
		var members := []
		for i in count:
			members.append({"name": "S%d" % i, "unit": "tank", "role": "tank", "position": Vector3(i, 0.0, 30.0)})
		for entry in TacticsFormation.place(members, shape, Vector3.ZERO, Vector3.FORWARD, spacing, {"halt": true, "corridor_m": INF}):
			var at: Vector3 = (entry["to"] as Vector3) + TacticsFormation.rotate(Vector3.FORWARD, deg_to_rad(float(entry["sector"]))) \
					* ElementPlan.FACE_LEAD
			out.append(Vector2(at.x, -at.z))
	_offset_memo[key] = out
	return out


static func min_step(blocks: Array) -> float:
	var floor_m := 0.0
	for block: Dictionary in blocks:
		floor_m = maxf(floor_m, float(block.get("halt_depth", 0.0)))
	return floor_m


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


## Round 34 (C34.11, O1; his "one of them was all the way across the bridge ... a suicidal mission"): THE GROUND CAP.
## The body's anchors were laid in the air (`ranks`, `row`) and slid off the walls (`fit_inside`); nothing asked the
## ground, so an anchor 70 m sideways stood across a river. An anchor stands only where it is reached from the CLICK
## directly: its drive from the click at most GROUND_CAP_RATIO x its straight offset + GROUND_CAP_SLACK_M, and no bridge
## deck on the way unless the click is on one (on the Crossing the west bridge is in line with the click, so the drive
## across is barely longer than the straight line: the deck is the test that catches his case). One that fails comes
## back toward the click along the straight line, GROUND_CAP_STEP_M at a time (each point clamped by `clamp`, onto dry
## ground), to the first that passes; none passes: the click. Anchors that pass are untouched, so open ground lays out
## exactly as before (no straight-line cap: packing near the click is O2's).
## `drive(from, to) -> float` (metres by ground), `crosses(from, to) -> bool` (a deck on the way), `clamp(p) -> Vector3`.
## `--ground-cap=off` (GROUND_CAP false) is round 33's layout.
const GROUND_CAP_RATIO := 1.5
const GROUND_CAP_SLACK_M := 8.0
const GROUND_CAP_STEP_M := 4.0
static var GROUND_CAP := not OS.get_cmdline_user_args().has("--ground-cap=off")
## How many anchors the cap moved, this process (a probe reads it).
static var ground_capped := 0


static func ground_cap(anchors: Array[Vector3], click: Vector3, drive: Callable, crosses: Callable,
		clamp: Callable) -> Array[Vector3]:
	var flat_click := Vector3(click.x, 0.0, click.z)
	var result: Array[Vector3] = []
	for anchor in anchors:
		if not GROUND_CAP or _reached_from(flat_click, anchor, drive, crosses):
			result.append(anchor)
			continue
		ground_capped += 1
		var back := flat_click - Vector3(anchor.x, 0.0, anchor.z)
		var steps := ceili(back.length() / GROUND_CAP_STEP_M)
		var placed := flat_click
		for k in range(1, steps):
			var p: Vector3 = clamp.call(Vector3(anchor.x, 0.0, anchor.z) + back * (float(k) / steps))
			if _reached_from(flat_click, p, drive, crosses):
				placed = p
				break
		result.append(placed)
	return result


## O1's ground, read on `node`'s navmesh (a vehicle in the match): the drive between two points
## (SlotGround.path_length), and whether that drive runs over a bridge deck (SlotGround.near_deck along the path, the
## test Element's crossing finder uses), unless it starts on one.
static func drive_on(node: Node3D) -> Callable:
	return func(from: Vector3, to: Vector3) -> float: return SlotGround.path_length(node, from, to)


static func crosses_on(node: Node3D) -> Callable:
	return func(from: Vector3, to: Vector3) -> bool:
		if SlotGround.near_deck(from, 0.0):
			return false
		var path := Pathing.find_path(node, from, to)
		if path.size() < 2:
			path = PackedVector3Array([from, to])
		for i in range(1, path.size()):
			var a := Vector3(path[i - 1].x, 0.0, path[i - 1].z)
			var b := Vector3(path[i].x, 0.0, path[i].z)
			var steps := maxi(1, ceili(a.distance_to(b) / 2.0))
			for k in steps + 1:
				if SlotGround.near_deck(a.lerp(b, float(k) / steps), 0.0):
					return true
		return false


## (G1's column calls it too, through `reached_from`.)
static func reached_from(click: Vector3, at: Vector3, drive: Callable, crosses: Callable) -> bool:
	return _reached_from(click, at, drive, crosses)


static func _reached_from(click: Vector3, at: Vector3, drive: Callable, crosses: Callable) -> bool:
	var straight := Vector2(at.x - click.x, at.z - click.z).length()
	if straight < 0.5:
		return true
	return float(drive.call(click, at)) <= straight * GROUND_CAP_RATIO + GROUND_CAP_SLACK_M and not bool(crosses.call(click, at))


## Round 34 (R34.12; planner's O5 probe): A RANK NEVER STANDS BEHIND ITS OWN SQUAD. Five squads, one click: the back rank's
## anchors were laid 71.6 m behind the click, where those squads already stood (the Locks) or 7-15 m behind them (the
## Terminus), so they "arrived" in 0.1 s or drove AWAY from his click. Along the body's heading (`heading`, as `ranks`
## laid it), an anchor farther back than its block's centre comes forward to that centre's line: the squad never drives
## away from the point he clicked. Across the heading it keeps its place. `--rank-forward=off` is round 23's ranks.
static var RANK_FORWARD := not OS.get_cmdline_user_args().has("--rank-forward=off")


## The body's approach: from the middle of the blocks to the click (round 21's `_heading`; a drawn facing when given).
static func approach_of(blocks: Array, click: Vector3, fallback_heading := Vector3.FORWARD, facing: Variant = null) -> Vector3:
	return _heading(blocks, Vector3(click.x, 0.0, click.z), facing, fallback_heading)


## Round 34 (planner's O5, the Terminus 3-squad route): an anchor laid ON an obstacle can never be arrived at (O3's
## narrower body put one inside a block; every seat was pushed 11-19 m off it and the squad never moved on). Each anchor
## `standable(p)` refuses goes to `ground(p, from)`, the nearest standable point reached from where its block stands
## (SlotGround.standable_from). Standable anchors are untouched.
static func ground_anchors(anchors: Array[Vector3], blocks: Array, standable: Callable, ground: Callable) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in anchors.size():
		var at := anchors[i]
		if not bool(standable.call(at)) and i < blocks.size():
			at = ground.call(at, Vector3((blocks[i]["center"] as Vector3).x, 0.0, (blocks[i]["center"] as Vector3).z))
		result.append(at)
	return result


## Round 34 (planner's O5, the Locks route cells): on a route's leg whose squads all come through ONE gate (a street
## mouth onto the Locks' north quay), the places were dealt by least straight driving, so a squad parked at the gate's
## mouth and the one going farther was blocked behind it for 30 s+ (Alpha by Bravo_2). FIRST THROUGH, FARTHEST ALONG:
## the squad that reaches the gate first takes the place farthest past it; the gate-mouth place goes last. `starts[i]`
## is where squad i begins the leg; `paths(from, to) -> PackedVector3Array`; `drive(from, to) -> float`. The gate is the
## last point every squad's path (start -> its place) shares (within GATE_SHARE_M), when they share GATE_MIN_SHARED_M of
## it (so every place lies past it); otherwise the places stand.
## `--gate-order=off` (GATE_ORDER false) is round 33's dealing.
static var GATE_ORDER := not OS.get_cmdline_user_args().has("--gate-order=off")
const GATE_SHARE_M := 10.0
const GATE_MIN_SHARED_M := 10.0


static func gate_of(routes: Array) -> Variant:
	if routes.size() < 2:
		return null
	# The first route sampled every 2 m (a straight leg has no vertex inside the stretch the others share).
	var first := PackedVector3Array()
	var raw: PackedVector3Array = routes[0]
	for i in raw.size():
		if i > 0:
			var steps := maxi(1, ceili(raw[i - 1].distance_to(raw[i]) / 2.0))
			for k in range(1, steps):
				first.append(raw[i - 1].lerp(raw[i], float(k) / steps))
		first.append(raw[i])
	var gate: Variant = null
	var shared := 0.0
	var started: Variant = null
	for i in first.size():
		var p := first[i]
		var everyone := true
		for r in range(1, routes.size()):
			if _distance_to_path(p, routes[r]) > GATE_SHARE_M:
				everyone = false
				break
		if everyone:
			if started == null:
				started = p
			gate = p
			shared = Vector2(p.x - (started as Vector3).x, p.z - (started as Vector3).z).length()
		elif gate != null:
			break
	return gate if gate != null and shared >= GATE_MIN_SHARED_M else null


static func _distance_to_path(p: Vector3, path: PackedVector3Array) -> float:
	var best := INF
	for i in range(1, path.size()):
		var a := Vector2(path[i - 1].x, path[i - 1].z)
		var b := Vector2(path[i].x, path[i].z)
		var q := Vector2(p.x, p.z)
		var ab := b - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		best = minf(best, q.distance_to(a + ab * t))
	if path.size() == 1:
		best = Vector2(p.x - path[0].x, p.z - path[0].z).length()
	return best


static func gate_order(anchors: Array[Vector3], starts: Array, paths: Callable, drive: Callable) -> Array[Vector3]:
	if not GATE_ORDER or anchors.size() < 2 or starts.size() != anchors.size():
		return anchors
	var routes: Array = []
	for i in anchors.size():
		routes.append(paths.call(starts[i], anchors[i]))
	var gate: Variant = gate_of(routes)
	if gate == null:
		return anchors
	var past: Array = []
	for a in anchors:
		past.append(float(drive.call(gate, a)))
	var arrive: Array = []
	for st: Vector3 in starts:
		arrive.append(float(drive.call(st, gate)))
	var by_arrival := range(anchors.size())
	by_arrival.sort_custom(func(a: int, b: int) -> bool: return arrive[a] < arrive[b] if arrive[a] != arrive[b] else a < b)
	var by_far := range(anchors.size())
	by_far.sort_custom(func(a: int, b: int) -> bool: return past[a] > past[b] if past[a] != past[b] else a < b)
	var result: Array[Vector3] = []
	result.resize(anchors.size())
	for k in by_arrival.size():
		result[by_arrival[k]] = anchors[by_far[k]]
	return result


static func never_behind(anchors: Array[Vector3], blocks: Array, click: Vector3, heading: Vector3) -> Array[Vector3]:
	if not RANK_FORWARD:
		return anchors
	var forward := TacticsFormation.flat(heading)
	var flat_click := Vector3(click.x, 0.0, click.z)
	var result: Array[Vector3] = []
	for i in anchors.size():
		var at := anchors[i]
		if i < blocks.size():
			var centre := Vector3((blocks[i]["center"] as Vector3).x, 0.0, (blocks[i]["center"] as Vector3).z)
			var behind := (centre - flat_click).dot(forward) - (Vector3(at.x, 0.0, at.z) - flat_click).dot(forward)
			if behind > 0.0:
				at += forward * behind
		result.append(at)
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


## Round 34 (C34.11, O3): an AUTO squad is priced at the shape it will ARRIVE in, its halt, not a line's frontage. An
## element's arrival lays the doctrine's HOLD pick (ElementPlan._halt: a coil in the open, a herringbone in lanes or
## dense ground for law/standard/condemned, a coil for the gangs, a line for the syndicate; brains' B6 trace), each seat
## led FACE_LEAD toward its sector. Five crews at 14 m: a line 57.2 x 0.7 m, a coil 36.3 x 34.5, a herringbone
## 25.4 x 54.8. Three AUTO squads abreast in the open price 3 x 36.3 + 2 x 14 = 137 m instead of 196.
## `--halt-price=off` (HALT_PRICE false) is round 33's line.
static var HALT_PRICE := not OS.get_cmdline_user_args().has("--halt-price=off")
## The terrain at the click of the order being laid ("" = none set: the open), set by RtsControls._order_squads.
static var halt_terrain := ""
static var _halt_memo := {}


## The shape a squad of `roles` halts in under `table`, on `terrain` (the table's hold pick; threat and composition as
## an element's situation reads them, the hold rules key on terrain only).
static func halt_shape(table: DoctrineTable, terrain: String, roles: Array) -> String:
	var members: Array = []
	for role: String in roles:
		members.append({"role": role})
	var pick := table.select({"task": "hold", "threat": "none", "terrain": terrain if terrain != "" else "open",
			"composition": ElementSituation.composition_of(members)})
	var shape := String(pick.get("formation", "coil"))
	return shape if TacticsFormation.NAMES.has(shape) else "coil"


## The halt shape of a squad of `units` (names in `game_match`): its element's `table` when it has one, else its
## faction's, on the clicked ground (`halt_terrain`).
static func squad_halt_shape(units: Array, table: DoctrineTable, game_match: Match) -> String:
	var roles := []
	var faction := ""
	for unit_name: String in units:
		var unit := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank if game_match != null else null
		if unit != null:
			roles.append(Units.role_of(unit.unit_id))
			faction = String(Units.PROFILES.get(unit.unit_id, {}).get("faction", ""))
	return halt_shape(table if table != null else DoctrineTable.for_faction(faction), halt_terrain, roles)


## [across, deep] of a halt in `shape`: the seats TacticsFormation.place lays with `halt`, each led ElementPlan.FACE_LEAD
## toward its sector, as ElementPlan._group stands them (memoised: pure in its three numbers).
static func halt_footprint(shape: String, count: int, spacing := SPACING_M) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var key := "%s:%d:%.2f" % [shape, count, spacing]
	if _halt_memo.has(key):
		return _halt_memo[key]
	var members := []
	for i in count:
		members.append({"name": "S%d" % i, "unit": "tank", "role": "tank", "position": Vector3(i, 0.0, 30.0)})
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for entry in TacticsFormation.place(members, shape, Vector3.ZERO, Vector3.FORWARD, spacing, {"halt": true, "corridor_m": INF}):
		var at: Vector3 = (entry["to"] as Vector3) + TacticsFormation.rotate(Vector3.FORWARD, deg_to_rad(float(entry["sector"]))) \
				* ElementPlan.FACE_LEAD
		low = Vector2(minf(low.x, at.x), minf(low.y, at.z))
		high = Vector2(maxf(high.x, at.x), maxf(high.y, at.z))
	var size := high - low
	_halt_memo[key] = size
	return size


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


## Round 35 (orders D3, C35.4; round 34's O2 (B), his correction 1: "isn't there enough spacing where we could intersect
## two wedges basically?"). TIGHT PACKING ON THE DEPLOY STEP. With the deploy step on, an AUTO squad's final seats are
## its halt shape (`block["halt"]`, O3's pick) laid on a heading fixed when the order is given (the body's approach), so
## where every crew will finally stand is known now and the squads can be packed by those seats, not by boxes:
##   * the squads' TRAVEL shapes at their anchors (what they arrive in) keep PACK_TRAVEL_CLEAR_M and do not mix;
##   * every halt seat of one squad stands at least HALT_CLEAR_M (9 m) from every halt seat of another (wedges nest),
##     and none inside another squad's halt outline (the convex hull of its seats): a coil is a ring with an empty middle,
##     and by seat clearance alone a second coil stood inside it, the two squads' crews mixed (D3's first controls test);
##     two squads that both halt in a column keep his COLUMN_GAP_M (28 m) between their files;
##   * the squad nearest the click is placed first and takes the place nearest it, and so on outward (first in, front);
##   * each squad keeps its own side of the approach (one standing clearly left of the click's line is never laid right
##     of it, and the other way round), so no two squads' drives cross to reach their places (untangle stays as the backstop);
##   * no anchor farther back along the approach than its own squad stands now (R34.12b: a back rank never drives away);
##   * every seat on ground `seat_ok(p)` accepts (dry, standable: nothing on a building), and the anchor one the click
##     reaches by ground (`reached(p)`, O1's ground cap), tried in order of cost up to PACK_REACH_TRIES.
## The search starts from `start` (the ranks the controls laid, where they fit) and compacts: each squad, farthest
## first, moves to the cheapest place that fits beside the others (cost: the farthest of its seats from the click), up to
## PACK_PASSES passes; so a pack is never wider than the ranks it began from.
## `headings` (out) gets each squad's halt heading: the approach, or the approach turned (PACK_TURNS).
## Places are searched on a PACK_STEP_M grid in the body's frame, PACK_ACROSS_M either side of the click and PACK_BEHIND_M
## behind it (never ahead: the front squad stands on the click). Returns [] (the caller keeps `ranks`) unless every
## block carries a halt shape. PARKED (round 35, D3): OFF by default, `--pack=on` (env PACK=on) opts in. With the travel
## shapes kept apart (PACK_TRAVEL_CLEAR_M) it is no tighter than the ranks (the wedge they arrive in binds, as round 34's
## O2 found); without that, two squads' arrival slots mix (test_control_two_squads). Status *D3* has the record.
static var PACK := OS.get_cmdline_user_args().has("--pack=on") or OS.get_environment("PACK") == "on"
const PACK_STEP_M := 2.0
const PACK_ACROSS_M := 90.0
const PACK_BEHIND_M := 100.0
## A squad whose centre stands more than this across the click's line has a side.
const PACK_SIDE_M := 8.0
const PACK_REACH_TRIES := 24
const PACK_PASSES := 4
## The turns a halt may be laid at, off the approach (degrees, the body's frame): the approach itself first, then across
## it. On the Locks his Law squads halt in a herringbone 55 m deep, which laid along the approach toward the canal did
## not fit the strip between the water and the buildings (the pack put them 48 m back, behind the buildings); laid along
## the bank it does. A turned halt costs PACK_TURN_COST_M more, so the approach wins wherever it fits.
const PACK_TURNS: Array[float] = [0.0, 90.0, -90.0]
const PACK_TURN_COST_M := 6.0
## A seat counts as on good ground when standable ground (a hull's clearance) lies within this of it: Element grounds
## every seat onto the nearest such point anyway, and the strict test (0.5 m) put the Locks squads behind the buildings.
## Water is never good ground (the controls' seat test refuses it outright).
const PACK_GROUND_SLACK_M := 4.0
## The squads arrive in their TRAVEL shapes (a block's nominal `shape`, laid on the approach at its anchor) and deploy
## only once every crew is in, so those must not mix either: no travel seat of one squad within this of another's, nor
## inside its outline (test_control_two_squads' bar: half the gap). Round 34's O2 note: "a fixed order-time heading
## makes the HALT seats exact, but the travel seats before all-in still aren't" -- this is what keeps them apart.
const PACK_TRAVEL_CLEAR_M := 7.0
## How many packs the controls laid, this process (a probe reads it).
static var packed := 0
## O4 (round 36), measurement: in the pack's LAST compaction pass, why each candidate cheaper than a squad's place was
## refused, by the first test that refused it ("halt", "outline", "travel", "travel_outline", "ground", "reach"): what keeps
## the squads from packing nearer the click (a probe reads it).
static var pack_refused := {}


static func _refuse(reason: String) -> bool:
	pack_refused[reason] = int(pack_refused.get(reason, 0)) + 1
	return false


static func pack_halts(blocks: Array, click: Vector3, heading: Vector3, seat_ok: Callable, reached: Callable,
		start: Array[Vector3] = [], headings: Array = []) -> Array[Vector3]:
	var none: Array[Vector3] = []
	headings.clear()
	if not PACK or blocks.size() < 2:
		return none
	for block: Dictionary in blocks:
		if not block.has("halt"):
			return none
	var ahead := TacticsFormation.flat(heading)
	var across := Vector3(-ahead.z, 0.0, ahead.x)
	var flat_click := Vector3(click.x, 0.0, click.z)
	# Each block's halt seats in the body's frame (x across, y ahead) for each turn PACK_TURNS (seats[i][o]), their
	# outlines, and where each block stands now in that frame.
	var seats: Array = []
	var hulls: Array = []
	var travel: Array = []  # each block's TRAVEL shape at its anchor on the approach (its nominal `shape`), and outline
	var travel_hulls: Array = []
	var now: Array[Vector2] = []
	for block: Dictionary in blocks:
		var p: Vector2 = block.get("pitch_v", Vector2(SPACING_M, SPACING_M))
		var moving := PackedVector2Array()
		if block.has("shape"):
			for o: Vector2 in TacticsFormation.offsets_at(String(block["shape"]), int(block.get("count", 1)), p):
				moving.append(Vector2(o.x, -o.y))  # offsets_at's y is behind; this frame's is ahead
		travel.append(moving)
		travel_hulls.append(Geometry2D.convex_hull(moving) if moving.size() >= 3 else PackedVector2Array())
		var offsets := halt_offsets(String(block["halt"]), int(block.get("count", 1)), p.x)
		var by_turn: Array = []
		var outline: Array = []
		for turn: float in PACK_TURNS:
			var turned := PackedVector2Array()
			for o: Vector2 in offsets:
				turned.append(o.rotated(deg_to_rad(turn)))
			by_turn.append(turned)
			outline.append(Geometry2D.convex_hull(turned) if turned.size() >= 3 else PackedVector2Array())
		seats.append(by_turn)
		hulls.append(outline)
		var c := Vector3((block["center"] as Vector3).x, 0.0, (block["center"] as Vector3).z) - flat_click
		now.append(Vector2(c.dot(across), c.dot(ahead)))
	var local := func(p: Vector3) -> Vector2:
		var d := Vector3(p.x, 0.0, p.z) - flat_click
		return Vector2(d.dot(across), d.dot(ahead))
	var world := func(at: Vector2) -> Vector3: return flat_click + across * at.x + ahead * at.y
	# Squads that all halt in one shape lay PLACES (no side, no squad yet), then are dealt to them by the least total
	# driving (`_assign`: straight paths that never cross); mixed shapes keep their side as they are placed.
	var shared := true
	for block: Dictionary in blocks:
		if String(block["halt"]) != String(blocks[0]["halt"]) or int(block.get("count", 1)) != int(blocks[0].get("count", 1)) \
				or block.get("pitch_v", Vector2(SPACING_M, SPACING_M)) != blocks[0].get("pitch_v", Vector2(SPACING_M, SPACING_M)):
			shared = false
	var lowest := 0.0
	for p in now:
		lowest = minf(lowest, p.y)
	var ok_memo := {}
	var seat_good := func(p: Vector3) -> bool:
		var key := Vector2i(roundi(p.x), roundi(p.z))
		if not ok_memo.has(key):
			ok_memo[key] = bool(seat_ok.call(p))
		return ok_memo[key]
	var reach_memo := {}
	var reaches := func(at: Vector2) -> bool:
		var key := Vector2i(roundi(at.x), roundi(at.y))
		if not reach_memo.has(key):
			reach_memo[key] = bool(reached.call(world.call(at)))
		return reach_memo[key]
	# A place is Vector3(x, y, turn index).
	var spread_of := func(i: int, place: Vector3) -> float:
		var at := Vector2(place.x, place.y)
		var far := 0.0
		for o: Vector2 in seats[i][int(place.z)]:
			far = maxf(far, (at + o).length())
		return far
	# Whether squad i fits at `place` beside the others placed (`places`: index -> place): hull clearance, no seat inside
	# another's outline, every seat on good ground.
	var fits := func(i: int, place: Vector3, places: Dictionary) -> bool:
		var at := Vector2(place.x, place.y)
		var mine: PackedVector2Array = seats[i][int(place.z)]
		for j: int in places:
			if j == i:
				continue
			var other: Vector3 = places[j]
			var there := Vector2(other.x, other.y)
			if (at - there).length() > 2.0 * PACK_ACROSS_M:
				continue
			var theirs: PackedVector2Array = seats[j][int(other.z)]
			var gap := COLUMN_GAP_M if String(blocks[i]["halt"]) == "column" and String(blocks[j]["halt"]) == "column" else HALT_CLEAR_M
			for a: Vector2 in mine:
				for b: Vector2 in theirs:
					if (at + a).distance_to(there + b) < gap:
						return _refuse("halt")
			var hj: PackedVector2Array = hulls[j][int(other.z)]
			if hj.size() >= 3:
				for a: Vector2 in mine:
					if Geometry2D.is_point_in_polygon(at + a - there, hj):
						return _refuse("outline")
			var hi: PackedVector2Array = hulls[i][int(place.z)]
			if hi.size() >= 3:
				for b: Vector2 in theirs:
					if Geometry2D.is_point_in_polygon(there + b - at, hi):
						return _refuse("outline")
			# The squads ARRIVE in their travel shapes before they deploy: those must not mix either.
			for a: Vector2 in travel[i]:
				for b: Vector2 in travel[j]:
					if (at + a).distance_to(there + b) < PACK_TRAVEL_CLEAR_M:
						return _refuse("travel")
			var tj: PackedVector2Array = travel_hulls[j]
			if tj.size() >= 3:
				for a: Vector2 in travel[i]:
					if Geometry2D.is_point_in_polygon(at + a - there, tj):
						return _refuse("travel_outline")
			var ti: PackedVector2Array = travel_hulls[i]
			if ti.size() >= 3:
				for b: Vector2 in travel[j]:
					if Geometry2D.is_point_in_polygon(there + b - at, ti):
						return _refuse("travel_outline")
		for a: Vector2 in mine:
			if not bool(seat_good.call(world.call(at + a))):
				return _refuse("ground")
		return true
	var grid: Array[Vector2] = []
	var n_across := int(PACK_ACROSS_M / PACK_STEP_M)
	for gi in range(-n_across, n_across + 1):
		for gj in range(0, int(PACK_BEHIND_M / PACK_STEP_M) + 1):
			grid.append(Vector2(gi * PACK_STEP_M, -gj * PACK_STEP_M))
	# Each squad's candidate places (every grid point at every turn), sorted once and natively by one float key: its
	# spread in dm (a turned halt PACK_TURN_COST_M dearer), then the anchor's own distance in dm, then the place index.
	var sorted_keys := {}
	var candidates := func(i: int) -> PackedFloat64Array:
		if sorted_keys.has(i):
			return sorted_keys[i]
		var side := 0.0 if shared or absf(now[i].x) <= PACK_SIDE_M else signf(now[i].x)
		var back := lowest if shared else minf(now[i].y, 0.0)
		var keys := PackedFloat64Array()
		for o in PACK_TURNS.size():
			for g in grid.size():
				var at := grid[g]
				if side * at.x < 0.0 or at.y < back - 0.01:
					continue
				var cost: float = spread_of.call(i, Vector3(at.x, at.y, o)) + (PACK_TURN_COST_M if o > 0 else 0.0)
				keys.append((roundf(cost * 10.0) * 10000.0 + roundf(at.length() * 10.0)) * 100000.0 + o * grid.size() + g)
		keys.sort()
		sorted_keys[i] = keys
		return keys
	var cost_of := func(i: int, place: Vector3) -> float:
		return float(spread_of.call(i, place)) + (PACK_TURN_COST_M if int(place.z) > 0 else 0.0)
	# The cheapest place for squad i beside `places` costing under `limit`, or null.
	var best_place := func(i: int, places: Dictionary, limit: float) -> Variant:
		var limit_key := roundf(limit * 10.0) * 1e9 if is_finite(limit) else INF
		var tries := 0
		for key in candidates.call(i):
			if key >= limit_key:
				return null
			var index := int(fmod(key, 100000.0))
			var at := grid[index % grid.size()]
			var place := Vector3(at.x, at.y, float(index / grid.size()))
			if not bool(fits.call(i, place, places)):
				continue
			if tries >= PACK_REACH_TRIES:
				return place
			tries += 1
			if bool(reaches.call(at)):
				return place
			_refuse("reach")
		return null
	var order := range(blocks.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return now[a].length() < now[b].length() if now[a].length() != now[b].length() else a < b)
	# Start: the ranks the caller laid (`start`, each kept only where it fits, on the approach), else nothing; every
	# squad without a place is placed nearest first; then COMPACTION passes, each squad (dearest first) moved to the
	# cheapest place that fits beside the others, until nothing moves. Never dearer than the start.
	var places := {}
	if start.size() == blocks.size():
		for i: int in order:
			var at: Vector2 = local.call(start[i])
			if bool(fits.call(i, Vector3(at.x, at.y, 0.0), places)):
				places[i] = Vector3(at.x, at.y, 0.0)
	for i: int in order:
		if not places.has(i):
			var place: Variant = best_place.call(i, places, INF)
			if place == null:
				return none  # no place fits: the caller keeps the ranks
			places[i] = place
	for pass_index in PACK_PASSES:
		pack_refused = {}  # O4 measurement: what the LAST pass refused (what keeps each squad from moving nearer the click)
		var moved := false
		var by_cost := order.duplicate()
		by_cost.sort_custom(func(a: int, b: int) -> bool: return float(cost_of.call(a, places[a])) > float(cost_of.call(b, places[b])))
		for i: int in by_cost:
			var others := places.duplicate()
			others.erase(i)
			var place: Variant = best_place.call(i, others, float(cost_of.call(i, places[i])))
			if place != null:
				places[i] = place
				moved = true
		if not moved:
			break
	var dealt: Array = []
	for i in blocks.size():
		dealt.append(places[i])
	if shared:
		var centers: Array[Vector3] = []
		var spots: Array[Vector3] = []
		for k in blocks.size():
			centers.append(Vector3((blocks[k]["center"] as Vector3).x, 0.0, (blocks[k]["center"] as Vector3).z))
			spots.append(world.call(Vector2((places[k] as Vector3).x, (places[k] as Vector3).y)))
		var given := _assign(centers, spots)
		for k in blocks.size():
			dealt[k] = places[given[k]]
	var anchors: Array[Vector3] = []
	for place: Vector3 in dealt:
		anchors.append(world.call(Vector2(place.x, place.y)))
		var turned := Vector2(0.0, 1.0).rotated(deg_to_rad(PACK_TURNS[int(place.z)]))
		headings.append((across * turned.x + ahead * turned.y).normalized())
	packed += 1
	return anchors


## Round 35 (orders D5, C35.5): A QUEUED LEG IS DEALT BY THE SQUADS' DRIVES. Planner's Locks 5-squad route: squads 3 and 5
## jammed ~55 s at the junction near (5, 65); the final anchors did not cross in a straight line, but their navmesh drives
## off the second waypoint did (`gate_order` found no shared gate; `untangle` reads straight lines and skips queued legs).
## For every pair whose paths (`paths(start, place)`) cross, the two places are swapped when the swap uncrosses that pair
## and the leg's total drive (`drive(start, place)`) grows by no more than UNCROSS_GUARD_RATIO + UNCROSS_GUARD_M (the
## length guard: a swap that sends both squads the long way round is worse than a crossing). Up to UNCROSS_ROUNDS
## sweeps. `starts[i]` is where squad i begins the leg. `--uncross=off` (UNCROSS false) is round 34's dealing.
static var UNCROSS := not OS.get_cmdline_user_args().has("--uncross=off")
const UNCROSS_GUARD_RATIO := 0.25
const UNCROSS_GUARD_M := 10.0
const UNCROSS_ROUNDS := 3
## Two paths crossing within this of either path's END is two squads arriving side by side, not a crossing.
const UNCROSS_END_M := 6.0
## How many swaps this process made (a probe reads it).
static var uncrossed := 0


static func uncross_paths(anchors: Array[Vector3], starts: Array, paths: Callable, drive: Callable) -> Array[Vector3]:
	var dealt: Array[Vector3] = anchors.duplicate()
	if not UNCROSS or anchors.size() < 2 or starts.size() != anchors.size():
		return dealt
	var guard := 0.0
	for i in dealt.size():
		guard += float(drive.call(starts[i], dealt[i]))
	guard = guard * (1.0 + UNCROSS_GUARD_RATIO) + UNCROSS_GUARD_M
	for sweep in UNCROSS_ROUNDS:
		var swapped := false
		for i in dealt.size():
			for j in range(i + 1, dealt.size()):
				if not paths_cross(paths.call(starts[i], dealt[i]), paths.call(starts[j], dealt[j])):
					continue
				if paths_cross(paths.call(starts[i], dealt[j]), paths.call(starts[j], dealt[i])):
					continue
				var total := 0.0
				for k in dealt.size():
					var place := dealt[j] if k == i else (dealt[i] if k == j else dealt[k])
					total += float(drive.call(starts[k], place))
				if total > guard:
					continue
				var keep := dealt[i]
				dealt[i] = dealt[j]
				dealt[j] = keep
				uncrossed += 1
				swapped = true
		if not swapped:
			break
	return dealt


## Whether two drives (polylines on the ground) cross, other than near either one's end (squads arriving side by side).
static func paths_cross(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	if a.size() < 2 or b.size() < 2:
		return false
	var a_end := Vector2(a[a.size() - 1].x, a[a.size() - 1].z)
	var b_end := Vector2(b[b.size() - 1].x, b[b.size() - 1].z)
	var a_start := Vector2(a[0].x, a[0].z)
	var b_start := Vector2(b[0].x, b[0].z)
	for i in range(1, a.size()):
		var p := Vector2(a[i - 1].x, a[i - 1].z)
		var q := Vector2(a[i].x, a[i].z)
		for j in range(1, b.size()):
			var hit: Variant = Geometry2D.segment_intersects_segment(p, q, Vector2(b[j - 1].x, b[j - 1].z), Vector2(b[j].x, b[j].z))
			if hit == null:
				continue
			var at: Vector2 = hit
			if at.distance_to(a_end) < UNCROSS_END_M or at.distance_to(b_end) < UNCROSS_END_M \
					or at.distance_to(a_start) < UNCROSS_END_M or at.distance_to(b_start) < UNCROSS_END_M:
				continue
			return true
	return false


## Round 35 (orders D6, R35.38; planner's Crossing 5 route s3643): a squad's place at a BRIDGE'S MOUTH put seats of its
## shape past the dry deck on the far bank (the water rule keeps seats off the canal, not off the deck's far end); squad 4,
## reaching its place by its whole route (D6) and laid on that heading, sent crews over the bridge he had not clicked
## across. A place is stepped back from every deck, DECK_CLEAR_STEP_M at a time along `back` (the way the squad came),
## until its reach (`reach[i]`: half the squad's widest extent) clears the deck, up to DECK_CLEAR_MAX_M; a click on or
## beside a deck (within DECK_CLEAR_CLICK_M) leaves every place alone: he chose the bridge. `--deck-clear=off` is round 34's.
static var DECK_CLEAR := not OS.get_cmdline_user_args().has("--deck-clear=off")
const DECK_CLEAR_STEP_M := 2.0
const DECK_CLEAR_MAX_M := 40.0
const DECK_CLEAR_CLICK_M := 2.0
## How many places it moved, this process (a probe reads it).
static var deck_cleared := 0


static func deck_clear(anchors: Array[Vector3], reach: Array, click: Vector3, back: Vector3, near_deck: Callable,
		clamp: Callable) -> Array[Vector3]:
	var out: Array[Vector3] = anchors.duplicate()
	if not DECK_CLEAR or bool(near_deck.call(Vector3(click.x, 0.0, click.z), DECK_CLEAR_CLICK_M)):
		return out
	var away := TacticsFormation.flat(back)
	for i in out.size():
		var r := float(reach[i]) if i < reach.size() else 0.0
		if not bool(near_deck.call(out[i], r)):
			continue
		var at := out[i]
		var moved := 0.0
		while moved < DECK_CLEAR_MAX_M and bool(near_deck.call(at, r)):
			at = clamp.call(at + away * DECK_CLEAR_STEP_M)
			moved += DECK_CLEAR_STEP_M
		if not bool(near_deck.call(at, r)):
			out[i] = at
			deck_cleared += 1
	return out
