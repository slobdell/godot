class_name CameraPlaytest
extends Node
## Round 41 (camera K1): the lead's case, played through real input, with CameraTrace recording what the camera did.
## His words: "if I'm trying to command a bunch of units to attack a target ... it's hard to click on the target because
## the camera jerks."
##
## With `--camera-autoplay` this is a scripted player at his pose (the defaults: auto_frame and yaw follow on): every
## 1-3 s it selects (ctrl+A for the whole army, or a group key), then, if an enemy is on screen, puts the cursor on it,
## carries the cursor onto it over REACH_S, holds still for AIM_S like a hand that has found its target, and right-clicks there (an attack order); with no enemy
## on screen it right-clicks the ground up-screen (a move). For each click it records the TARGET SLIP: how far (px at
## 1080 rows) the ground point that was under the cursor AIM_S before the click has slid by the click, and which source
## slid it; and whether the click still lands on the unit it aimed at. Without `--camera-autoplay` it only records (his
## own session: `make skirmish SKIRMISH_FLAGS="--camera-trace=DIR"`). Either way it writes DIR/camera_trace.json at the
## end and prints CAMERA_TRACE / CAMERA_SLIP lines; the autoplay quits after `--camera-seconds` (default 150).
## `--camera-hold` turns auto_frame and yaw follow off: the floor a click's miss has from the units' own motion.
## `--camera-clip=CAPTION` (for a filmed clip, `make camera-clip`): a recorded movie has no OS cursor, so it draws the
## autoplay's cursor, a ring where it clicks, and CAPTION in a corner.
## Round 42 (K4.1), `--camera-scenario=`: his two camera cases, staged, with CameraLook measuring where the view looks.
##   ambush   group 1 drives north; AMBUSH_AT_S in, one CPU squad (up to AMBUSH_UNITS) is set down AMBUSH_M off its flank
##            or rear (the lane: `--camera-lane=right|left|rear`, else seed % 3) facing it, told to hold, and fires from
##            there. The autoplay then plays round 41's hand: an enemy on screen is aimed at and attacked, else it waits.
##   retreat  his scout squad (the group with the most scouts) drives north at a CPU squad held RETREAT_ENEMY_M ahead; once
##            it is under fire (or RETREAT_CONTACT_S passes) and has fought RETREAT_FIGHT_S, it is ordered back to his own
##            edge behind his lines (the lead: "the camera pointed out completely to the audience").

const AIM_S := 0.5
## How long his hand takes to carry the cursor to what he aims at (a Fitts-law reach across a 1080p screen is ~0.25-0.4 s).
const REACH_S := 0.3
const SECONDS := 150.0
## K4.1's staged cases (see the header).
const AMBUSH_AT_S := 5.0
const AMBUSH_M := 40.0
const AMBUSH_UNITS := 3
const AMBUSH_SPACING_M := 8.0
const DRIVE_M := 110.0
const RETREAT_ENEMY_M := 70.0
const RETREAT_CONTACT_S := 15.0
const RETREAT_FIGHT_S := 4.0
const EDGE_M := 128.0
## A staged unit is set down at least this far from any obstacle's footprint.
const CLEAR_M := 4.0
const LANES := ["right", "left", "rear"]
## K5.2's corner: the lanes per side a seed picks from (the nearest to group 1), and his column's spacing at the start.
const CORNER_LANES := 3
const CORNER_COLUMN_M := 9.0

