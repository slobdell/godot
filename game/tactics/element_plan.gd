class_name ElementPlan
extends RefCounted
## The leader's decision, as a pure function (doctrine X1/X3): given what the element knows
## (ElementSituation), what it was doing (its state) and its doctrine (DoctrineTable), work out the
## formation, the movement technique, the battle drill and ONE order per unit. No engine access, no clock,
## no randomness: the same inputs always produce the same plan, which is what makes drills testable and the
## simulation deterministic.
##
##   ElementPlan.build(situation, state, table) ->
##     {"formation", "technique", "drill", "why", "anchor", "heading", "bounding", "arrived",
##      "orders": {unit: {"verb", "to": Vector3 | null, "target": String}},
##      "slots": {unit: Vector3}, "sectors": {unit: degrees}}
##
## Orders use control's K1 verbs (move, attack_move, attack, hold), so the brains keep obeying exactly one
## thing and all their micro — cover, peeking, strafing, weak spots — still applies inside the order.
## Movement is by LEGS, not by a destination that slides every tick: the anchor (the element's centre of
## formation) jumps forward one leg at a time and only when the element has closed up on the last one. That
## is the doctrinal "close up before the next bound", and it keeps a brain's commitment from being reset
## every second (round-3 lesson: re-issuing an order throws away what the brain was doing).

## Front to back: who leads an element. Armour in front, fragile and indirect-fire vehicles behind.
const ROLE_RANK := {"tank": 0, "burner": 1, "ifv": 2, "scout": 3, "lancer": 4, "artillery": 5}
## How much being at the FRONT of the shape counts toward a slot's exposure, next to being on its edge.
## Both matter: the point of a wedge and the outside of a line are where the fire comes from.
const FRONT_EXPOSURE := 1.5
## Hull points are worth this much armour thickness when ranking what a vehicle can take.
const HULL_PER_ARMOUR := 25.0
## Indirect fire and lasers go in the middle whatever their armour says. Artillery is better protected than a
## scout on paper, but it is the thing the element exists to protect, and a gun that is being shot at is not
## shooting (game_design.md: "protecting fragile units (artillery, Lancers)").
const PROTECTED_ROLES := ["artillery", "lancer"]
const PROTECTED_PENALTY := 100.0
## The element counts as arrived within this far of its task destination (meters)...
const ARRIVE_M := 12.0
## ...and as having reached its current leg's anchor within this far.
const LEG_ARRIVE := 14.0
## A halt formation's crews drive this far out along their sector so they end up facing it (meters).
## K1 orders carry no facing, so a vehicle's heading comes from the way it travelled (see _agents/doctrine.md).
const FACE_LEAD := 5.0
## A unit this far off its slot holds the element up (the leg gate); scaled by the doctrine's cohesion number.
const COHESION_SLACK := 1.0
## A far ambush's maneuver element turns in once it is this close to its flank position (meters).
const FLANK_ARRIVE := 18.0
## Encircling: the ring turns this far every ORBIT_TICKS, so the pack keeps moving round its target instead
## of parking on a circle. Coarse on purpose — a new goal every tick would reset what every brain was doing.
const ORBIT_STEP_DEG := 30.0
const ORBIT_TICKS := 240
## Attack orders are given to units within this multiple of their weapon range; the rest keep moving up.
const ENGAGE_RANGE_FACTOR := 1.15


static func build(situation: Dictionary, state: Dictionary, table: DoctrineTable) -> Dictionary:
	var members: Array = situation.get("members", [])
	var task: Dictionary = state.get("task", {})
	var plan := {"formation": TacticsFormation.DEFAULT, "technique": "traveling", "drill": "", "why": "",
			"anchor": state.get("anchor"), "heading": situation.get("heading", Vector3.FORWARD),
			"bounding": int(state.get("bounding", 0)), "arrived": bool(state.get("arrived", false)),
			"orders": {}, "slots": {}, "sectors": {}}
	if members.is_empty():
		return plan

	var drill := Drills.select(situation, state, table)
	var pick := table.select({"task": String(task.get("verb", "hold")), "threat": String(situation["threat"]),
			"terrain": String(situation["terrain"]), "composition": String(situation["composition"])})
	plan["formation"] = pick["formation"]
	plan["technique"] = pick["technique"]
	plan["why"] = pick["why"]
	plan["drill"] = drill["drill"]
	if drill["drill"] != "":
		plan["why"] = drill["why"]
		_plan_drill(plan, situation, state, table, drill)
	else:
		_plan_movement(plan, situation, state, table)
	return plan


