class_name RepathPlaytest
extends Node
## Round 10 (control item 1; contract R2). The lead, on Terminus: *"I had a selection and the yellow X's on the map were
## in the center, that's where they were driving to, and I was trying to right click to move them in a different
## direction and they didnt respond."*
##
## His situation on the default skirmish path, through real input: squad 1 is sent somewhere (a move, an attack-move,
## a base of fire), and three seconds later he right-clicks somewhere else. Then, per physics tick, per crew, what
## Orders says that crew is CARRYING OUT (lesson 183: log what was issued, not what was intended): the order id, verb,
## source and goal, the element's task, and every order Orders dropped as a repeat. The verdict per crew is:
##
##   new       its order changed within RESPONSE_TICKS of the click
##   follows   it follows (K1 follow) a crew whose order changed: the column turns with its leader
##   STALE     neither: the click did not reach this crew
##
## Variants of the in-flight state, one per way the brief suspects a click can be swallowed: a squad move, an
## attack-move (the yellow pin), a support-by-fire task, an armed card command (whose right press is spent on the
## cancel: the NEXT press must issue), a right-drag facing, a click 5 m from the last one, and a squad that has arrived.
## `--repath-test=DIR` on a skirmish: prints REPATH lines, writes DIR/repath.json, prints REPATH_DONE ok=..., quits.

## R2: every crew's order changes within this many physics ticks of the click.
const RESPONSE_TICKS := 2
## How far off the squad's line the second click lands (the brief: 20-60 m; 40 m is the test).
const OFF_LINE_M := 40.0
## How long the first order runs before the second click.
const EN_ROUTE_S := 3.0
## Ticks logged after each click.
const LOG_TICKS := 8
## B7: a crew shows visible intent (moves or turns, ResponsePlaytest's thresholds) within this long of the order.
const VISIBLE_S := 1.0

var out_dir := ""
var controls: RtsControls
## Scenario names to run (empty: all of them).
var only: PackedStringArray = []

