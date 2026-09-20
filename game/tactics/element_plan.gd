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
##
## Do NOT add a floor like max(..., Drills near_ambush_m + margin) to keep the line out of near-ambush range (proposed and
## refused in round 6): with a 45 m band it puts the line at ~47 m, OUTSIDE the band, where a gun lands ~31-50% of shells
## instead of ~100%. A base of fire that cannot hit is not one. The invariant is precedence instead: a support-by-fire
## task outranks near ambush in Drills.select (only break contact outranks it), tested in test_tactics_tasks.gd.
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
			"leader": String(situation.get("leader", "")), "previous_seats": state.get("seats", {}), "facing_sent": bool(state.get("facing_sent", false)),
			"route": [], "route_index": 0, "pitch": Vector2(TacticsFormation.DEFAULT_SPACING,
			TacticsFormation.DEFAULT_SPACING), "corridor_m": float(situation.get("corridor_m", INF)), "file": 0.0,
			# X3 (A9): only a bounding advance fills this; everything else says "not bounding" rather than leaving
			# last update's phase standing (a stale phase would report firepower stationary that is driving).
			"bound": {}}
	if members.is_empty():
		return plan
	# X1: this element's TACTICAL pitch — the doctrine's number for the terrain, raised per axis to what its own
	# hulls fit in. Published so control's readout, the coherence probe and a slot's leash read a real number rather
	# than the one that was asked for or a constant. X2's corridor deformation is reported separately (`file`), so
	# this stays the element's dispersion rather than whatever the narrowest gap squeezed it to.
	plan["pitch"] = TacticsFormation.pitch(members, table.spacing(String(situation["terrain"])))

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
	var told: Variant = ElementTask.facing(state.get("task", {}))
	if holding and state.get("heading") is Vector3 and String(state.get("formation", "")) != "":
		plan["heading"] = state["heading"]
		plan["formation"] = String(state["formation"])
	elif told is Vector3:
		plan["heading"] = told  # the player said which way: lay the formation facing it
	else:
		plan["heading"] = TacticsFormation.flat(destination - center) if center.distance_to(destination) > 2.0 \
				else TacticsFormation.flat(situation.get("heading", Vector3.FORWARD))
	plan["anchor"] = destination
	plan["technique"] = "traveling"
	# X2: these slots are where the element STANDS when it gets there — the shape the player saw when he clicked —
	# not a shape filing through a gap, so the corridor does not deform them. The transit is `_flow`'s business, and
	# deforming that is recorded as the follow-on rather than guessed at here.
	plan["corridor_m"] = INF
	plan["arrived"] = center.distance_to(destination) <= ARRIVE_M
	plan["why"] = "moving as ordered: form up on the spot, %s" % String(plan["formation"]).replace("_", " ")
	# Sent once means SEATED once: when everyone has been sent to their final slot (the flow joined, or no flow) the
	# seating stands. A CPU crew fights from within its slot's leash and drifts ~10 m off it; left to "saves real
	# driving", the seating re-shuffled around the drift and re-ordered idle units (round 7: the CPU five-squad test).
	var joined: bool = not FLOW_ENABLED or bool(state.get("flow_joined", false))
	# `told` goes through to the per-unit orders: a facing the player dragged is an ARRIVAL heading, and K1 has carried
	# one since round 5 (`TankBrain.intended_facing`, and `test_wheeled_arrival` covers the per-unit case).
	# ARRIVED, WITH A HEADING THE PLAYER DREW: the posture is a HOLD on that heading, and it is the plan's STEADY
	# STATE rather than a one-shot. My first version issued the hold once on arrival and it was overwritten on the very
	# next update, because `_group` re-issues its orders every time -- measured as `Green_A_1 hold facing=[1.0, 0.0]`
	# with every follower on `NO ORDER`, the leader's surviving only because its order happened not to change. An event
	# cannot hold a posture against a function that runs every tick; the posture has to BE what the function computes.
	#
	# Chosen from `plan["arrived"]` each update, so it needs no flag to remember it. The verb is `hold` because a hold
	# is a standing order that outlives the drive, and `halt` stays FALSE because the two are different things:
	# `_group` passes `entry["facing"] if halt else told`, so halting would hand each crew its own ALL-ROUND SECTOR
	# instead of the heading the player drew. Measured, with halt on: the crews held `[1,0]`, `[-1,0]` and `[0,-1]` --
	# east, west and north, which is a coil covering every approach and not an answer to a right-drag. Zeroing
	# `plan["sectors"]` above does not help, because that happens AFTER `_group` has already read the entries.
	#
	# A facing on a MOVE is an arrival heading and dies with the order; a facing on a HALT is a sector and is not the
	# drawn one. A hold carrying `told` is the only combination that both persists and points where he pointed.
	var holding_heading: bool = told is Vector3 and bool(plan["arrived"])
	_group(plan, slot_order(situation), String(plan["formation"]), destination, plan["heading"],
			table.spacing(String(situation["terrain"])), "hold" if holding_heading else "move", "",
			false, holding and joined, told if told is Vector3 else null)
	if holding_heading:
		plan["why"] = "%s; holding the heading you drew" % String(plan["why"])
	if told is Vector3:
		# A facing the player chose is everyone's facing, not the formation's all-round sectors.
		for unit_name: String in plan["sectors"]:
			plan["sectors"][unit_name] = 0.0
	_flow(plan, situation, state)
	# THE DRAGGED HEADING REACHES THE CREWS THAT WERE FOLLOWING (option 3, ruled by the orchestrator).
	#
	# `23b1d1a7` got the facing into the order of any crew driving to its own slot, which is the LEADER and, once the
	# flow has joined, everybody. It never reached a follower: `_flow` hands a follower a `follow` on the leader with no
	# destination, and a facing there would be an arrival heading for a moving target. By the time `flow_joined` lets
	# `_group`'s move orders through -- which happens when the LEADER reaches its own slot, essentially arrival -- the
	# orders have completed (measured: 8 s into a 20 m move, no orders at all). So there was no tick on which a
	# follower held the drawn heading, and control's page promised what the vehicles did not do.
	#
	# On arrival, re-issue every crew's final move order once, carrying the facing. **One order per crew per task**:
	# `facing_sent` is cleared only by `Element.assign`, so an element whose centre wobbles across ARRIVE_M cannot
	# re-order anybody twice, and a crew standing on its slot simply turns in place. That once-only property is what
	# made this the reversible option rather than putting a facing on a `follow` order and reaching into nav's arrival
	# code, which is not my paths and not one place.
