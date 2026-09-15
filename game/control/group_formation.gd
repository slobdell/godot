class_name GroupFormation
extends RefCounted
## Automatic formation slots for a group of units ordered together (control X1, refined in X5). Pure geometry.
## A slot is Vector2(right, back) meters in the group's frame (Formations' convention), centered on the group's
## destination, so a click is where the group's middle ends up.

## Meters between neighbors in the automatic rows.
const SPACING := 10.0
## Most units abreast in one automatic row.
const ROW_WIDTH := 5
## Front to back: who leads a group. Heavies in front, fragile and indirect-fire units behind.
const ROLE_RANK := {"tank": 0, "burner": 1, "ifv": 1, "scout": 2, "lancer": 3, "artillery": 4}


## {unit name: Vector2 slot} for `tanks` moving along `heading` to `anchor`.
static func slots(tanks: Array[Tank], formation: String, heading: Vector3, anchor: Vector3) -> Dictionary:
	if tanks.size() == 1:
		return {String(tanks[0].name): Vector2.ZERO}
	var ordered := _front_to_back(tanks)
	var offsets: Array[Vector2] = []
	if formation != UnitCommand.AUTO and Formations.NAMES.has(formation) and tanks.size() <= Formations.MAX_MEMBERS:
		offsets = Formations.offsets(formation, tanks.size(), SPACING)
	else:
		offsets = rows(tanks.size())
	offsets = _centered(offsets)
	return _assign(ordered, offsets, heading, anchor)


## Behind a followed unit: rows starting one spacing back.
static func follow_slots(tanks: Array[Tank]) -> Dictionary:
	var result := {}
	var offsets := rows(tanks.size())
	var ordered := _front_to_back(tanks)
	for i in ordered.size():
		result[String(ordered[i].name)] = offsets[i] + Vector2(0.0, SPACING)
	return result


## Rows abreast, front row first, each row centered on the line of travel.
static func rows(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var width := mini(ROW_WIDTH, count) if count <= ROW_WIDTH * 2 else ceili(sqrt(count * 2.0))
	for i in count:
		var row := i / width
		var in_row := mini(width, count - row * width)
		var column := i - row * width
		result.append(Vector2((column - (in_row - 1) * 0.5) * SPACING, row * SPACING))
	return result


## Units sorted heavy-first (then by name, for determinism).
static func _front_to_back(tanks: Array[Tank]) -> Array[Tank]:
	var ordered := tanks.duplicate()
	ordered.sort_custom(func(a: Tank, b: Tank) -> bool:
		var rank_a: int = ROLE_RANK.get(Units.role_of(a.unit_id), 2)
		var rank_b: int = ROLE_RANK.get(Units.role_of(b.unit_id), 2)
		return rank_a < rank_b if rank_a != rank_b else String(a.name) < String(b.name))
	return ordered


static func _centered(offsets: Array[Vector2]) -> Array[Vector2]:
	var middle := Vector2.ZERO
	for offset in offsets:
		middle += offset
	middle /= maxf(offsets.size(), 1.0)
	var result: Array[Vector2] = []
	for offset in offsets:
		result.append(offset - middle)
	return result


## Front slots to front units (the offsets' order is front to back); within a rank, the unit farthest to the
## right takes the rightmost slot, so paths don't cross.
static func _assign(ordered: Array[Tank], offsets: Array[Vector2], heading: Vector3, anchor: Vector3) -> Dictionary:
	var result := {}
	var right := Vector3(-heading.z, 0.0, heading.x)
	var slot_indices: Array = range(offsets.size())
	slot_indices.sort_custom(func(a: int, b: int) -> bool:
		return offsets[a].y < offsets[b].y - 0.01 or (absf(offsets[a].y - offsets[b].y) <= 0.01 and a < b))
	var i := 0
	while i < ordered.size():
		# One rank = the slots sharing a "back" distance.
		var rank_back: float = offsets[slot_indices[i]].y
		var j := i
		while j < ordered.size() and absf(offsets[slot_indices[j]].y - rank_back) <= 0.01:
			j += 1
		var rank_units := ordered.slice(i, j)
		var rank_slots := slot_indices.slice(i, j)
		rank_units.sort_custom(func(a: Tank, b: Tank) -> bool:
			return (a.global_position - anchor).dot(right) < (b.global_position - anchor).dot(right))
		rank_slots.sort_custom(func(a: int, b: int) -> bool: return offsets[a].x < offsets[b].x)
		for k in rank_units.size():
			result[String(rank_units[k].name)] = offsets[rank_slots[k]]
		i = j
	return result
