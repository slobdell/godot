class_name ArmyPlan
extends RefCounted
## X8: the army layer (_agents/doctrine.md "Proposal for round 6: an army-level decision above the elements"). The
## decision a company commander makes before any drill runs: WHICH elements take the objective, which shape the fight
## around it, and which stay back. Without it every line element of a 30-a-side army attacks the nearest contact, so the
## whole army converges on one point and the flanking lanes go unused (arena: 4-5% of unit-time).
##
## Pure and deterministic, like ElementPlan: dictionaries in, roles and element tasks out. ElementCommander runs it when
## the table asks (`traits.commander == "army"`, the ladder's `+army`), so it is a bet measured against brains-only and
## the direct commander, adopted only if it wins.
##
## Roles, given once and kept (a role that changes every think is the thrash X6 measured):
##   main     the strongest line element(s): take the objective, attack what holds it
##   base     support elements (long reach): support by fire onto the main effort's objective, not the nearest contact
##   shaping  recon first, then the lightest line elements, one per flank lane: drive the lane to level with the objective,
##            then wait there until the enemy at the objective is pinned (or there is no base of fire), then attack
##   reserve  whatever is left: trail the main effort, committed once it has been in contact COMMIT_S or is worn down
##
## plan(elements, contacts, context, state) ->
##   {"roles": {id: role}, "tasks": {id: task}, "engaged_since": tick or -1}
## elements: [{"id": int, "class": "line"|"recon"|"support", "center": Vector3, "strength": float (0-1 of full)}]
## contacts: [{"name", "position": Vector3, "pinned": bool}]
## context:  {"objective": Vector3, "hold_ground": bool (a real objective to take, vs the enemy's ground), "home": Vector3,
##            "lanes": [lateral offset m, outermost first], "tick": int}
## state:    what the last plan returned ({} the first time)

## Line elements that are the main effort: this share of them, at least one.
const MAIN_SHARE := 0.34
## Shaping elements at most (one per side).
const MAX_SHAPING := 2
## An element attacks a contact this close to it (or to the objective) rather than driving past it.
const ENGAGE_M := 110.0
## The reserve trails the main effort by this much, and is committed after it has been in contact this long, or once
## the main effort is below this strength.
const RESERVE_BEHIND_M := 40.0
const COMMIT_S := 20.0
const COMMIT_STRENGTH := 0.5
## Shaping: a lane point counts as reached within this, and "the enemy at the objective" is within this of it.
const LANE_REACHED_M := 20.0
const AT_OBJECTIVE_M := 45.0
## With no annotated lanes, shaping swings this far off the axis.
const FLANK_M := 45.0


static func plan(elements: Array, contacts: Array, context: Dictionary, state: Dictionary) -> Dictionary:
	var roles := _roles(elements, state.get("roles", {}))
	var by_id := {}
	for element: Dictionary in elements:
		by_id[int(element["id"])] = element
	var objective: Vector3 = context["objective"]
	var home: Vector3 = context.get("home", Vector3.ZERO)
	var tick := int(context.get("tick", 0))
	var main_ids := _ids_with(roles, elements, "main")
	var main_center := _centroid(main_ids, by_id, home)
	var axis := TacticsFormation.flat(objective - home)
	# The point the army fights for: the objective itself when there is ground to take, else the enemy's mass.
	var point := objective
	if not bool(context.get("hold_ground", false)) and not contacts.is_empty():
		point = _centroid_of_contacts(contacts)
	var at_point := _nearest(contacts, point)
	var enemy_pinned := false
	for contact: Dictionary in contacts:
		if bool(contact.get("pinned", false)) and (contact["position"] as Vector3).distance_to(point) <= AT_OBJECTIVE_M:
			enemy_pinned = true
	# The main effort's fight: when it began (for the reserve's commitment).
	var main_target := {}
	var near_main := _nearest(contacts, main_center)
	if not near_main.is_empty() and (near_main["position"] as Vector3).distance_to(main_center) <= ENGAGE_M:
		main_target = near_main
	elif not at_point.is_empty() and (at_point["position"] as Vector3).distance_to(point) <= AT_OBJECTIVE_M:
		main_target = at_point
	var engaged_since := int(state.get("engaged_since", -1))
	if main_target.is_empty():
		engaged_since = -1
	elif engaged_since < 0:
		engaged_since = tick
	var main_strength := 1.0
	for id: int in main_ids:
		main_strength = minf(main_strength, float(by_id[id].get("strength", 1.0)))
	var tasks := {}
	var has_base := not _ids_with(roles, elements, "base").is_empty()
	var shaping_index := 0
	var ids: Array = by_id.keys()
	ids.sort()
	for id: int in ids:
		var element: Dictionary = by_id[id]
		var center: Vector3 = element["center"]
		match String(roles[id]):
			"main":
				tasks[id] = _attack(main_target) if not main_target.is_empty() else {"verb": "move", "to": _xz(point)}
			"base":
				var aim := at_point if not at_point.is_empty() else main_target
				if aim.is_empty():
					tasks[id] = {"verb": "move", "to": _xz(ElementPlan.clamp_to_arena(main_center - axis * RESERVE_BEHIND_M))}
				else:
					tasks[id] = {"verb": "support_by_fire", "to": _xz(aim["position"]), "target": String(aim["name"])}
			"shaping":
				tasks[id] = _shape(center, shaping_index, point, axis, context.get("lanes", []), contacts,
						enemy_pinned or not has_base)
				shaping_index += 1
			_:
				var commit := main_ids.is_empty() or main_strength < COMMIT_STRENGTH \
						or (engaged_since >= 0 and tick - engaged_since >= int(COMMIT_S * SimClock.TICK_RATE))
				if commit:
					var fight := main_target if not main_target.is_empty() else _nearest(contacts, center)
					tasks[id] = _attack(fight) if not fight.is_empty() and (fight["position"] as Vector3).distance_to(center) <= ENGAGE_M * 1.5 \
							else {"verb": "move", "to": _xz(point)}
				else:
					tasks[id] = {"verb": "move", "to": _xz(ElementPlan.clamp_to_arena(main_center - axis * RESERVE_BEHIND_M)),
							"drills": false}
	return {"roles": roles, "tasks": tasks, "engaged_since": engaged_since}


