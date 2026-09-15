class_name ControlPlaytest
extends Node
## Control X7: a scripted player session through the real input pipeline (Viewport.push_input), for
## `make control-playtest` (headless, log only) and `make control-playtest-shots` (windowed, screenshots).
##   1 box-select the first group          4 save a group, swap groups, double tap to center
##   2 attack-move it across the arena      5 a unit pushed away from its group drives back to it
##   3 queue a route with shift-clicks
## Every order's response is logged to orders.jsonl: the tick it was issued and the first tick the unit's tracks
## steered toward it (the K1 response guarantee: within 3 ticks). Prints CONTROL_PLAYTEST lines and
## CONTROL_PLAYTEST_DONE ok=<bool> at the end, then quits (exit 1 when a check failed).

const RESPONSE_TICKS := 3
## A pushed unit must be back within this distance of its station after REJOIN_SECONDS.
const REJOIN_DISTANCE := 6.0
const REJOIN_SECONDS := 10.0

var controls: RtsControls
var radar: Radar
var out_dir := ""

var _can_capture := false
var _log: FileAccess
## unit name -> {"verb", "issued_tick", "goal": Vector3 | null, "target": String}: orders waiting for a response.
var _waiting := {}
var _responses: Array = []
var _checks := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 10  # after controllers (-10) wrote this tick's commands


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_log = FileAccess.open(out_dir.path_join("orders.jsonl"), FileAccess.WRITE)
	_can_capture = DisplayServer.get_name() != "headless"
	if not _can_capture:
		get_tree().root.size = Vector2i(1280, 720)  # headless roots are 64×64 (trip-up 31)
	controls.orders.order_changed.connect(_on_order_changed)
	var tree := get_tree()
	await tree.create_timer(1.0).timeout
	await _capture("0_start")
	await _box_select()
	await _attack_move()
	await _queued_route()
	await _group_swap()
	await _rejoin()
	var slow := _responses.filter(func(r: Dictionary) -> bool: return int(r["ticks"]) < 0 or int(r["ticks"]) > RESPONSE_TICKS)
	_checks["every_order_responded_within_3_ticks"] = slow.is_empty() and not _responses.is_empty()
	var worst := 0
	for response: Dictionary in _responses:
		worst = maxi(worst, int(response["ticks"]))
	_log.close()
	var ok := _checks.values().all(func(v: bool) -> bool: return v)
	print("CONTROL_PLAYTEST ", JSON.stringify({"checks": _checks, "orders_logged": _responses.size(), "worst_response_ticks": worst,
			"late": slow}))
	print("CONTROL_PLAYTEST_DONE ok=%s dir=%s" % [ok, out_dir])
	tree.quit(0 if ok else 1)


# ---- Steps ----------------------------------------------------------------------------------------------

func _box_select() -> void:
	var members := _alive(controls.groups.members(1))
	var rect := Rect2()
	for i in members.size():
		var at := _screen(_tank(members[i]).global_position)
		rect = Rect2(at, Vector2.ZERO) if i == 0 else rect.expand(at)
	rect = rect.grow(16.0)
	await _drag(rect.position, rect.end)
	# Whatever else the box catches (neighbors at spawn) is fine; every unit of group 1 must be in it.
	_checks["box_select_takes_group_1"] = not members.is_empty() and members.all(func(n: String) -> bool: return controls.selection.units.has(n))
	_step("box_select", {"selected": controls.selection.units})
	await get_tree().create_timer(0.4).timeout
	await _capture("1_box_select")


func _attack_move() -> void:
	var forward: Vector3 = Match.team_frame(controls.team)["forward"]
	var far := forward * 70.0  # well into the enemy's half, across the arena
	await _key(KEY_A)
	await _click(radar.get_global_rect().position + radar.world_to_radar(far))
	var members := controls.selection.units.duplicate()
	_checks["attack_move_ordered"] = members.all(func(n: String) -> bool:
		return controls.orders.current(n).get("verb", "") == "attack_move")
	_step("attack_move", {"units": members, "to": [far.x, far.z]})
	await get_tree().create_timer(2.0).timeout
	await _capture("2_attack_move_2s")
	await get_tree().create_timer(3.0).timeout
	await _capture("2_attack_move_5s")