var trace: CameraTrace
var look: CameraLook
## K5.2: the corner census, made when the corner scenario is staged.
var corner: CameraCorner
var scenario := ""
var lane := ""
## How far off the selection the ambush is set down (`--camera-ambush-m=`, default AMBUSH_M).
var ambush_m := AMBUSH_M
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
var _cursor := Vector2(-1, -1)
var _overlay: Control
var _clicked_at := Vector2(-1, -1)
var _clicked_clock := -10.0
var _caption := ""
## Seconds with an enemy the autoplay could aim at on screen (the camera finding the action; K3 v2 line 5's why).
var _action_s := 0.0
var _playing := false
## What the staged scenario set up (who, where, when), for the report.
var _staged := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera-seconds="):
			_seconds = float(arg.trim_prefix("--camera-seconds="))
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--camera-clip="):
			_caption = arg.trim_prefix("--camera-clip=")
		elif arg.begins_with("--camera-scenario="):
			scenario = arg.trim_prefix("--camera-scenario=")
		elif arg.begins_with("--camera-lane="):
			lane = arg.trim_prefix("--camera-lane=")
		elif arg.begins_with("--camera-ambush-m="):
			ambush_m = float(arg.trim_prefix("--camera-ambush-m="))
	if lane == "":
		lane = LANES[posmod(_seed, LANES.size())]
	if scenario != "" and not ["ambush", "retreat", "corner"].has(scenario):
		push_error("CameraPlaytest: unknown --camera-scenario=%s" % scenario)  # a probe flag that fails must stop the run
		print("CAMERA_TRACE_DONE ok=false reason=unknown_scenario")
		get_tree().quit(1)
		return
	_rng.seed = hash(["camera-playtest", _seed])
	trace.keep_frames = OS.get_cmdline_user_args().has("--camera-trace-frames")
	if DisplayServer.get_name() == "headless":
		get_tree().root.size = Vector2i(1920, 1080)  # headless roots are 64x64 (trip-up 31); measure at his desktop size
	get_tree().auto_accept_quit = false
	if _caption != "":
		_add_overlay()
	_run.call_deferred()


func _process(delta: float) -> void:
	_clock += delta
	if _playing and not _ended and not _aimable().is_empty():
		_action_s += delta
	if _overlay != null:
		_overlay.queue_redraw()


func _add_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	layer.add_child(_overlay)
	var label := Label.new()
	label.text = _caption
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	layer.add_child(label)


