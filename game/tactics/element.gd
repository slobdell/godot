class_name Element
extends RefCounted
## An element: a cluster of vehicles with a LEADER that runs them by standard operating procedure (contract
## L1, doctrine X1). The commander — the player or the CPU — gives the element a TASK (move, attack, screen,
## support by fire, hold). The leader decides the movement formation, the movement technique and the battle
## drills from its DoctrineTable, and issues ONE order per vehicle through control's K1 `Orders`, so every
## brain still obeys exactly one thing and keeps all of its own micro.
##
## The lead (2026-09-16): *"we should generally treat the game as cases where we're commanding well trained
## battle squads who operated based on standard operating procedures (like the army does) where there's
## essentially always a formation for any given task OR there's always a central decision maker per cluster
## of vehicles that automatically determines what the formation is based on their own decision matrix."*
##
## A player order always wins: if a vehicle's current order did not come from this element, the element stops
## commanding it (`detached`) until that order is finished, then quietly takes it back. Nothing an element
## does can hold a unit against its commander (K1's response guarantee).
##
## Decisions are pure: ElementSituation.build (the only impure step) -> Drills.select -> ElementPlan.build.

## Members are re-planned this often (ticks). Matches Match.INTEL_EVERY_TICKS: a leader can't react to
## intelligence it doesn't have yet.
const UPDATE_TICKS := SimClock.TICK_RATE / 10
## A unit's goal has to move this far before its order is re-issued: every new order resets what its brain
## was doing (round-3 lesson), so the leader does not nudge people around.
const REISSUE_M := 8.0
## The same intention is not handed to the same unit again inside this many ticks (2 s): a standing order already
## follows a moving target, and re-giving it only redraws the player's markers and costs frames.
const RE_ISSUE_TICKS := SimClock.TICK_RATE * 2
## A unit already this close to the goal of an order it has finished is left standing.
const SETTLED_M := 6.0
const MAX_EVENTS := 12

var id := 0
var element_name := ""
var team := 0
## Succession order: the first living member is the leader. Never reordered.
var roster: PackedStringArray = []
var leader := ""
var task := {}
var table: DoctrineTable = null

## What the leader decided last update (ElementPlan.build's output, for the HUD).
var formation := TacticsFormation.DEFAULT
var technique := "traveling"
var drill := ""
var reason := ""
var slots := {}
var sectors := {}
## Who stands in which slot of which shape ({unit: [formation, count, index]}): handed back to the next plan so
## the seating is stable from one update to the next (N2).
var seats := {}
## X3: seconds each member needs to reach its slot, and the speed fraction it drives at so the element arrives
## together (FormUp). Refreshed every update.
var etas := {}
var paces := {}
var events: PackedStringArray = []

## Plan state carried between updates.
var anchor: Variant = null
## X7: the covered route the element is following (waypoints) and which one it is driving to.
var route: Array = []
var route_index := 0
var heading := Vector3.FORWARD
var bounding := 0
var arrived := false
var drill_tick := 0
var drill_point: Variant = null
var drill_target := ""
## unit name -> the order this element issued it: {"id", "verb", "to", "target"}.
var _issued := {}
## Units whose current order came from somewhere else (the player): not ours to command.
var _detached := {}
## Contact name -> the tick this element first knew of it, so a drill can tell an ambush from a firefight.
var _known := {}
## Bumped whenever anything the HUD shows changes.
var revision := 0
## What changed in the last update ("task", "formation", "technique", "drill", "leader", "roster"): the
## announcer and the HUD both want to know WHICH, not just that something did.
var changed_fields: PackedStringArray = []
## A task was just assigned: the next decision is the element acting on it, which is worth reporting even
## when the shape it picks happens to be the one it already had.
var _fresh_task := false
## How far the element was from what triggered its current drill, in meters, when the drill started.
var drill_distance := 0.0
## Living members when the last decision was taken.
var strength := 0
## The situation's member data at the last decision (formation_group()).
var _last_members: Array = []


func _init(p_id: int = 0, p_name: String = "", p_team: int = 0, p_roster: PackedStringArray = [],
		p_table: DoctrineTable = null) -> void:
	id = p_id
	element_name = p_name
	team = p_team
	roster = p_roster
	leader = roster[0] if not roster.is_empty() else ""
	table = p_table


## Give the element something to do. "" or a human-readable reason it can't.
func assign(new_task: Variant) -> String:
	var error := ElementTask.validate(new_task)
	if error != "":
		return error
	task = (new_task as Dictionary).duplicate(true)
	_fresh_task = true
	# A new task starts a new movement: forget the leg, the route and any drill we were running.
	anchor = null
	route = []
	route_index = 0
	arrived = false
	drill = ""
	drill_point = null
	drill_target = ""
	_log("task: %s" % ElementTask.describe(task))
	revision += 1
	return ""