# ---- Movement (no contact): formation, technique, legs -------------------------------------------------

static func _plan_movement(plan: Dictionary, situation: Dictionary, state: Dictionary, table: DoctrineTable) -> void:
	var task: Dictionary = state.get("task", {})
	var verb := String(task.get("verb", "hold"))
	var center: Vector3 = situation["center"]
	var destination: Variant = _task_point(task, situation)
	if verb == "hold" or destination == null:
		plan["arrived"] = true
		_halt(plan, situation, table)
		return
	var to_go := center.distance_to(destination)
	plan["arrived"] = to_go <= ARRIVE_M
	if plan["arrived"]:
		_halt(plan, situation, table)
		return
	var heading := TacticsFormation.flat(destination - center)
	plan["heading"] = heading
	var spacing := table.spacing(String(situation["terrain"]))
	var order_verb := "attack_move" if verb in ["attack", "screen"] or String(situation["threat"]) in ["likely", "contact"] else "move"
	var ordered := slot_order(situation)

	match String(plan["technique"]):
		"bounding_overwatch":
			_plan_bounding(plan, situation, state, table, ordered, destination, heading, spacing, order_verb)
		"traveling_overwatch":
			var halves := split(ordered)
			# The anchor belongs to the LEAD section: measured from the whole element's centre it stops
			# advancing, because the trail section is a gap behind on purpose (measured 2026-09-16).
			var anchor := _advance(plan, situation, state, table, _center_of(halves[0]), destination, heading,
					halves[0], spacing)
			_group(plan, halves[0], String(plan["formation"]), anchor, heading, spacing, order_verb)
			var trail_anchor := anchor - heading * table.leg("overwatch_gap_m")
			_group(plan, halves[1], "wedge", trail_anchor, heading, spacing, "attack_move")
		_:
			var anchor := _advance(plan, situation, state, table, center, destination, heading, ordered, spacing)
			_group(plan, ordered, String(plan["formation"]), anchor, heading, spacing, order_verb)



## Bounding overwatch: one half moves, the other covers it by fire, then they swap. A bound never goes
## further than the overwatch can support by fire (table.legs.support_range_m).
static func _plan_bounding(plan: Dictionary, situation: Dictionary, state: Dictionary, table: DoctrineTable,
		ordered: Array, destination: Vector3, heading: Vector3, spacing: float, order_verb: String) -> void:
	var halves := split(ordered)
	var bounding: int = clampi(int(state.get("bounding", 0)), 0, 1)
	var movers: Array = halves[bounding]
	var overwatch: Array = halves[1 - bounding]
	if movers.is_empty() or overwatch.is_empty():
		var anchor := _advance(plan, situation, state, table, situation["center"], destination, heading, ordered, spacing)
		_group(plan, ordered, String(plan["formation"]), anchor, heading, spacing, order_verb)
		return
	var mover_center := _center_of(movers)
	var cover_center := _center_of(overwatch)
	var anchor: Variant = state.get("anchor")
	var bound := table.leg("bounding_m")
	# The bound is over when the moving half has closed on its anchor: hand the move to the other half.
	# (With no anchor yet this is the element's first bound, and the lead section takes it.)
	var swap: bool = anchor != null and _cohesive(movers, anchor, String(plan["formation"]), heading, spacing, table)
	if anchor == null or swap:
		if swap:
			bounding = 1 - bounding
			movers = halves[bounding]
			overwatch = halves[1 - bounding]
			mover_center = _center_of(movers)
			cover_center = _center_of(overwatch)
		var room := maxf(table.leg("support_range_m") - cover_center.distance_to(mover_center), 0.0)
		var step := minf(minf(bound, room), mover_center.distance_to(destination))
		anchor = clamp_to_arena(mover_center + heading * step)
	plan["bounding"] = bounding
	plan["anchor"] = anchor
	_group(plan, movers, String(plan["formation"]), anchor, heading, spacing, order_verb)
	# The overwatch half stays where it is, guns out, covering the bound.
	_hold(plan, overwatch, situation, heading, "overwatch")


