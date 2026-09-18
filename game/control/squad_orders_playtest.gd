class_name SquadOrdersPlaytest
extends Node
## Round 5 reopened, top priority (the lead): *"I start the game by selecting squad 1, having them go somewhere, select
## squad 2, move them, and I do that for all squads. And in just that simple action, the units do not re-arrange as
## intended."*
##
## This is that exact sequence, through real input: press 1, right-click a spot, press 2, right-click another spot, and
## so on for every squad. Then it records, per unit, **where it was sent, where it is SETTLE seconds later, and where it
## is LATER seconds after that** — the table that tells three different bugs apart:
##
##   never moved            selection or the order path (control)
##   moved, then drifted     a brain returning to a post that isn't its order's destination (ai)
##   moved, but piled up     formation slots (control's GroupFormation) or squads sharing slots
##
## It also snapshots every squad's order after each later squad is ordered, to catch one squad's order being disturbed
## by commanding the next (selection leaking, an order hitting the wrong units, `source` mis-set).
## `--squad-orders-test=DIR` on a skirmish: prints SQUAD_ORDERS lines, writes DIR/squad_orders.json, quits.

## Seconds after the last order before the first reading, and after that before the second.
const SETTLE := 6.0
const LATER := 20.0
## A unit counts as having arrived within this far of the spot it was sent to (a formation slot is a few metres wide).
const ARRIVED_M := 14.0
## It counts as having moved at all once it is this far from where it started.
const MOVED_M := 3.0
## After a player's order finishes, ai leashes whatever the unit decides for itself to this far from the spot he sent it
## to, so it fights from cover nearby instead of chasing. Staying inside that is holding the ground he gave it.
const LEASH_M := 20.0

var out_dir := ""
var controls: RtsControls

