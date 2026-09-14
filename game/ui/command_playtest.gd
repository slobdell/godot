class_name CommandPlaytest
extends Node
## The command stream's playtest script (`make command-playtest`, `--skirmish --command-playtest=DIR`):
## plays like a player through the real UI and records what the camera did.
##   for each squad: tap its chip → tap a far spot on the radar (off screen) → watch for WATCH_SECONDS
## Every SAMPLE_SECONDS it logs the camera (focus, zoom, tracking mode, whether the squad and its
## destination are on screen) to DIR/camera.jsonl; with a display it also saves frames to DIR/*.png.
## At the end it prints one COMMAND_PLAYTEST line per squad and COMMAND_PLAYTEST_DONE ok=true|false:
##   squad_framed_after  seconds until the squad was on screen (-1 = never); must be under FRAME_DEADLINE
##   both_framed_after   seconds until squad and destination were on screen together (-1 = never: a far goal)
##   max_speed           the fastest the view moved (m/s); must stay under the tracking limit
##   max_zoom            the highest the camera went while tracking (≤ RtsCamera.TRACK_MAX_ZOOM)
##   tracked             whether order tracking started

const WATCH_SECONDS := 8.0
const SAMPLE_SECONDS := 0.25
const FRAME_AT := [0.0, 1.0, 3.0, 6.0]
const FRAME_DEADLINE := 4.0
const SPEED_WINDOW_SECONDS := 0.25

var map: TacticalMap
var radar: Radar
var out_dir := ""

var _camera_log: FileAccess
var _can_capture := false


func run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	_camera_log = FileAccess.open(out_dir.path_join("camera.jsonl"), FileAccess.WRITE)
	_can_capture = DisplayServer.get_name() != "headless"
	if not _can_capture:
		get_tree().root.size = Vector2i(1280, 720)  # headless roots are 64×64 (trip-up #31)
	var tree := get_tree()
	await tree.create_timer(1.0).timeout
	var ok := true
	var squads := map.game_match.team_squads(map.team)
	for i in squads.size():
		var squad := squads[i]
		map.tap_squad_chip(squad.squad_name)
		await tree.create_timer(0.5).timeout
		await _capture("%d_%s_selected" % [i, squad.squad_name.to_lower()])
		# Far up the enemy's half, alternating flanks: off screen from our side of the arena.
		var forward: Vector3 = Match.team_frame(map.team)["forward"]
		var goal := Vector3(50.0 if i % 2 == 0 else -50.0, 0.0, -45.0 * forward.dot(Vector3.FORWARD))
		var destination_on_screen := map.all_on_screen([goal])
		radar.tap(radar.world_to_radar(goal))
		var tracked := map.rig.is_tracking()
		var result := await _watch(squad.squad_name, goal, i)
		var line := {"squad": squad.squad_name, "goal": [goal.x, goal.z], "destination_was_on_screen": destination_on_screen,
				"tracked": tracked, "squad_framed_after": result["squad_after"], "both_framed_after": result["both_after"],
				"max_speed": snappedf(result["max_speed"], 0.1), "speed_limit": RtsCamera.TRACK_SPEED,
				"max_zoom": snappedf(result["max_zoom"], 0.01)}
		print("COMMAND_PLAYTEST ", JSON.stringify(line))
		if destination_on_screen:
			continue
		ok = ok and tracked and float(result["squad_after"]) >= 0.0 and float(result["squad_after"]) <= FRAME_DEADLINE \
				and float(result["max_speed"]) <= RtsCamera.TRACK_SPEED * 1.05 and float(result["max_zoom"]) <= RtsCamera.TRACK_MAX_ZOOM + 0.02
	_camera_log.close()
	print("COMMAND_PLAYTEST_DONE ok=%s dir=%s" % [ok, out_dir])
	tree.quit(0 if ok else 1)


func _watch(squad_name: String, goal: Vector3, index: int) -> Dictionary:
	var tree := get_tree()
	var elapsed := 0.0
	var squad_after := -1.0
	var both_after := -1.0
	var max_speed := 0.0
	var max_zoom := 0.0
	var last_focus := map.rig._shown_focus
	var last_usec := Time.get_ticks_usec()
	var next_sample := 0.0
	var frames := FRAME_AT.duplicate()
	while elapsed < WATCH_SECONDS:
		await tree.process_frame
		var delta := get_process_delta_time()
		elapsed += delta
		# Speed over quarter-second windows of real time: single frames are noisy (captures span frames, and
		# the engine smooths frame deltas), and a quarter second is what an eye perceives as a whip anyway.
		var now_usec := Time.get_ticks_usec()
		var seconds := float(now_usec - last_usec) / 1e6
		if seconds >= SPEED_WINDOW_SECONDS:
			max_speed = maxf(max_speed, map.rig._shown_focus.distance_to(last_focus) / seconds)
			last_focus = map.rig._shown_focus
			last_usec = now_usec
		if map.rig.is_tracking():
			max_zoom = maxf(max_zoom, map.rig._shown_zoom)
		var points := map.squad_points(squad_name)
		var squad_framed := not points.is_empty() and map.all_on_screen(points)
		var both := squad_framed and map.all_on_screen([goal])
		if squad_framed and squad_after < 0.0:
			squad_after = snappedf(elapsed, 0.01)
		if both and both_after < 0.0:
			both_after = snappedf(elapsed, 0.01)
		if elapsed >= next_sample:
			next_sample += SAMPLE_SECONDS
			_camera_log.store_line(JSON.stringify({"squad": squad_name, "t": snappedf(elapsed, 0.01),
					"focus": [snappedf(map.rig._shown_focus.x, 0.1), snappedf(map.rig._shown_focus.z, 0.1)],
					"zoom": snappedf(map.rig._shown_zoom, 0.001), "tracking": map.rig.tracking_mode(),
					"squad_on_screen": squad_framed, "goal_on_screen": map.all_on_screen([goal])}))
		if not frames.is_empty() and elapsed >= float(frames[0]):
			await _capture("%d_%s_order_%.0fs" % [index, squad_name.to_lower(), float(frames.pop_front())])
	return {"squad_after": squad_after, "both_after": both_after, "max_speed": max_speed, "max_zoom": max_zoom}


func _capture(shot_name: String) -> void:
	if not _can_capture:
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(out_dir.path_join(shot_name + ".png"))
