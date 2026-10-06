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
##  "loose": Array[String]} for the living `units`. Squads come out in the order found (elements first, then groups
## by size); `row` decides who stands where.
##
## 1. An element whose living members are all selected (and which is no bigger than a squad) is a squad.
## 2. Else the SMALLEST control group whose living members are all selected (lowest number on a tie): a group dealt
##    one squad each (1, 2) beats a group the player saved over both (Ctrl+3), so the squads come back out of it.
## 3. A whole group bigger than a squad that holds no smaller one is dealt into squads of at most MAX_MEMBERS,
##    west to east, sharing the group's number (so they share its formation too).
## 4. Everything else is loose: units in no squad of the selection (part of a squad, or in no group at all).
static func split(units: Array, groups: ControlGroups, elements: Elements, alive: Callable, position: Callable) -> Dictionary:
	var living: Array[String] = []
	for unit_name: Variant in units:
		if bool(alive.call(String(unit_name))) and not living.has(String(unit_name)):
			living.append(String(unit_name))
	var squads: Array = []
	var taken := {}
	if elements != null:
		for unit_name in living:
			if taken.has(unit_name):
				continue
			var element := elements.of(unit_name)
			if element == null:
				continue
			var members: Array[String] = []
			for member in element.members():
				if bool(alive.call(String(member))):
					members.append(String(member))
			if members.is_empty() or members.size() > Formations.MAX_MEMBERS \
					or not members.all(func(n: String) -> bool: return living.has(n) and not taken.has(n)):
				continue
			for member in members:
				taken[member] = true
			squads.append({"number": _group_exactly(groups, members, alive), "units": members, "element": element})
	if groups != null:
		var whole: Array = []  # [size, number, living members] of every group wholly inside what is left
		for number in groups.numbers():
			var members := _living(groups.members(number), alive)
			if not members.is_empty() and members.all(func(n: String) -> bool: return living.has(n) and not taken.has(n)):
				whole.append([members.size(), number, members])
		whole.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		for entry: Array in whole:
			var members: Array[String] = entry[2]
			if members.any(func(n: String) -> bool: return taken.has(n)):
				continue
			for member in members:
				taken[member] = true
			if members.size() <= Formations.MAX_MEMBERS:
				squads.append({"number": int(entry[1]), "units": members, "element": null})
				continue
			for piece in deal(members, position):
				squads.append({"number": int(entry[1]), "units": piece, "element": null})
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
	var heading := Vector3.ZERO
	if facing is Vector3 and (facing as Vector3).length() > 1e-6:
		heading = TacticsFormation.flat(facing)
	elif (flat_click - middle).length() > 2.0:
		heading = TacticsFormation.flat(flat_click - middle)
	else:
		heading = TacticsFormation.flat(fallback_heading)
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


## How wide a squad stands across its heading in `shape` (metres between its outermost hulls' centres).
static func width(shape: String, count: int, spacing := SPACING_M) -> float:
	if count <= 1:
		return 0.0
	if not TacticsFormation.NAMES.has(shape):
		shape = TacticsFormation.auto(count, "move")
	return TacticsFormation.frontage(shape, count, spacing)


static func _living(names: Array[String], alive: Callable) -> Array[String]:
	var result: Array[String] = []
	for unit_name in names:
		if bool(alive.call(unit_name)):
			result.append(unit_name)
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
