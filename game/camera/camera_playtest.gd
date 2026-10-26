class_name CameraPlaytest
extends Node
## Round 41 (camera K1): the lead's case, played through real input, with CameraTrace recording what the camera did.
## His words: "if I'm trying to command a bunch of units to attack a target ... it's hard to click on the target because
## the camera jerks."
##
## With `--camera-autoplay` this is a scripted player at his pose (the defaults: auto_frame and yaw follow on): every
## 1-3 s it selects (ctrl+A for the whole army, or a group key), then, if an enemy is on screen, puts the cursor on it,
## holds still for AIM_S like a hand that has found its target, and right-clicks there (an attack order); with no enemy
## on screen it right-clicks the ground up-screen (a move). For each click it records the TARGET SLIP: how far (px at
## 1080 rows) the ground point that was under the cursor AIM_S before the click has slid by the click, and which source
## slid it; and whether the click still lands on the unit it aimed at. Without `--camera-autoplay` it only records (his
## own session: `make skirmish SKIRMISH_FLAGS="--camera-trace=DIR"`). Either way it writes DIR/camera_trace.json at the
## end and prints CAMERA_TRACE / CAMERA_SLIP lines; the autoplay quits after `--camera-seconds` (default 150).
## `--camera-hold` turns auto_frame and yaw follow off: the floor a click's miss has from the units' own motion.

const AIM_S := 0.5
const SECONDS := 150.0

var trace: CameraTrace
var rig: RtsCamera
var out_dir := ""
var autoplay := false
var controls: RtsControls
var clicks: Array = []

var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _done := false
var _seconds := SECONDS
var _seed := 0
var _ended := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera-seconds="):
			_seconds = float(arg.trim_prefix("--camera-seconds="))
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
	_rng.seed = hash(["camera-playtest", _seed])
	trace.keep_frames = OS.get_cmdline_user_args().has("--camera-trace-frames")
	if DisplayServer.get_name() == "headless":
		get_tree().root.size = Vector2i(1920, 1080)  # headless roots are 64x64 (trip-up 31); measure at his desktop size
	get_tree().auto_accept_quit = false
	_run.call_deferred()


func _process(delta: float) -> void:
	_clock += delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_finish()
		get_tree().quit()


func _run() -> void:
	for i in 600:
		controls = get_tree().root.find_child("TacticalMap", true, false) as RtsControls
		if controls != null and controls.game_match != null:
			break
		await get_tree().process_frame
	if controls == null:
		print("CAMERA_TRACE_DONE ok=false reason=no_desktop_controls")
		get_tree().quit(1)
		return
	controls.game_match.finished.connect(func(_result: Dictionary) -> void: _ended = true)
	if not autoplay:
		return
	rig.edge_pan = false
	if OS.get_cmdline_user_args().has("--camera-hold"):
		# The comparison arm: the camera never moves by itself, so what is left of a click's miss is the unit's own motion.
		rig.set_auto_frame(false)
		rig.yaw_follow = false
	await _wait(1.0)
	controls.set_paused(false, "")
	while _clock < _seconds and not _ended:
		await _select()
		await _wait(_rng.randf_range(0.3, 0.8))
		if not await _attack():
			await _move()
		await _wait(_rng.randf_range(1.0, 3.0))
	_finish()
	get_tree().quit()


func _finish() -> void:
	if _done:
		return
	_done = true
	var summary := trace.summary()
	var slips: Array = clicks.map(func(c: Dictionary) -> float: return float(c["slip_px"]))
	slips.sort()
	var aimed := clicks.filter(func(c: Dictionary) -> bool: return c["kind"] == "attack")
	var hits := aimed.filter(func(c: Dictionary) -> bool: return bool(c["hit"]))
	var slip := {"clicks": clicks.size(), "attacks": aimed.size(), "hit": hits.size(), "p50": CameraTrace.quantile(slips, 0.5),
			"p95": CameraTrace.quantile(slips, 0.95), "max": slips.back() if not slips.is_empty() else 0.0}
	var report := {"seed": _seed, "args": " ".join(OS.get_cmdline_user_args()), "summary": summary, "slip": slip,
			"clicks": clicks, "events": trace.events}
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		var file := FileAccess.open(out_dir.path_join("camera_trace_%d.json" % _seed), FileAccess.WRITE)
		file.store_string(JSON.stringify(report))
		file.close()
		if trace.keep_frames:
			var rows := FileAccess.open(out_dir.path_join("camera_frames_%d.jsonl" % _seed), FileAccess.WRITE)
			for row: Dictionary in trace.frames:
				rows.store_line(JSON.stringify(row))
			rows.close()
	var by: Dictionary = summary["by_source"]
	for source: String in by:
		var row: Dictionary = by[source]
		if int(row["events"]) == 0 and float(row["px_per_min"]) < 1.0:
			continue
		print("CAMERA_TRACE seed=%d source=%s events=%d per_min=%.2f dv_p50=%.0f dv_max=%.0f snaps=%d reversals=%d px_per_min=%.0f" % [
				_seed, source, row["events"], row["per_min"], row["dv_p50"], row["dv_max"], row["snaps"], row["reversals"],
				row["px_per_min"]])
	print("CAMERA_SLIP seed=%d clicks=%d attacks=%d hit=%d p50=%.1f p95=%.1f max=%.1f" % [_seed, slip["clicks"], slip["attacks"],
			slip["hit"], slip["p50"], slip["p95"], slip["max"]])
	print("CAMERA_TRACE_DONE ok=true seed=%d seconds=%.1f frames=%d" % [_seed, summary["seconds"], summary["frames"]])