## A halt: all-round security. An element that has arrived is no longer on its movement task, so the table is
## asked what a HALT looks like — normally the herringbone (in lanes or cover) or the coil (in the open) —
## and the crews face their sectors instead of the way they drove in.
static func _halt(plan: Dictionary, situation: Dictionary, table: DoctrineTable) -> void:
	var pick := table.select({"task": "hold", "threat": String(situation["threat"]),
			"terrain": String(situation["terrain"]), "composition": String(situation["composition"])})
	plan["formation"] = pick["formation"]
	plan["technique"] = pick["technique"]
	plan["why"] = pick["why"]
	_plan_halt(plan, situation, table)


static func _plan_halt(plan: Dictionary, situation: Dictionary, table: DoctrineTable) -> void:
	var ordered := slot_order(situation)
	var formation := String(plan["formation"])
	var heading: Vector3 = plan["heading"]
	var spacing := table.spacing(String(situation["terrain"]))
	_group(plan, ordered, formation, situation["center"], heading, spacing, "move", "", true)


# ---- Battle drills -------------------------------------------------------------------------------------

static func _plan_drill(plan: Dictionary, situation: Dictionary, state: Dictionary, table: DoctrineTable,
		drill: Dictionary) -> void:
	var ordered := slot_order(situation)
	var center: Vector3 = situation["center"]
	var spacing := table.spacing(String(situation["terrain"]))
	var point: Variant = drill.get("point")
	var contact := Drills.nearest_visible(situation)
	var focus: Vector3 = point if point is Vector3 else (contact["position"] if not contact.is_empty() else center)
	var toward: Vector3 = TacticsFormation.flat(focus - center) if focus.distance_to(center) > 1.0 else plan["heading"]

	match String(drill["drill"]):
		"react_to_contact":
			# Return fire, take cover, report: nobody drives anywhere until the leader has decided.
			plan["technique"] = "traveling"
			plan["heading"] = toward
			_engage(plan, ordered, situation, toward, contact)
		"near_ambush":
			# Immediate action: turn into it. A short move toward the ambush swings every hull round to face it.
			plan["formation"] = "line"
			plan["technique"] = "traveling"
			plan["heading"] = toward
			for member: Dictionary in ordered:
				_order(plan, String(member["name"]), "attack_move", (member["position"] as Vector3) + toward * 10.0,
						String(contact.get("name", "")))
		"assault_through":
			# Charge past the ambush position, abreast, and keep going until we are through it.
			plan["formation"] = "line"
			plan["technique"] = "traveling"
			plan["heading"] = toward
			var through: Vector3 = focus + toward * table.drill_number("assault_through_m")
			plan["anchor"] = through
			_group(plan, ordered, "line", through, toward, spacing, "attack_move")
		"far_ambush", "support_by_fire":
			_plan_fire_and_maneuver(plan, situation, state, table, ordered, focus, toward, spacing, contact)
		"break_contact":
			_plan_break_contact(plan, situation, state, table, ordered, focus, toward, spacing)
		"herringbone":
			plan["formation"] = "herringbone"
			plan["technique"] = "traveling"
			_group(plan, ordered, "herringbone", center, plan["heading"], spacing, "move", "", true)
		"encircle":
			_plan_encircle(plan, situation, table, ordered, focus, toward, spacing, contact)
		"bait":
			_plan_bait(plan, situation, table, ordered, focus, toward, spacing, contact)
		_:
			_engage(plan, ordered, situation, toward, contact)