func _draw_overlay() -> void:
	if _cursor.x < 0.0:
		return
	var scale := _overlay.get_viewport_rect().size.y / CameraTrace.REFERENCE_ROWS
	var arm := 30.0 * maxf(scale, 0.5)
	for line in [[Vector2(-arm, 0), Vector2(-arm * 0.3, 0)], [Vector2(arm * 0.3, 0), Vector2(arm, 0)],
			[Vector2(0, -arm), Vector2(0, -arm * 0.3)], [Vector2(0, arm * 0.3), Vector2(0, arm)]]:
		_overlay.draw_line(_cursor + line[0], _cursor + line[1], Color.BLACK, 6.0 * maxf(scale, 0.5))
		_overlay.draw_line(_cursor + line[0], _cursor + line[1], Color.WHITE, 2.5 * maxf(scale, 0.5))
	var since := _clock - _clicked_clock
	if since < 0.5:
		_overlay.draw_arc(_clicked_at, arm * (1.0 + since * 3.0), 0.0, TAU, 32, Color(1.0, 0.85, 0.2, 1.0 - since * 2.0),
				4.0 * maxf(scale, 0.5))


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
	if look != null:
		look.feed = DangerFeed.new().attach(controls.game_match, controls.team, controls.commanded_units, controls.can_see,
				controls.selection_facing)
	if not autoplay:
		return
	rig.edge_pan = false
	if OS.get_cmdline_user_args().has("--camera-hold"):
		# The comparison arm: the camera never moves by itself, so what is left of a click's miss is the unit's own motion.
		rig.set_auto_frame(false)
		rig.yaw_follow = false
	await _wait(1.0)
	controls.set_paused(false, "")
	_playing = true
	if scenario == "ambush":
		await _ambush()
	elif scenario == "retreat":
		await _retreat()
	elif scenario == "corner":
		await _corner()
	while scenario == "" and _clock < _seconds and not _ended:
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
			"p95": CameraTrace.quantile(slips, 0.95), "max": slips.back() if not slips.is_empty() else 0.0,
			"action_s": snappedf(_action_s, 0.01)}
	var report := {"seed": _seed, "args": " ".join(OS.get_cmdline_user_args()), "summary": summary, "slip": slip,
			"clicks": clicks, "events": trace.events, "scenario": scenario, "lane": lane, "staged": _staged}
	if look != null:
		report["look"] = look.summary()
		report["episodes"] = look.episodes
	if corner != null:
		report["corner"] = corner.summary()
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
			if look != null:
				var looks := FileAccess.open(out_dir.path_join("camera_look_%d.jsonl" % _seed), FileAccess.WRITE)
				for row: Dictionary in look.frames:
					looks.store_line(JSON.stringify(row))
				looks.close()
	var by: Dictionary = summary["by_source"]
	for source: String in by:
		var row: Dictionary = by[source]
		if int(row["events"]) == 0 and float(row["px_per_min"]) < 1.0:
			continue
		print("CAMERA_TRACE seed=%d source=%s events=%d per_min=%.2f dv_p50=%.0f dv_max=%.0f snaps=%d reversals=%d px_per_min=%.0f" % [
				_seed, source, row["events"], row["per_min"], row["dv_p50"], row["dv_max"], row["snaps"], row["reversals"],
				row["px_per_min"]])
	print("CAMERA_SLIP seed=%d clicks=%d attacks=%d hit=%d p50=%.1f p95=%.1f max=%.1f action_s=%.1f" % [_seed, slip["clicks"],
			slip["attacks"], slip["hit"], slip["p50"], slip["p95"], slip["max"], _action_s])
	if look != null:
		var l: Dictionary = report["look"]
		print("CAMERA_LOOK seed=%d scenario=%s lane=%s staged=%s play_s=%.1f under_fire_s=%.1f blind_s=%.1f wall_s=%.1f episodes=%d never=%d latencies=%s reversals=%d" % [
				_seed, scenario if scenario != "" else "attack", lane, _staged.get("ok", false), l["play_s"], l["under_fire_s"],
				l["blind_s"], l["wall_s"], l["episodes"], l["never"], JSON.stringify(l["latencies"]), l["yaw_reversals"]])
	if corner != null:
		var c: Dictionary = report["corner"]
		print("CAMERA_CORNER seed=%d lane=%s feature=%s opened=%s open_to_seen=%s open_to_screen=%s seen_to_screen=%s corner_s=%.1f facing_s=%.1f toward_s=%.1f away_s=%.1f back_s=%.1f hidden=%s mean_abs_bearing=%s" % [
				_seed, lane, _staged.get("feature", -1), c["opened"], c["open_to_seen_s"], c["open_to_screen_s"], c["seen_to_screen_s"],
				c["corner_s"], c["facing_s"], c["toward_s"], c["away_s"], c["back_s"], c["hidden"], c["mean_abs_bearing"]])
		if out_dir != "":
			var yaws := FileAccess.open(out_dir.path_join("camera_yaw_%d.jsonl" % _seed), FileAccess.WRITE)
			for row: Array in corner.yaw_log:
				yaws.store_line(JSON.stringify(row))
			yaws.close()
		if corner.keep_frames and out_dir != "":
			var rows := FileAccess.open(out_dir.path_join("camera_corner_%d.jsonl" % _seed), FileAccess.WRITE)
			for row: Dictionary in corner.frames:
				rows.store_line(JSON.stringify(row))
			rows.close()
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
	var choices := _aimable()
	if choices.is_empty() or controls.selection.units.is_empty():
		return false
	var target: Tank = choices[_rng.randi_range(0, choices.size() - 1)]
	var aim := rig.camera.unproject_position(Shown.at(target))
	await _click_after_aim(aim, "attack", target)
	return true


## The enemies he could aim at now: seen, alive, on screen inside a margin and above the HUD.
func _aimable() -> Array:
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
	return choices


## A move order up-screen of the selection, where a player sends an army.
func _move() -> void:
	var size := get_viewport().get_visible_rect().size
	var aim := Vector2(size.x * _rng.randf_range(0.3, 0.7), size.y * _rng.randf_range(0.25, 0.45))
	await _click_after_aim(aim, "move", null)


func _click_after_aim(aim: Vector2, kind: String, target: Tank) -> void:
	await _reach(aim, target)
	if target != null and target.is_alive() and not rig.camera.is_position_behind(Shown.at(target)):
		aim = rig.camera.unproject_position(Shown.at(target))  # the hand lands where the unit is now
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


## Carry the cursor to `aim` (re-aimed at the target each frame, as an eye-hand would) over REACH_S, one motion a frame.
func _reach(aim: Vector2, target: Tank) -> void:
	var from := _cursor if _cursor.x >= 0.0 else get_viewport().get_visible_rect().size * 0.5
	var start := _clock
	while _clock - start < REACH_S and not _ended:
		var goal := aim
		if target != null and target.is_alive() and not rig.camera.is_position_behind(Shown.at(target)):
			goal = rig.camera.unproject_position(Shown.at(target))
		var t := clampf((_clock - start) / REACH_S, 0.0, 1.0)
		_motion(from.lerp(goal, t * t * (3.0 - 2.0 * t)))
		await get_tree().process_frame


