class_name ShellPlaytest
extends Node
## Control round 5 (X1, X6): the first minutes of the game the way the lead met them, driven through the real input
## pipeline (Viewport.push_input) so a click that a person can't make fails here too.
##   1 title      the menu buttons are what the mouse is over, and SKIRMISH starts a skirmish in this process
##   2 factions   the faction menu takes clicks for both sides, and FIGHT starts the match it shows
##   3 camera     from the planning pause through two minutes of battle, the camera keeps the element it frames
##                on screen and centred nearer to it than to the enemy
## `--shell-playtest=DIR` on `--title` starts at 1, on `--skirmish` at 2. The node lives on the tree root so it survives
## the scene changes it is testing. Prints SHELL_PLAYTEST lines, SHELL_PLAYTEST_DONE ok=<bool>, then quits.

const NODE_NAME := "ShellPlaytest"
## A stage that never shows up fails instead of hanging the run.
const WAIT_SECONDS := 25.0
## Seconds into the running battle when the camera is sampled.
const CAMERA_SAMPLES := [1.0, 3.0, 6.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 75.0, 90.0, 105.0, 120.0]
const CAMERA_SHOTS := [3.0, 50.0, 75.0, 120.0]

var out_dir := ""

var _checks := {}
var _can_capture := false


## The playtest for this run, created once: a reloaded scene asks again and gets the same node.
static func ensure(tree: SceneTree, dir: String) -> void:
	if tree.root.get_node_or_null(NODE_NAME) != null:
		return
	var playtest := ShellPlaytest.new()
	playtest.name = NODE_NAME
	playtest.out_dir = dir
	tree.root.add_child.call_deferred(playtest)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_can_capture = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(out_dir)
	run()


func run() -> void:
	await _seconds(2.0)
	if _title() != null:
		await _title_stage()
	if await _wait_for(func() -> bool: return _picker() != null or _controls() != null) and _picker() != null:
		await _faction_stage()
	if await _wait_for(func() -> bool: return _controls() != null):
		await _camera_stage()
	else:
		_checks["match_started"] = false
	var ok := not _checks.is_empty() and _checks.values().all(func(v: bool) -> bool: return v)
	print("SHELL_PLAYTEST ", JSON.stringify({"checks": _checks}))
	print("SHELL_PLAYTEST_DONE ok=%s dir=%s" % [ok, out_dir])
	get_tree().quit(0 if ok else 1)


# ---- Stages -------------------------------------------------------------------------------------------------

func _title_stage() -> void:
	await _capture("1_title")
	var title := _title()
	var button := _find_button(title, "SKIRMISH")
	_checks["title_has_skirmish_button"] = button != null
	if button == null:
		return
	var at := button.get_global_rect().get_center()
	var hovered := await _hover(at)
	_step("title_hover", {"at": [at.x, at.y], "hovered": _describe(hovered), "button": _describe(button)})
	_checks["title_button_under_mouse"] = hovered == button
	await _click(at)
	var started := await _wait_for(func() -> bool: return _title() == null)
	_checks["title_click_leaves_title"] = started
	_step("title_click", {"left_title": started, "scene": _describe(get_tree().current_scene)})