## Encircle (gangs): fan out around them and keep going round, so their fire has to keep re-aiming and the
## damage is spread across the pack instead of stacked on whoever is in front. The ring is anchored on the
## ENEMY, not on a heading, and it turns a notch every ORBIT_TICKS.
static func _plan_encircle(plan: Dictionary, situation: Dictionary, table: DoctrineTable, ordered: Array,
		focus: Vector3, toward: Vector3, spacing: float, contact: Dictionary) -> void:
	plan["formation"] = "ring"
	plan["technique"] = "traveling"
	plan["heading"] = toward
	plan["anchor"] = focus
	# The ring's phase comes from the tick, so every peer computes the same circle at the same moment.
	var turns := int(situation["tick"]) / ORBIT_TICKS
	var spun := TacticsFormation.rotate(toward, deg_to_rad(turns * ORBIT_STEP_DEG))
	# Only the vehicles still closing are driven to a place on the ring. Once one can shoot, it is told to
	# fight and left alone: its brain already circles, dodges and goes for the weak side, and a drill that
	# keeps handing it a new patch of ground to stand on just interrupts all of that (measured, 2026-09-16 —
	# driving the whole ring cost half the pack against a standard element that simply engaged).
	var closing: Array = []
	var target := String(contact.get("name", ""))
	for member: Dictionary in ordered:
		var in_range: bool = target != "" \
				and (member["position"] as Vector3).distance_to(focus) <= float(member["range"]) * ENGAGE_RANGE_FACTOR
		if in_range:
			_order(plan, String(member["name"]), "attack", null, target)
		else:
			closing.append(member)
	if not closing.is_empty():
		_group(plan, closing, "ring", focus, spun, spacing, "attack_move", target)


## Bait (gangs): the fastest vehicle runs at them and then leads them back over the rest of the pack, which
## is waiting off the line it returns along. When they follow, the near-ambush drill takes it from there.
static func _plan_bait(plan: Dictionary, situation: Dictionary, table: DoctrineTable, ordered: Array,
		focus: Vector3, toward: Vector3, spacing: float, contact: Dictionary) -> void:
	plan["formation"] = "swarm"
	plan["technique"] = "traveling"
	plan["heading"] = toward
	var runner := Drills.bait_of(situation)
	var center: Vector3 = situation["center"]
	var waiting: Array = []
	for member: Dictionary in ordered:
		if String(member["name"]) != String(runner.get("name", "")):
			waiting.append(member)
	if runner.is_empty() or waiting.is_empty():
		_engage(plan, ordered, situation, toward, contact)
		return
	# The pack waits BEHIND where the bait will come back through, spread wide off the approach.
	var hide := clamp_to_arena(center - toward * table.drill_number("bait_back_m"))
	_group(plan, waiting, "swarm", hide, toward, spacing, "hold")
	# The bait drives at them: close enough to be worth chasing, never close enough to be caught.
	var lure := clamp_to_arena(focus - toward * table.drill_number("bait_min_m") * 0.8)
	_order(plan, String(runner["name"]), "attack_move", lure, String(contact.get("name", "")))
	plan["slots"][String(runner["name"])] = lure