## Round 7: the element FLOWS into formation on the way, not only at the end (the lead's "formula to form up", its
## visible half). The leader drives to its own slot; every other member follows the leader at its slot's offset from the
## leader's (K1 `follow` with a `slot`, in the leader's frame): its goal slides with the leader every tick, so nav's PID
## keeps station on it. Within FLOW_JOIN_M of its slot the leader is nearly there, and everyone is sent to their fixed
## final slot once (so the element goes quiet on arrival, X4). FLOW_ENABLED is the A/B switch.
static var FLOW_ENABLED := true
const FLOW_JOIN_M := 15.0


static func _flow(plan: Dictionary, situation: Dictionary, state: Dictionary) -> void:
	var leader := String(plan.get("leader", ""))
	# Once the element has joined its final slots for this task it never flows again: a leader fighting near its slot
	# drifts in and out of FLOW_JOIN_M, and toggling follow <-> move would re-order everyone (the CPU five-squad test
	# caught 6 idle orders). A new task clears it (Element.assign).
	plan["flow_joined"] = bool(state.get("flow_joined", false))
	if not FLOW_ENABLED or plan["flow_joined"] or leader == "" or not (plan["seats"] as Dictionary).has(leader):
		return
	var at := {}
	for member: Dictionary in situation.get("members", []):
		at[String(member["name"])] = member["position"]
	if not at.has(leader) or (at[leader] as Vector3).distance_to(plan["slots"][leader]) <= FLOW_JOIN_M:
		plan["flow_joined"] = true
		return
	var heading: Vector3 = plan["heading"]
	var right := Vector3(-heading.z, 0.0, heading.x)
	var lead_slot: Vector3 = plan["slots"][leader]
	for unit_name: String in plan["slots"]:
		if unit_name == leader:
			continue
		# The final slot relative to the leader's, as [right, back] in the formation's frame (the follow frame).
		var offset: Vector3 = (plan["slots"][unit_name] as Vector3) - lead_slot
		plan["orders"][unit_name] = {"verb": "follow", "to": null, "target": leader,
				"slot": [offset.dot(right), -offset.dot(heading)]}


