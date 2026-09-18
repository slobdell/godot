class_name GroupFormation
extends RefCounted
## Automatic formation slots for a group of units ordered together (control X1, refined in X5). Since round 6 (N2)
## this is an ADAPTER: the shapes, the seating (who stands where) and the pacing all live in TacticsFormation, the
## one formation system; this file only turns Tanks into the member data it takes. A slot is Vector2(right, back)
## meters in the group's frame, centered on the group's destination, so a click is where the group's middle ends up.

## Meters between neighbors in the automatic rows.
const SPACING := 10.0
## Front to back: who leads a group (TacticsFormation's table; the selection panel sorts by it).
const ROLE_RANK := TacticsFormation.ROLE_RANK
## Units at least this fast (m/s) count as fast: a group of only fast units charging spreads into a wide wedge.
const FAST_MPS := 12.0
## A fast charge spaces its wedge this much wider.
const CHARGE_SPREAD := 1.4


## The formation a group uses for `verb` when the player asked for `requested` ("auto" or a shape name):
## TacticsFormation.auto — a line when holding, a wedge up to a platoon, rows beyond; "single" for one unit.
static func choose(tanks: Array[Tank], requested: String, verb: String) -> String:
	return TacticsFormation.auto(tanks.size(), verb, requested)


## True when every unit is fast (a charge by these spreads wide).
static func all_fast(tanks: Array[Tank]) -> bool:
	for tank in tanks:
		if tank.max_forward_speed < FAST_MPS:
			return false
	return not tanks.is_empty()


## {unit name: Vector2 slot} for `tanks` in `formation` (a choose() result) moving along `heading` to `anchor`.
## Heavies take the front ranks; within that, every unit takes the slot that keeps paths from crossing
## (TacticsFormation.seat).
static func slots(tanks: Array[Tank], formation: String, heading: Vector3, anchor: Vector3, verb := "move") -> Dictionary:
	if tanks.size() == 1:
		return {String(tanks[0].name): Vector2.ZERO}
	var spacing := SPACING * (CHARGE_SPREAD if verb == "attack_move" and all_fast(tanks) else 1.0)
	var result := {}
	for entry in TacticsFormation.place(members_of(tanks), formation, anchor, heading, spacing, {"policy": "front"}):
		result[String(entry["unit"])] = entry["offset"]
	return result


## Behind a followed unit: rows starting one spacing back.
static func follow_slots(tanks: Array[Tank]) -> Dictionary:
	var result := {}
	var offsets := TacticsFormation.rows(tanks.size(), 0, SPACING)
	var seats := TacticsFormation.seat(members_of(tanks, false), offsets)
	for unit_name: String in seats:
		result[unit_name] = offsets[int(seats[unit_name])] + Vector2(0.0, SPACING)
	return result


## Arrive together (TacticsFormation.pace).
static func pace(remaining: float, top_speed: float, group_eta: float) -> float:
	return TacticsFormation.pace(remaining, top_speed, group_eta)


## TacticsFormation's member data for `tanks`: name, unit, role, and (unless `with_position` is false) where each is.
static func members_of(tanks: Array[Tank], with_position := true) -> Array:
	var members: Array = []
	for tank in tanks:
		var member := {"name": String(tank.name), "unit": tank.unit_id, "role": Units.role_of(tank.unit_id)}
		if with_position:
			member["position"] = Vector3(tank.global_position.x, 0.0, tank.global_position.z)
		members.append(member)
	return members