func _queued_route() -> void:
	await _key(KEY_2)
	var members := _alive(controls.groups.members(2))
	if members.is_empty():
		_checks["queued_route"] = false
		return
	controls.center_on(members)
	await get_tree().create_timer(0.8).timeout
	var middle := _middle(members)
	var forward: Vector3 = Match.team_frame(controls.team)["forward"]
	var right := Vector3(-forward.z, 0.0, forward.x)
	var stops := [middle + forward * 15.0, middle + forward * 15.0 + right * 18.0, middle + forward * 30.0 + right * 18.0]
	for stop: Vector3 in stops:
		await _right_click(_screen(stop), true)
	var queued: int = controls.orders.queue(members[0]).size()
	_checks["queued_route_has_three_stops"] = controls.waypoints(members[0]).size() == 3 and queued == 2
	_step("queued_route", {"units": members, "stops": stops.map(func(p: Vector3) -> Array: return [snappedf(p.x, 0.1), snappedf(p.z, 0.1)]),
			"queued": queued})
	await get_tree().create_timer(0.3).timeout
	await _capture("3_queued_route")


func _group_swap() -> void:
	await _key(KEY_3, false, true)  # ctrl+3: group 2's units are also group 3 now
	var saved := controls.groups.members(3)
	await _key(KEY_1)
	var first := controls.selection.units.duplicate()
	await _capture("4_group_1_selected")
	await _key(KEY_3)
	await _key(KEY_3)  # a quick second tap centers the camera
	await get_tree().create_timer(0.8).timeout
	var centered := Vector2(controls.rig.focus.x, controls.rig.focus.z).distance_to(
			Vector2(_middle(controls.selection.units).x, _middle(controls.selection.units).z)) < 15.0
	_checks["group_swap"] = not saved.is_empty() and controls.selection.units == _alive(saved) and first != controls.selection.units
	_checks["double_tap_centers"] = centered
	_step("group_swap", {"group_3": saved, "group_1": first, "centered": centered})
	await _capture("4_group_3_centered")


func _rejoin() -> void:
	var members := _alive(controls.groups.members(3))
	if members.size() < 2:
		members = _alive(controls.selection.units)
	# Send the group somewhere open behind our lines and let it arrive.
	var forward: Vector3 = Match.team_frame(controls.team)["forward"]
	var spot := -forward * 60.0 + Vector3(-45.0, 0.0, 0.0)
	controls.selection.set_units(members)
	await _right_click(radar.get_global_rect().position + radar.world_to_radar(spot))
	var tree := get_tree()
	var waited := 0.0
	while waited < 20.0 and not members.all(func(n: String) -> bool: return controls.orders.is_idle(n)):
		await tree.create_timer(0.5).timeout
		waited += 0.5
	var pushed := members[members.size() - 1]
	var station := controls.orders.station(pushed)
	if station.is_empty() or _tank(pushed) == null:
		_checks["separated_unit_rejoins"] = false
		_step("rejoin", {"error": "no station", "waited": waited})
		return
	var home := Vector3(float(station["position"][0]), 0.0, float(station["position"][1]))
	controls.center_on(members)
	_tank(pushed).global_position = home + Vector3(18.0, 0.0, 14.0 * forward.dot(Vector3.BACK))
	await tree.create_timer(0.6).timeout
	await _capture("5_rejoin_pushed")
	await tree.create_timer(REJOIN_SECONDS).timeout
	var gap := _tank(pushed).global_position.distance_to(home) if _tank(pushed) != null else INF
	_checks["separated_unit_rejoins"] = gap <= REJOIN_DISTANCE
	_step("rejoin", {"unit": pushed, "arrived_after_s": waited, "gap_after_s": REJOIN_SECONDS, "gap_m": snappedf(gap, 0.1)})
	await _capture("5_rejoin_back")


# ---- Response logging ---------------------------------------------------------------------------------------

func _on_order_changed(unit_name: String) -> void:
	var order := controls.orders.current(unit_name)
	if order.is_empty() or order["verb"] in ["stop", "hold"]:
		_waiting.erase(unit_name)
		return
	# A queued order that starts on arrival isn't a player's click: log only orders issued this tick.
	if int(order["issued_tick"]) != controls.game_match.tick:
		return
	_waiting[unit_name] = {"verb": order["verb"], "issued_tick": controls.game_match.tick}