# ---- A9: bounding overwatch as an explicit two-phase machine (round 9, X3) ------------------------------
#
# Before round 9 "bounding overwatch" was a TECHNIQUE NAME and a boolean: `bounding` said which half of the element
# had the current leg, the halves swapped whenever the movers closed up on their anchor, and NOTHING guaranteed that
# anybody was stationary or that a phase lasted a legible length of time. A9 makes it a state machine with the
# guarantee in it: at every tick at least half the element's guns are still, and a phase lasts 5-8 s so a spectator
# can see the alternation rather than a shimmer.
#
# THE FALSIFIER'S WORDING IS WHY THE SHAPE CHANGED. A9 pre-registered ">= 50% of squad firepower stationary at every
# tick", and two alternating halves of an ODD-sized element cannot meet it: `split` gives ceil(n/2) and floor(n/2),
# so whichever phase moves the three-vehicle half of a five-vehicle squad leaves 2 of 5 = 40% still. Swapping which
# half goes first only moves the 40% to the other phase. So an odd-sized element leaves a permanent BASE OF FIRE and
# bounds the rest in two equal teams — 1 + 2 + 2 for a squad of five, 3 of 5 stationary in BOTH phases — which is
# what a platoon actually does, and the falsifier is then met by construction rather than by a measurement that
# happens to pass. (Orchestrator's ruling, 2026-09-20.) The base is the vehicle whose firepower is worth most from a
# static position: the indirect-fire and long-reach roles, which are also the ones the element exists to protect and
# the ones that shoot worst on the move.

## A bounding phase lasts at least this long and at most this long (ticks): the catalogue's 5-8 s. The minimum stops
## a shimmer when both teams close up fast; the maximum stops a team that never closes up from parking the element
## (lesson 17: a gate above a behaviour must not be able to cancel it forever).
const BOUND_MIN_TICKS := SimClock.TICK_RATE * 5
const BOUND_MAX_TICKS := SimClock.TICK_RATE * 8


## The teams a bounding element alternates, and the base of fire that never bounds.
## Returns {"teams": [Array, Array], "base": Array}: two equal teams, plus the odd vehicle out when the element has
## an odd number of them. A single vehicle does not bound (both teams empty); a pair alternates singles.
static func bound_teams(ordered: Array) -> Dictionary:
	if ordered.size() < 2:
		return {"teams": [[], []], "base": ordered.duplicate()}
	var rest: Array = ordered.duplicate()
	var base: Array = []
	if rest.size() % 2 == 1:
		# The odd one out stays: the vehicle worth most standing still. `slot_order` already sorts leader first, then
		# by ROLE_RANK, so the LAST of it is the most protected role (artillery, then lancer) -- the gun that is
		# worth most from a static position and shoots worst on the move.
		base.append(rest.pop_back())
	var half := rest.size() / 2
	return {"teams": [rest.slice(0, half), rest.slice(half)], "base": base}


