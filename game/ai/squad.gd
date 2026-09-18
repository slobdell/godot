class_name Squad
extends RefCounted
## Runtime state of one squad on the simulating peer: roster, commander, formation,
## drill, destination. Turns ONE player command into per-tank slot targets and
## directive modifiers; the tank brains stay autonomous inside them.
## See _agents/tactical_map.md.
##
## SquadCommand (structured data, from the tactical map / CPU / agent / network):
##   {"squad": "Alpha",
##    "verb": "move" | "bound" | "hold" | "assault" | "break_contact",   (optional)
##    "to": [x, z],          world meters (required for move/bound/assault; optional otherwise)
##    "facing": [x, z],      direction to face on arrival (optional)
##    "formation": "wedge",  (optional)
##    "commander": "Green_Alpha_2"}   (optional)

## The commander was destroyed and `successor` took over (not emitted for elections).
signal commander_lost(fallen: String, successor: String)

const VERBS := ["move", "bound", "hold", "assault", "break_contact"]
const NEEDS_DESTINATION := ["move", "bound", "assault"]
const ARENA_LIMIT := Match.DRIVABLE_LIMIT
## The commander counts as arrived within this distance of the destination.
const ARRIVE_RADIUS := 6.0
## How far the bounding element moves before the elements swap roles.
const BOUND_DISTANCE := 25.0
## Bounding overwatch (A6): after a swap the next bound waits until the new overwatch element is set (every member
## slower than OVERWATCH_SET_SPEED m/s, after at least OVERWATCH_MIN_WAIT squad updates) or OVERWATCH_MAX_WAIT
## updates pass. Squad updates run every Match.INTEL_EVERY_TICKS (0.1 s).
const OVERWATCH_SET_SPEED := 1.0
const OVERWATCH_MIN_WAIT := 10
const OVERWATCH_MAX_WAIT := 40
const MAX_EVENTS := 12
## Commander pacing: followers may lag this far behind their slots before the commander slows,
## down to MIN_PACE when they're PACE_SLACK + PACE_FALLOFF behind.
const PACE_SLACK := 10.0
const PACE_FALLOFF := 40.0
const MIN_PACE := 0.5
## Perimeter walls' inner faces are at ±60 and tanks keep ~2 m off them.
const SLOT_LIMIT := Match.DRIVABLE_LIMIT - 2.0

var squad_name := ""
var team := 0
## Succession order. Never reordered; the commander is tracked separately.
var roster: PackedStringArray = []
var commander := ""
## "" = no formation control (legacy doctrine behavior: objectives only).
var formation := ""
var spacing := Formations.DEFAULT_SPACING
## "" = no drill (legacy).
var verb := ""
var destination: Variant = null
var facing_on_arrival := Vector3.ZERO
## Current formation heading (the direction of travel, or the arrival facing).
var heading := Vector3.FORWARD
var arrived := false
## Bounding overwatch: which element (0 = the commander's, 1 = the other) is moving, and where to.
var bounding_element := 1
var bound_goal: Variant = null
## Squad updates the bounding element has waited for the overwatch to set (-1 = not waiting).
var bound_waited := -1
var events: PackedStringArray = []
## Who stands in which slot ({name: index}), from TacticsFormation.seat (N2: the one seating rule): the commander
## keeps the point, the rest take the slots that keep their paths from crossing, and keep them between updates.
var seats := {}
## Bumped by every accepted command. Brains compare it to re-think at once and drop their
## commitment, so a player order takes effect on the next tick (G3 responsiveness).
var order_serial := 0


func _init(p_name: String = "", p_team: int = 0, p_roster: PackedStringArray = []) -> void:
	squad_name = p_name
	team = p_team
	roster = p_roster
	commander = roster[0] if not roster.is_empty() else ""


func is_commanded() -> bool:
	return verb != ""


# ---- Commands ---------------------------------------------------------------------

