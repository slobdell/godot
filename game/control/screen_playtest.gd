class_name ScreenPlaytest
extends Node
## Round 11 follow-up. The lead, playing the merged build (2026-09-24): *"I also noticed a bug where I had a group of
## trucks and I commanded them to go and screen to a certain point and they did nothing. I could still just tell them
## to move though."*
##
## Reading the code found several places a task CAN be swallowed and no way to tell which one did it, so this rides a
## real skirmish through real input and reports the facts instead:
##
##   1. **grouped** — squad 1 (a control group, so `can_task()` is true), Screen armed with E, left-click a point
##      60 m off. This is the path his words describe if "group of trucks" means a control group.
##   2. **ungrouped** — the same crews selected by name with NO control group, then Screen. The arm should REFUSE and
##      say why (round 10's R1); if it silently does nothing, that is the bug.
##   3. **near** — grouped, but the point is 20 m away, inside `Drills.SCREEN_REACHED_M` (30 m), where the element
##      plans "on the line" rather than a march. A player cannot know about a 30 m threshold, so if this stands still
##      it is a defect whatever the doctrine intends.
##   4. **move_after** — his own control: a plain move to the same point, which he reports DOES work.
##
## Per scenario it prints what the controls returned (a refusal or ""), the element's task, drill and reason, the
## order each crew is CARRYING (lesson 183: what was issued, not what was intended), and how far each hull actually
## travelled. `--screen-test=DIR` on a skirmish: prints SCREEN lines, writes DIR/screen.json, prints SCREEN_DONE.

## How far off the squad's centre the screened point lands, and the near variant's distance.
const OFF_M := 60.0
const NEAR_M := 20.0
## How long to watch after the order before judging "nothing happened".
const WATCH_S := 8.0
## A hull that travels less than this in WATCH_S did nothing a player would call moving.
const MOVED_M := 3.0

var out_dir := ""
var controls: RtsControls
var only: PackedStringArray = []

var _results: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	if DisplayServer.get_name() == "headless":
		get_tree().root.size = Vector2i(1920, 1080)  # headless roots are 64x64 (trip-up 31)
	await _seconds(1.0)
	_resume()
	await _seconds(1.0)
	_resume()
	for scenario: String in ["grouped", "ungrouped", "near", "move_after"]:
		if not only.is_empty() and not only.has(scenario):
			continue
		await _scenario(scenario)
	var file := FileAccess.open(out_dir.path_join("screen.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_results, "  "))
	var stalled: Array = _results.filter(func(r: Dictionary) -> bool: return bool(r.get("nobody_moved", false))) \
			.map(func(r: Dictionary) -> String: return String(r["scenario"]))
	print("SCREEN_DONE scenarios=%d nobody_moved=%s" % [_results.size(), ",".join(stalled)])
	get_tree().quit(0)


func _scenario(scenario: String) -> void:
	await _key(KEY_1)  # select squad 1 (a control group: this is what makes a task possible at all)
	await _seconds(0.3)
	var members: Array = controls.selection.units.duplicate()
	if members.is_empty():
		_results.append({"scenario": scenario, "why": "squad 1 has no living members"})
		return
	if scenario == "ungrouped":
		# The same crews, selected directly, belonging to no control group: what a box-select gives him.
		controls.groups.save(1, [])
		controls.selection.units = members.duplicate()
	var centre := _centroid(members)
	var reach := NEAR_M if scenario == "near" else OFF_M
	var at := ElementPlan.clamp_to_arena(centre + Vector3(reach, 0.0, 0.0))
	var before := {}
	for unit_name: String in members:
		before[unit_name] = _position_of(unit_name)

	_resume()
	var row := {"scenario": scenario, "members": members.size(), "paused": get_tree().paused,
			"centre": [snappedf(centre.x, 0.1), snappedf(centre.z, 0.1)],
			"at": [snappedf(at.x, 0.1), snappedf(at.z, 0.1)],
			"distance_m": snappedf(Vector2(centre.x, centre.z).distance_to(Vector2(at.x, at.z)), 0.1),
			"screen_reached_m": Drills.SCREEN_REACHED_M,
			"can_task": controls.can_task(), "selected_group": controls.selected_group(),
			"task_refusal": controls.task_refusal()}

	var verb := "move" if scenario == "move_after" else "screen"
	row["verb"] = verb
	# Through the real call the armed click makes, so the input guards are exercised rather than bypassed.
	row["returned"] = controls.order_selection(verb, {"to": [at.x, at.z]})

	var element: Object = controls.elements.of(String(members[0])) if controls.elements != null else null
	row["element_formed"] = element != null
	if element != null:
		row["task_at_issue"] = str(element.get("task"))

	var tick_before: int = controls.game_match.tick
	await _seconds(WATCH_S)
	row["ticks_elapsed"] = controls.game_match.tick - tick_before
	if element != null:
		row["task_after"] = str(element.get("task"))
		row["drill"] = String(element.get("drill"))
		row["reason"] = String(element.get("reason"))
		row["arrived"] = bool(element.get("arrived"))
		row["anchor"] = str(element.get("anchor"))
	var moved := {}
	var carrying := {}
	var any := false
	for unit_name: String in members:
		var travelled: float = (before[unit_name] as Vector3).distance_to(_position_of(unit_name))
		moved[unit_name] = snappedf(travelled, 0.1)
		if travelled >= MOVED_M:
			any = true
		var current: Dictionary = controls.orders.call("current", unit_name)
		var tank: Node3D = controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Node3D
		var mover: Dictionary = Movement.state(tank) if tank != null else {}
		carrying[unit_name] = "%s src=%s phase=%s by=%s" % [String(current.get("verb", "(none)")),
				String(current.get("source", "-")), String(mover.get("phase", "-")),
				String(mover.get("blocked_by", ""))]
	row["moved_m"] = moved
	row["carrying"] = carrying
	row["nobody_moved"] = not any
	print("SCREEN %s" % JSON.stringify(row))
	_results.append(row)
	# Put them back under one order so the next scenario starts from rest, not mid-manoeuvre.
	controls.order_selection("stop", {})
	await _seconds(1.0)


func _position_of(unit_name: String) -> Vector3:
	var tank: Node3D = controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Node3D
	return tank.global_position if tank != null else Vector3.ZERO


func _centroid(members: Array) -> Vector3:
	var sum := Vector3.ZERO
	for unit_name: String in members:
		sum += _position_of(unit_name)
	return sum / maxf(1.0, float(members.size()))


func _resume() -> void:
	if get_tree().paused:
		controls.set_paused(false, "")


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)
	await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