func _physics_process(_delta: float) -> void:
	if controls == null or _waiting.is_empty():
		return
	var names := _waiting.keys()
	names.sort()
	for unit_name: String in names:
		var entry: Dictionary = _waiting[unit_name]
		var tank := _tank(unit_name)
		var goal: Variant = controls.orders.goal_position(unit_name)
		var order := controls.orders.current(unit_name)
		if goal == null and order.has("target"):
			var target := _tank(String(order["target"]))
			goal = target.global_position if target != null else null
		var ticks := controls.game_match.tick - int(entry["issued_tick"])
		if tank == null or goal == null:
			_waiting.erase(unit_name)
			continue
		if _steering_toward(tank, goal) or ticks > 30:
			var line := {"unit": unit_name, "verb": entry["verb"], "issued_tick": entry["issued_tick"],
					"responded_tick": controls.game_match.tick if ticks <= 30 else -1, "ticks": ticks if ticks <= 30 else -1}
			_responses.append(line)
			_log.store_line(JSON.stringify(line))
			_waiting.erase(unit_name)


static func _steering_toward(tank: Tank, goal: Vector3) -> bool:
	var to_goal := Vector3(goal.x - tank.global_position.x, 0.0, goal.z - tank.global_position.z)
	if to_goal.length() < Orders.ARRIVE_RADIUS:
		return true
	var forward := -tank.global_basis.z
	var error := Vector3(forward.x, 0.0, forward.z).signed_angle_to(to_goal, Vector3.UP)
	var turning := absf(error) > deg_to_rad(5.0) and signf(-error) == signf(tank.command.turn) and absf(tank.command.turn) > 0.05
	return turning or (absf(error) < deg_to_rad(70.0) and tank.command.throttle > 0.05)


# ---- Input and helpers --------------------------------------------------------------------------------------

func _push(event: InputEvent) -> void:
	get_viewport().push_input(event)


func _mouse(at: Vector2, pressed: bool, index: MouseButton, shift := false, ctrl := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	_push(event)


func _click(at: Vector2, shift := false) -> void:
	_mouse(at, true, MOUSE_BUTTON_LEFT, shift)
	_mouse(at, false, MOUSE_BUTTON_LEFT, shift)
	await get_tree().process_frame


func _right_click(at: Vector2, shift := false) -> void:
	_mouse(at, true, MOUSE_BUTTON_RIGHT, shift)
	_mouse(at, false, MOUSE_BUTTON_RIGHT, shift)
	await get_tree().process_frame


func _drag(from: Vector2, to: Vector2) -> void:
	_mouse(from, true, MOUSE_BUTTON_LEFT)
	for i in range(1, 9):
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, i / 8.0)
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		_push(motion)
		await get_tree().process_frame
	_mouse(to, false, MOUSE_BUTTON_LEFT)
	await get_tree().process_frame


func _key(keycode: Key, shift := false, ctrl := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		event.shift_pressed = shift
		event.ctrl_pressed = ctrl
		_push(event)
	await get_tree().process_frame


func _step(step_name: String, data: Dictionary) -> void:
	data["step"] = step_name
	data["tick"] = controls.game_match.tick
	print("CONTROL_PLAYTEST ", JSON.stringify(data))


func _screen(world: Vector3) -> Vector2:
	return controls.camera.unproject_position(world)


func _tank(unit_name: String) -> Tank:
	return controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank


func _alive(names: Array) -> Array[String]:
	var result: Array[String] = []
	for unit_name in names:
		var tank := _tank(String(unit_name))
		if tank != null and tank.is_alive():
			result.append(String(unit_name))
	return result


func _middle(names: Array) -> Vector3:
	var middle := Vector3.ZERO
	var count := 0
	for unit_name in names:
		var tank := _tank(String(unit_name))
		if tank != null:
			middle += Vector3(tank.global_position.x, 0.0, tank.global_position.z)
			count += 1
	return middle / maxf(count, 1.0)


func _capture(shot_name: String) -> void:
	if not _can_capture:
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(out_dir.path_join(shot_name + ".png"))
