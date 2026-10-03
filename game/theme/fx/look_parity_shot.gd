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
## boom over the centre), `base` (the same over the south base, looking south), `venue` (a low look at the north stands, screens and
## skyline) and `overview` (77 deg from 200 m: the whole floor, water and the cutaway's blocks).
##
## Flags: --look-parity=<abs dir>  --look-parity-ticks=a,b,c (150)  --look-parity-no-stage
## Prints LOOK_PARITY_FRAME <file> tick=<n> and LOOK_PARITY_DONE files=<n>.

const PITCH_DEG := 21.0
const FOV_DEG := 35.0
const DISTANCE_M := 49.0
## Frames to let the always-processing systems (lights, LOD, cutaway, crowd) answer a camera move before the capture.
const SETTLE_FRAMES := 4
## A hang guard: the shots should finish long before this many frames.
const MAX_FRAMES := 30 * 60 * 4
## Frames of FX clock (1/30 s each) between staging the effects and shooting them: fireballs mid-bloom, the fires'
## haze most of the way in (HeatHaze ramps over 1 s), the crowd mid-cheer.
const STAGE_FRAMES := 20

var out_dir := ""
## The windowed skirmish is NOT repeatable across runs past first contact, even at --fixed-fps (round 16: two runs of
## the same tree agreed to 0.015 % at tick 150 and to 3-75 % at 450 and 900 -- different fights). So the default
## freezes ONCE, before contact, and the battle's effects are STAGED on that frozen frame (`_stage`) rather than
## waited for.
var ticks: Array[int] = [150]
## `--look-parity-no-stage`: the frozen frame only, no staged effects.
var stage_effects := true
## `--look-parity-ref=<abs dir>` + `--look-parity-ref-layers=a,b`: every frame is shot a second time, at the same
## frozen instant, with RenderLayers' "before" layers swapped in (the code as it was before a render change), into
## the ref dir. The two sets then differ in that change and in nothing else -- not even the GPU's warm-up.
var ref_dir := ""
var ref_layers: Array[String] = []
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
		elif arg == "--look-parity-no-stage":
			stage_effects = false
		elif arg.begins_with("--look-parity-ref="):
			ref_dir = arg.trim_prefix("--look-parity-ref=")
		elif arg.begins_with("--look-parity-ref-layers="):
			for piece in arg.trim_prefix("--look-parity-ref-layers=").split(",", false):
				ref_layers.append(piece)
	if out_dir == "":
		set_physics_process(false)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	if ref_dir != "":
		DirAccess.make_dir_recursive_absolute(ref_dir)
	# builder0's compositor throttles a hidden vsync'd window to ~1 frame a second (795 frames in 800 s, 2026-10-02),
	# and under --fixed-fps every frame is a tick, so a set took an hour. These frames are judged by pixels, not time.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
	var tag := "t%04d" % at_tick
	await _shoot_set(tag, at_tick)
	if stage_effects:
		# Staged combat (see the header): effects at fixed places, then only the FX clock runs, a fixed number of
		# fixed-length frames, with the simulation still paused. Every run gets the same fireballs at the same ages.
		var fx := FxWorld.existing()
		if fx != null:
			var shake := fx.shake.enabled
			fx.shake.enabled = false
			LookParityShot.stage(fx, _live_focus(), self)
			Engine.time_scale = 1.0
			for i in STAGE_FRAMES:
				await get_tree().process_frame
			Engine.time_scale = 0.0
			await _shoot_set(tag + "_fx", at_tick)
			fx.shake.enabled = shake
	_next += 1
	if _next >= ticks.size():
		print("LOOK_PARITY_DONE files=%d in %s" % [_written, out_dir])
		Engine.time_scale = 1.0
		get_tree().quit()
		return
	Engine.time_scale = 1.0
	get_tree().paused = false
	_busy = false


