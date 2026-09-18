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
##      "slots": {unit: Vector3}, "sectors": {unit: degrees}, "seats": {unit: [formation, count, index]}}
##
## Every formation is laid out and seated by TacticsFormation (N2, the one formation system): the leader keeps the
## shape's point, whatever can take a hit stands where the fire comes from, and the rest take the slots that keep
## their paths from crossing — and keep them from one update to the next (the seating in `state.seats`).
##
## Orders use control's K1 verbs (move, attack_move, attack, hold), so the brains keep obeying exactly one
## thing and all their micro — cover, peeking, strafing, weak spots — still applies inside the order.
## Movement is by LEGS, not by a destination that slides every tick: the anchor (the element's centre of
## formation) jumps forward one leg at a time and only when the element has closed up on the last one. That
## is the doctrinal "close up before the next bound", and it keeps a brain's commitment from being reset
## every second (round-3 lesson: re-issuing an order throws away what the brain was doing).

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
const ORBIT_TICKS := SimClock.TICK_RATE * 4
## Support by fire: the firing line stands this fraction of the element's shortest EFFECTIVE range off the point it
## covers, so every gun in the line reaches it with fire that counts, and never closer than SBF_MIN_STANDOFF_M.
const SBF_STANDOFF := 0.8
const SBF_MIN_STANDOFF_M := 25.0
## An ambush lies closer than a base of fire: this fraction of the shortest effective range from the kill zone, so
## the first volley is inside every gun's band.
const AMBUSH_STANDOFF := 0.6
## A screen is a thin line: its vehicles stand this many times the doctrine spacing apart, to watch a wide front.
const SCREEN_SPREAD := 1.5
## A unit within this far of its place on a firing or screen line holds it (fires from there, drives back if pushed);
## further out it moves to it.
const IN_POSITION_M := 8.0
## Attack orders are given to units within this multiple of their weapon range; the rest keep moving up.
const ENGAGE_RANGE_FACTOR := 1.15


static func build(situation: Dictionary, state: Dictionary, table: DoctrineTable) -> Dictionary:
	var members: Array = situation.get("members", [])
	var task: Dictionary = state.get("task", {})
	var plan := {"formation": TacticsFormation.DEFAULT, "technique": "traveling", "drill": "", "why": "",
			"anchor": state.get("anchor"), "heading": situation.get("heading", Vector3.FORWARD),
			"bounding": int(state.get("bounding", 0)), "arrived": bool(state.get("arrived", false)),
			"orders": {}, "slots": {}, "sectors": {}, "seats": {},
			"leader": String(situation.get("leader", "")), "previous_seats": state.get("seats", {}),
			"route": [], "route_index": 0}
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
	if verb == "screen" and Drills.on_screen_line(situation, state):
		_plan_screen(plan, situation, state, table, destination)
		return
	if verb == "hold" and destination == null:
		# Hold here: where the element stood when told, kept from update to update (the centre of a halted
		# element wanders as its crews face their sectors, and a halt that follows it creeps).
		plan["arrived"] = true
		_halt(plan, situation, state, table, _kept_halt(state, center))
		return
	if destination == null:
		plan["arrived"] = true
		_halt(plan, situation, state, table, _kept_halt(state, center))
		return
	var to_go := center.distance_to(destination)
	if not ElementTask.runs_drills(task):
		_plan_form_up(plan, situation, state, table, destination)
		return
	if verb == "attack":
		# X5: an attack closes until its guns count, then fights; it does not "arrive" and halt on the enemy's spot.
		var band := INF
		for member: Dictionary in members_of(situation):
			band = minf(band, float(member.get("effective_range", member.get("range", 60.0))))
		if to_go <= band:
			plan["formation"] = "line"
			plan["arrived"] = false
			var toward := TacticsFormation.flat(destination - center)
			plan["heading"] = toward
			var target := _target_contact(task, situation)
			_engage(plan, slot_order(situation), situation, toward, target)
			return
	plan["arrived"] = to_go <= ARRIVE_M
	if plan["arrived"]:
		# Arrived: the halt formation stands ON the ordered spot, not wherever the element's centre happens to be.
		_halt(plan, situation, state, table, destination)
		return
	# X7: under a known threat an element that runs drills takes the least-exposed route (CoveredRoute), leg by leg;
	# a plain move (the player's right-click) goes where it was sent by the direct line.
	if ElementTask.runs_drills(task) and not _threat_points(situation).is_empty():
		destination = _route_step(plan, situation, state, center, destination)
	var heading := TacticsFormation.flat(destination - center)
	plan["heading"] = heading
	var spacing := table.spacing(String(situation["terrain"]))
	var order_verb := "attack_move" if verb in ["attack", "screen"] or String(situation["threat"]) in ["likely", "contact"] else "move"
	if not ElementTask.runs_drills(task):
		order_verb = "move"  # a plain move goes where it was sent; its crews still shoot what they pass
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



