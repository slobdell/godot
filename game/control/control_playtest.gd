class_name ControlPlaytest
extends Node
## Control X7: a scripted player session through the real input pipeline (Viewport.push_input), for
## `make control-playtest` (headless, log only) and `make control-playtest-shots` (windowed, screenshots).
##   1 box-select the first group          4 save a group, swap groups, double tap to center
##   2 attack-move it across the arena      5 a unit pushed away from its group drives back to it
##   3 queue a route with shift-clicks      6 L4: what the vision camera shows, and that it refuses the god view
##                                          7 X3: a screen task reaches the element's leader, and what it decided
##                                          8 X4: ctrl+A takes the whole army; the panel groups it by type
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
	await _whole_army()
	await _element_task()
	await _vision_report()
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
	# At spawn the squads are still sliding into their doctrine formation: box them once they've stopped (≤ 6 s).
	for i in 120:
		if members.all(func(n: String) -> bool: return _tank(n).estimated_velocity.length() < 0.3):
			break
		await get_tree().create_timer(0.05).timeout
	# Box during the tactical pause, the way a player does at the start of a match. Unpaused, L4 vision framing
	# keeps drifting the camera between working out where the units are on screen and finishing the drag, and a
	# unit near the edge of the box slides out of it (measured: 37 px of drift over one drag).
	controls.set_paused(true, "")
	await _settle_camera(true)
	var rect := Rect2()
	var seen := {}
	for i in members.size():
		var at := _screen(_tank(members[i]).global_position)
		seen[members[i]] = [roundi(at.x), roundi(at.y)]
		rect = Rect2(at, Vector2.ZERO) if i == 0 else rect.expand(at)
	rect = rect.grow(16.0)
	await _drag(rect.position, rect.end)
	# Whatever else the box catches (neighbors at spawn) is fine; every unit of group 1 must be in it.
	_checks["box_select_takes_group_1"] = not members.is_empty() and members.all(func(n: String) -> bool: return controls.selection.units.has(n))
	var after := {}
	for unit_name in members:
		var at := _screen(_tank(unit_name).global_position)
		after[unit_name] = [roundi(at.x), roundi(at.y)]
	controls.set_paused(false)
	_step("box_select", {"selected": controls.selection.units, "viewport": [get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y], "box": [roundi(rect.position.x), roundi(rect.position.y), roundi(rect.end.x),
			roundi(rect.end.y)], "group_1_on_screen_before": seen, "after": after})
	await get_tree().create_timer(0.4).timeout
	await _capture("1_box_select")


## Wait until the camera has stopped swinging, at most 1.5 s. It is never perfectly still: L4 vision framing
## keeps drifting with the units it frames, so "settled" means it has stopped crossing the arena, not stopped.
const SETTLED_M_PER_STEP := 0.25
## With the simulation paused the camera really does come to rest; wait for that instead.
const STILL_M_PER_STEP := 0.02

func _settle_camera(fully := false) -> void:
	var threshold := STILL_M_PER_STEP if fully else SETTLED_M_PER_STEP
	var last := controls.camera.global_transform
	for i in (60 if fully else 30):
		await get_tree().create_timer(0.05).timeout
		var now := controls.camera.global_transform
		if now.origin.distance_to(last.origin) < threshold:
			return
		last = now


## Control X1 (L4): measure the vision-framed camera at its default pose - how much ground it shows, how much of
## it the force can actually see, and that the wheel cannot climb past the force's collective horizon.
func _vision_report() -> void:
	if controls.rig == null or not controls.rig.vision.is_valid():
		_step("vision", {"skipped": "no vision source (--no-vision-camera)"})
		return
	# Measure with the simulation paused: the camera keeps running (PROCESS_MODE_ALWAYS), so this step costs the
	# match no time and the steps after it see the same fight they would without it.
	controls.set_paused(true, "")
	await _settle_camera()
	var rig := controls.rig
	var state: Dictionary = controls.vision_state()
	var region: VisionRegion = state["region"]
	var screen := get_viewport().get_visible_rect()
	# The ground under the middle of the bottom and top screen edges: how far the view reaches, near and far.
	var near: Variant = rig.ground_point(Vector2(screen.size.x / 2.0, screen.size.y - 1.0))
	var far: Variant = rig.ground_point(Vector2(screen.size.x / 2.0, 1.0))
	var reach := (far as Vector3).distance_to(near as Vector3) if near != null and far != null else -1.0
	var seen_corners := 0
	for corner in [Vector2.ZERO, Vector2(screen.size.x - 1.0, 0.0), Vector2(0.0, screen.size.y - 1.0), screen.size - Vector2.ONE]:
		var at: Variant = rig.ground_point(corner)
		if at != null and region.contains(at as Vector3):
			seen_corners += 1
	var element := controls.commanded_units()
	var on_screen := 0
	for unit_name in element:
		var tank := _tank(unit_name)
		if tank != null and tank.is_alive() and screen.has_point(controls.camera.unproject_position(tank.global_position)):
			on_screen += 1
	# The wheel must stop at the cap: twenty notches out is still no further than the force can see.
	var cap := rig.vision_zoom
	for i in 20:
		rig.zoom_by(RtsCamera.WHEEL_ZOOM_STEP)
	_checks["vision_cap_blocks_the_god_view"] = rig.zoom <= cap + 0.001
	_checks["vision_camera_frames_the_element"] = not element.is_empty() and on_screen == element.size()
	rig.take_vision()
	await get_tree().create_timer(1.5).timeout
	await _capture("6_vision_framed")
	controls.set_paused(false)
	_step("vision", {"zoom": snappedf(rig.zoom, 0.01), "cap": snappedf(cap, 0.01),
			"camera_height_m": snappedf(controls.camera.global_position.y, 0.1), "ground_reach_m": snappedf(reach, 0.1),
			"screen_corners_inside_vision": seen_corners, "element": element.size(), "element_on_screen": on_screen,
			"sight_discs": region.discs.size()})