## Stop: the element holds where it stands.
func stand_down() -> void:
	assign({"verb": "hold"})


## One decision cycle. Returns true when anything the HUD shows changed.
func update(game_match: Match, orders: Object) -> bool:
	var before := _snapshot()
	changed_fields = PackedStringArray()
	_prune(game_match)
	_adopt(orders)
	var commanded := _commanded_members()
	if commanded.is_empty():
		return _note_changes(before)
	var situation := ElementSituation.build(game_match, team, commanded, leader,
			{"heading": heading, "arrived": arrived, "known": _known})
	_known = situation["known"]
	var state := {"task": task, "drill": drill, "drill_tick": drill_tick, "drill_point": drill_point,
			"drill_target": drill_target, "drill_why": reason, "anchor": anchor, "bounding": bounding,
			"arrived": arrived, "heading": heading, "seats": seats,
			"route": route, "route_index": route_index}
	var plan := ElementPlan.build(situation, state, _doctrine())
	Element.ground(plan, game_match.tanks.get_child(0) as Node3D if game_match.tanks != null \
			and game_match.tanks.get_child_count() > 0 else null)
	_take(plan, situation)
	var by_name := AiTickCache.tanks_by_name(game_match)
	etas = FormUp.etas(by_name, slots)
	paces = FormUp.paces(by_name, slots, etas)
	_issue(plan, orders, situation, game_match)
	return _note_changes(before)


## What the HUD reads (L1: read-only).
func state() -> Dictionary:
	return {"id": id, "name": element_name, "team": team, "leader": leader, "members": members(),
			"task": task.duplicate(true), "formation": formation, "technique": technique, "drill": drill,
			"reason": reason, "slots": slots.duplicate(), "sectors": sectors.duplicate(), "pace": paces.duplicate(),
			"form_up_eta": form_up_eta(),
			"detached": _detached.keys(), "events": events}


## X3: seconds until the element is formed up — until its slowest member reaches its slot (the lead's estimate).
func form_up_eta() -> float:
	return FormUp.group_eta(etas)


## N2 for TacticsFormation.slots(element, ...): this element as formation data (members where they were last update).
func formation_group() -> Dictionary:
	return {"formation": formation, "leader": leader, "policy": "exposure", "spacing": _doctrine().spacing("open"),
			"members": _last_members.duplicate(), "previous": _seating_now()}


func _seating_now() -> Dictionary:
	var result := {}
	for unit_name: String in seats:
		result[unit_name] = int(seats[unit_name][2])
	return result


## Living members, in succession order.
func members() -> PackedStringArray:
	return roster


func has(unit_name: String) -> bool:
	return roster.has(unit_name)


func is_detached(unit_name: String) -> bool:
	return _detached.has(unit_name)


func remove(unit_name: String) -> void:
	var index := roster.find(unit_name)
	if index >= 0:
		roster.remove_at(index)
	_issued.erase(unit_name)
	_detached.erase(unit_name)
	slots.erase(unit_name)
	sectors.erase(unit_name)
	seats.erase(unit_name)
	etas.erase(unit_name)
	paces.erase(unit_name)
	if leader == unit_name:
		leader = roster[0] if not roster.is_empty() else ""
		if leader != "":
			_log("%s takes over" % leader)
		revision += 1


## One line a spectator could read: "Alpha: wedge, bounding overwatch — contact likely in the open".
func describe() -> String:
	var words := "%s: %s" % [element_name, formation.replace("_", " ")]
	if drill != "":
		words += ", %s" % drill.replace("_", " ")
	else:
		words += ", %s" % technique.replace("_", " ")
	return "%s — %s" % [words, reason] if reason != "" else words


# ---- Internals -----------------------------------------------------------------------------------------

func _doctrine() -> DoctrineTable:
	if table == null:
		table = DoctrineTable.for_faction("")
	return table


## Drop the dead; the senior survivor takes over.
func _prune(game_match: Match) -> void:
	for unit_name in Array(roster):
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank if game_match.tanks != null else null
		if tank == null or not tank.is_alive():
			var was_leader: bool = leader == unit_name
			remove(unit_name)
			if was_leader and leader != "":
				_log("%s down" % unit_name)
	if leader == "" and not roster.is_empty():
		leader = roster[0]