## A plain move (X4: the player's right-click to a whole element) is the lead's form-up formula taken literally: ONE
## target formation anchored on the clicked spot, its heading and shape fixed when the order is given, and every vehicle
## sent once, straight to its own slot from wherever it is — paced by FormUp so they arrive together. No legs (a leg
## re-anchors and re-orders everyone), no halt re-shape on arrival (the shape the player saw going in is the shape that
## stands), no heading that turns with the element's moving centre. Round 5 took plain moves away from elements because a
## leader re-slotting after a move is what the lead saw as "overridden by a higher priority"; control's five-squad
## playtest measured this path at 31-38 orders in the idle window before it was made to stand still (round 6).
static func _plan_form_up(plan: Dictionary, situation: Dictionary, state: Dictionary, table: DoctrineTable,
		destination: Vector3) -> void:
	var kept: Variant = state.get("anchor")
	var holding: bool = kept is Vector3 and (kept as Vector3).distance_to(destination) < 0.5
	var center: Vector3 = situation["center"]
	if holding and state.get("heading") is Vector3 and String(state.get("formation", "")) != "":
		plan["heading"] = state["heading"]
		plan["formation"] = String(state["formation"])
	else:
		plan["heading"] = TacticsFormation.flat(destination - center) if center.distance_to(destination) > 2.0 \
				else TacticsFormation.flat(situation.get("heading", Vector3.FORWARD))
	plan["anchor"] = destination
	plan["technique"] = "traveling"
	plan["arrived"] = center.distance_to(destination) <= ARRIVE_M
	plan["why"] = "moving as ordered: form up on the spot, %s" % String(plan["formation"]).replace("_", " ")
	_group(plan, slot_order(situation), String(plan["formation"]), destination, plan["heading"],
			table.spacing(String(situation["terrain"])), "move")


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
## `at` is where the halt stands; the heading is the one the element arrived with, kept while it stays halted (the
## averaged hull facing turns as crews face their sectors, and a formation that turned with it would never settle).
static func _halt(plan: Dictionary, situation: Dictionary, state: Dictionary, table: DoctrineTable, at: Vector3) -> void:
	var pick := table.select({"task": "hold", "threat": String(situation["threat"]),
			"terrain": String(situation["terrain"]), "composition": String(situation["composition"])})
	plan["formation"] = pick["formation"]
	plan["technique"] = pick["technique"]
	plan["why"] = pick["why"]
	plan["anchor"] = clamp_to_arena(at)
	if bool(state.get("arrived", false)) and state.get("heading") is Vector3:
		plan["heading"] = state["heading"]
	_plan_halt(plan, situation, table)


static func _plan_halt(plan: Dictionary, situation: Dictionary, table: DoctrineTable) -> void:
	var ordered := slot_order(situation)
	var formation := String(plan["formation"])
	var heading: Vector3 = plan["heading"]
	var spacing := table.spacing(String(situation["terrain"]))
	var at: Vector3 = plan["anchor"] if plan.get("anchor") is Vector3 else situation["center"]
	_group(plan, ordered, formation, at, heading, spacing, "move", "", true)


## Where a halt that is already standing keeps standing: last update's anchor while the element stays halted, else
## `center` (a fresh halt).
static func _kept_halt(state: Dictionary, center: Vector3) -> Vector3:
	var anchor: Variant = state.get("anchor")
	if bool(state.get("arrived", false)) and anchor is Vector3:
		return anchor
	return center


## Screen (N4): a thin line ACROSS the point, facing the way the element came to it (away from its own side), each
## crew on its sector; it observes and fights only what comes to it (Drills gives a screen on its line no drill).
static func _plan_screen(plan: Dictionary, situation: Dictionary, state: Dictionary, table: DoctrineTable,
		point: Vector3) -> void:
	plan["formation"] = "line"
	plan["technique"] = "traveling"
	plan["why"] = "screen: on the line, observe, fight what comes"
	plan["arrived"] = true
	var kept: Variant = state.get("anchor")
	var heading: Vector3 = state["heading"] if kept is Vector3 and (kept as Vector3).distance_to(point) < 0.5 \
			and state.get("heading") is Vector3 else TacticsFormation.flat(point - (situation["center"] as Vector3))
	plan["anchor"] = point
	plan["heading"] = heading
	var spacing := table.spacing(String(situation["terrain"])) * SCREEN_SPREAD
	_line_positions(plan, situation, slot_order(situation), point, heading, spacing)