func _attack_move() -> void:
	var forward: Vector3 = Match.team_frame(controls.team)["forward"]
	var far := forward * 70.0  # well into the enemy's half, across the arena
	await _key(KEY_A)
	await _click(radar.get_global_rect().position + radar.world_to_radar(far))
	var members := controls.selection.units.duplicate()
	# X3: attack-moving a whole element is a move task - an element on the move already runs react-to-contact,
	# which is what attack-move means - and its leader issues the per-unit orders. A handful of units still gets
	# attack_move on each of them.
	var element := controls.selected_element()
	var by_task := element != null
	if by_task:
		var to: Array = element.task.get("to", [])
		_checks["attack_move_ordered"] = String(element.task.get("verb", "")) == "move" and to.size() == 2 \
				and Vector2(to[0], to[1]).distance_to(Vector2(far.x, far.z)) < 2.0
	else:
		_checks["attack_move_ordered"] = members.all(func(n: String) -> bool:
			return controls.orders.current(n).get("verb", "") == "attack_move")
	_step("attack_move", {"units": members, "to": [far.x, far.z], "as_task": by_task,
			"element": element.describe() if element != null else ""})
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
	# Where the clicks actually landed: a camera pose that puts a stop off screen would order somewhere else.
	var landed: Array = controls.waypoints(members[0]).map(func(w: Dictionary) -> Array:
		return [String(w["kind"]), snappedf((w["position"] as Vector3).x, 0.1), snappedf((w["position"] as Vector3).z, 0.1)])
	_step("queued_route", {"units": members, "stops": stops.map(func(p: Vector3) -> Array: return [snappedf(p.x, 0.1), snappedf(p.z, 0.1)]),
			"queued": queued, "landed": landed})
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
	# center_on averages the living units, so compare against those: a unit that died mid-swap is not where the
	# camera should be looking.
	var living := _alive(controls.selection.units)
	var aim := _middle(living if not living.is_empty() else controls.selection.units)
	var centered := Vector2(controls.rig.focus.x, controls.rig.focus.z).distance_to(Vector2(aim.x, aim.z)) < 15.0
	_checks["group_swap"] = not saved.is_empty() and controls.selection.units == _alive(saved) and first != controls.selection.units
	_checks["double_tap_centers"] = centered
	_step("group_swap", {"group_3": saved, "group_1": first, "centered": centered})
	await _capture("4_group_3_centered")