func _faction_stage() -> void:
	var picker := _picker()
	await _seconds(0.5)
	await _capture("2_factions")
	var begin := Time.get_ticks_usec()
	FactionPicker.options(picker.budget)
	_step("faction_options_cost", {"ms": (Time.get_ticks_usec() - begin) / 1000.0})
	# A player waits for the loading screen to go before clicking; so does this (it used to click through a fading one).
	var screen_gone := await _wait_for(func() -> bool: return LoadingScreen.current == null)
	var mine := _picker_point(picker, "gangs", false)
	var hovered := await _hover(mine)
	_step("faction_hover", {"at": [mine.x, mine.y], "hovered": _describe(hovered), "loading_screen_gone": screen_gone})
	_checks["faction_row_under_mouse"] = hovered == picker
	await _click(mine)
	await _click(_picker_point(picker, "law", true), MOUSE_BUTTON_RIGHT)
	_checks["faction_click_picks_yours"] = picker.player_faction == "gangs"
	_checks["faction_right_click_picks_theirs"] = picker.enemy_faction == "law"
	var arena_row := picker.arena_rect()
	var chosen_arena := ""
	if arena_row.has_area():
		await _click(picker.get_global_transform() * arena_row.get_center())
		await _click(picker.get_global_transform() * arena_row.get_center())
		chosen_arena = picker.arena
	_checks["arena_row_takes_clicks"] = chosen_arena != "" and chosen_arena != GameLauncher.RANDOM
	await _seconds(0.3)
	await _capture("2_factions_picked")
	var fight: Rect2 = picker.call("fight_rect") if picker.has_method("fight_rect") else Rect2()
	_checks["faction_menu_has_fight_button"] = fight.has_area()
	if fight.has_area():
		await _click(picker.get_global_transform() * fight.get_center())
	else:
		await _key(KEY_ENTER)
	var begin_load := Time.get_ticks_msec()
	# Round 6 X4: the loading screen is up between FIGHT and the match (it lives on the root, so it survives the switch).
	await get_tree().process_frame
	await get_tree().process_frame
	_checks["loading_screen_shows"] = LoadingScreen.current != null
	await _capture("2b_loading")
	var loaded := await _wait_for(func() -> bool: return _controls() != null)
	_step("faction_fight", {"match_loaded": loaded, "load_ms": Time.get_ticks_msec() - begin_load,
			"arena_chosen": chosen_arena, "arena_built": String(Arena.active.get("name", ""))})
	_checks["the_chosen_arena_is_built"] = loaded and chosen_arena != "" and String(Arena.active.get("name", "")) == chosen_arena


func _camera_stage() -> void:
	var controls := _controls()
	await _seconds(1.0)
	var paused := get_tree().paused
	_step("match_start", {"paused": paused, "green": controls.game_match.alive_count(Match.Team.GREEN),
			"rust": controls.game_match.alive_count(Match.Team.RUST)})
	await _capture("3_planning")
	_checks["planning_frames_own_army"] = _sample_camera("planning")
	# The wiring that keeps the player's army from marching off before he commands it (ai's brains read this meta).
	_checks["the_match_says_the_player_commands_green"] = controls.game_match.get_meta("player_team", -1) == Match.Team.GREEN
	# Round 5 reopened: a right-click on ground occupied by your own vehicles must be a MOVE. It used to be a FOLLOW, so
	# with an army packed on the start line the player's "go there" became "trail that one" (game_design.md: right-click
	# ground = move, F + click = follow).
	var mine := controls.game_match.sorted_team_tanks(Match.Team.GREEN).filter(func(t: Tank) -> bool: return t.is_alive())
	if not mine.is_empty() and not controls.selection.units.is_empty():
		var crowd: Tank = mine[mine.size() / 2]
		var on_a_friendly := controls.camera.unproject_position(crowd.global_position)
		await _click(on_a_friendly, MOUSE_BUTTON_RIGHT)
		await _seconds(0.3)
		var verbs := []
		for unit_name in controls.selection.units:
			verbs.append(String(controls.orders.current(unit_name).get("verb", "")))
		_step("right_click_on_our_own", {"verbs": verbs, "clicked": String(crowd.name)})
		_checks["right_clicking_our_own_units_is_a_move"] = not verbs.has("follow")
	var hints := controls.get_node_or_null("ControlHints") as ControlHints
	_checks["planning_shows_control_hints"] = hints != null and hints.visible and hints.shown().has("pause")
	if paused:
		await _key(KEY_SPACE)
		await _seconds(0.2)
		_checks["space_starts_the_match"] = not get_tree().paused
		_checks["a_used_control_retires_its_hint"] = hints != null and not hints.shown().has("pause")
	var hud := get_tree().current_scene.get_node("HUD") as Hud
	var captions: Array = []
	var logged: Array = []
	hud.caption_posted.connect(func(speaker: String, text: String) -> void: captions.append("%s: %s" % [speaker, text]))
	hud.message_posted.connect(func(text: String, _severity: int) -> void: logged.append(text))
	var clock := 0.0
	var framed := true
	for at: float in CAMERA_SAMPLES:
		await _seconds(at - clock)
		clock = at
		if _controls() == null:
			break
		framed = _sample_camera("battle_%ds" % roundi(at)) and framed
		if CAMERA_SHOTS.has(at):
			await _capture("3_battle_%02ds" % roundi(at))
	_checks["battle_frames_own_army"] = framed
	var leaked := logged.filter(func(text: String) -> bool: return Hud.CAPTION_SPEAKERS.any(func(who: String) -> bool: return text.begins_with(who + ": ")))
	_step("captions", {"captions": captions.size(), "log_messages": logged.size(), "booth_lines_in_log": leaked.size(),
			"first": captions.slice(0, 3)})
	if hud.caption_line.visible:
		await _capture("4_caption")
	_checks["booth_lines_stay_out_of_the_log"] = leaked.is_empty()


