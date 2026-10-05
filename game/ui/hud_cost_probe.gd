class_name HudCostProbe
extends Node
## Control X4 (CP1's HUD line: ≤ 130 draw calls, ≤ 1 ms of `_process` at 60 vehicles): what each piece of the HUD costs,
## in a live skirmish. After a warm-up of real fighting it takes the tactical pause (the HUD keeps processing and
## drawing, the battle holds still, so every phase measures the same picture), measures the whole HUD, then hides one
## widget at a time (and stops its processing) for PHASE_FRAMES with an `all` phase either side; a widget's cost is the
## difference. Canvas draw calls come from the viewport's own counter, so the 3D scene doesn't blur them.
## `--hud-cost=PATH` on a skirmish: prints HUD_COST lines, writes PATH (JSON), then HUD_COST_DONE and quits.

const WARMUP_SECONDS := 10.0
const PHASE_FRAMES := 8

var out_path := ""
var main: Main

var _rows: Array = []


## Round 16 (hud H1): `--hud-profile-seconds=N` (with `--hud-cost=PATH`) runs the fight instead of pausing it and
## reads HudClock's counters: each widget's `_process` and `_draw` calls and microseconds per frame over N seconds of
## real play, and how many of the redraws drew a changed state. Runs headless (`make hud-profile`) at his window size.
const PROFILE_WARMUP_SECONDS := 6.0
const PROFILE_SIZE := Vector2i(1854, 1011)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var seconds := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hud-profile-seconds="):
			seconds = float(arg.get_slice("=", 1))
	var shots := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hud-bar-shots="):
			shots = arg.get_slice("=", 1)
	if shots != "":
		bar_shots(shots)
	elif seconds > 0.0:
		profile(seconds)
	else:
		run()


func profile(seconds: float) -> void:
	var tree := get_tree()
	if DisplayServer.get_name() == "headless":
		tree.root.size = PROFILE_SIZE  # trip-up 31: a headless root is 64x64, and the HUD would lay out for that
	await tree.create_timer(2.0, true, false, true).timeout
	var controls := main.get_node_or_null("HUD/TacticalMap") as RtsControls
	if controls != null:
		controls.set_paused(false)
		# His first click closes the planning intro's tooltip (and its animated preview) for good; nobody clicks here.
		var panel := controls.get_node_or_null("SelectionPanel") as SelectionPanel
		if panel != null:
			panel.dismiss_intro()
	await tree.create_timer(PROFILE_WARMUP_SECONDS, true, false, true).timeout
	# Round 18 (picker P5): `--hud-profile-picker=open` measures with the Formation panel open (pinned, previewing the
	# card in use); without it the panel stays closed, and its rows must show no calls at all.
	var picker_open := OS.get_cmdline_user_args().has("--hud-profile-picker=open")
	if picker_open and controls != null:
		if controls.selection.units.is_empty():
			controls.recall_group(1)
		await tree.process_frame
		var picker_panel := controls.get_node_or_null("SelectionPanel") as SelectionPanel
		if picker_panel != null:
			picker_panel.picker.pinned = true
			picker_panel.picker.open()
		await tree.create_timer(1.0, true, false, true).timeout
	var vehicles_start := _vehicles()
	HudClock.reset()
	HudClock.on = true
	var frames := 0
	var process_ms := 0.0
	var started := Time.get_ticks_usec()
	var reference_usec := 0
	# Round 18 (picker): `--hud-digest=PATH` writes one line a frame, a hash of what the HUD's per-unit work produced
	# (the markers placed, the element awareness, the vision state), so a change that claims EQUAL OUTPUT can be
	# compared frame for frame with the arm before it. Run it with `--fixed-fps 60` so frames are ticks
	# (`make hud-digest`); its timings are not measurements (it calls vision_state a second time).
	var digest_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hud-digest="):
			digest_path = arg.get_slice("=", 1)
	var digest: FileAccess = FileAccess.open(digest_path, FileAccess.WRITE) if digest_path != "" else null
	while Time.get_ticks_usec() - started < int(seconds * 1000000.0):
		await tree.process_frame
		frames += 1
		if digest != null:
			digest.store_line("%d %s" % [frames, HudCostProbe.digest_of(main, controls)])
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var t := Time.get_ticks_usec()
		HudClock.reference_work()
		reference_usec += Time.get_ticks_usec() - t
	HudClock.on = false
	if digest != null:
		digest.close()
	var wall := (Time.get_ticks_usec() - started) / 1000000.0
	var reference := float(reference_usec) / frames  # µs of the yardstick, on average, this run
	var rows: Array = []
	var hud_usec := 0
	for row: Dictionary in HudClock.report():
		row["per_frame_calls"] = snappedf(float(row["calls"]) / frames, 0.01)
		row["usec_per_frame"] = snappedf(float(row["usec"]) / frames, 0.1)
		row["refs_per_frame"] = snappedf(float(row["usec"]) / frames / reference, 0.01)
		var key := String(row["key"])
		if key.ends_with(".process") or key.ends_with(".draw"):
			hud_usec += int(row["usec"])  # widget entry points only: sub-timers nest inside them
		rows.append(row)
		print("HUD_PROFILE ", JSON.stringify(row))
	var report := {"frames": frames, "seconds": snappedf(wall, 0.01), "picker": "open" if picker_open else "closed",
			"selected": controls.selection.units.size() if controls != null else 0, "fps": snappedf(frames / wall, 0.1),
			"vehicles": [vehicles_start, _vehicles()], "screen": [tree.root.size.x, tree.root.size.y],
			"display": DisplayServer.get_name(), "process_ms_per_frame": snappedf(process_ms / frames, 0.01),
			"hud_ms_per_frame": snappedf(hud_usec / 1000.0 / frames, 0.001),
			"reference_usec": snappedf(reference, 0.1), "hud_refs_per_frame": snappedf(hud_usec / float(frames) / reference, 0.01),
			"rows": rows}
	print("HUD_PROFILE_SUMMARY ", JSON.stringify({"frames": frames, "fps": report["fps"], "picker": report["picker"],
			"selected": report["selected"], "vehicles": report["vehicles"],
			"process_ms_per_frame": report["process_ms_per_frame"], "hud_ms_per_frame": report["hud_ms_per_frame"],
			"reference_usec": report["reference_usec"], "hud_refs_per_frame": report["hud_refs_per_frame"]}))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	print("HUD_COST_DONE")
	tree.quit(0)