func _motion(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion)
	trace.cursor = at
	_cursor = at


func _right_click(at: Vector2) -> void:
	_clicked_at = at
	_clicked_clock = _clock
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


# ---- Round 42 (K4.1): his two camera cases, staged ---------------------------------------------------------------

## Group 1 drives north; a CPU squad is set down on its flank or rear and opens fire. Then round 41's hand.
func _ambush() -> void:
	await _key(KEY_0 + _first_group() as Key)
	var from: Variant = _centre(controls.selection.units)
	if from == null:
		_staged = {"ok": false, "why": "group 1 has no living units"}
		return
	var north: Vector3 = Match.team_frame(controls.team)["forward"]
	controls.order_selection("move", {"to": _pair(ElementPlan.clamp_to_arena((from as Vector3) + north * DRIVE_M))})
	await _wait(AMBUSH_AT_S)
	from = _centre(controls.selection.units)
	if from == null:
		_staged = {"ok": false, "why": "group 1 died before the ambush"}
		return
	var heading: Variant = controls.selection_facing()
	var ahead: Vector3 = heading if heading is Vector3 else north
	var side: Vector3 = {"right": ahead.cross(Vector3.UP), "left": -ahead.cross(Vector3.UP), "rear": -ahead}[lane]
	_staged = _stage_enemy(from as Vector3, side.normalized(), ambush_m)
	_staged["lane"] = lane
	_staged["at_s"] = snappedf(_clock, 0.01)
	while _clock < _seconds and not _ended:
		if not await _attack():
			await _wait(0.5)
		await _wait(_rng.randf_range(1.0, 3.0))


## His scouts drive at a held CPU squad, take fire, and are ordered back to his own edge.
func _retreat() -> void:
	var group := _scout_group()
	await _key(KEY_0 + group as Key)
	var from: Variant = _centre(controls.selection.units)
	if from == null:
		_staged = {"ok": false, "why": "no scout group"}
		return
	var north: Vector3 = Match.team_frame(controls.team)["forward"]
	_staged = _stage_enemy(from as Vector3, north, RETREAT_ENEMY_M)
	_staged["group"] = group
	controls.order_selection("move", {"to": _pair(ElementPlan.clamp_to_arena((from as Vector3) + north * DRIVE_M))})
	var start := _clock
	while _clock - start < RETREAT_CONTACT_S and not _ended and not _under_fire():
		await _wait(0.2)
	_staged["contact_s"] = snappedf(_clock - start, 0.01)
	await _wait(RETREAT_FIGHT_S)
	from = _centre(controls.selection.units)
	if from == null or _ended:
		_staged["why"] = "the scouts died before the retreat"
		return
	var edge := ElementPlan.clamp_to_arena(Vector3((from as Vector3).x, 0.0, 0.0) - north * EDGE_M)
	controls.order_selection("move", {"to": _pair(edge)})
	_staged["retreat_s"] = snappedf(_clock, 0.01)
	await _wait(_seconds - _clock)