## One reading of what the camera shows. True when the element the camera is framing (the selection, the last group,
## else the whole army) has a vehicle on screen and the view is centred nearer to it than to the enemy's army.
func _sample_camera(label: String) -> bool:
	var controls := _controls()
	var game_match := controls.game_match
	var camera := get_viewport().get_camera_3d()
	var rect := get_viewport().get_visible_rect()
	var center: Variant = controls.rig.ground_point(rect.size / 2.0)
	var reading := {"label": label}
	var element: Array[Tank] = []
	for unit_name in controls.commanded_units():
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null and tank.is_alive():
			element.append(tank)
	reading["element"] = _group_reading(element, camera, rect, center)
	for team: int in [Match.Team.GREEN, Match.Team.RUST]:
		var alive: Array[Tank] = []
		for tank in game_match.sorted_team_tanks(team):
			if tank.is_alive():
				alive.append(tank)
		reading["green" if team == Match.Team.GREEN else "rust"] = _group_reading(alive, camera, rect, center)
	var mine: Dictionary = reading["element"]
	var rust: Dictionary = reading["rust"]
	var ok := true
	if int(mine["alive"]) > 0:
		ok = int(mine["on_screen"]) > 0
		if int(rust["alive"]) > 0:
			ok = ok and int(mine["from_center_m"]) <= int(rust["from_center_m"])
	reading["selected"] = controls.selection.units.size()
	reading["inspected"] = controls.selection.inspected
	reading["zoom"] = snappedf(controls.rig.zoom, 0.01)
	reading["ok"] = ok
	_step("camera", reading)
	return ok


static func _group_reading(tanks: Array[Tank], camera: Camera3D, rect: Rect2, center: Variant) -> Dictionary:
	var middle := Vector3.ZERO
	var on_screen := 0
	for tank in tanks:
		middle += tank.global_position
		if not camera.is_position_behind(tank.global_position) and rect.has_point(camera.unproject_position(tank.global_position)):
			on_screen += 1
	middle /= maxf(tanks.size(), 1.0)
	return {"alive": tanks.size(), "on_screen": on_screen, "middle": [roundi(middle.x), roundi(middle.z)],
			"from_center_m": roundi(Vector2(middle.x, middle.z).distance_to(Vector2(center.x, center.z))) if center is Vector3 else -1}


# ---- Finding things -------------------------------------------------------------------------------------------

func _title() -> Node:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path.ends_with("title_screen.tscn"):
		return scene
	return null


func _picker() -> FactionPicker:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("HUD/FactionPicker") as FactionPicker if scene != null else null


func _controls() -> RtsControls:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("HUD/TacticalMap") as RtsControls if scene != null else null


func _picker_point(picker: FactionPicker, faction: String, enemy: bool) -> Vector2:
	return picker.get_global_transform() * picker.row_rect(faction, enemy).get_center()


static func _find_button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null


func _describe(node: Variant) -> String:
	if node == null or not is_instance_valid(node):
		return "<none>"
	return "%s (%s)" % [(node as Node).get_path(), (node as Node).get_class()]


# ---- Input, time and output -----------------------------------------------------------------------------------

func _hover(at: Vector2) -> Control:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion)
	await get_tree().process_frame
	await get_tree().process_frame
	return get_viewport().gui_get_hovered_control()


func _click(at: Vector2, index := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = index
		event.pressed = pressed
		event.position = at
		event.global_position = at
		event.button_mask = (1 << (index - 1)) if pressed else 0
		get_viewport().push_input(event)
		await get_tree().process_frame


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true, false, true).timeout


func _wait_for(condition: Callable) -> bool:
	var waited := 0.0
	while not condition.call():
		if waited >= WAIT_SECONDS:
			return false
		await _seconds(0.25)
		waited += 0.25
	return true


func _step(step_name: String, data: Dictionary) -> void:
	data["step"] = step_name
	print("SHELL_PLAYTEST ", JSON.stringify(data))


func _capture(shot_name: String) -> void:
	if not _can_capture:
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(out_dir.path_join(shot_name + ".png"))