## Far ambush and support by fire: one element pins them by fire, the other maneuvers onto their flank.
static func _plan_fire_and_maneuver(plan: Dictionary, situation: Dictionary, state: Dictionary,
		table: DoctrineTable, ordered: Array, focus: Vector3, toward: Vector3, spacing: float,
		contact: Dictionary) -> void:
	plan["technique"] = "bounding_overwatch"
	plan["heading"] = toward
	var halves := split(ordered)
	var base: Array = halves[0]
	var maneuver: Array = halves[1]
	var task_verb := String((state.get("task", {}) as Dictionary).get("verb", ""))
	if task_verb == "support_by_fire" or maneuver.is_empty():
		# The task itself is the base of fire: everyone suppresses, nobody advances.
		plan["formation"] = "line"
		_engage(plan, ordered, situation, toward, contact)
		return
	plan["formation"] = "line"
	_engage(plan, base, situation, toward, contact)
	# The maneuver element swings off the line of contact, then turns in. The line of contact is measured
	# from the BASE OF FIRE, which is standing still: taken from the maneuver element instead, it rotates as
	# that element moves and walks the flank position round and round the enemy (measured, 2026-09-16).
	var axis := TacticsFormation.flat(focus - _center_of(base))
	var right := Vector3(-axis.z, 0.0, axis.x)
	var maneuver_center := _center_of(maneuver)
	var side := signf((maneuver_center - focus).dot(right))
	side = 1.0 if side == 0.0 else side
	var flank := focus + right * side * table.drill_number("flank_m")
	if maneuver_center.distance_to(flank) <= FLANK_ARRIVE:
		# On the flank: turn in and roll them up.
		_group(plan, maneuver, "wedge", focus, TacticsFormation.flat(focus - maneuver_center), spacing, "attack_move")
	else:
		# On the way there, under the base of fire's protection: move, don't stop to trade shots frontally.
		_group(plan, maneuver, "wedge", flank, TacticsFormation.flat(flank - maneuver_center), spacing, "move")


## Break contact: bound back, one half moving while the other keeps the enemy's heads down.
static func _plan_break_contact(plan: Dictionary, situation: Dictionary, state: Dictionary,
		table: DoctrineTable, ordered: Array, focus: Vector3, toward: Vector3, spacing: float) -> void:
	plan["formation"] = "column"
	plan["technique"] = "bounding_overwatch"
	var away := -toward
	plan["heading"] = away
	var rally := clamp_to_arena((situation["center"] as Vector3) + away * table.drill_number("rally_back_m"))
	var halves := split(ordered)
	var bounding: int = clampi(int(state.get("bounding", 0)), 0, 1)
	# The half nearest the enemy covers; the other half moves first.
	var movers: Array = halves[bounding]
	var cover: Array = halves[1 - bounding]
	if movers.is_empty() or cover.is_empty():
		_group(plan, ordered, "column", rally, away, spacing, "move")
		return
	var mover_center := _center_of(movers)
	var anchor: Variant = state.get("anchor")
	var swap: bool = anchor != null and _cohesive(movers, anchor, "column", away, spacing, table)
	if anchor == null or swap:
		if swap:
			bounding = 1 - bounding
			movers = halves[bounding]
			cover = halves[1 - bounding]
			mover_center = _center_of(movers)
		var step := minf(table.leg("bounding_m"), mover_center.distance_to(rally))
		anchor = clamp_to_arena(mover_center + away * step)
	plan["bounding"] = bounding
	plan["anchor"] = anchor
	_group(plan, movers, "column", anchor, away, spacing, "move")
	_hold(plan, cover, situation, toward, "covering the withdrawal")


# ---- Order helpers -------------------------------------------------------------------------------------

## Units in range shoot; the rest close up on the enemy so they can.
static func _engage(plan: Dictionary, members: Array, situation: Dictionary, toward: Vector3,
		contact: Dictionary) -> void:
	var target := String(contact.get("name", ""))
	var focus: Variant = contact.get("position")
	for member: Dictionary in members:
		var name := String(member["name"])
		var position: Vector3 = member["position"]
		if target != "" and focus is Vector3 and position.distance_to(focus) <= float(member["range"]) * ENGAGE_RANGE_FACTOR:
			_order(plan, name, "attack", null, target)
		elif target != "":
			_order(plan, name, "attack_move", clamp_to_arena(position + toward * 15.0), "")
		else:
			_order(plan, name, "hold", null, "")