## A vehicle whose current order isn't the one we gave it is under someone else's command (the player).
func _adopt(orders: Object) -> void:
	if orders == null:
		return
	for unit_name in roster:
		var current: Dictionary = orders.call("current", unit_name)
		if current.is_empty():
			if _detached.erase(unit_name):
				_log("%s back under command" % unit_name)
				revision += 1
			continue
		var mine: Dictionary = _issued.get(unit_name, {})
		if mine.is_empty() or int(current.get("id", -1)) != int(mine.get("id", -2)):
			if not _detached.has(unit_name):
				_detached[unit_name] = true
				_log("%s taken by its commander" % unit_name)
				revision += 1


func _commanded_members() -> PackedStringArray:
	var result: PackedStringArray = []
	for unit_name in roster:
		if not _detached.has(unit_name):
			result.append(unit_name)
	return result


## X2: every slot and every order's destination moved onto ground a vehicle can stand on (SlotGround). The plan is
## pure geometry; this is the step that meets the arena. `node` is any node in the match's world (null: unchanged).
static func ground(plan: Dictionary, node: Node3D) -> void:
	if node == null:
		return
	var slots_in: Dictionary = plan["slots"]
	for unit_name: String in slots_in:
		slots_in[unit_name] = SlotGround.standable(node, slots_in[unit_name])
	for unit_name: String in plan["orders"]:
		var order: Dictionary = plan["orders"][unit_name]
		if order["to"] is Vector3:
			order["to"] = SlotGround.standable(node, order["to"])


## Record what the leader decided.
func _take(plan: Dictionary, situation: Dictionary) -> void:
	formation = String(plan["formation"])
	technique = String(plan["technique"])
	reason = String(plan["why"])
	anchor = plan["anchor"]
	heading = plan["heading"]
	bounding = int(plan["bounding"])
	arrived = bool(plan["arrived"])
	slots = plan["slots"]
	sectors = plan["sectors"]
	seats = plan["seats"]
	route = plan["route"]
	route_index = int(plan["route_index"])
	strength = (situation["members"] as Array).size()
	_last_members = situation["members"]
	var new_drill := String(plan["drill"])
	if new_drill != drill:
		drill = new_drill
		drill_tick = int(situation["tick"])
		drill_point = null
		drill_distance = 0.0
		if drill != "":
			drill_point = _drill_focus(plan, situation)
			var contact := Drills.nearest_contact(situation)
			drill_target = String(contact.get("name", ""))
			drill_distance = float(contact.get("distance", 0.0))
			_log("drill: %s" % drill.replace("_", " "))
		revision += 1


static func _drill_focus(plan: Dictionary, situation: Dictionary) -> Variant:
	var contact := Drills.nearest_contact(situation)
	if not contact.is_empty():
		return contact["position"]
	return plan.get("anchor")


## Turn the plan into K1 commands, issuing only what actually changed.
func _issue(plan: Dictionary, orders: Object, situation: Dictionary, game_match: Match = null) -> void:
	if orders == null:
		return
	var positions := {}
	for member: Dictionary in situation["members"]:
		positions[String(member["name"])] = member["position"]
	var names: Array = (plan["orders"] as Dictionary).keys()
	names.sort()
	var player_team := OrderFeed.player_team(game_match)
	for unit_name: String in names:
		if _detached.has(unit_name):
			continue
		var desired: Dictionary = plan["orders"][unit_name]
		var current: Dictionary = orders.call("current", unit_name)
		# The player's authority is absolute (the lead, 2026-09-17: *"if they get sucked into combat I have no control
		# whatsoever"*). A unit carrying an order the PLAYER gave is not taken off it by its leader, and on the player's
		# own team a leader that has been given no task commands nobody at all — an untasked element running its SOP
		# over the player's army is the oldest version of this bug (L1's sharp edge, round 4).
		if String(current.get("source", "")) == "player":
			continue
		if team == player_team and task.is_empty():
			continue
		if not _should_issue(unit_name, desired, current, positions.get(unit_name, Vector3.ZERO), int(situation["tick"])):
			continue
		# K1's `source`: the player's own orders are the ones the response guarantee is about, and the only ones render
		# confirms with a marker and a cue. An element's are its own.
		var command := {"units": [unit_name], "verb": String(desired["verb"]), "source": "element"}
		if desired["to"] is Vector3:
			var point: Vector3 = desired["to"]
			command["to"] = [point.x, point.z]
		if String(desired.get("target", "")) != "":
			command["target"] = desired["target"]
		if command["verb"] == "attack" and not command.has("target"):
			command["verb"] = "hold"
			command.erase("to")
		var error: String = orders.call("issue", command, team)
		if error != "":
			# A target that just died, or a unit that did: try again next update with fresh facts.
			continue
		var issued: Dictionary = orders.call("current", unit_name)
		_issued[unit_name] = {"id": int(issued.get("id", -1)), "verb": command["verb"], "tick": int(situation["tick"]),
				"to": desired["to"], "target": String(desired.get("target", ""))}