## Validate without applying. "" or a human-readable reason.
static func validate_command(command: Variant) -> String:
	if typeof(command) != TYPE_DICTIONARY:
		return "command must be an object"
	if typeof(command.get("squad")) != TYPE_STRING:
		return "command needs a string 'squad'"
	if not (command.has("verb") or command.has("formation") or command.has("commander")):
		return "command needs at least one of verb, formation, commander"
	if command.has("verb") and not VERBS.has(command["verb"]):
		return "verb must be one of %s" % [VERBS]
	if command.has("formation") and not Formations.NAMES.has(command["formation"]):
		return "formation must be one of %s" % [Formations.NAMES]
	if command.has("commander") and typeof(command["commander"]) != TYPE_STRING:
		return "commander must be a tank name"
	for key in ["to", "facing"]:
		if command.has(key):
			var pair: Variant = command[key]
			if typeof(pair) != TYPE_ARRAY or pair.size() != 2 or not Directives._is_number(pair[0]) \
					or not Directives._is_number(pair[1]):
				return "'%s' must be [x, z]" % key
			if key == "to" and (absf(float(pair[0])) > ARENA_LIMIT or absf(float(pair[1])) > ARENA_LIMIT):
				return "'to' must be inside the arena (|x|, |z| <= %d)" % int(ARENA_LIMIT)
	if NEEDS_DESTINATION.has(command.get("verb", "")) and not command.has("to"):
		return "'%s' needs a destination 'to'" % command["verb"]
	return ""


## Apply a validated command. `tanks` maps name → Tank; `rally` is the team's base.
func apply_command(command: Dictionary, tanks: Dictionary, rally: Vector3) -> String:
	var error := Squad.validate_command(command)
	if error != "":
		return error
	if command.has("commander"):
		error = elect(command["commander"], tanks)
		if error != "":
			return error
	if command.has("formation"):
		formation = command["formation"]
		if verb == "":
			verb = "hold"  # a formation alone means: form up here
	if command.has("verb"):
		verb = command["verb"]
		arrived = false
		bound_goal = null
		bounding_element = 1
		bound_waited = -1
		var lead := tanks.get(commander) as Tank
		if command.has("to"):
			destination = Vector3(float(command["to"][0]), 0.0, float(command["to"][1]))
		elif verb == "break_contact":
			destination = rally
		elif lead != null:
			destination = lead.global_position
		if command.has("facing"):
			facing_on_arrival = Vector3(float(command["facing"][0]), 0.0, float(command["facing"][1])).normalized()
		else:
			facing_on_arrival = Vector3.ZERO
		if formation == "":
			formation = Formations.DEFAULT
	if destination == null and tanks.get(commander) != null:
		destination = (tanks[commander] as Tank).global_position
	order_serial += 1
	_log("orders: %s%s%s" % [verb, " in " + formation if formation != "" else "",
			"" if destination == null else " to (%.0f, %.0f)" % [destination.x, destination.z]])
	return ""


func elect(tank_name: String, tanks: Dictionary) -> String:
	if not roster.has(tank_name):
		return "%s is not in squad %s" % [tank_name, squad_name]
	var tank := tanks.get(tank_name) as Tank
	if tank == null or not tank.is_alive():
		return "%s can't take command right now" % tank_name
	if commander != tank_name:
		commander = tank_name
		_log("%s takes command" % tank_name)
	return ""


# ---- Per-tick bookkeeping (called by Match) ----------------------------------------

func update(tanks: Dictionary) -> void:
	var alive := alive_members(tanks)
	if alive.is_empty():
		return
	if not alive.has(commander):
		var start := maxi(roster.find(commander), 0)
		for step in range(1, roster.size() + 1):
			var candidate := roster[(start + step) % roster.size()]
			if alive.has(candidate):
				_log("commander down, %s takes command" % candidate)
				var fallen := commander
				commander = candidate
				commander_lost.emit(fallen, candidate)
				break
	if not is_commanded() or destination == null:
		return
	_seat(tanks)
	var lead: Tank = tanks[commander]
	var to_goal: Vector3 = destination - lead.global_position
	to_goal.y = 0.0
	arrived = to_goal.length() <= ARRIVE_RADIUS
	if not arrived:
		heading = to_goal.normalized()
	elif facing_on_arrival != Vector3.ZERO:
		heading = facing_on_arrival
	if verb == "bound":
		_update_bound(tanks, alive)


