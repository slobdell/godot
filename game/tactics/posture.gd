class_name Posture
extends RefCounted
## Round 19 (brains B2): whether a side HOLDS what it has or ATTACKS, read from the match's own score. Pure over
## numbers and positions, so the commander's choice has a unit test; the same rule for any side a commander runs (his
## rule, 2026-10-04: *"our friendly players are just as smart"*), and his squads get the same posture as an order (the
## Ambush order with a `from`).
##
##   Posture.decide(team, scores, objectives, contacts, enemy_center) -> {"posture": "hold"|"attack", "zone": {...}, "why"}
##
## HOLD when the side holds at least one objective AND (it is ahead on points, OR an enemy it knows of is within
## THREAT_M of an objective it holds). A side that holds nothing has nothing to defend: it attacks even when ahead (it
## is losing ground and the score will turn). ATTACK otherwise, as before round 19.
##
## The ZONE it holds: the held objective with the nearest known enemy (the threatened one), or before any contact the
## held objective nearest the enemy's centre (the front one). Ties go to the earlier-listed objective (deterministic).
##
## Round 20 (M2), THE OPENING: given `opening` (the side's near ring and whether the map gives an ambush site on the way
## to it), a side that is not behind HOLDS its near ring from the start, taking it first if nobody has it, unless the
## enemy owns it. It comes after a threatened zone and after being ahead, and before attacking.

## An enemy this close to an objective we hold threatens it (m from the zone's centre; parade's zones are 15 m across
## and its floor about 112 m: an enemy halfway across is coming for it).
const THREAT_M := 60.0
## A ring is a side's NEAR ring when it is at least this much nearer that side's spawn than the enemy's (m).
const NEAR_MARGIN_M := 20.0


static func decide(team: int, scores: Array, objectives: Array, contacts: Array, enemy_center: Vector3,
		opening: Dictionary = {}) -> Dictionary:
	var held: Array = []
	for objective: Dictionary in objectives:
		if int(objective.get("owner", -1)) == team:
			held.append(objective)
	var mine := int(scores[team]) if scores.size() == 2 else 0
	var theirs := int(scores[1 - team]) if scores.size() == 2 else 0
	var opened := _opening(team, mine, theirs, objectives, opening)
	if held.is_empty():
		if not opened.is_empty():
			return {"posture": "hold", "zone": opened, "why": "opening: take and hold %s" % String(opened.get("name", "?"))}
		return {"posture": "attack", "zone": {}, "why": "holds no objective"}
	var threatened := {}
	var threat_d := INF
	for objective: Dictionary in held:
		var d := _nearest(contacts, objective["position"])
		if d <= THREAT_M and d < threat_d - 0.001:
			threatened = objective
			threat_d = d
	if not threatened.is_empty():
		return {"posture": "hold", "zone": threatened, "why": "zone threatened (enemy %.0f m from %s)" % [threat_d,
				String(threatened.get("name", "?"))]}
	if mine > theirs:
		var front := {}
		var front_d := INF
		for objective: Dictionary in held:
			var d := _flat(objective["position"]).distance_to(_flat(enemy_center))
			if d < front_d - 0.001:
				front = objective
				front_d = d
		return {"posture": "hold", "zone": front, "why": "ahead on points (%d to %d)" % [mine, theirs]}
	if not opened.is_empty():
		return {"posture": "hold", "zone": opened, "why": "opening: hold %s (%d to %d)" % [String(opened.get("name", "?")),
				mine, theirs]}
	return {"posture": "attack", "zone": {}, "why": "not ahead (%d to %d), zone not threatened" % [mine, theirs]}


## Round 20 (brains M2): THE OPENING. `opening` = {"name": the side's near ring (near_ring), "site": whether the map
## gives an ambush site on the enemy's way to it}. The near ring is held — taken first if nobody has it — while the
## side is not behind on points and the enemy does not own it; otherwise {} and the rest of the rule decides.
static func _opening(team: int, mine: int, theirs: int, objectives: Array, opening: Dictionary) -> Dictionary:
	if String(opening.get("name", "")) == "" or not bool(opening.get("site", false)) or mine < theirs:
		return {}
	for objective: Dictionary in objectives:
		if String(objective.get("name", "")) == String(opening["name"]):
			return objective if int(objective.get("owner", -1)) != 1 - team else {}
	return {}


## The ring a side reaches first: the objective nearest `own_spawn` among those nearer to it than to `enemy_spawn` by
## NEAR_MARGIN_M; "" when there is none (a centre ring is equally far from both). Pure.
static func near_ring(objectives: Array, own_spawn: Vector3, enemy_spawn: Vector3) -> String:
	var best := ""
	var best_d := INF
	for objective: Dictionary in objectives:
		var at := _flat(objective["position"])
		var ours := at.distance_to(_flat(own_spawn))
		if ours + NEAR_MARGIN_M <= at.distance_to(_flat(enemy_spawn)) and ours < best_d - 0.001:
			best = String(objective.get("name", ""))
			best_d = ours
	return best


static func _nearest(contacts: Array, point: Vector3) -> float:
	var nearest := INF
	for contact: Dictionary in contacts:
		nearest = minf(nearest, _flat(contact["position"]).distance_to(_flat(point)))
	return nearest


static func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)
