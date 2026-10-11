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

## Round 26 (orders O2): his case, every armed task. Two squads selected, the task armed with its key, then the REAL
## gesture - press at a point, drag toward a second point, release - and, on arrival, the heading the crews
## actually stand on against the one he drew. Run only when asked (`--screen-only=faced_screen,...`, or `faced` for all
## five; `make facing-probe`), so the four scenarios above keep their meaning.
const FACED := {"faced_screen": KEY_E, "faced_support_by_fire": KEY_R, "faced_ambush": KEY_B,
		"faced_attack_move": KEY_A, "faced_move": KEY_M}
## The drawn facing is this far off the travel (left of it): far enough that the automatic pick (the travel, or the
## threat) cannot pass by accident at FACED_TOLERANCE_DEG.
const FACED_OFF_TRAVEL_DEG := 60.0
const FACED_WATCH_S := 75.0
const FACED_SETTLE_S := 5.0
const FACED_TOLERANCE_DEG := 15.0
## The release is drawn this far along the facing from the press (metres on the ground; at least FACING_DRAG_PX on screen).
const FACED_DRAG_M := 14.0

var out_dir := ""
var controls: RtsControls
var only: PackedStringArray = []
## Windowed runs: frames of the drag (the arrow) and the settled line go here ("" = none; headless never has frames).
var shots_dir := ""