## Support by fire (N4, round 6): a firing line at a standoff from the point, every gun in effective range of it,
## facing it with interlocking sectors — and nobody advances. The line is chosen once, on the element's side of the
## point, and kept (Element.assign clears it); the element drives to it and holds.
static func _plan_support_by_fire(plan: Dictionary, situation: Dictionary, state: Dictionary, table: DoctrineTable,
		ordered: Array, focus: Vector3, spacing: float, fraction := SBF_STANDOFF,
		keeping: Array = ["support_by_fire"]) -> void:
	plan["formation"] = "line"
	plan["technique"] = "traveling"
	var anchor: Variant = state.get("anchor")
	if not (keeping.has(String(state.get("drill", ""))) and anchor is Vector3):
		var reach := INF
		for member: Dictionary in ordered:
			reach = minf(reach, float(member.get("effective_range", member.get("range", 60.0))))
		var standoff := maxf(reach * fraction, SBF_MIN_STANDOFF_M) if is_finite(reach) else SBF_MIN_STANDOFF_M
		var center: Vector3 = situation["center"]
		var away := TacticsFormation.flat(center - focus) if center.distance_to(focus) > 1.0 \
				else -TacticsFormation.flat(plan["heading"])
		anchor = clamp_to_arena(focus + away * standoff)
	plan["anchor"] = anchor
	var heading := TacticsFormation.flat(focus - (anchor as Vector3))
	plan["heading"] = heading
	_line_positions(plan, situation, ordered, anchor, heading, spacing)


## Put `members` on a line at `anchor` facing `heading`, each on its sector: far from its place it moves there, on it
## it holds (a holding crew fires at will and drives back onto the spot if pushed off it).
static func _line_positions(plan: Dictionary, situation: Dictionary, members: Array, anchor: Vector3,
		heading: Vector3, spacing: float) -> void:
	_group(plan, members, "line", anchor, heading, spacing, "move", "", true)
	for member: Dictionary in members:
		var name := String(member["name"])
		var spot: Vector3 = plan["slots"][name]
		if (member["position"] as Vector3).distance_to(spot) <= IN_POSITION_M:
			_order(plan, name, "hold", spot, "")


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
		"ambush", "spring_ambush":
			# X7: the same firing line as a base of fire, closer, facing the kill zone. The drill decides whether the
			# crews may shoot (ElementFeed.holds_fire); the positions do not change when it is sprung.
			var zone: Variant = ElementTask.destination(state.get("task", {}))
			_plan_support_by_fire(plan, situation, state, table, ordered, zone if zone is Vector3 else focus, spacing,
					AMBUSH_STANDOFF, ["ambush", "spring_ambush"])
			plan["why"] = drill["why"]
		"herringbone":
			plan["formation"] = "herringbone"
			plan["technique"] = "traveling"
			var at := _kept_halt(state, center)
			plan["anchor"] = at
			_group(plan, ordered, "herringbone", at, plan["heading"], spacing, "move", "", true)
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
	if task_verb == "support_by_fire":
		# The task itself is the base of fire: take the firing line and hold it. (Before round 6 this called
		# _engage() alone: with nobody in sight every crew was told to hold where it stood, so the element never
		# moved and never formed — exactly what the lead saw when he pressed the button.)
		var point: Variant = ElementTask.destination(state.get("task", {}))
		_plan_support_by_fire(plan, situation, state, table, ordered, point if point is Vector3 else focus, spacing)
		return
	if maneuver.is_empty():
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
		# On the way there, under the base of fire's protection: move, don't stop to trade shots frontally — and go
		# round the way they can see least of (X7), not straight across their front.
		var step := _route_step(plan, situation, state, maneuver_center, flank)
		_group(plan, maneuver, "wedge", step, TacticsFormation.flat(step - maneuver_center), spacing, "move")


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


# ---- Routes (X7) ---------------------------------------------------------------------------------------

## A waypoint counts as reached within this far (meters), and the route is re-chosen when its end moves this far.
const WAYPOINT_M := 15.0
const ROUTE_KEEP_M := 12.0


## The point to drive toward now on the way from `from` to `to`: the current waypoint of a covered route chosen
## once (CoveredRoute) and kept while its end stays put. Records the route in the plan.
static func _route_step(plan: Dictionary, situation: Dictionary, state: Dictionary, from: Vector3, to: Vector3) -> Vector3:
	var route: Array = state.get("route", [])
	var index := int(state.get("route_index", 0))
	if route.is_empty() or (route[route.size() - 1] as Vector3).distance_to(to) > ROUTE_KEEP_M:
		var chosen := CoveredRoute.choose(situation.get("cover_map"), from, to, _threat_points(situation),
				float(situation.get("sight", 90.0)), situation.get("lanes", []))
		route = chosen.get("waypoints", [to])
		index = 0
	while index < route.size() - 1 and from.distance_to(route[index]) <= WAYPOINT_M:
		index += 1
	plan["route"] = route
	plan["route_index"] = index
	return route[index]