## Bounding overwatch: one team moves while the other (and the base of fire, if there is one) covers it, then they
## swap. A bound never goes further than the overwatch can support by fire (table.legs.support_range_m).
static func _plan_bounding(plan: Dictionary, situation: Dictionary, state: Dictionary, table: DoctrineTable,
		ordered: Array, destination: Vector3, heading: Vector3, spacing: float, order_verb: String) -> void:
	var split_up := bound_teams(ordered)
	var teams: Array = split_up["teams"]
	var base: Array = split_up["base"]
	var tick := int(situation.get("tick", 0))
	var was: Dictionary = state.get("bound", {})
	var phase: int = clampi(int(was.get("phase", int(state.get("bounding", 0)))), 0, 1)
	var since: int = int(was.get("since_tick", tick))
	if (teams[0] as Array).is_empty() or (teams[1] as Array).is_empty():
		# Nothing to alternate: the element travels as one, and says so rather than pretending to bound.
		var anchor := _advance(plan, situation, state, table, situation["center"], destination, heading, ordered, spacing)
		_group(plan, ordered, String(plan["formation"]), anchor, heading, spacing, order_verb)
		plan["bound"] = {}
		return
	var movers: Array = teams[phase]
	var overwatch: Array = (teams[1 - phase] as Array) + base
	var anchor: Variant = state.get("anchor")
	var age := maxi(tick - since, 0)
	# The phase is over when the moving team has closed up on its anchor AND the phase has run its minimum, or when
	# it has run its maximum whatever the team is doing.
	var closed: bool = anchor != null and _cohesive(movers, anchor, String(plan["formation"]), heading, spacing,
			table, float(plan.get("corridor_m", INF)))
	var swap: bool = (closed and age >= BOUND_MIN_TICKS) or age >= BOUND_MAX_TICKS
	if anchor == null or swap:
		if swap:
			phase = 1 - phase
			since = tick
			movers = teams[phase]
			overwatch = (teams[1 - phase] as Array) + base
		var room := maxf(table.leg("support_range_m") - _center_of(overwatch).distance_to(_center_of(movers)), 0.0)
		var step := minf(minf(table.leg("bounding_m"), room), _center_of(movers).distance_to(destination))
		anchor = clamp_to_arena(_center_of(movers) + heading * step)
	plan["bounding"] = phase
	plan["anchor"] = anchor
	_group(plan, movers, String(plan["formation"]), anchor, heading, spacing, order_verb)
	# The covering team stays where it is, guns out, covering the bound. So does the base of fire, in both phases.
	_hold(plan, overwatch, situation, heading, "overwatch")
	plan["bound"] = {"phase": phase, "since_tick": since, "movers": _names_of(movers),
			"overwatch": _names_of(overwatch), "base": _names_of(base),
			"stationary_share": float(overwatch.size()) / float(maxi(ordered.size(), 1))}


static func _names_of(members: Array) -> PackedStringArray:
	var names: PackedStringArray = []
	for member: Dictionary in members:
		names.append(String(member["name"]))
	return names


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
			# X5: a crew standing on a firing line keeps the sector it was put there to watch.
			_order(plan, name, "hold", spot, "",
					TacticsFormation.rotate(heading, deg_to_rad(float(plan["sectors"].get(name, 0.0)))))


# ---- Battle drills -------------------------------------------------------------------------------------

static func _plan_drill(plan: Dictionary, situation: Dictionary, state: Dictionary, table: DoctrineTable,
		drill: Dictionary) -> void:
	var ordered := slot_order(situation)
	var center: Vector3 = situation["center"]
	var spacing := table.spacing(String(situation["terrain"]))
	var point: Variant = drill.get("point")
	# Round 8 (the lead: "telling a group to attack a single unit ... they shoot at whatever they were already shooting
	# at"): a task that names a target aims every drill at it while it is in sight. Drills picked the nearest visible
	# enemy, so an element in a fight (always in a drill) never turned its guns to the one it was told.
	var contact := _ordered_target(state.get("task", {}), situation)
	if contact.is_empty():
		contact = Drills.nearest_visible(situation)
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
	# Round 8: the maneuver half's moves and attack-moves carry the ordered target too, so crews driving round keep their
	# guns on it (TankBrain: a named move lays its gun on the target; a named attack-move fights only it).
	var ordered_target := _ordered_target(state.get("task", {}), situation)
	if not ordered_target.is_empty():
		for unit_name: String in plan["orders"]:
			var order: Dictionary = plan["orders"][unit_name]
			if String(order["verb"]) in ["attack_move", "move"] and String(order.get("target", "")) == "":
				order["target"] = String(ordered_target["name"])


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
	var swap: bool = anchor != null and _cohesive(movers, anchor, "column", away, spacing, table,
			float(plan.get("corridor_m", INF)))
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
			# X5: "guns toward `facing`" was the docstring and nothing in the order said it. Now it does.
			_order(plan, name, "hold", null, "", facing)
		plan["slots"][name] = position


