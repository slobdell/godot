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
##
## Round 38 (doctrine D2), DEFEND: given `near` (the side's near ring objective; {} when the switch is off), a side whose
## near ring is not the enemy's and has a known enemy within DEFEND_M of it HOLDS that ring, whatever the score and
## whether or not it has taken the ring yet. D1 (the guard lines, builder0): 75 % of the CPU's damage against a blob was
## fired in ATTACK posture from its own half because it "holds no objective" yet: the blob reached the near ring first
## and the CPU met it as an attacker, firing on the move. A threatened zone it already holds comes first. D2b: only an
## enemy COMING for the ring counts (nearer it than to any zone its side owns; `_coming`), not one sitting at home.

## An enemy this close to an objective we hold threatens it (m from the zone's centre; parade's zones are 15 m across
## and its floor about 112 m: an enemy halfway across is coming for it).
const THREAT_M := 60.0
## Round 38 (D2): an enemy this close to our near ring makes us DEFEND it (m). Wider than THREAT_M so the posts are
## taken before the guns reach them (the lab at 60 m: crews drove onto posts 15 m+ away under fire, 87 % moving).
const DEFEND_M := 100.0
## A ring is a side's NEAR ring when it is at least this much nearer that side's spawn than the enemy's (m).
const NEAR_MARGIN_M := 20.0


static func decide(team: int, scores: Array, objectives: Array, contacts: Array, enemy_center: Vector3,
		opening: Dictionary = {}, near: Dictionary = {}) -> Dictionary:
	var held: Array = []
	for objective: Dictionary in objectives:
		if int(objective.get("owner", -1)) == team:
			held.append(objective)
	var mine := int(scores[team]) if scores.size() == 2 else 0
	var theirs := int(scores[1 - team]) if scores.size() == 2 else 0
	var opened := _opening(team, mine, theirs, objectives, opening)
	var defended := _defend(team, objectives, contacts, near)
	if held.is_empty() and not defended.is_empty():
		return defended
	if held.is_empty():
		if not opened.is_empty():
			return {"posture": "hold", "zone": opened, "why": "opening: take and hold %s" % String(opened.get("name", "?"))}
		return {"posture": "attack", "zone": {}, "why": "holds no objective"}
	var threatened := {}
	var threat_d := INF
	for objective: Dictionary in held:
		# D2b, with DEFEND on only: a held zone is threatened by an enemy coming for it, not one at home 60 m off (the lab:
		# with defend's trigger fixed, "zone threatened" by a turtle sitting on its own zone still held the CPU 66 % of its fire).
		var d := _nearest(contacts if near.is_empty() else _coming(contacts, objective, objectives, team), objective["position"])
		if d <= THREAT_M and d < threat_d - 0.001:
			threatened = objective
			threat_d = d
	if not threatened.is_empty():
		return {"posture": "hold", "zone": threatened, "why": "zone threatened (enemy %.0f m from %s)" % [threat_d,
				String(threatened.get("name", "?"))]}
	if not defended.is_empty():
		return defended
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


## Round 38 (D2): the hold decision for `near` (re-read from `objectives` by name, so its owner is today's) when it is
## not the enemy's and a known enemy is within DEFEND_M of it; {} otherwise, or when `near` is {} (the switch off). Pure.
static func _defend(team: int, objectives: Array, contacts: Array, near: Dictionary) -> Dictionary:
	if near.is_empty():
		return {}
	var zone := near
	for objective: Dictionary in objectives:
		if String(objective.get("name", "")) == String(near.get("name", "")):
			zone = objective
	if int(zone.get("owner", -1)) == 1 - team:
		return {}
	var d := _nearest(_coming(contacts, zone, objectives, team), zone["position"])
	if d > DEFEND_M:
		return {}
	return {"posture": "hold", "zone": zone, "why": "defend: enemy %.0f m from %s" % [d, String(zone.get("name", "?"))]}


## D2b: the contacts that are coming for `zone`: each nearer it than to every objective its own side owns. An enemy sitting
## on its own zone (the turtle line's guard, within DEFEND_M of our ring on the small maps) is home, not coming: D2 counted
## it, and the CPU stopped attacking a turtle (acbdef4c5, builder2, 160 turtle fights: kills a fight 32.4 -> 26.2, -3.8 se).
static func _coming(contacts: Array, zone: Dictionary, objectives: Array, team: int) -> Array:
	var theirs: Array = objectives.filter(func(o: Dictionary) -> bool: return int(o.get("owner", -1)) == 1 - team)
	return contacts.filter(func(contact: Dictionary) -> bool:
		var to_zone := _flat(contact["position"]).distance_to(_flat(zone["position"]))
		for objective: Dictionary in theirs:
			if _flat(contact["position"]).distance_to(_flat(objective["position"])) <= to_zone:
				return false
		return true)


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