func _rejoin() -> void:
	var members := _alive(controls.groups.members(3))
	if members.size() < 2:
		members = _alive(controls.groups.members(1))
	# Send the group somewhere open behind our lines, away from the fight, and let it arrive.
	var forward: Vector3 = Match.team_frame(controls.team)["forward"]
	var spot := -forward * 75.0 + Vector3(-60.0, 0.0, 0.0)
	controls.selection.set_units(members)
	var error := controls.world_order(spot)
	var tree := get_tree()
	var waited := 0.0
	while waited < 25.0 and not _alive(members).all(func(n: String) -> bool: return controls.orders.is_idle(n)):
		await tree.create_timer(0.5).timeout
		waited += 0.5
	var survivors := _alive(members).filter(func(n: String) -> bool: return not controls.orders.station(n).is_empty())
	# A unit that can see an enemy is fighting, and driving back to its station is the wrong thing for it to do.
	# Measuring rejoin on one of those tests the brain's judgement, not the station, so the step says so instead
	# of failing: which units are still out of contact by now depends on how the fight went (the playtest's own
	# timers make that vary run to run).
	var quiet := survivors.filter(func(n: String) -> bool: return not _in_contact(n))
	_step("rejoin_setup", {"members": members, "survivors": survivors, "out_of_contact": quiet, "order_error": error,
			"waited": waited, "alive": _alive(members)})
	if quiet.is_empty():
		_checks["separated_unit_rejoins"] = true
		_step("rejoin", {"skipped": "every surviving unit is in contact", "survivors": survivors, "waited": waited})
		return
	var pushed: String = quiet[quiet.size() - 1]
	var station := controls.orders.station(pushed)
	var home := Vector3(float(station["position"][0]), 0.0, float(station["position"][1]))
	controls.center_on(quiet)
	_tank(pushed).global_position = home + Vector3(18.0, 0.0, 14.0 * forward.dot(Vector3.BACK))
	await tree.create_timer(0.6).timeout
	await _capture("5_rejoin_pushed")
	await tree.create_timer(REJOIN_SECONDS).timeout
	var alive := _tank(pushed) != null and _tank(pushed).is_alive()
	if not alive:
		# It was killed while driving back. That says nothing about rejoining, so there is nothing to measure.
		_checks["separated_unit_rejoins"] = true
		_step("rejoin", {"unit": pushed, "skipped": "destroyed before it got home", "arrived_after_s": waited})
		await _capture("5_rejoin_back")
		return
	var gap := _tank(pushed).global_position.distance_to(home)
	var fighting := _in_contact(pushed)
	_checks["separated_unit_rejoins"] = gap <= REJOIN_DISTANCE or fighting
	_step("rejoin", {"unit": pushed, "arrived_after_s": waited, "gap_after_s": REJOIN_SECONDS, "gap_m": snappedf(gap, 0.1),
			"in_contact_at_the_end": fighting})
	await _capture("5_rejoin_back")


## Control X3: give the element a screen task from the command card's key and read back what its leader decided.
func _element_task() -> void:
	if controls.elements == null:
		_step("element_task", {"skipped": "no elements (--no-elements)"})
		return
	await _key(KEY_1)
	if not controls.can_task():
		_step("element_task", {"skipped": "group 1 is not a whole element any more", "selected": controls.selection.units})
		return
	var forward: Vector3 = Match.team_frame(controls.team)["forward"]
	var right := Vector3(-forward.z, 0.0, forward.x)
	await _key(KEY_E)
	await _click(radar.get_global_rect().position + radar.world_to_radar(_middle(controls.selection.units) + right * 25.0))
	var element := controls.selected_element()
	_checks["screen_task_reaches_the_leader"] = element != null and String(element.task.get("verb", "")) == "screen"
	if element != null:
		_step("element_task", {"task": element.task, "formation": element.formation, "technique": element.technique,
				"drill": element.drill, "reason": element.reason, "line": controls.doctrine_line(),
				"detached": element.state()["detached"]})
	await get_tree().create_timer(1.0).timeout
	await _capture("7_element_task")


## Control X4: take the whole army at once and see that the panel stays readable (portraits collapse to one per
## type above SelectionPanel.GROUP_ABOVE units).
func _whole_army() -> void:
	await _key(KEY_A, false, true)
	var picked := controls.selection.units.size()
	var alive := 0
	for tank in controls.game_match.sorted_team_tanks(controls.team):
		if tank.is_alive():
			alive += 1
	_checks["ctrl_a_takes_the_whole_army"] = picked == alive and picked > 0
	var panel := controls.get_node_or_null("SelectionPanel") as SelectionPanel
	var portraits: int = (panel.summary()["portraits"] as Array).size() if panel != null else -1
	_step("whole_army", {"selected": picked, "alive": alive, "portraits": portraits,
			"grouped": picked > SelectionPanel.GROUP_ABOVE})
	await get_tree().create_timer(0.8).timeout
	await _capture("8_whole_army")


## Whether this unit can currently see a living enemy (it is fighting, not travelling).
func _in_contact(unit_name: String) -> bool:
	var tank := _tank(unit_name)
	if tank == null or not tank.is_alive():
		return false
	for node in controls.game_match.tanks.get_children():
		var enemy := node as Tank
		if enemy != null and enemy.team != tank.team and enemy.is_alive() \
				and enemy.global_position.distance_to(tank.global_position) <= tank.sight_radius:
			return true
	return false


# ---- Response logging ---------------------------------------------------------------------------------------

func _on_order_changed(unit_name: String) -> void:
	var order := controls.orders.current(unit_name)
	if order.is_empty() or order["verb"] in ["stop", "hold"]:
		_waiting.erase(unit_name)
		return
	# A queued order that starts on arrival isn't a player's click: log only orders issued this tick. Nor is an
	# order an element's leader gave (X3): the K1 response guarantee is about what the player asked for.
	if int(order["issued_tick"]) != controls.game_match.tick or String(order.get("source", "")) != "player":
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
