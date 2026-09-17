class_name DiscoveryBridge
extends Node
## Round-5 X5 (ai): groundwork for OFFLINE tactics discovery. The lead (round 4): *"a local, offline simulation of our
## game that we could plug into an AI brain … not for the purpose of live gameplay, but for the purpose of discovering
## novel tactics … and somehow formalizing those discoveries into deterministic heuristics."* Nothing here ever runs
## in live play: it exists only with --<side>-discovery, in a headless match an external process drives.
##
## One side's ELEMENTS take their tasks from an external decision-maker on a slow cadence, in lockstep: every
## `every_ticks` the match stops, prints what that side knows, and waits for one line of decisions on stdin before it
## simulates another tick. So a slow thinker (a script, a search, a language model) is never "late", and the same
## seed with the same decisions replays the same match. Everything below the task — formations, drills, the brains —
## is the shared library, exactly as for a player.
##
##   stdout:  DISCOVERY_STATE {"step", "tick", "seconds", "team", "score", "control", "elements": [...], "contacts": [...],
##                             "lanes": [...], "regions": [...]}
##   stdin:   {"tasks": [{"element": <id>, "verb": ..., "to": [x, z], "target": name}, ...]}   (one line; {} = no change)
##   stdout:  DISCOVERY_ERROR <reason>   for a task that doesn't validate (the rest still apply)
##   log:     one JSON line per decision: {"state", "decision", "outcome"} where outcome is what the next
##            `every_ticks` did to both sides (hull + shield lost, units lost, the control point), per element too.
##
## The observation is the side's own knowledge only (its team intel), never the true positions of the enemy.

const DEFAULT_EVERY_SECONDS := 5.0

var game_match: Match
var team := Match.Team.RUST
var elements: Elements
var every_ticks := int(DEFAULT_EVERY_SECONDS * 60)
var log_path := ""

var _step := 0
var _log: FileAccess
var _open_step: Dictionary = {}
var _stdin_buffer := ""


static func install(p_match: Match, p_team: int, p_elements: Elements, every_seconds: float, p_log_path: String) -> DiscoveryBridge:
	var bridge := DiscoveryBridge.new()
	bridge.name = "DiscoveryBridge_%d" % p_team
	bridge.game_match = p_match
	bridge.team = p_team
	bridge.elements = p_elements
	bridge.every_ticks = maxi(1, roundi(every_seconds * 60.0))
	bridge.log_path = p_log_path
	p_match.finished.connect(bridge._on_finished)
	p_match.add_child(bridge)
	return bridge


func _ready() -> void:
	# Before the elements plan this tick, so a decision acts at once.
	process_physics_priority = Elements.PRIORITY - 2
	if log_path != "":
		_log = FileAccess.open(log_path, FileAccess.WRITE)
		if _log == null:
			push_error("discovery: cannot write %s" % log_path)


func _physics_process(_delta: float) -> void:
	if game_match == null or game_match.tick % every_ticks != 0:
		return
	_close_step()
	if elements.of_team(team).is_empty():
		_form()
	var state := observe()
	print("DISCOVERY_STATE " + JSON.stringify(state))
	var decision := _read_decision()
	for error in apply(decision):
		print("DISCOVERY_ERROR " + error)
	_open_step = {"state": state, "decision": decision, "before": _tally()}
	_step += 1


## One element per squad (the same grouping the ElementCommander uses).
func _form() -> void:
	for squad: Squad in game_match.team_squads(team):
		var roster: Array = []
		for unit_name in squad.roster:
			var tank := AiTickCache.tanks_by_name(game_match).get(unit_name) as Tank
			if tank != null and tank.is_alive() and elements.of(unit_name) == null:
				roster.append(unit_name)
		if not roster.is_empty():
			elements.form(roster, squad.squad_name)


## What this side knows, compactly: its elements and its intel, never the enemy's true state.
func observe() -> Dictionary:
	var own: Array = []
	var tanks := AiTickCache.tanks_by_name(game_match)
	for element: Element in elements.of_team(team):
		var hp := 0.0
		var full := 0.0
		var center := Vector3.ZERO
		var alive := 0
		for unit_name in element.members():
			var tank := tanks.get(unit_name) as Tank
			if tank == null or not tank.is_alive():
				continue
			alive += 1
			center += tank.global_position
			hp += tank.health + tank.shield
			full += tank.max_health + tank.max_shield
		if alive == 0:
			continue
		center /= alive
		own.append({"id": element.id, "name": element.element_name, "units": alive,
				"roles": _roles(element.members()), "at": _xz(center), "strength": snappedf(hp / maxf(full, 1.0), 0.01),
				"task": element.task, "formation": element.formation, "technique": element.technique, "drill": element.drill})
	var contacts: Array = []
	var intel: Dictionary = game_match.intel[team]
	for contact_name: String in AiTickCache.intel_names(game_match, team):
		var known: Dictionary = intel[contact_name]
		contacts.append({"name": contact_name, "unit": String(known.get("unit", "")),
				"role": Units.role_of(String(known.get("unit", ""))) if Units.exists(String(known.get("unit", ""))) else "",
				"at": _xz(known["position"]), "visible": bool(known["visible"]),
				"age_seconds": snappedf((game_match.tick - int(known["seen_tick"])) / 60.0, 0.1)})
	var lanes: Array = []
	for lane: Dictionary in Arena.lanes_of(Arena.active):
		var points: Array = []
		for point: Vector3 in lane["points"]:
			points.append(_xz(point))
		lanes.append({"name": lane["name"], "points": points})
	var regions: Array = []
	for region: Dictionary in Arena.regions_of(Arena.active):
		regions.append({"name": region["name"], "kind": region["kind"], "at": _xz(region["position"])})
	return {"step": _step, "tick": game_match.tick, "seconds": snappedf(game_match.tick / 60.0, 0.1), "team": team,
			"score": [game_match.score_green, game_match.score_rust],
			"control": {"at": _xz(Match.CONTROL_CENTER), "owner": game_match.control_owner} if game_match.control_point else null,
			"elements": own, "contacts": contacts, "lanes": lanes, "regions": regions,
			"half_size": float(Arena.active.get("half_size", 120.0))}