## Roles for every element: last plan's kept where the element still exists; new elements (and a main effort that has
## been wiped out) filled by the rules in the header. Deterministic: strongest first, then lowest id.
static func _roles(elements: Array, previous: Dictionary) -> Dictionary:
	var roles := {}
	var unassigned: Array = []
	for element: Dictionary in elements:
		var id := int(element["id"])
		if previous.has(id):
			roles[id] = previous[id]
		else:
			unassigned.append(element)
	var line: Array = []
	for element: Dictionary in unassigned:
		match String(element.get("class", "line")):
			"support":
				roles[int(element["id"])] = "base"
			"recon":
				roles[int(element["id"])] = "shaping"
			_:
				line.append(element)
	line.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := float(a.get("strength", 1.0)) * float(a.get("size", 1))
		var sb := float(b.get("strength", 1.0)) * float(b.get("size", 1))
		return sa > sb or (sa == sb and int(a["id"]) < int(b["id"])))
	var line_total := line.size()
	for id in roles:
		if String(roles[id]) == "main" or (String(roles[id]) in ["shaping", "reserve"] and _is_line(elements, id)):
			line_total += 1
	var main_wanted := maxi(1, ceili(line_total * MAIN_SHARE))
	# Every lane offset is a lane on each side, and with no lanes the shapers swing FLANK_M off the axis: two either way.
	var shaping_wanted := MAX_SHAPING if line_total >= 3 else 0
	var mains := _count(roles, "main")
	var shapers := _count(roles, "shaping")
	# A main effort that is gone is replaced from the reserve first (the reserve exists for this).
	if mains == 0:
		var promoted := _first_with(roles, elements, "reserve")
		if promoted >= 0:
			roles[promoted] = "main"
			mains += 1
	for element: Dictionary in line:
		var id := int(element["id"])
		if mains < main_wanted:
			roles[id] = "main"
			mains += 1
		elif shapers < shaping_wanted:
			roles[id] = "shaping"
			shapers += 1
		else:
			roles[id] = "reserve"
	return roles


## A shaping element's task: drive its flank lane to level with the point, then attack once `go` (the enemy there is
## pinned, or there is no base of fire to pin it); until then hold the lane point.
static func _shape(center: Vector3, index: int, point: Vector3, axis: Vector3, lanes: Array, contacts: Array,
		go: bool) -> Dictionary:
	var side := 1.0 if index % 2 == 0 else -1.0
	var across := Vector3(-axis.z, 0.0, axis.x)
	var wide: Vector3
	if not lanes.is_empty():
		# Lanes are lateral offsets from the centre line (x): the lane's point level with the objective.
		wide = Vector3(float(lanes[(index / 2) % lanes.size()]) * side, 0.0, point.z)
	else:
		wide = point + across * FLANK_M * side
	wide = ElementPlan.clamp_to_arena(wide)
	if center.distance_to(wide) > LANE_REACHED_M:
		# On its way round: crews shoot what they pass, the leader does not turn the element into the first fight it
		# meets (a far ambush there is the whole army converging again).
		return {"verb": "move", "to": _xz(wide), "drills": false}
	var target := _nearest(contacts, center)
	if go and not target.is_empty():
		return _attack(target)
	if go:
		return {"verb": "move", "to": _xz(point)}
	return {"verb": "hold", "to": _xz(wide), "facing": _xz(TacticsFormation.flat(point - wide))}


static func _attack(contact: Dictionary) -> Dictionary:
	return {"verb": "attack", "target": String(contact["name"])}


static func _nearest(contacts: Array, from: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	for contact: Dictionary in contacts:
		var d := (contact["position"] as Vector3).distance_to(from)
		if d < best_d - 0.001 or (absf(d - best_d) <= 0.001 and String(contact["name"]) < String(best.get("name", ""))):
			best = contact
			best_d = d
	return best


static func _centroid_of_contacts(contacts: Array) -> Vector3:
	var sum := Vector3.ZERO
	for contact: Dictionary in contacts:
		sum += contact["position"]
	return Vector3(sum.x, 0.0, sum.z) / float(contacts.size())


static func _centroid(ids: Array, by_id: Dictionary, fallback: Vector3) -> Vector3:
	if ids.is_empty():
		return fallback
	var sum := Vector3.ZERO
	for id: int in ids:
		sum += by_id[id]["center"]
	return sum / float(ids.size())


static func _ids_with(roles: Dictionary, elements: Array, role: String) -> Array:
	var ids: Array = []
	for element: Dictionary in elements:
		if String(roles.get(int(element["id"]), "")) == role:
			ids.append(int(element["id"]))
	ids.sort()
	return ids


static func _first_with(roles: Dictionary, elements: Array, role: String) -> int:
	var ids := _ids_with(roles, elements, role)
	return ids[0] if not ids.is_empty() else -1


static func _count(roles: Dictionary, role: String) -> int:
	var count := 0
	for id in roles:
		if String(roles[id]) == role:
			count += 1
	return count


static func _is_line(elements: Array, id: int) -> bool:
	for element: Dictionary in elements:
		if int(element["id"]) == id:
			return String(element.get("class", "line")) == "line"
	return false


static func _xz(point: Vector3) -> Array:
	return [point.x, point.z]