## Stand and cover: hold where you are, guns toward `facing`.
static func _hold(plan: Dictionary, members: Array, situation: Dictionary, facing: Vector3, _why: String) -> void:
	var contact := Drills.nearest_visible(situation)
	for member: Dictionary in members:
		var name := String(member["name"])
		var position: Vector3 = member["position"]
		var target := String(contact.get("name", ""))
		if target != "" and (contact["position"] as Vector3).distance_to(position) <= float(member["range"]) * ENGAGE_RANGE_FACTOR:
			_order(plan, name, "attack", null, target)
		else:
			_order(plan, name, "hold", null, "")
		plan["slots"][name] = position


## Place `members` in `formation` around `anchor` and send each to its slot.
## `halt` puts every crew on its sector of fire instead of the direction of travel.
static func _group(plan: Dictionary, members: Array, formation: String, anchor: Vector3, heading: Vector3,
		spacing: float, verb: String, target := "", halt := false) -> void:
	var count := members.size()
	if count == 0:
		return
	var slots := TacticsFormation.centered(TacticsFormation.offsets(formation, count, spacing))
	var sectors := TacticsFormation.sectors(formation, count)
	var seats := by_exposure(members, slots)
	for i in count:
		var name := String(members[seats[i]]["name"])
		var spot := TacticsFormation.to_world(anchor, heading, slots[i])
		if halt:
			spot += TacticsFormation.rotate(heading, deg_to_rad(sectors[i])) * FACE_LEAD
		spot = clamp_to_arena(spot)
		plan["slots"][name] = spot
		plan["sectors"][name] = sectors[i]
		_order(plan, name, verb, spot, target)


static func _order(plan: Dictionary, unit_name: String, verb: String, to: Variant, target: String) -> void:
	plan["orders"][unit_name] = {"verb": verb, "to": to, "target": target}


# ---- Legs, splits and geometry -------------------------------------------------------------------------

## Where the element's formation centre should be next: one leg further on, but only once the element has
## closed up on the leg it is driving to now.
## `keyed` is the group whose slots are measured from this anchor (the whole element, or the lead section
## under traveling overwatch: the trail section is deliberately a gap behind and must not hold the advance up).
static func _advance(plan: Dictionary, situation: Dictionary, state: Dictionary, table: DoctrineTable,
		center: Vector3, destination: Vector3, heading: Vector3, keyed: Array, spacing: float) -> Vector3:
	var anchor: Variant = state.get("anchor")
	var leg := table.leg("%s_m" % String(plan["technique"]))
	var reached: bool = anchor == null or center.distance_to(anchor) <= LEG_ARRIVE \
			or (destination - (anchor as Vector3)).dot(heading) < 0.0 \
			or (anchor as Vector3).distance_to(destination) > center.distance_to(destination) + leg
	if reached and _cohesive(keyed, anchor, String(plan["formation"]), heading, spacing, table):
		anchor = clamp_to_arena(center + heading * minf(leg, center.distance_to(destination)))
	elif anchor == null:
		anchor = clamp_to_arena(center)
	plan["anchor"] = anchor
	return anchor


## Has the element closed up? Every member within the doctrine's cohesion distance of its slot.
static func _cohesive(members: Array, anchor: Variant, formation: String, heading: Vector3, spacing: float,
		table: DoctrineTable) -> bool:
	if anchor == null or members.is_empty():
		return true
	var slots := TacticsFormation.centered(TacticsFormation.offsets(formation, members.size(), spacing))
	var allowed := table.leg("cohesion_m") * COHESION_SLACK
	for i in members.size():
		var spot := TacticsFormation.to_world(anchor, heading, slots[i])
		if (members[i]["position"] as Vector3).distance_to(spot) > allowed:
			return false
	return true