## The live camera's view, then the four fixed poses, of the frozen instant.
func _shoot_set(tag: String, at_tick: int) -> void:
	var live := get_viewport().get_camera_3d()
	await _settle()
	await _save_both("live_%s.png" % tag, at_tick)
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
	# `his` and `base` are lifted over buildings exactly as the live camera is (RtsCamera.clear_pose), or on a city map
	# they are the inside of a wall. `base` looks SOUTH from inside the arena, so the south stands are its backdrop
	# and `venue` (looking north, low) has the north ones.
	var poses := [
		["his", _clear(Vector3.ZERO, 0.0, DISTANCE_M, PITCH_DEG)],
		["base", _clear(Vector3(0.0, 0.0, half * 0.6), PI, DISTANCE_M, PITCH_DEG)],
		["venue", RtsCamera.pose_at(Vector3(0.0, 0.0, -half * 0.55), 0.0, DISTANCE_M, 12.0)],
		["overview", RtsCamera.pose_at(Vector3.ZERO, 0.0, 200.0, 77.0)],
	]
	for pose: Array in poses:
		cam.global_transform = pose[1]
		cam.current = true
		await _settle()
		await _save_both("%s_%s.png" % [pose[0], tag], at_tick)
	cam.current = false
	if live != null:
		live.current = true
	cam.queue_free()
	await _settle()


## Where the live camera looks on the ground (its forward ray meets y = 0), or the centre.
func _live_focus() -> Vector3:
	return LookParityShot.live_focus(get_viewport())


static func live_focus(viewport: Viewport) -> Vector3:
	var live := viewport.get_camera_3d()
	if live == null:
		return Vector3.ZERO
	var ray := -live.global_basis.z
	if ray.y > -0.01:
		return Vector3.ZERO
	var t := -live.global_position.y / ray.y
	var hit := live.global_position + ray * t
	return Vector3(hit.x, 0.0, hit.z)


## Kills, hits and laser fire at fixed offsets around the centre (his pose) and the live camera's focus: fireballs,
## sparks, ground glows, pooled lights, burning wrecks (so the heat haze is in frame), beams, the crowd's and the
## show's ripple. Everything goes through FxWorld's public calls, as combat's own effects do.
## `beam_owner` keeps the staged beams alive (a beam is removed when its source is freed). RenderSplit stages the same.
static func stage(fx: FxWorld, focus: Vector3, beam_owner: Object) -> void:
	for centre: Vector3 in [Vector3.ZERO, focus]:
		for i in 6:
			var angle := TAU * float(i) / 6.0
			var at := centre + Vector3(cos(angle), 0.0, sin(angle)) * (6.0 + 3.0 * float(i % 3))
			fx.explosion(at + Vector3.UP * 0.6, i % 2 == 0)
		fx.laser(beam_owner, centre + Vector3(-14.0, 1.2, 4.0), centre + Vector3(10.0, 1.0, -6.0), Color(1.0, 0.2, 0.6))
		fx.laser(beam_owner, centre + Vector3(12.0, 1.2, 8.0), centre + Vector3(-8.0, 1.0, -10.0), Color(0.2, 0.9, 1.0))


func _clear(focus: Vector3, yaw: float, distance: float, pitch: float) -> Transform3D:
	var clear := RtsCamera.clear_pose(focus, yaw, distance, pitch)
	return RtsCamera.pose_at(focus, yaw, float(clear["distance"]), float(clear["pitch_deg"]))


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


## The frame as it is, then (with a ref dir) the same frame with the "before" layers swapped in.
func _save_both(file: String, at_tick: int) -> void:
	_save(file, at_tick)
	if ref_dir == "" or ref_layers.is_empty():
		return
	var undo: Array = []
	for layer in ref_layers:
		undo.append_array(RenderLayers.apply(get_tree(), layer))
	await _settle()
	_save(file, at_tick, ref_dir)
	RenderLayers.restore(undo)
	await _settle()


func _save(file: String, at_tick: int, dir := "") -> void:
	var err := get_viewport().get_texture().get_image().save_png((out_dir if dir == "" else dir).path_join(file))
	if err != OK:
		push_error("look-parity: could not save %s (%s)" % [file, error_string(err)])
		return
	_written += 1
	print("LOOK_PARITY_FRAME %s tick=%d" % [file, at_tick])