func _update_bound(tanks: Dictionary, alive: PackedStringArray) -> void:
	if bound_waited >= 0:
		bound_waited += 1
		var set := bound_waited >= OVERWATCH_MIN_WAIT
		for member in _element_members(1 - bounding_element, alive):
			if (tanks[member] as Tank).estimated_velocity.length() > OVERWATCH_SET_SPEED:
				set = false
		if set or bound_waited >= OVERWATCH_MAX_WAIT:
			bound_waited = -1
			_log("bound: overwatch set, element %d moves" % bounding_element)
		return
	var moving := _element_members(bounding_element, alive)
	if moving.is_empty():
		bounding_element = 1 - bounding_element
		moving = _element_members(bounding_element, alive)
	var center := Vector3.ZERO
	for member in moving:
		center += (tanks[member] as Tank).global_position
	center /= maxf(moving.size(), 1)
	if bound_goal == null:
		bound_goal = _next_bound_goal(center)
	elif Vector2(center.x - bound_goal.x, center.z - bound_goal.z).length() <= ARRIVE_RADIUS:
		# The bounding element is set: it becomes the overwatch, and the other element bounds past it.
		bounding_element = 1 - bounding_element
		bound_goal = _next_bound_goal(bound_goal)
		bound_waited = 0
		_log("bound: element %d moves" % bounding_element)


func _next_bound_goal(from: Vector3) -> Vector3:
	var to_goal: Vector3 = destination - from
	to_goal.y = 0.0
	if to_goal.length() <= BOUND_DISTANCE:
		return destination
	return from + to_goal.normalized() * BOUND_DISTANCE


# ---- Queries for brains and the map ------------------------------------------------

func alive_members(tanks: Dictionary) -> PackedStringArray:
	var alive: PackedStringArray = []
	for member in roster:
		var tank := tanks.get(member) as Tank
		if tank != null and tank.is_alive():
			alive.append(member)
	return alive


## Commander first, then surviving members in roster order: the formation closes gaps.
func formation_order(tanks: Dictionary) -> PackedStringArray:
	var order: PackedStringArray = [commander]
	for member in alive_members(tanks):
		if member != commander:
			order.append(member)
	return order


func element_of(tank_name: String) -> int:
	return 0 if tank_name == commander else (1 + roster.find(tank_name)) % 2


func _element_members(element: int, alive: PackedStringArray) -> PackedStringArray:
	var members: PackedStringArray = []
	for member in alive:
		if element_of(member) == element:
			members.append(member)
	return members


## What the squad wants from one tank right now, for its brain:
## {"slot": Vector3 | null, "facing": Vector3, "moving": bool, "pace": float, "reverse": bool,
##  "is_commander": bool, "verb": String}
func context_for(tank_name: String, tanks: Dictionary) -> Dictionary:
	var context := _raw_context(tank_name, tanks)
	if context["slot"] != null:
		# A formation hugging a wall would put slots inside it; keep every slot drivable: inside the arena...
		var slot: Vector3 = context["slot"]
		slot = Vector3(clampf(slot.x, -SLOT_LIMIT, SLOT_LIMIT), 0.0, clampf(slot.z, -SLOT_LIMIT, SLOT_LIMIT))
		# X2: and never inside an obstacle (the navmesh's nearest standable point).
		context["slot"] = SlotGround.standable(tanks.get(tank_name) as Node3D, slot)
	return context