## Which member takes each slot: `result[slot index]` is an index into `members`.
##
## The shape says where the exposed places are — the outside of a line, the point of a wedge, the ends of a
## column — and the vehicle that can take a hit goes there, with the fragile ones inboard. The lead
## (2026-09-16): *"I don't know if your doctrines are accounting for how to manage formations with multiple
## vehicles (i.e. heavy armor on the outside of a column, light armor on the inside)."*
##
## The leader keeps slot 0, which is its place in the formation's own geometry (the point of the wedge, the
## head of the column): a leader that cannot see its element cannot lead it.
static func by_exposure(members: Array, slots: Array) -> Array:
	var count := members.size()
	var seats: Array = []
	seats.resize(count)
	if count == 0:
		return seats
	seats[0] = 0
	if count == 1:
		return seats
	# Slots, most exposed first (ties by index, so the same shape always fills the same way).
	var order: Array = range(1, count)
	order.sort_custom(func(a: int, b: int) -> bool:
		var exposure_a := exposure_of(slots[a])
		var exposure_b := exposure_of(slots[b])
		return exposure_a > exposure_b + 0.01 or (absf(exposure_a - exposure_b) <= 0.01 and a < b))
	# Members, toughest first (ties by name).
	var toughest: Array = range(1, count)
	toughest.sort_custom(func(a: int, b: int) -> bool:
		var hard_a := toughness_of(members[a])
		var hard_b := toughness_of(members[b])
		return hard_a > hard_b + 0.01 or (absf(hard_a - hard_b) <= 0.01
				and String(members[a]["name"]) < String(members[b]["name"])))
	for i in order.size():
		seats[order[i]] = toughest[i]
	return seats


## How exposed a slot is: how far out of the middle of the shape it sits, and how far toward the front.
static func exposure_of(slot: Vector2) -> float:
	return slot.length() + FRONT_EXPOSURE * maxf(-slot.y, 0.0)


## What a vehicle can take, and whether it should have to: front and side armour plus hull, minus a heavy
## penalty for the roles an element is built to keep alive.
static func toughness_of(member: Dictionary) -> float:
	var role := String(member.get("role", "scout"))
	var protected_penalty := PROTECTED_PENALTY if PROTECTED_ROLES.has(role) else 0.0
	var unit := String(member.get("unit", ""))
	if not Units.exists(unit):
		return -float(ROLE_RANK.get(role, 3)) - protected_penalty
	return Units.armor(unit, "front") + Units.armor(unit, "side") \
			+ float(Units.stat(unit, "max_health")) / HULL_PER_ARMOUR - protected_penalty


## Who stands where: the leader first, then armour, then the fragile and indirect-fire vehicles, by name.
static func slot_order(situation: Dictionary) -> Array:
	var leader := String(situation.get("leader", ""))
	var members: Array = (situation.get("members", []) as Array).duplicate()
	members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_lead := String(a["name"]) == leader
		var b_lead := String(b["name"]) == leader
		if a_lead != b_lead:
			return a_lead
		var rank_a: int = ROLE_RANK.get(String(a["role"]), 3)
		var rank_b: int = ROLE_RANK.get(String(b["role"]), 3)
		return rank_a < rank_b if rank_a != rank_b else String(a["name"]) < String(b["name"]))
	return members


## Split an ordered element into its two sections: the lead (bounds first, or is the base of fire) and the trail.
static func split(ordered: Array) -> Array:
	var half := int(ceil(ordered.size() / 2.0))
	return [ordered.slice(0, half), ordered.slice(half)]


static func _center_of(members: Array) -> Vector3:
	if members.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for member: Dictionary in members:
		sum += member["position"] as Vector3
	return sum / float(members.size())


static func _task_point(task: Dictionary, situation: Dictionary) -> Variant:
	var destination: Variant = ElementTask.destination(task)
	if destination != null:
		return destination
	if String(task.get("verb", "")) == "attack":
		for contact: Dictionary in situation.get("contacts", []):
			if String(contact["name"]) == String(task.get("target", "")):
				return contact["position"]
		var nearest := Drills.nearest_contact(situation)
		return nearest.get("position") if not nearest.is_empty() else null
	return null


static func clamp_to_arena(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT), 0.0,
			clampf(point.z, -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT))