var _dropped: Array = []
var _results: Array = []
## While a click is being logged: the tick each unit's current order first changed, and the tick the controls issued.
var _changed := {}
var _issued_tick := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	if DisplayServer.get_name() == "headless":
		get_tree().root.size = Vector2i(1920, 1080)  # headless roots are 64x64 (trip-up 31)
	if controls.orders.has_signal("deduplicated"):  # guarded so the harness also runs against pre-R2 Orders (A/B)
		controls.orders.connect("deduplicated", func(unit_name: String, order: Dictionary) -> void:
			_dropped.append({"tick": controls.game_match.tick, "unit": unit_name, "verb": order.get("verb", ""),
					"source": order.get("source", ""), "goal": order.get("goal", [])}))
	controls.orders.order_changed.connect(func(unit_name: String) -> void:
		if not _changed.has(unit_name):
			_changed[unit_name] = controls.game_match.tick)
	controls.command_issued.connect(func(_command: Dictionary, _error: String) -> void:
		if _issued_tick < 0:
			_issued_tick = controls.game_match.tick)
	await _seconds(1.0)
	_resume()
	await _seconds(1.0)
	_resume()  # the planning pause is applied after the mode finishes building the controls
	var scenarios := ["move", "attack_move", "support_by_fire", "armed", "facing_drag", "near", "arrived"]
	for scenario: String in scenarios:
		if not only.is_empty() and not only.has(scenario):
			continue
		await _scenario(scenario)
	var ok := not _results.is_empty() and _results.all(func(r: Dictionary) -> bool: return bool(r["ok"]))
	var file := FileAccess.open(out_dir.path_join("repath.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_results, "  "))
	var failed: Array = _results.filter(func(r: Dictionary) -> bool: return not bool(r["ok"])).map(
			func(r: Dictionary) -> String: return String(r["scenario"]))
	print("REPATH_DONE ok=%s scenarios=%d failed=%s" % [ok, _results.size(), ",".join(failed)])
	get_tree().quit(0 if ok else 1)


func _scenario(scenario: String) -> void:
	await _key(KEY_1)
	await _seconds(0.3)
	var members: Array = controls.selection.units.duplicate()
	if members.is_empty():
		_results.append({"scenario": scenario, "ok": false, "why": "squad 1 has no living members"})
		return
	var start := _centroid(members)
	# The first order: toward the arena's middle (where his yellow pins were), from wherever the squad now stands.
	var toward := Vector3(-start.x, 0.0, -start.z)
	if toward.length() < 20.0:
		toward = Vector3(0.0, 0.0, -1.0) * 40.0
	var first := start + toward.limit_length(60.0)
	if scenario == "arrived":
		first = start + toward.normalized() * 15.0
	match scenario:
		"attack_move":
			await _key(KEY_A)
			await _left_click_world(first)
		"support_by_fire":
			await _key(KEY_R)
			await _left_click_world(first)
		_:
			await _right_click_world(first)
	await _seconds(15.0 if scenario == "arrived" else EN_ROUTE_S)
	var now := _centroid(members)
	var line := (first - start).normalized()
	var across := Vector3(-line.z, 0.0, line.x)
	var second := Orders.clamp_to_arena(now + across * OFF_LINE_M + line * 10.0)
	if scenario == "near":
		second = Orders.clamp_to_arena(first + across * 5.0)
	var element := controls.elements.of(members[0]) if controls.elements != null else null
	var before := _snapshot(members)
	var task_before: Dictionary = element.task.duplicate(true) if element != null else {}
	var row := {"scenario": scenario, "members": members, "first": _xz(first), "second": _xz(second),
			"task_before": task_before, "orders_before": before}
	if scenario == "armed":
		await _key(KEY_R)  # a card command armed and forgotten: this right press is spent cancelling it
		row["armed_mode"] = controls.mode
		var spent := await _click_and_log(members, second, "right", before)
		row["spent_press"] = spent
		before = _snapshot(members)
	var how := "drag" if scenario == "facing_drag" else "right"
	var log := await _click_and_log(members, second, how, before)
	row.merge(log)
	element = controls.elements.of(members[0]) if controls.elements != null else null
	row["task_after"] = element.task.duplicate(true) if element != null else {}
	row["ok"] = log["verdicts"].values().all(func(v: String) -> bool: return v != "STALE")
	_results.append(row)
	print("REPATH ", JSON.stringify({"scenario": scenario, "ok": row["ok"], "verdicts": log["verdicts"],
			"click_tick": log["click_tick"], "via": log["via"], "dropped": log["dropped"].size(),
			"visible_1s": "%d/%d" % [(log["visible_1s"] as Dictionary).values().count(true), members.size()],
			"task_before": task_before.get("verb", ""), "task_after": (row["task_after"] as Dictionary).get("verb", ""),
			"armed_spent": row.get("spent_press", {}).get("verdicts", {})}))
	# Leave the squad standing still for the next scenario.
	await _key(KEY_S)
	await _seconds(1.5)


## Click `at` (right press and release, or a right drag across it), then log every crew per tick. Returns the log.
func _click_and_log(members: Array, at: Vector3, how: String, before: Dictionary) -> Dictionary:
	_dropped.clear()
	var via := await _aim(at)
	var click_tick := controls.game_match.tick
	_changed.clear()
	_issued_tick = -1
	if via == "screen":
		var screen := controls.camera.unproject_position(at)
		if how == "drag":
			await _right_drag(screen, screen + Vector2(160, 0))
		else:
			await _right_click(screen)
	else:
		controls.world_order(at)
	var ticks: Array = []
	var verdicts := {}
	var changed_at := {}
	var poses := _poses(members)
	# The response is counted from the tick the controls ISSUED (the input frame), which is what R2 promises; on a
	# slow headless machine one process frame can span several physics ticks, so the click's own tick is logged too.
	var issued := _issued_tick if _issued_tick >= 0 else click_tick
	while controls.game_match.tick - issued <= LOG_TICKS:
		ticks.append({"tick": controls.game_match.tick, "orders": _snapshot(members)})
		await get_tree().physics_frame
	var final := _snapshot(members)
	# B7's second half (squad's): within a second of the order every crew shows visible intent. Reported, not judged.
	while controls.game_match.tick - issued < SimClock.TICK_RATE * VISIBLE_S:
		await get_tree().physics_frame
	var visible := {}
	var later := _poses(members)
	for unit_name: String in members:
		if poses.has(unit_name) and later.has(unit_name):
			var moved: float = (later[unit_name][0] as Vector3).distance_to(poses[unit_name][0])
			var turned := rad_to_deg(absf(angle_difference(float(later[unit_name][1]), float(poses[unit_name][1]))))
			visible[unit_name] = moved >= ResponsePlaytest.MOVED_M or turned >= ResponsePlaytest.TURNED_DEG
	for unit_name: String in members:
		if _changed.has(unit_name) and int(final[unit_name]["id"]) != int(before[unit_name]["id"]):
			changed_at[unit_name] = int(_changed[unit_name]) - issued
		if changed_at.get(unit_name, 1 << 20) <= RESPONSE_TICKS:
			verdicts[unit_name] = "new"
	for unit_name: String in members:
		if verdicts.has(unit_name):
			continue
		var order: Dictionary = final[unit_name]
		var leader := String(order.get("target", ""))
		verdicts[unit_name] = "follows" if String(order["verb"]) == "follow" and verdicts.get(leader, "") == "new" else "STALE"
	return {"click_tick": click_tick, "issued_tick": _issued_tick, "via": via, "visible_1s": visible, "ticks": ticks, "verdicts": verdicts,
			"changed_after_ticks": changed_at, "dropped": _dropped.duplicate(true)}


## {unit: [flat position, yaw]} for the living members.
func _poses(members: Array) -> Dictionary:
	var result := {}
	for unit_name: String in members:
		var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null and tank.is_alive():
			result[unit_name] = [Vector3(tank.global_position.x, 0.0, tank.global_position.z), tank.global_rotation.y]
	return result


func _snapshot(members: Array) -> Dictionary:
	var result := {}
	for unit_name: String in members:
		var order := controls.orders.current(unit_name)
		result[unit_name] = {"id": int(order.get("id", -1)), "verb": String(order.get("verb", "")),
				"source": String(order.get("source", "")), "goal": order.get("goal", []),
				"target": String(order.get("target", ""))}
	return result


## Put `at` on screen the way a player would (pan to it). "screen" when a click there lands on that ground, else
## "radar" (the same order_selection path, through the minimap's world_order).
func _aim(at: Vector3) -> String:
	if controls.rig != null:
		controls.rig.focus_on(at)
		controls.rig.snap()
	await get_tree().process_frame
	await get_tree().process_frame
	var screen := controls.camera.unproject_position(at)
	var rect := get_viewport().get_visible_rect().grow(-40.0)
	if controls.camera.is_position_behind(at) or not rect.has_point(screen):
		return "radar"
	var ground: Variant = controls.screen_to_world(screen)
	if ground == null or (ground as Vector3).distance_to(Orders.clamp_to_arena(at)) > 3.0:
		return "radar"
	return "screen"


func _right_click_world(at: Vector3) -> void:
	if await _aim(at) == "screen":
		await _right_click(controls.camera.unproject_position(at))
	else:
		controls.world_order(at)


func _left_click_world(at: Vector3) -> void:
	if await _aim(at) == "screen":
		await _left_click(controls.camera.unproject_position(at))
	else:
		controls.armed_world_order(at)


func _centroid(members: Array) -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for unit_name: String in members:
		var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null and tank.is_alive():
			sum += Vector3(tank.global_position.x, 0.0, tank.global_position.z)
			count += 1
	return sum / maxf(count, 1.0)


static func _xz(point: Vector3) -> Array:
	return [snappedf(point.x, 0.1), snappedf(point.z, 0.1)]


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


func _button(at: Vector2, index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = at
	event.global_position = at
	get_viewport().push_input(event)


func _right_click(at: Vector2) -> void:
	_button(at, MOUSE_BUTTON_RIGHT, true)
	_button(at, MOUSE_BUTTON_RIGHT, false)
	await get_tree().process_frame


func _left_click(at: Vector2) -> void:
	_button(at, MOUSE_BUTTON_LEFT, true)
	_button(at, MOUSE_BUTTON_LEFT, false)
	await get_tree().process_frame


func _right_drag(from: Vector2, to: Vector2) -> void:
	_button(from, MOUSE_BUTTON_RIGHT, true)
	for i in range(1, 6):
		var event := InputEventMouseMotion.new()
		event.position = from.lerp(to, i / 5.0)
		event.global_position = event.position
		event.button_mask = MOUSE_BUTTON_MASK_RIGHT
		get_viewport().push_input(event)
	_button(to, MOUSE_BUTTON_RIGHT, false)
	await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