func _raw_context(tank_name: String, tanks: Dictionary) -> Dictionary:
	var context := {"verb": verb, "slot": null, "facing": heading, "moving": false, "pace": 1.0,
			"reverse": verb == "break_contact", "is_commander": tank_name == commander}
	if not is_commanded() or destination == null or not tanks.has(commander):
		return context
	var order := formation_order(tanks)
	if order.find(tank_name) < 0:
		return context
	var index := _slot_index(tank_name, order)
	var offsets := Formations.offsets(formation, order.size(), spacing)
	var lead: Tank = tanks[commander]

	if verb == "bound":
		var moving_now := element_of(tank_name) == bounding_element and bound_waited < 0
		context["waiting"] = element_of(tank_name) == bounding_element and bound_waited >= 0
		if moving_now and bound_goal != null:
			context["slot"] = Formations.to_world(bound_goal, heading, offsets[index] - offsets[_slot_index(_element_anchor(tanks), order)])
			context["moving"] = true
		else:
			context["slot"] = (tanks[tank_name] as Tank).global_position  # overwatch: stay put and cover
		return context

	var anchored_at_destination := formation == "coil" or arrived or verb == "hold" or verb == "break_contact"
	if anchored_at_destination:
		context["slot"] = Formations.to_world(destination, heading, offsets[index])
		context["facing"] = Formations.facing(formation, heading, offsets[index])
		context["moving"] = not arrived
	elif tank_name == commander:
		context["slot"] = destination
		context["moving"] = true
		context["pace"] = _commander_pace(tanks, order, offsets, lead)
	else:
		var lead_point := lead.global_position + lead.estimated_velocity * 0.6
		context["slot"] = Formations.to_world(lead_point, heading, offsets[index])
		context["moving"] = true
	return context


## Seat the living members in the formation anchored on the destination (TacticsFormation.seat, "front" policy
## with the commander pinned to the point), keeping the last seating unless a new one saves real driving.
func _seat(tanks: Dictionary) -> void:
	var order := formation_order(tanks)
	var members: Array = []
	for member in order:
		var tank: Tank = tanks[member]
		members.append({"name": member, "unit": tank.unit_id,
				"position": Vector3(tank.global_position.x, 0.0, tank.global_position.z)})
	var shape := Formations.offsets(formation, order.size(), spacing)
	var previous := seats if seats.size() == order.size() else {}
	seats = TacticsFormation.seat(members, shape, destination, heading,
			{"leader": commander, "policy": "front", "previous": previous, "spacing": spacing})


## A member's slot index: its seat, or its place in formation_order before the first seating.
func _slot_index(tank_name: String, order: PackedStringArray) -> int:
	var index := int(seats.get(tank_name, -1))
	return index if index >= 0 and index < order.size() else order.find(tank_name)


func _element_anchor(tanks: Dictionary) -> String:
	for member in formation_order(tanks):
		if element_of(member) == bounding_element:
			return member
	return commander


## Slow the commander while followers lag far BEHIND their slots, so the squad arrives together.
## Only lag along the heading counts: a wingman off to the side catches up by cutting across, and
## counting it made a freshly ordered squad crawl (G3: pace lag was the biggest start-up delay).
func _commander_pace(tanks: Dictionary, order: PackedStringArray, offsets: Array[Vector2], lead: Tank) -> float:
	var worst := 0.0
	for i in range(1, order.size()):
		var slot := Formations.to_world(lead.global_position, heading, offsets[_slot_index(order[i], order)])
		var behind := (slot - (tanks[order[i]] as Tank).global_position).dot(heading)
		worst = maxf(worst, behind)
	return clampf(1.0 - (worst - PACE_SLACK) / PACE_FALLOFF, MIN_PACE, 1.0)


## A drill's effect on a brain's weights. The brain still decides; the drill tilts it.
static func drill_directives(base: Dictionary, context: Dictionary) -> Dictionary:
	var d := base.duplicate(true)
	match context["verb"]:
		"move":
			d["aggression"] = float(d["aggression"]) * 0.8
		"bound":
			d["aggression"] = 0.3 if context["moving"] else maxf(float(d["aggression"]), 0.6)
		"hold":
			d["aggression"] = minf(float(d["aggression"]), 0.35)
		"assault":
			d["aggression"] = maxf(float(d["aggression"]), 0.9)
			d["flanking"] = minf(float(d["flanking"]) + 0.2, 1.0)
		"break_contact":
			d["aggression"] = 0.1
			d["caution"] = maxf(float(d["caution"]), 0.8)
	return d


func _log(text: String) -> void:
	events.append("%s: %s" % [squad_name, text])
	if events.size() > MAX_EVENTS:
		events = events.slice(events.size() - MAX_EVENTS)