func _should_issue(unit_name: String, desired: Dictionary, current: Dictionary, position: Vector3, tick: int) -> bool:
	var mine: Dictionary = _issued.get(unit_name, {})
	if current.is_empty():
		# Idle, having just finished what we gave it. The trap (round 5): a fight order's destination is a MOVING enemy,
		# so "there is somewhere else to be" is true on every update, and the leader re-gave the same intention five
		# times a second for as long as the fight lasted. A standing attack already follows its target, so the same
		# intention is not re-issued until RE_ISSUE_TICKS have passed or something real changes.
		var again: bool = not mine.is_empty() and String(mine.get("verb", "")) == String(desired["verb"]) \
				and String(mine.get("target", "")) == String(desired.get("target", ""))
		if again and tick - int(mine.get("tick", -RE_ISSUE_TICKS)) < RE_ISSUE_TICKS and _same_place(mine, desired, REISSUE_M):
			return false
		if desired["to"] is Vector3 and position.distance_to(desired["to"]) > SETTLED_M:
			return true
		# Arrived on a firing or screen line: the move is done, and the crew now HOLDS the spot (fires from it, and
		# drives back onto it if pushed). Left idle instead, a brain wanders its idle leash and the line dissolves.
		if String(desired["verb"]) == "hold" and desired["to"] is Vector3 and String(mine.get("verb", "")) != "hold":
			return true
		if String(desired["verb"]) in ["attack", "attack_move"] and String(desired.get("target", "")) != "":
			return String(mine.get("target", "")) != String(desired["target"]) \
					or tick - int(mine.get("tick", -RE_ISSUE_TICKS)) >= RE_ISSUE_TICKS
		return mine.is_empty() and String(desired["verb"]) != "hold"
	if mine.is_empty() or int(current.get("id", -1)) != int(mine.get("id", -2)):
		return false  # not ours to change
	# Round 5 (the lead's playtest): a leader re-issues only when the INTENTION changed. Two verbs that mean "fight that
	# one" (attack, attack_move) are the same intention while the target is the same, and "go there" and "stay there"
	# are the same intention while the place is the same. Without this the plan's verb flapped between them every
	# update, and every flap was a new order id: a marker drawn and a cue played on the player's screen, ~35 a second
	# across an army, which is what he saw as blue dots repeating and heard as beeping.
	var same_target := String(mine.get("target", "")) == String(desired.get("target", ""))
	var fight := ["attack", "attack_move"]
	var stay := ["move", "hold"]
	var same_intention: bool = String(mine["verb"]) == String(desired["verb"]) \
			or (fight.has(String(mine["verb"])) and fight.has(String(desired["verb"])) and same_target) \
			or (stay.has(String(mine["verb"])) and stay.has(String(desired["verb"])) and _same_place(mine, desired, SETTLED_M))
	if not same_intention or not same_target:
		return true
	if desired["to"] is Vector3 and mine["to"] is Vector3:
		return not _same_place(mine, desired, REISSUE_M)
	return desired["to"] is Vector3 != mine["to"] is Vector3


## Whether two orders point at the same place, within `slack` metres (a destination either may not have).
static func _same_place(mine: Dictionary, desired: Dictionary, slack: float) -> bool:
	if not (desired["to"] is Vector3 and mine["to"] is Vector3):
		return desired["to"] is Vector3 == mine["to"] is Vector3
	return (mine["to"] as Vector3).distance_to(desired["to"]) <= slack


## Everything the HUD shows: cheap change detection for element_changed, and the list of what moved, which
## the announcer uses to decide whether a decision is worth calling (Elements.element_reported).
func _snapshot() -> Dictionary:
	return {"formation": formation, "technique": technique, "drill": drill, "reason": reason,
			"leader": leader, "roster": ", ".join(Array(roster))}


func _note_changes(before: Dictionary) -> bool:
	var now := _snapshot()
	if _fresh_task:
		changed_fields.append("task")
		_fresh_task = false
	for key: String in now:
		if now[key] != before[key]:
			changed_fields.append(key)
	return not changed_fields.is_empty()


func _log(text: String) -> void:
	events.append(text)
	if events.size() > MAX_EVENTS:
		events.remove_at(0)