func _wait(seconds: float) -> void:
	var until := _clock + seconds
	while _clock < until and not _ended:
		await get_tree().process_frame


# ---- The player's hands ------------------------------------------------------------------------------------------

## ctrl+A (his "a bunch of units") half the time, else one of his groups.
func _select() -> void:
	var numbers: Array = controls.groups.numbers()
	if numbers.is_empty() or _rng.randf() < 0.5:
		await _key(KEY_A, true)
	else:
		await _key(KEY_0 + int(numbers[_rng.randi_range(0, numbers.size() - 1)]) as Key)


## Aim at an enemy on screen and right-click it. False when no enemy is on screen.
func _attack() -> bool:
	var size := get_viewport().get_visible_rect().size
	var floor_y := size.y * 0.72
	if rig.hud_bottom.is_valid():
		var top: float = rig.hud_bottom.call()
		if top > 0.0:
			floor_y = top - 20.0
	var choices: Array = []
	for node in controls.game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null or tank.team == controls.team or not tank.is_alive() or not controls.can_see(tank):
			continue
		if rig.camera.is_position_behind(Shown.at(tank)):
			continue
		var at := rig.camera.unproject_position(Shown.at(tank))
		if at.x > 60.0 and at.x < size.x - 60.0 and at.y > 60.0 and at.y < floor_y:
			choices.append(tank)
	if choices.is_empty() or controls.selection.units.is_empty():
		return false
	var target: Tank = choices[_rng.randi_range(0, choices.size() - 1)]
	var aim := rig.camera.unproject_position(Shown.at(target))
	await _click_after_aim(aim, "attack", target)
	return true


## A move order up-screen of the selection, where a player sends an army.
func _move() -> void:
	var size := get_viewport().get_visible_rect().size
	var aim := Vector2(size.x * _rng.randf_range(0.3, 0.7), size.y * _rng.randf_range(0.25, 0.45))
	await _click_after_aim(aim, "move", null)


func _click_after_aim(aim: Vector2, kind: String, target: Tank) -> void:
	_motion(aim)
	var anchor: Variant = rig.ground_point(aim)
	trace.anchor_motion.clear()
	trace.anchors.clear()
	if anchor != null:
		trace.anchors["aim"] = anchor
	var target_at := aim
	await _wait(AIM_S)
	if _ended:
		return
	var row := {"t": snappedf(_clock, 0.01), "kind": kind, "cursor": [roundi(aim.x), roundi(aim.y)], "slip_px": 0.0, "by": {}}
	var scale := CameraTrace.REFERENCE_ROWS / maxf(get_viewport().get_visible_rect().size.y, 1.0)
	if anchor != null and not rig.camera.is_position_behind(anchor as Vector3):
		row["slip_px"] = snappedf(rig.camera.unproject_position(anchor as Vector3).distance_to(aim) * scale, 0.1)
		var by := {}
		for source: String in trace.anchor_motion.get("aim", {}):
			var moved: Vector2 = trace.anchor_motion["aim"][source]
			if moved.length() * scale >= 0.5:
				by[source] = snappedf(moved.length() * scale, 0.1)
		row["by"] = by
	if target != null:
		row["target"] = String(target.name)
		if target.is_alive():
			target_at = rig.camera.unproject_position(Shown.at(target))
			row["target_slip_px"] = snappedf(target_at.distance_to(aim) * scale, 0.1)
		row["hit"] = target.is_alive() and controls.pick_unit(aim) == target
	trace.anchors.clear()
	await _right_click(aim)
	clicks.append(row)


func _motion(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion)
	trace.cursor = at


func _right_click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event)
	await get_tree().process_frame


func _key(keycode: Key, ctrl := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		event.ctrl_pressed = ctrl
		get_viewport().push_input(event)
	await get_tree().process_frame