## Round 18: one frame of the HUD's per-unit output as hashes "markers:awareness:vision" (exact: var_to_bytes, no
## rounding). A part that does not exist hashes as 0.
static func digest_of(main_node: Node, controls: RtsControls) -> String:
	var markers := main_node.get_node_or_null("SelectionMarkers") as SelectionMarkers if main_node != null else null
	var marks := 0
	if markers != null:
		var placed := []
		for kind: String in SelectionMarkers.KINDS:
			placed.append([kind, markers.last_placed.get(kind, [])])
		marks = hash(var_to_bytes([placed, markers.state()]))
	var aware := 0
	var vision := 0
	if controls != null:
		if controls.awareness != null:
			aware = hash(var_to_bytes(controls.awareness.elements()))
		var state := controls.vision_state()
		var region: VisionRegion = state.get("region") as VisionRegion
		vision = hash(var_to_bytes([state.get("frame"), state.get("own"), state.get("pad_m"), state.get("destination"),
				region.discs if region != null else []]))
	return "%d:%d:%d" % [marks, aware, vision]


func _vehicles() -> int:
	return main.game_match.alive_count(Match.Team.GREEN) + main.game_match.alive_count(Match.Team.RUST)


func run() -> void:
	var tree := get_tree()
	await tree.create_timer(2.0, true, false, true).timeout
	var controls := main.get_node_or_null("HUD/TacticalMap") as RtsControls
	if controls != null:
		controls.set_paused(false)
	await tree.create_timer(WARMUP_SECONDS, true, false, true).timeout
	if controls != null:
		controls.set_paused(true, "")
	var hud := main.get_node("HUD") as CanvasLayer
	var widgets: Array[Node] = []
	for child in hud.get_children():
		if child is CanvasItem and child.name != "TacticalMap":
			widgets.append(child)
	if controls != null:
		for child in controls.get_children():
			if child is CanvasItem:
				widgets.append(child)
	var markers := main.get_node_or_null("SelectionMarkers")
	var baseline := await _measure("all")
	var hud_off := await _measure_hidden("whole_hud", [hud], baseline)
	if controls != null:
		# Every widget under the map at once; the map's own drawing (rings, bars, waypoints) is whole_hud minus the rest.
		await _measure_hidden("tactical_map_children", [controls], baseline, true)
	for widget in widgets:
		await _measure_hidden(String(widget.name), [widget], baseline)
	if markers != null:
		await _measure_hidden("selection_markers_3d", [markers], baseline)
	var vehicles: int = main.game_match.alive_count(Match.Team.GREEN) + main.game_match.alive_count(Match.Team.RUST)
	var report := {"vehicles": vehicles, "screen": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
			"all": baseline, "hud_canvas_draw_calls": baseline["canvas_draw_calls"] - hud_off["canvas_draw_calls"],
			"hud_process_ms": snappedf(baseline["process_ms"] - hud_off["process_ms"], 0.01), "widgets": _rows}
	print("HUD_COST_SUMMARY ", JSON.stringify(report))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	print("HUD_COST_DONE")
	tree.quit(0)