## Where the enemies we know of are (seen or remembered).
static func _threat_points(situation: Dictionary) -> Array:
	var points: Array = []
	for contact: Dictionary in situation.get("contacts", []):
		points.append(contact["position"])
	return points


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


## Place `members` in `formation` around `anchor` and send each to its slot (TacticsFormation.place: the
## leader keeps the point, armour goes where the fire comes from, nobody's path crosses another's, and last
## update's seating stands unless a new one saves real driving).
## `halt` puts every crew on its sector of fire instead of the direction of travel.
static func _group(plan: Dictionary, members: Array, formation: String, anchor: Vector3, heading: Vector3,
		spacing: float, verb: String, target := "", halt := false) -> void:
	if members.is_empty():
		return
	var placed := TacticsFormation.place(members, formation, anchor, heading, spacing,
			{"leader": String(plan.get("leader", "")), "policy": "exposure",
			"previous": _previous_seating(plan, members, formation)})
	for entry in placed:
		var name := String(entry["unit"])
		var spot: Vector3 = entry["to"]
		if halt:
			spot += TacticsFormation.rotate(heading, deg_to_rad(float(entry["sector"]))) * FACE_LEAD
		spot = clamp_to_arena(spot)
		plan["slots"][name] = spot
		plan["sectors"][name] = entry["sector"]
		plan["seats"][name] = [formation, members.size(), int(entry["index"])]
		_order(plan, name, verb, spot, target)


## Last update's seating for these members in this shape, if they all had one ({} otherwise).
static func _previous_seating(plan: Dictionary, members: Array, formation: String) -> Dictionary:
	var before: Dictionary = plan.get("previous_seats", {})
	var result := {}
	for member: Dictionary in members:
		var seat: Variant = before.get(String(member["name"]))
		if not (seat is Array) or String(seat[0]) != formation or int(seat[1]) != members.size():
			return {}
		result[String(member["name"])] = int(seat[2])
	return result


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


## Has the element closed up? Judged in TIME, the lead's form-up estimate (X3): every member reaches its slot within
## the time the slowest vehicle needs to cover the doctrine's cohesion distance. A fast scout 30 m out is as closed
## up as a tank 15 m out; measured in metres the tank held every leg up and the scout never did.
## (Straight line over top speed, as FormUp.eta estimates it until nav's Movement.eta exists.)
static func _cohesive(members: Array, anchor: Variant, formation: String, heading: Vector3, spacing: float,
		table: DoctrineTable) -> bool:
	if anchor == null or members.is_empty():
		return true
	var slowest := INF
	for member: Dictionary in members:
		slowest = minf(slowest, maxf(float(member.get("speed", 9.0)), 0.5))
	var allowed_s := table.leg("cohesion_m") * COHESION_SLACK / slowest
	var by_name := {}
	for member: Dictionary in members:
		by_name[String(member["name"])] = member
	for entry in TacticsFormation.place(members, formation, anchor, heading, spacing, {"policy": "exposure"}):
		var member: Dictionary = by_name[String(entry["unit"])]
		var seconds := (member["position"] as Vector3).distance_to(entry["to"]) / maxf(float(member.get("speed", 9.0)), 0.5)
		if seconds > allowed_s:
			return false
	return true


## Who stands where: the leader first, then armour, then the fragile and indirect-fire vehicles, by name.
static func slot_order(situation: Dictionary) -> Array:
	var leader := String(situation.get("leader", ""))
	var members: Array = (situation.get("members", []) as Array).duplicate()
	members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_lead := String(a["name"]) == leader
		var b_lead := String(b["name"]) == leader
		if a_lead != b_lead:
			return a_lead
		var rank_a: int = TacticsFormation.ROLE_RANK.get(String(a["role"]), 3)
		var rank_b: int = TacticsFormation.ROLE_RANK.get(String(b["role"]), 3)
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


static func members_of(situation: Dictionary) -> Array:
	return situation.get("members", [])


## The contact an attack task is on: the named target when known, else the nearest.
static func _target_contact(task: Dictionary, situation: Dictionary) -> Dictionary:
	for contact: Dictionary in situation.get("contacts", []):
		if String(contact["name"]) == String(task.get("target", "")):
			return contact
	return Drills.nearest_contact(situation)


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
