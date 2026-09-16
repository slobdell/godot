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
const UPDATE_TICKS := 6
## A unit's goal has to move this far before its order is re-issued: every new order resets what its brain
## was doing (round-3 lesson), so the leader does not nudge people around.
const REISSUE_M := 8.0
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
var events: PackedStringArray = []

## Plan state carried between updates.
var anchor: Variant = null
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
	# A new task starts a new movement: forget the leg and any drill we were running.
	anchor = null
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
	var before := _fingerprint()
	_prune(game_match)
	_adopt(orders)
	var commanded := _commanded_members()
	if commanded.is_empty():
		return before != _fingerprint()
	var situation := ElementSituation.build(game_match, team, commanded, leader,
			{"heading": heading, "arrived": arrived, "known": _known})
	_known = situation["known"]
	var state := {"task": task, "drill": drill, "drill_tick": drill_tick, "drill_point": drill_point,
			"drill_target": drill_target, "drill_why": reason, "anchor": anchor, "bounding": bounding,
			"arrived": arrived, "heading": heading}
	var plan := ElementPlan.build(situation, state, _doctrine())
	_take(plan, situation)
	_issue(plan, orders, situation)
	return before != _fingerprint()


## What the HUD reads (L1: read-only).
func state() -> Dictionary:
	return {"id": id, "name": element_name, "team": team, "leader": leader, "members": members(),
			"task": task.duplicate(true), "formation": formation, "technique": technique, "drill": drill,
			"reason": reason, "slots": slots.duplicate(), "sectors": sectors.duplicate(),
			"detached": _detached.keys(), "events": events}


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
	var new_drill := String(plan["drill"])
	if new_drill != drill:
		drill = new_drill
		drill_tick = int(situation["tick"])
		drill_point = null
		if drill != "":
			drill_point = _drill_focus(plan, situation)
			drill_target = String(Drills.nearest_contact(situation).get("name", ""))
			_log("drill: %s" % drill.replace("_", " "))
		revision += 1


static func _drill_focus(plan: Dictionary, situation: Dictionary) -> Variant:
	var contact := Drills.nearest_contact(situation)
	if not contact.is_empty():
		return contact["position"]
	return plan.get("anchor")


## Turn the plan into K1 commands, issuing only what actually changed.
func _issue(plan: Dictionary, orders: Object, situation: Dictionary) -> void:
	if orders == null:
		return
	var positions := {}
	for member: Dictionary in situation["members"]:
		positions[String(member["name"])] = member["position"]
	var names: Array = (plan["orders"] as Dictionary).keys()
	names.sort()
	for unit_name: String in names:
		if _detached.has(unit_name):
			continue
		var desired: Dictionary = plan["orders"][unit_name]
		var current: Dictionary = orders.call("current", unit_name)
		if not _should_issue(unit_name, desired, current, positions.get(unit_name, Vector3.ZERO)):
			continue
		var command := {"units": [unit_name], "verb": String(desired["verb"])}
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
		_issued[unit_name] = {"id": int(issued.get("id", -1)), "verb": command["verb"],
				"to": desired["to"], "target": String(desired.get("target", ""))}


func _should_issue(unit_name: String, desired: Dictionary, current: Dictionary, position: Vector3) -> bool:
	var mine: Dictionary = _issued.get(unit_name, {})
	if current.is_empty():
		# Idle: only wake it up if there is somewhere else to be, or something new to do.
		if desired["to"] is Vector3 and position.distance_to(desired["to"]) > SETTLED_M:
			return true
		if String(desired["verb"]) in ["attack", "attack_move"] and String(desired.get("target", "")) != "":
			return String(mine.get("target", "")) != String(desired["target"])
		return mine.is_empty() and String(desired["verb"]) != "hold"
	if mine.is_empty() or int(current.get("id", -1)) != int(mine.get("id", -2)):
		return false  # not ours to change
	if String(mine["verb"]) != String(desired["verb"]) or String(mine.get("target", "")) != String(desired.get("target", "")):
		return true
	if desired["to"] is Vector3 and mine["to"] is Vector3:
		return (mine["to"] as Vector3).distance_to(desired["to"]) > REISSUE_M
	return desired["to"] is Vector3 != mine["to"] is Vector3


## Everything the HUD shows, as one string: cheap change detection for element_changed.
func _fingerprint() -> String:
	return "%d|%s|%s|%s|%s|%s|%s" % [revision, formation, technique, drill, reason, leader,
			", ".join(Array(roster))]


func _log(text: String) -> void:
	events.append(text)
	if events.size() > MAX_EVENTS:
		events.remove_at(0)