## Round 43 (K5.2): group 1 drives along a building's wall past its far corner, a CPU squad parked out of sight behind
## it (CameraCorner.lanes: the side is `--camera-lane=right|left`, else seed % 2; the lane one of the CORNER_LANES
## nearest group 1 on that side, by seed). His crews are set down in a column at the lane's start and ordered to its
## end; then round 41's hand, as in the ambush.
func _corner() -> void:
	var group := _first_group()
	await _key(KEY_0 + group as Key)
	var names: Array = controls.selection.units.duplicate()
	var from: Variant = _centre(names)
	if from == null:
		_staged = {"ok": false, "why": "group 1 has no living units"}
		return
	var given := OS.get_cmdline_user_args().has("--camera-lane=" + lane)
	var side: String = lane if given and lane in ["right", "left"] else ["right", "left"][posmod(_seed, 2)]
	var cover := CoverMap.of(controls)
	var all := CameraCorner.lanes(cover, Match.DRIVABLE_LIMIT - 6.0, CameraCorner.water_of(Arena.active))
	print("CAMERA_CORNER_LANES walls=%d lanes=%d right=%d rejects=%s" % [CameraCorner.walls(cover).size(), all.size(),
			all.filter(func(l: Dictionary) -> bool: return l["side"] == "right").size(), JSON.stringify(CameraCorner.rejects)])
	var near := all.filter(func(l: Dictionary) -> bool: return l["side"] == side)
	if near.is_empty() and not given:
		# An arena with corners on one side only (Locks: the canal takes its right lanes): the seed drives the other.
		side = "left" if side == "right" else "right"
		near = all.filter(func(l: Dictionary) -> bool: return l["side"] == side)
	var here := Vector2((from as Vector3).x, (from as Vector3).z)
	near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["start"] as Vector2).distance_to(here) < (b["start"] as Vector2).distance_to(here))
	if near.is_empty():
		_staged = {"ok": false, "why": "no %s corner on this arena" % side}
		return
	lane = side
	var pick: Dictionary = near[posmod(_seed / 2, mini(CORNER_LANES, near.size()))]
	var along: Vector2 = pick["along"]
	var start: Vector2 = pick["start"]
	var end: Vector2 = pick["end"]
	var ahead := Vector3(along.x, 0.0, along.y)
	for i in names.size():
		var tank := controls.game_match.tanks.get_node_or_null(NodePath(String(names[i]))) as Tank
		if tank == null or not tank.is_alive():
			continue
		var at := CameraPlaytest.clear_spot(Vector3(start.x, 0.0, start.y) - ahead * CORNER_COLUMN_M * float(i), Vector3(end.x, 0.0, end.y))
		tank.place(Vector3(at.x, tank.global_position.y, at.z), RtsCamera.yaw_facing(ahead))
	var hide: Vector2 = pick["hide"]
	if OS.get_cmdline_user_args().has("--camera-corner-hidden=off"):
		# Bar K5's empty corner and its no-fog-cheat twin: the same lane, nobody behind the wall.
		_staged = {"ok": true, "why": "", "units": [], "hidden": false}
	else:
		var squad := _cpu_squad()
		if squad.is_empty():
			_staged = {"ok": false, "why": "no CPU squad with two living units"}
			return
		_staged = _stage_squad(squad, Vector3(hide.x, 0.0, hide.y), ahead, Vector3(hide.x, 0.0, hide.y) - ahead * 10.0)
		_staged["hidden"] = true
	_staged["lane"] = side
	_staged["feature"] = pick["feature"]
	_staged["start"] = [snappedf(start.x, 0.1), snappedf(start.y, 0.1)]
	_staged["end"] = [snappedf(end.x, 0.1), snappedf(end.y, 0.1)]
	_staged["hide"] = [snappedf(hide.x, 0.1), snappedf(hide.y, 0.1)]
	_staged["lanes"] = near.size()
	corner = CameraCorner.new()
	corner.name = "CameraCorner"
	corner.rig = rig
	corner.look = look
	corner.feed = look.feed if look != null else null
	corner.cover = cover
	corner.lane = pick
	corner.hidden = _staged.get("units", [])
	corner.keep_frames = OS.get_cmdline_user_args().has("--camera-trace-frames")
	rig.add_child(corner)
	rig.focus = Vector3(start.x, 0.0, start.y)
	rig.yaw = RtsCamera.yaw_facing(ahead)
	rig.wrote["focus"] = "jump"  # the staging jump is the harness's, not an automatic move (CameraTrace: not a snap)
	rig.wrote["yaw"] = "jump"
	rig.wrote["zoom"] = "jump"
	rig.wrote["pitch"] = "jump"
	rig.snap()  # the camera jumps to the staged column, looking down the drive (a jump has nothing to ease from)
	controls.order_selection("move", {"to": _pair(Vector3(end.x, 0.0, end.y))})
	_staged["at_s"] = snappedf(_clock, 0.01)
	while _clock < _seconds and not _ended:
		if not await _attack():
			await _wait(0.5)
		await _wait(_rng.randf_range(1.0, 3.0))


func _under_fire() -> bool:
	if look == null or look.feed == null:
		return false
	for enemy: Dictionary in look.feed.read()["enemies"]:
		if float(enemy["fired_s"]) <= CameraLook.FIRING_S:
			return true
	return false


