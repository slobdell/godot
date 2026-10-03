class_name LookParityShot
extends Node
## `make look-parity-shots` (render, round 16, R1): the frames `tools/look_parity.py` diffs to prove a performance
## change left the picture alone (contract C16.6: "the picture he sees does not change").
##
## A diff is only worth something if two runs of the SAME code produce the same pixels, so everything that varies
## between runs is pinned rather than tolerated:
##   * the run is `--fixed-fps 30` (the Makefile passes it): every frame advances exactly one 30 Hz tick and 1/30 s of
##     FX clock and shader TIME, whatever the machine's real frame time was. The simulation, the camera's smoothing,
##     the effects' ages and every animated shader land on the same values in every run;
##   * each capture FREEZES the scene at an exact match tick (the tree paused from inside the physics step, so no
##     further tick runs, and `Engine.time_scale = 0`, so the always-processing FX and shader clocks stop too), then
##     shoots every pose of the same frozen instant before letting it run on.
## What is left is the GPU's own rounding, which is what the before/before run measures (the noise floor).
##
## Poses, per tick: `live` is the scene's own camera exactly as he would see it (HUD included -- the HUD is part of the
## picture), then four fixed cameras that cover what the live camera may not be looking at: `his` (his pitch, FOV and
## boom over the centre), `base` (the same over the south base), `venue` (a low look at the north stands, screens and
## skyline) and `overview` (77 deg from 200 m: the whole floor, water and the cutaway's blocks).
##
## Flags: --look-parity=<abs dir>  --look-parity-ticks=a,b,c (150,450,900)
## Prints LOOK_PARITY_FRAME <file> tick=<n> and LOOK_PARITY_DONE files=<n>.

const PITCH_DEG := 21.0
const FOV_DEG := 35.0
const DISTANCE_M := 49.0
## Frames to let the always-processing systems (lights, LOD, cutaway, crowd) answer a camera move before the capture.
const SETTLE_FRAMES := 4
## A hang guard: the shots should finish long before this many frames.
const MAX_FRAMES := 30 * 60 * 4

var out_dir := ""
var ticks: Array[int] = [150, 450, 900]
var _next := 0
var _match: Node
var _busy := false
var _frames := 0
var _written := 0


static func wanted() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--look-parity="):
			return true
	return false


func _init() -> void:
	name = "LookParityShot"
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After the match's own physics step, so "the tick is N" means tick N has fully run.
	process_physics_priority = 1000


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--look-parity="):
			out_dir = arg.trim_prefix("--look-parity=")
		elif arg.begins_with("--look-parity-ticks="):
			ticks.clear()
			for piece in arg.trim_prefix("--look-parity-ticks=").split(","):
				ticks.append(int(piece))
			ticks.sort()
	if out_dir == "":
		set_physics_process(false)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	# `--fixed-fps` is consumed by the engine and is not in the user args: the Makefile is what guarantees it.
	print("LOOK_PARITY_START dir=%s ticks=%s" % [out_dir, ticks])


func _process(_delta: float) -> void:
	_frames += 1
	if _frames > MAX_FRAMES:
		print("LOOK_PARITY_FAILED timeout at frame %d, tick %d" % [_frames, _tick()])
		get_tree().quit(1)


func _physics_process(_delta: float) -> void:
	if _busy or _next >= ticks.size():
		return
	if _match == null:
		var scene := get_tree().current_scene
		_match = scene.get_node_or_null("Match") if scene != null else null
		if _match == null:
			return
	var tick := _tick()
	if tick > 0 and tick % 150 == 0:
		print("LOOK_PARITY_PROGRESS tick=%d frame=%d wall=%.1fs" % [tick, Engine.get_frames_drawn(), Time.get_ticks_msec() / 1000.0])
	if tick < ticks[_next]:
		return
	_busy = true
	# Paused from inside the step: no further tick runs, whatever this frame's step count was.
	get_tree().paused = true
	Engine.time_scale = 0.0
	_shoot.call_deferred(ticks[_next])


func _tick() -> int:
	return int(_match.get("tick")) if _match != null else -1


func _shoot(at_tick: int) -> void:
	var live := get_viewport().get_camera_3d()
	var tag := "t%04d" % at_tick
	await _settle()
	_save("live_%s.png" % tag, at_tick)
	var cam := Camera3D.new()
	cam.fov = FOV_DEG
	if live != null:
		cam.near = live.near
		cam.far = live.far
		cam.attributes = live.attributes
		cam.environment = live.environment
		cam.cull_mask = live.cull_mask
	add_child(cam)
	var half := float(Match.ARENA_HALF_SIZE)
	var poses := [
		["his", RtsCamera.pose_at(Vector3.ZERO, 0.0, DISTANCE_M, PITCH_DEG)],
		["base", RtsCamera.pose_at(Vector3(0.0, 0.0, half * 0.7), 0.0, DISTANCE_M, PITCH_DEG)],
		["venue", RtsCamera.pose_at(Vector3(0.0, 0.0, -half * 0.55), 0.0, DISTANCE_M, 12.0)],
		["overview", RtsCamera.pose_at(Vector3.ZERO, 0.0, 200.0, 77.0)],
	]
	for pose: Array in poses:
		cam.global_transform = pose[1]
		cam.current = true
		await _settle()
		_save("%s_%s.png" % [pose[0], tag], at_tick)
	cam.current = false
	if live != null:
		live.current = true
	cam.queue_free()
	await _settle()
	_next += 1
	if _next >= ticks.size():
		print("LOOK_PARITY_DONE files=%d in %s" % [_written, out_dir])
		Engine.time_scale = 1.0
		get_tree().quit()
		return
	Engine.time_scale = 1.0
	get_tree().paused = false
	_busy = false


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(file: String, at_tick: int) -> void:
	var err := get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	if err != OK:
		push_error("look-parity: could not save %s (%s)" % [file, error_string(err)])
		return
	_written += 1
	print("LOOK_PARITY_FRAME %s tick=%d" % [file, at_tick])