## Apply one decision; returns the reasons any task was refused.
func apply(decision: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var tasks: Variant = decision.get("tasks", [])
	if typeof(tasks) != TYPE_ARRAY:
		errors.append("'tasks' must be a list")
		return errors
	for entry: Variant in tasks:
		if typeof(entry) != TYPE_DICTIONARY or not (entry as Dictionary).has("element"):
			errors.append("each task needs an 'element' id")
			continue
		var element := elements.get_element(int((entry as Dictionary)["element"]))
		if element == null or element.team != team:
			errors.append("no element %s on this side" % str((entry as Dictionary)["element"]))
			continue
		var task := (entry as Dictionary).duplicate()
		task.erase("element")
		var error := element.assign(task)
		if error != "":
			errors.append("element %d: %s" % [element.id, error])
	return errors


func _read_decision() -> Dictionary:
	# Blocks until the decision-maker answers: lockstep, so a slow thinker is never late. Godot hands back a line
	# WITHOUT its newline, so a read that parses as a whole JSON object is a whole decision.
	while not _stdin_buffer.contains("\n"):
		var chunk := OS.read_string_from_stdin(65536)
		if chunk == "":
			return {}  # stdin closed: nobody is deciding, so the tasks stand
		_stdin_buffer += chunk
		if not _stdin_buffer.contains("\n") and JSON.parse_string(_stdin_buffer) is Dictionary:
			_stdin_buffer += "\n"
	var line := _stdin_buffer.get_slice("\n", 0)
	_stdin_buffer = _stdin_buffer.substr(line.length() + 1)
	var parsed: Variant = JSON.parse_string(line)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("DISCOVERY_ERROR not a JSON object: %s" % line.left(120))
		return {}
	return parsed


## Both sides' hull + shield and living units, and each of our elements' own, right now.
func _tally() -> Dictionary:
	var sides := [{"hp": 0.0, "units": 0}, {"hp": 0.0, "units": 0}]
	for side in 2:
		for tank: Tank in game_match.sorted_team_tanks(side):
			if tank.is_alive():
				sides[side]["hp"] += tank.health + tank.shield
				sides[side]["units"] += 1
	var by_element := {}
	var tanks := AiTickCache.tanks_by_name(game_match)
	for element: Element in elements.of_team(team):
		var hp := 0.0
		for unit_name in element.members():
			var tank := tanks.get(unit_name) as Tank
			if tank != null and tank.is_alive():
				hp += tank.health + tank.shield
		by_element[str(element.id)] = hp
	return {"sides": sides, "elements": by_element, "control": game_match.control_owner if game_match.control_point else -1,
			"tick": game_match.tick}


## Write the decision that just played out with what it did.
func _close_step() -> void:
	if _open_step.is_empty():
		return
	var before: Dictionary = _open_step["before"]
	var after := _tally()
	var us := team
	var them := 1 - team
	var element_loss := {}
	for key: String in before["elements"]:
		element_loss[key] = snappedf(float(before["elements"][key]) - float(after["elements"].get(key, 0.0)), 0.1)
	var outcome := {"seconds": snappedf((after["tick"] - before["tick"]) / 60.0, 0.1),
			"our_loss": snappedf(before["sides"][us]["hp"] - after["sides"][us]["hp"], 0.1),
			"their_loss": snappedf(before["sides"][them]["hp"] - after["sides"][them]["hp"], 0.1),
			"our_units_lost": before["sides"][us]["units"] - after["sides"][us]["units"],
			"their_units_lost": before["sides"][them]["units"] - after["sides"][them]["units"],
			"control_before": before["control"], "control_after": after["control"], "element_loss": element_loss}
	if _log != null:
		_log.store_line(JSON.stringify({"state": _open_step["state"], "decision": _open_step["decision"], "outcome": outcome}))
		_log.flush()
	_open_step = {}


func _on_finished(result: Dictionary) -> void:
	_close_step()
	if _log != null:
		_log.store_line(JSON.stringify({"result": {"winner": result.get("winner", ""), "reason": result.get("reason", ""),
				"duration_seconds": result.get("duration_seconds", 0.0), "team": team}}))
		_log.flush()
	print("DISCOVERY_DONE winner=%s" % str(result.get("winner", "")))


func _roles(names: PackedStringArray) -> Array:
	var roles: Array = []
	var tanks := AiTickCache.tanks_by_name(game_match)
	for unit_name in names:
		var tank := tanks.get(unit_name) as Tank
		if tank != null and tank.is_alive():
			roles.append(Units.role_of(tank.unit_id))
	return roles


static func _xz(point: Vector3) -> Array:
	return [snappedf(point.x, 0.1), snappedf(point.z, 0.1)]