## Place `members` in `formation` around `anchor` and send each to its slot (TacticsFormation.place: the
## leader keeps the point, armour goes where the fire comes from, nobody's path crosses another's, and last
## update's seating stands unless a new one saves real driving).
## `halt` puts every crew on its sector of fire instead of the direction of travel.
## `fixed` keeps last update's seating whatever it costs (a plain move standing on its spot).
static func _group(plan: Dictionary, members: Array, formation: String, anchor: Vector3, heading: Vector3,
		spacing: float, verb: String, target := "", halt := false, fixed := false, told: Variant = null) -> void:
	if members.is_empty():
		return
	var placed := TacticsFormation.place(members, formation, anchor, heading, spacing,
			{"leader": String(plan.get("leader", "")), "policy": "exposure",
			"previous": _previous_seating(plan, members, formation), "fixed": fixed,
			# X5: a halt's crews face their sectors of fire, so place() gives each entry that facing rather than the
			# direction of travel, and the order carries it.
			"halt": halt,
			# X2 (A8): a MOVING formation deforms to the corridor it is driving through; a halt does not — it is
			# standing in an area, not filing through a gap, and its all-round sectors are the point of it.
			"corridor_m": INF if halt else float(plan.get("corridor_m", INF))})
	for entry in placed:
		var name := String(entry["unit"])
		plan["file"] = maxf(float(plan.get("file", 0.0)), float(entry.get("file", 0.0)))
		var spot: Vector3 = entry["to"]
		if halt:
			spot += TacticsFormation.rotate(heading, deg_to_rad(float(entry["sector"]))) * FACE_LEAD
		spot = clamp_to_arena(spot)
		plan["slots"][name] = spot
		plan["sectors"][name] = entry["sector"]
		plan["seats"][name] = [formation, members.size(), int(entry["index"])]
		# X5: at a halt the crew's sector of fire IS the facing it is being given; on the move the order's facing is
		# the direction of travel, which nav derives itself, so only a halt carries one.
		# X5, and the case X5 got wrong: a HALT's crew is given its sector of fire, and on the move the heading is
		# the direction of travel, which nav derives for itself -- so a moving order carried no facing at all. That is
		# right for every heading the doctrine chose and wrong for the one the PLAYER chose. A facing drag on a whole
		# squad reaches `plan["heading"]` and zeroes the sectors (see `_plan_form_up`), so the formation is laid facing
		# where he dragged, and then the orders threw the heading away and the squad arrived pointing whichever way it
		# had driven. `told` is that explicitly-chosen facing and nothing else: null on every doctrine-chosen heading,
		# so nav keeps deriving those from travel exactly as before.
		_order(plan, name, verb, spot, target, entry["facing"] if halt else told)


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


## `facing` (a flat direction, or null) is the heading the crew is to END UP on — X5: the only thing that makes the
## pair of "squad sets a facing" and nav's arrival arc measurable in a real match. A halt, a hold and a firing line
## all know which way their crews should look (their sector of fire, or the point they cover); before round 9 they
## expressed it only by driving FACE_LEAD metres along the sector and hoping the hull ended up pointing there.
static func _order(plan: Dictionary, unit_name: String, verb: String, to: Variant, target: String,
		facing: Variant = null) -> void:
	var order := {"verb": verb, "to": to, "target": target}
	if facing is Vector3 and (facing as Vector3).length_squared() > 1e-6:
		order["facing"] = TacticsFormation.flat(facing)
	plan["orders"][unit_name] = order


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
	if reached and _cohesive(keyed, anchor, String(plan["formation"]), heading, spacing, table,
			float(plan.get("corridor_m", INF))):
		anchor = clamp_to_arena(center + heading * minf(leg, center.distance_to(destination)))
	elif anchor == null:
		anchor = clamp_to_arena(center)
	plan["anchor"] = anchor
	return anchor