var _results: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	if shots_dir == "" and DisplayServer.get_name() != "headless":
		shots_dir = out_dir.path_join("shots")  # a window has frames to give; the flags stay the skirmish's own
	if DisplayServer.get_name() == "headless":
		get_tree().root.size = Vector2i(1920, 1080)  # headless roots are 64x64 (trip-up 31)
	await _seconds(1.0)
	_resume()
	await _seconds(1.0)
	_resume()
	var wanted: Array = ["grouped", "ungrouped", "near", "move_after"]
	if not only.is_empty():
		wanted = []
		for name: String in only:
			if name == "faced":
				wanted.append_array(FACED.keys())
			else:
				wanted.append(name)
	for scenario: String in wanted:
		if FACED.has(scenario):
			await _faced(scenario)
		elif scenario in ["grouped", "ungrouped", "near", "move_after"]:
			await _scenario(scenario)
	var file := FileAccess.open(out_dir.path_join("screen.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_results, "  "))
	var stalled: Array = _results.filter(func(r: Dictionary) -> bool: return bool(r.get("nobody_moved", false))) \
			.map(func(r: Dictionary) -> String: return String(r["scenario"]))
	var unfaced: Array = _results.filter(func(r: Dictionary) -> bool: return r.has("faced_ok") and not bool(r["faced_ok"])) \
			.map(func(r: Dictionary) -> String: return String(r["scenario"]))
	print("SCREEN_DONE scenarios=%d nobody_moved=%s ignored_facing=%s" % [_results.size(), ",".join(stalled),
			",".join(unfaced)])
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


## O2: one armed task given by the real gesture to squads 1 and 2 together, then judged on the ground.
func _faced(scenario: String) -> void:
	var members: Array[String] = []
	for number in [1, 2]:
		for unit_name: String in controls.groups.members(number):
			if _alive(unit_name):
				members.append(unit_name)
	var row := {"scenario": scenario, "members": members.size()}
	if members.size() < 2:
		row["why"] = "squads 1 and 2 have fewer than two living crews"
		_results.append(row)
		return
	_resume()
	controls.selection.set_units(members)
	var forward: Vector3 = Match.team_frame(controls.team)["forward"]
	var centre := _centroid(members)
	var at := ElementPlan.clamp_to_arena(centre + forward * OFF_M)
	var facing := forward.rotated(Vector3.UP, deg_to_rad(FACED_OFF_TRAVEL_DEG)).normalized()
	row["at"] = [snappedf(at.x, 0.1), snappedf(at.z, 0.1)]
	row["drawn"] = [snappedf(facing.x, 0.001), snappedf(facing.z, 0.001)]
	# Look at the spot from his pose: the press must land on the ground there, the release toward the facing.
	var rig := controls.rig
	if rig != null:
		rig.focus = at
		rig.snap()
	await _key(FACED[scenario])
	row["armed"] = controls.mode
	# The vision camera keeps framing the selection, so every screen point is read from the camera of the frame it is
	# pushed in (a press read one frame early lands metres off, and the heading it draws turns with it).
	var camera := controls.camera
	if rig != null:
		rig.focus = at
		rig.snap()
	var press := camera.unproject_position(at)
	var release := camera.unproject_position(at + facing * FACED_DRAG_M)
	row["drag_px"] = snappedf(press.distance_to(release), 0.1)
	_mouse(press, true)
	for i in range(1, 7):
		_motion(press.lerp(release, i / 6.0))
	await get_tree().process_frame
	await _shot(scenario + "_1_drag")
	var spot: Variant = controls.armed_gesture().get("spot")
	if spot is Vector3:
		release = camera.unproject_position((spot as Vector3) + facing * FACED_DRAG_M)  # this frame's camera
	_motion(release)
	_mouse(release, false)
	await get_tree().process_frame
	var given := {}
	var given_way := Vector3.ZERO
	for unit_name in members:
		var element: Element = controls.elements.of(unit_name) if controls.elements != null else null
		var carried: Dictionary = element.task if element != null else controls.orders.current(unit_name)
		var way: Variant = carried.get("facing", null)
		given[String(carried.get("verb", "(none)"))] = way if way != null else "none"
		if way is Array and (way as Array).size() == 2:
			given_way = Vector3(float(way[0]), 0.0, float(way[1])).normalized()
	row["given"] = given
	row["gesture_error_deg"] = snappedf(rad_to_deg(Vector2(given_way.x, given_way.z).angle_to(Vector2(facing.x, facing.z))), 0.1) \
			if given_way != Vector3.ZERO else -1.0
	var lines := scenario in ["faced_screen", "faced_support_by_fire", "faced_ambush"]
	await _seconds(10.0)
	await _shot(scenario + "_2_moving")
	# Judged where they ended up: both squads' elements arrived (then FACED_SETTLE_S to dress), or FACED_WATCH_S.
	var waited := 10.0
	while waited < FACED_WATCH_S and not _both_arrived():
		await _seconds(1.0)
		waited += 1.0
	row["arrived_after_s"] = waited if _both_arrived() else -1.0
	await _seconds(FACED_SETTLE_S)
	if rig != null:
		rig.focus = _centroid(members)
		rig.snap()
	await get_tree().process_frame
	await _shot(scenario + "_3_settled")
	var squads := []
	var ok := true
	for number in [1, 2]:
		var crews: Array[String] = []
		for unit_name: String in controls.groups.members(number):
			if _alive(unit_name):
				crews.append(unit_name)
		var judged := _judge(crews, given_way if given_way != Vector3.ZERO else facing, lines)
		var element: Element = controls.elements.of(crews[0]) if controls.elements != null and not crews.is_empty() else null
		judged["arrived"] = bool(element.get("arrived")) if element != null else false
		squads.append(judged)
		ok = ok and bool(judged["ok"])
	row["squads"] = squads
	row["faced_ok"] = ok
	print("SCREEN %s" % JSON.stringify(row))
	_results.append(row)
	controls.order_selection("stop", {})
	await _seconds(1.0)


func _both_arrived() -> bool:
	for number in [1, 2]:
		for unit_name: String in controls.groups.members(number):
			if not _alive(unit_name):
				continue
			var element: Element = controls.elements.of(unit_name) if controls.elements != null else null
			if element == null or not bool(element.get("arrived")):
				return false
			break
	return true


## The heading a squad stands on: its hulls' mean heading, and for a line task (three or more crews) the way its line
## LOOKS (the normal of the line through them, on the facing's side). Both within FACED_TOLERANCE_DEG of the facing the
## task was GIVEN (what brains is asked to honour; the gesture's own error is `gesture_error_deg` on the row).
func _judge(crews: Array[String], facing: Vector3, lines := true) -> Dictionary:
	var heading := Vector3.ZERO
	var points: Array[Vector3] = []
	for unit_name in crews:
		var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Node3D
		var nose := -tank.global_basis.z
		heading += Vector3(nose.x, 0.0, nose.z).normalized()
		points.append(_position_of(unit_name))
	var result := {"crews": crews.size()}
	if crews.is_empty():
		result["ok"] = true
		return result
	var hull_error := rad_to_deg(Vector2(heading.x, heading.z).angle_to(Vector2(facing.x, facing.z)))
	result["hull_error_deg"] = snappedf(absf(hull_error), 0.1)
	var ok := absf(hull_error) <= FACED_TOLERANCE_DEG
	if lines and points.size() >= 3:
		var axis := _line_axis(points)
		var looks := Vector3(-axis.z, 0.0, axis.x)
		if looks.dot(facing) < 0.0:
			looks = -looks
		var line_error := rad_to_deg(Vector2(looks.x, looks.z).angle_to(Vector2(facing.x, facing.z)))
		result["line_error_deg"] = snappedf(absf(line_error), 0.1)
		result["line_spread_m"] = snappedf(_spread(points, axis), 0.1)
		ok = ok and absf(line_error) <= FACED_TOLERANCE_DEG
	result["ok"] = ok
	return result


## The principal axis of the points on the ground (their line), as a unit vector.
static func _line_axis(points: Array[Vector3]) -> Vector3:
	var mean := Vector3.ZERO
	for p in points:
		mean += p
	mean /= float(points.size())
	var xx := 0.0
	var xz := 0.0
	var zz := 0.0
	for p in points:
		var d := p - mean
		xx += d.x * d.x
		xz += d.x * d.z
		zz += d.z * d.z
	var angle := 0.5 * atan2(2.0 * xz, xx - zz)
	return Vector3(cos(angle), 0.0, sin(angle))


static func _spread(points: Array[Vector3], axis: Vector3) -> float:
	var low := INF
	var high := -INF
	for p in points:
		low = minf(low, p.dot(axis))
		high = maxf(high, p.dot(axis))
	return high - low


func _alive(unit_name: String) -> bool:
	var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
	return tank != null and tank.is_alive()


func _mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	get_viewport().push_input(event)


func _motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event)


func _shot(label: String) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(label + ".png"))


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