func _measure_hidden(label: String, nodes: Array, before: Dictionary, children_only := false) -> Dictionary:
	var hidden: Array = []
	for node: Node in nodes:
		var targets: Array = node.get_children().filter(func(c: Node) -> bool: return c is CanvasItem) if children_only else [node]
		for target: Node in targets:
			hidden.append([target, target.get("visible"), target.process_mode])
			target.set("visible", false)
			target.process_mode = Node.PROCESS_MODE_DISABLED
	var off := await _measure("no_" + label)
	for entry in hidden:
		(entry[0] as Node).set("visible", entry[1])
		(entry[0] as Node).process_mode = entry[2]
	var after := await _measure("all")
	var draws: float = (before["canvas_draw_calls"] + after["canvas_draw_calls"]) / 2.0 - off["canvas_draw_calls"]
	var total: float = (before["draw_calls"] + after["draw_calls"]) / 2.0 - off["draw_calls"]
	var ms: float = (before["process_ms"] + after["process_ms"]) / 2.0 - off["process_ms"]
	var row := {"widget": label, "canvas_draw_calls": roundi(draws), "draw_calls": roundi(total), "process_ms": snappedf(ms, 0.01)}
	_rows.append(row)
	print("HUD_COST ", JSON.stringify(row))
	return off


func _measure(label: String) -> Dictionary:
	var tree := get_tree()
	await tree.process_frame
	await tree.process_frame
	var frames := 0
	var canvas := 0.0
	var total := 0.0
	var process := 0.0
	while frames < PHASE_FRAMES:
		await RenderingServer.frame_post_draw
		frames += 1
		canvas += get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		total += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	frames = maxi(frames, 1)
	return {"label": label, "frames": frames, "canvas_draw_calls": canvas / frames, "draw_calls": total / frames,
			"process_ms": process / frames}


## Round 16 (hud, the bar fixes): `--hud-bar-shots=DIR` - the hull bars at his pose (the skirmish's own camera on group
## 1, his window): the Road Gangs' 14 m rig and a scout set down in sight in front of the group, one selected friendly hurt,
## the tactical pause taken, then the whole frame and a crop around each of the three saved as PNGs in DIR. Needs a
## display. Run before and after a bar change and compare (references/round16/hud/).
func bar_shots(dir: String) -> void:
	var tree := get_tree()
	DirAccess.make_dir_recursive_absolute(dir)
	await tree.create_timer(2.0, true, false, true).timeout
	var controls := main.get_node_or_null("HUD/TacticalMap") as RtsControls
	controls.get_node("SelectionPanel").dismiss_intro()
	controls.recall_group(1)
	controls.set_paused(false)
	var game_match := main.game_match
	var ours: Array = []
	for unit_name in controls.selection.units:
		ours.append(game_match.tanks.get_node(NodePath(unit_name)))
	var middle := Vector3.ZERO
	for tank: Tank in ours:
		middle += tank.global_position
	middle /= maxf(ours.size(), 1)
	var ahead: Vector3 = Match.team_frame(controls.team)["forward"]
	var right: Vector3 = Match.team_frame(controls.team)["right"]
	var picks := {"rig": "gang_tank", "scout": "gang_scout"}
	var placed := {}
	for key: String in picks:
		for tank in game_match.sorted_team_tanks(1 - controls.team):
			if tank.unit_id == picks[key] and tank.is_alive() and not placed.values().has(tank):
				placed[key] = tank
				break
	if not placed.has("rig"):
		# This army fielded no rig: one stands in (no brain, so it stays where it is set down).
		placed["rig"] = game_match.spawn_tank("Rust_ShotRig", 0, 1 - controls.team, "gang_tank")
	var spots := {"rig": middle + ahead * 32.0 - right * 10.0, "scout": middle + ahead * 30.0 + right * 12.0}
	for key: String in placed:
		var tank: Tank = placed[key]
		tank.global_position = Vector3(spots[key].x, tank.global_position.y, spots[key].z)
		tank.reset_physics_interpolation()
		tank.health = int(tank.max_health * 0.6)  # hurt, so its bar is drawn solid rather than as the quiet full one
	var hurt: Tank = ours[0] if not ours.is_empty() else null
	if hurt != null:
		hurt.health = int(hurt.max_health * 0.45)
	placed["hurt_selected"] = hurt
	await tree.create_timer(1.0, true, false, true).timeout  # an intel tick or more: the enemies are seen
	controls.set_paused(true, "")
	for i in 6:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(dir.path_join("frame.png"))
	var camera := get_viewport().get_camera_3d()
	var lines: Array[String] = []
	for key: String in placed:
		var tank: Tank = placed[key]
		if tank == null or camera.is_position_behind(tank.global_position):
			lines.append("%s: not in view" % key)
			continue
		var at := camera.unproject_position(tank.global_position + Vector3.UP * 3.0)
		var box := Rect2i(Vector2i(at) - Vector2i(160, 170), Vector2i(320, 260)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		if box.has_area():
			var crop := image.get_region(box)
			crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
			crop.save_png(dir.path_join("%s.png" % key))
		lines.append("%s: %s %s at %s visible=%s alive=%s hp=%d/%d shield=%.0f/%.0f camera_m=%.0f" % [key, tank.name, tank.unit_id, at,
				game_match.is_visible_to(controls.team, tank), tank.is_alive(), tank.health, tank.max_health, tank.shield,
				tank.max_shield, camera.global_position.distance_to(tank.global_position)])
	print("HUD_BAR_SHOTS ", " | ".join(lines))
	print("HUD_COST_DONE")
	tree.quit(0)