## Has the element closed up? Judged in TIME, the lead's form-up estimate (X3): every member reaches its slot within
## the time the slowest vehicle needs to cover the doctrine's cohesion distance. A fast scout 30 m out is as closed
## up as a tank 15 m out; measured in metres the tank held every leg up and the scout never did.
## (Straight line over top speed: the plan is pure and cannot ask the navmesh. The element's published form-up ETA —
## Element.form_up_eta(), which paces the members — is nav's route-aware Movement.eta.)
static func _cohesive(members: Array, anchor: Variant, formation: String, heading: Vector3, spacing: float,
		table: DoctrineTable, corridor_m := INF) -> bool:
	if anchor == null or members.is_empty():
		return true
	var slowest := INF
	for member: Dictionary in members:
		slowest = minf(slowest, maxf(float(member.get("speed", 9.0)), 0.5))
	var allowed_s := table.leg("cohesion_m") * COHESION_SLACK / slowest
	var by_name := {}
	for member: Dictionary in members:
		by_name[String(member["name"])] = member
	# X2: against the DEFORMED slots, because those are the ones the orders were given to. Measured against the
	# nominal shape, an element filing through a defile would never read as closed up and would never take its next
	# leg — lesson 17 in a new place: a gate above a behaviour that cancels it every tick.
	for entry in TacticsFormation.place(members, formation, anchor, heading, spacing,
			{"policy": "exposure", "corridor_m": corridor_m}):
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


## The contact the task names ("target"), if it is in sight now; {} otherwise.
static func _ordered_target(task: Dictionary, situation: Dictionary) -> Dictionary:
	var target := String(task.get("target", ""))
	if target == "":
		return {}
	for contact: Dictionary in situation.get("contacts", []):
		if String(contact["name"]) == target and bool(contact.get("visible", false)):
			return contact
	return {}


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


# ---- Preview (control's animated button help) ----------------------------------------------------------

## The posture the leader would take for task `verb` ("support_by_fire", "screen", "ambush", "hold", "attack_move",
## "move") if `count` tanks stood at `from` and the player clicked `point` — computed by the SAME planner (build()) on a
## synthetic element under the standard doctrine, so the tooltip shows what the button does, not an illustration of it.
## Pure: no match, no element. Returns {"slots": [Vector3], "facing": [Vector3], "fires": "no" | "always" |
## "on_contact", "advances": bool}. A screen is shown on its line (as it stands once it gets there).
static func preview(verb: String, count: int, point: Vector3, from: Vector3) -> Dictionary:
	var table := DoctrineTable.for_faction("")
	var at := point if verb == "screen" else from
	var members: Array = []
	var toward := TacticsFormation.flat(point - from)
	var across := Vector3(-toward.z, 0.0, toward.x)
	for i in maxi(count, 1):
		members.append({"name": "P%d" % i, "position": at + across * (float(i) - (count - 1) * 0.5) * 8.0,
				"forward": toward, "role": "tank", "unit": "tank", "speed": 9.0,
				"range": float(Weapons.profile(String(Units.stat("tank", "weapon"))).get("range", 60.0)),
				"effective_range": TankBrain.fire_band(Weapons.profile(String(Units.stat("tank", "weapon")))),
				"sight": 90.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	var situation := {"tick": 0, "team": 0, "center": at, "heading": toward, "leader": "P0", "members": members,
			"contacts": [], "terrain": "open", "threat": "none", "composition": "heavy", "strength": 800.0,
			"enemy_strength": 0.0, "taking_fire": false, "arrived": false}
	var task := {"verb": {"attack_move": "move"}.get(verb, verb)}
	if verb != "hold":
		task["to"] = [point.x, point.z]
	if verb == "move":
		task["drills"] = false
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": false, "heading": toward, "seats": {}}
	var plan := build(situation, state, table)
	var heading: Vector3 = plan["heading"]
	var halted: bool = verb in ["support_by_fire", "screen", "ambush", "hold"]
	var slots: Array = []
	var facing: Array = []
	for member: Dictionary in members:
		var unit := String(member["name"])
		if not (plan["slots"] as Dictionary).has(unit):
			continue
		slots.append(plan["slots"][unit])
		facing.append(TacticsFormation.rotate(heading, deg_to_rad(float(plan["sectors"].get(unit, 0.0)))) if halted else heading)
	return {"slots": slots, "facing": facing,
			"fires": {"support_by_fire": "always", "move": "on_contact"}.get(verb, "on_contact"),
			"advances": verb in ["attack_move", "move"]}
