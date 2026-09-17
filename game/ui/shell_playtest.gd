class_name ShellPlaytest
extends Node
## Control round 5 (X1, X6): the first minutes of the game the way the lead met them, driven through the real input
## pipeline (Viewport.push_input) so a click that a person can't make fails here too.
##   1 title      the menu buttons are what the mouse is over, and SKIRMISH starts a skirmish in this process
##   2 factions   the faction menu takes clicks for both sides, and FIGHT starts the match it shows
##   3 camera     from the planning pause through a minute of battle, the camera keeps the player's own army in
##                view and centred nearer to it than to the enemy
## `--shell-playtest=DIR` on `--title` starts at 1, on `--skirmish` at 2. The node lives on the tree root so it survives
## the scene changes it is testing. Prints SHELL_PLAYTEST lines, SHELL_PLAYTEST_DONE ok=<bool>, then quits.

const NODE_NAME := "ShellPlaytest"
## A stage that never shows up fails instead of hanging the run.
const WAIT_SECONDS := 25.0
## Seconds into the running battle when the camera is sampled.
const CAMERA_SAMPLES := [1.0, 3.0, 6.0, 10.0, 15.0, 20.0, 30.0, 45.0, 60.0]
const CAMERA_SHOTS := [3.0, 20.0, 60.0]

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
	var mine := _picker_point(picker, "gangs", false)
	var hovered := await _hover(mine)
	_step("faction_hover", {"at": [mine.x, mine.y], "hovered": _describe(hovered)})
	_checks["faction_row_under_mouse"] = hovered == picker
	await _click(mine)
	await _click(_picker_point(picker, "law", true), MOUSE_BUTTON_RIGHT)
	_checks["faction_click_picks_yours"] = picker.player_faction == "gangs"
	_checks["faction_right_click_picks_theirs"] = picker.enemy_faction == "law"
	await _seconds(0.3)
	await _capture("2_factions_picked")
	var fight: Rect2 = picker.call("fight_rect") if picker.has_method("fight_rect") else Rect2()
	_checks["faction_menu_has_fight_button"] = fight.has_area()
	if fight.has_area():
		await _click(picker.get_global_transform() * fight.get_center())
	else:
		await _key(KEY_ENTER)
	var begin_load := Time.get_ticks_msec()
	var loaded := await _wait_for(func() -> bool: return _controls() != null)
	_step("faction_fight", {"match_loaded": loaded, "load_ms": Time.get_ticks_msec() - begin_load})


func _camera_stage() -> void:
	var controls := _controls()
	await _seconds(1.0)
	var paused := get_tree().paused
	_step("match_start", {"paused": paused, "green": controls.game_match.alive_count(Match.Team.GREEN),
			"rust": controls.game_match.alive_count(Match.Team.RUST)})
	await _capture("3_planning")
	_checks["planning_frames_own_army"] = _sample_camera("planning")
	if paused:
		await _key(KEY_SPACE)
		await _seconds(0.2)
		_checks["space_starts_the_match"] = not get_tree().paused
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


## One reading of what the camera shows. True when the player's army is on screen and the view is centred nearer
## to it than to the enemy (or the player has nothing left to frame).
func _sample_camera(label: String) -> bool:
	var controls := _controls()
	var game_match := controls.game_match
	var camera := get_viewport().get_camera_3d()
	var rect := get_viewport().get_visible_rect()
	var center: Variant = controls.rig.ground_point(rect.size / 2.0)
	var reading := {"label": label}
	var ok := true
	for team: int in [Match.Team.GREEN, Match.Team.RUST]:
		var middle := Vector3.ZERO
		var alive := 0
		var on_screen := 0
		for tank in game_match.sorted_team_tanks(team):
			if not tank.is_alive():
				continue
			alive += 1
			middle += tank.global_position
			if not camera.is_position_behind(tank.global_position) and rect.has_point(camera.unproject_position(tank.global_position)):
				on_screen += 1
		middle /= maxf(alive, 1.0)
		var key := "green" if team == Match.Team.GREEN else "rust"
		reading[key] = {"alive": alive, "on_screen": on_screen, "middle": [roundi(middle.x), roundi(middle.z)],
				"from_center_m": roundi(Vector2(middle.x, middle.z).distance_to(Vector2(center.x, center.z))) if center is Vector3 else -1}
	var green: Dictionary = reading["green"]
	var rust: Dictionary = reading["rust"]
	if int(green["alive"]) > 0:
		ok = int(green["on_screen"]) > 0
		if int(rust["alive"]) > 0:
			ok = ok and int(green["from_center_m"]) <= int(rust["from_center_m"])
	reading["selected"] = controls.selection.units.size()
	reading["inspected"] = controls.selection.inspected
	reading["zoom"] = snappedf(controls.rig.zoom, 0.01)
	reading["ok"] = ok
	_step("camera", reading)
	return ok


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