## Up to AMBUSH_UNITS of one CPU squad set down `metres` from `from` along `direction` (in a line across it, each on
## clear ground), facing `from`, out of their element and told to hold (they fire at what comes in range).
func _stage_enemy(from: Vector3, direction: Vector3, metres: float) -> Dictionary:
	var squad := _cpu_squad()
	if squad.is_empty():
		return {"ok": false, "why": "no CPU squad with two living units"}
	return _stage_squad(squad, from + direction * metres, direction.cross(Vector3.UP).normalized(), from)


## Up to AMBUSH_UNITS living tanks of the first CPU squad with two or more alive.
func _cpu_squad() -> Array:
	var enemy_team := Match.Team.RUST if controls.team == Match.Team.GREEN else Match.Team.GREEN
	for candidate in controls.game_match.team_squads(enemy_team):
		var alive: Array = []
		for unit_name: String in candidate.roster:
			var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank != null and tank.is_alive():
				alive.append(tank)
		if alive.size() >= 2:
			return alive.slice(0, AMBUSH_UNITS)
	return []


## `squad` (living CPU tanks) set down in a line across `across` centred on `centre`, each on clear ground, facing
## `face`, out of their element and told to hold.
func _stage_squad(squad: Array, centre: Vector3, across: Vector3, face: Vector3) -> Dictionary:
	var enemy_team := Match.Team.RUST if controls.team == Match.Team.GREEN else Match.Team.GREEN
	var from := face
	var names: Array = []
	var spots: Array = []
	for i in squad.size():
		var tank: Tank = squad[i]
		var offset := (float(i) - float(squad.size() - 1) * 0.5) * AMBUSH_SPACING_M
		var at := CameraPlaytest.clear_spot(ElementPlan.clamp_to_arena(centre + across * offset), from)
		var owner: Element = controls.elements.of(String(tank.name)) if controls.elements != null else null
		if owner != null:
			owner.remove(String(tank.name))
		tank.place(Vector3(at.x, tank.global_position.y, at.z), RtsCamera.yaw_facing(from - at))
		names.append(String(tank.name))
		spots.append([snappedf(at.x, 0.1), snappedf(at.z, 0.1)])
	var error := controls.orders.issue({"units": names, "verb": "hold", "source": "player"}, enemy_team)
	return {"ok": error == "", "why": error, "units": names, "spots": spots}


## The nearest point to `point` (searching rings toward `toward`, then around) that is CLEAR_M from every obstacle.
static func clear_spot(point: Vector3, toward: Vector3) -> Vector3:
	var data := RtsCamera.seen()
	if CameraPlaytest.clearance(point, data) >= CLEAR_M:
		return point
	for ring in range(1, 9):
		for k in 12:
			var probe := ElementPlan.clamp_to_arena(point + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 12.0) * 3.0 * ring)
			if CameraPlaytest.clearance(probe, data) >= CLEAR_M:
				return probe
	return point.lerp(toward, 0.3)


static func clearance(point: Vector3, data: Dictionary) -> float:
	var nearest := INF
	for obstacle: Dictionary in data.get("obstacles", []):
		var centre := Vector2(float(obstacle["position"][0]), float(obstacle["position"][1]))
		nearest = minf(nearest, ArenaKit.distance_to_footprint(Vector2(point.x, point.z), centre, Arena.obstacle_size(obstacle),
				float(obstacle.get("rotation_deg", 0.0))))
	return nearest


func _first_group() -> int:
	var numbers: Array = controls.groups.numbers()
	return int(numbers[0]) if not numbers.is_empty() else 1


## The group with the most scouts (his "group of scouts"), else group 1.
func _scout_group() -> int:
	var best := _first_group()
	var most := 0
	for number: int in controls.groups.numbers():
		var scouts := 0
		for unit_name: String in controls.groups.members(number):
			var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank != null and tank.is_alive() and tank.unit_id.contains("scout"):
				scouts += 1
		if scouts > most:
			most = scouts
			best = number
	return best


func _centre(names: Array) -> Variant:
	var sum := Vector3.ZERO
	var count := 0
	for unit_name: String in names:
		var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null and tank.is_alive():
			sum += Vector3(tank.global_position.x, 0.0, tank.global_position.z)
			count += 1
	return sum / float(count) if count > 0 else null


static func _pair(point: Vector3) -> Array:
	return [snappedf(point.x, 0.01), snappedf(point.z, 0.01)]