var _rows: Array = []
var _cross_talk: Array = []
## Every command Orders accepted while the test watched: [seconds, source, verb, units, destination].
var _issues: Array = []
var _watch_from := 0.0
## How many orders actually changed while watching: this is what draws a marker and plays a cue, not the attempts.
var _changes := 0
## Acknowledgement cues played while watching (the "beeping"), sampled from the feedback system each frame.
var _cues := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	controls.orders.issued.connect(_on_issued)
	controls.orders.order_changed.connect(_on_order_changed)
	await _seconds(2.0)
	_resume()
	await _seconds(2.0)
	_resume()  # the planning pause is applied after the mode finishes building the controls
	_watch_from = Time.get_ticks_msec() / 1000.0  # count the cues the player's own clicks earn, before the idle window
	var groups: Array = controls.groups.numbers()
	var ordered := {}
	var rect := get_viewport().get_visible_rect()
	for i in groups.size():
		var number: int = groups[i]
		var members := controls.groups.members(number)
		if members.is_empty():
			continue
		# Press the number key and right-click a spot, the way a player does it. Each squad gets its own spot, spread
		# across the screen so the destinations are far apart and easy to tell from each other.
		await _key(KEY_0 + number)
		await _seconds(0.4)
		var selected := controls.selection.units.duplicate()
		var at := rect.get_center() + Vector2(rect.size.x * (-0.3 + 0.15 * i), rect.size.y * (0.25 if i % 2 == 0 else -0.25))
		await _right_click(at)
		await _seconds(0.3)
		var goals := {}
		var starts := {}
		for unit_name: String in members:
			var tank := _tank(unit_name)
			if tank == null:
				continue
			starts[unit_name] = _flat(tank.global_position)
			var goal: Variant = controls.orders.goal_position(unit_name)
			goals[unit_name] = goal if goal is Vector3 else null
		ordered[number] = {"members": members, "goals": goals, "starts": starts,
				"selected_matched": selected == members, "order_ids": _order_ids(members)}
		_step("ordered", {"squad": number, "units": members.size(), "selection_was_the_squad": selected == members,
				"units_with_a_goal": goals.values().filter(func(g: Variant) -> bool: return g != null).size()})
		# Did commanding this squad disturb the ones already ordered?
		for earlier: int in ordered:
			if earlier == number:
				continue
			var was: Dictionary = ordered[earlier]["order_ids"]
			var now := _order_ids(ordered[earlier]["members"])
			if was != now:
				_cross_talk.append({"squad": earlier, "disturbed_by": number, "before": was, "after": now})
				_step("disturbed", {"squad": earlier, "by": number})
	var cues_from_the_players_clicks := _cues
	_step("player_clicks", {"squads_ordered": ordered.size(), "acknowledgement_cues": cues_from_the_players_clicks})
	# The lead sees the order markers "repeating or re-orienting": count what is actually being issued, and by whom,
	# while nobody touches the controls.
	_watch_from = Time.get_ticks_msec() / 1000.0
	_issues.clear()
	_changes = 0
	_cues = 0
	set_process(true)
	await _seconds(SETTLE)
	var watch := _issue_tally()
	_step("issues_while_idle", watch)
	var settle := _readings(ordered)
	await _seconds(LATER)
	var later := _readings(ordered)
	for unit_name: String in settle:
		var row: Dictionary = settle[unit_name]
		row["later_at"] = later[unit_name]["at"]
		row["later_from_goal_m"] = later[unit_name]["from_goal_m"]
		row["later_from_start_m"] = later[unit_name]["from_start_m"]
		row["verdict"] = _verdict(row)
		_rows.append(row)
	var verdicts := {}
	for row: Dictionary in _rows:
		verdicts[row["verdict"]] = int(verdicts.get(row["verdict"], 0)) + 1
	watch["cues_from_the_players_clicks"] = cues_from_the_players_clicks
	var report := {"squads": ordered.size(), "units": _rows.size(), "verdicts": verdicts, "issues_while_idle": watch,
			"cross_talk": _cross_talk, "settle_seconds": SETTLE, "later_seconds": LATER}
	print("SQUAD_ORDERS_SUMMARY ", JSON.stringify(report))
	for row: Dictionary in _rows:
		print("SQUAD_ORDERS ", JSON.stringify(row))
	var file := FileAccess.open(out_dir.path_join("squad_orders.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"summary": report, "units": _rows}, "  "))
	print("SQUAD_ORDERS_DONE dir=%s" % out_dir)
	get_tree().quit(0)


## Where every ordered unit is now, against where it was sent and where it started.
func _readings(ordered: Dictionary) -> Dictionary:
	var out := {}
	for number: int in ordered:
		var entry: Dictionary = ordered[number]
		for unit_name: String in entry["members"]:
			var tank := _tank(unit_name)
			var goal: Variant = entry["goals"].get(unit_name)
			var start: Variant = entry["starts"].get(unit_name)
			var alive := tank != null and tank.is_alive()
			var at: Variant = _flat(tank.global_position) if alive else null
			out[unit_name] = {"unit": unit_name, "squad": number, "alive": alive,
					"sent_to": [roundi(goal.x), roundi(goal.z)] if goal is Vector3 else null,
					"started_at": [roundi(start.x), roundi(start.z)] if start is Vector3 else null,
					"at": [roundi(at.x), roundi(at.z)] if at is Vector3 else null,
					"from_goal_m": roundi(at.distance_to(goal)) if at is Vector3 and goal is Vector3 else -1,
					"from_start_m": roundi(at.distance_to(start)) if at is Vector3 and start is Vector3 else -1,
					"order": String(controls.orders.current(unit_name).get("verb", "")) if alive else "",
					"order_source": String(controls.orders.current(unit_name).get("source", "")) if alive else "",
					"station_m": _station_distance(unit_name, at)}
	return out


## What this unit did, in the three words that separate the three bugs.
static func _verdict(row: Dictionary) -> String:
	if not bool(row["alive"]):
		return "destroyed"
	if row["sent_to"] == null:
		return "no_goal_recorded"
	if int(row["from_start_m"]) < MOVED_M and int(row["later_from_start_m"]) < MOVED_M:
		return "never_moved"
	if int(row["later_from_goal_m"]) <= ARRIVED_M:
		return "arrived_and_stayed"
	if int(row["from_goal_m"]) <= ARRIVED_M and int(row["later_from_goal_m"]) <= LEASH_M:
		return "arrived_and_held_nearby"  # inside ai's leash: fighting from cover around the spot, not wandering off
	if int(row["from_goal_m"]) <= ARRIVED_M and int(row["later_from_goal_m"]) > LEASH_M:
		return "arrived_then_left"
	if int(row["later_from_goal_m"]) < int(row["from_goal_m"]):
		return "still_travelling"
	return "never_arrived"


func _station_distance(unit_name: String, at: Variant) -> int:
	var station: Dictionary = controls.orders.station(unit_name)
	if not station.has("position") or not (at is Vector3):
		return -1
	var spot := Vector3(float(station["position"][0]), 0.0, float(station["position"][1]))
	return roundi((at as Vector3).distance_to(spot))


func _order_ids(members: Array) -> Dictionary:
	var ids := {}
	for unit_name: String in members:
		var order := controls.orders.current(unit_name)
		ids[unit_name] = [int(order.get("id", -1)), String(order.get("verb", ""))]
	return ids


func _process(_delta: float) -> void:
	if _watch_from <= 0.0:
		return
	var fx := FxWorld.existing()
	if fx != null and fx.order_feedback != null:
		_cues += fx.order_feedback.last_acks.size()


func _on_order_changed(_unit_name: String) -> void:
	if _watch_from > 0.0:
		_changes += 1


func _on_issued(command: Dictionary) -> void:
	if _watch_from <= 0.0:
		return
	_issues.append({"at": snappedf(Time.get_ticks_msec() / 1000.0 - _watch_from, 0.01),
			"source": String(command.get("source", "")), "verb": String(command.get("verb", "")),
			"units": (command.get("units", []) as Array).size(),
			"to": command.get("to"), "target": command.get("target", "")})


## How many orders were issued while nobody was touching the controls, by whom and for what.
func _issue_tally() -> Dictionary:
	var by_source := {}
	var by_verb := {}
	var per_unit := 0
	for issue: Dictionary in _issues:
		var key := "%s|%s" % [issue["source"], issue["verb"]]
		by_source[issue["source"]] = int(by_source.get(issue["source"], 0)) + 1
		by_verb[key] = int(by_verb.get(key, 0)) + 1
		per_unit += int(issue["units"])
	return {"seconds": SETTLE, "commands": _issues.size(), "unit_orders": per_unit, "order_changes": _changes, "acknowledgement_cues": _cues,
			"changes_per_second": snappedf(_changes / SETTLE, 0.1), "by_source": by_source,
			"by_verb": by_verb, "first": _issues.slice(0, 5)}


# ---- helpers -------------------------------------------------------------------------------------------------

func _resume() -> void:
	if get_tree().paused:
		controls.set_paused(false, "")


static func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)


func _tank(unit_name: String) -> Tank:
	return controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank


func _step(step_name: String, data: Dictionary) -> void:
	data["step"] = step_name
	print("SQUAD_ORDERS ", JSON.stringify(data))


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame


func _right_click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event)
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
