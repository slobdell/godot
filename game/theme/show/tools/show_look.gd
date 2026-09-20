class_name ShowLook
extends Node
## `make show-frames` (S6): the arena light show at THE LEAD'S POSE, before and after, so a human can answer the only
## question that matters about it — *"make it beautiful"*. `_agents/lighting.md` section 9.
##
## His pose is 21 degrees of pitch, FOV 35, 49 m (NOT 12 degrees: that is the camera he played and rejected). The
## same three numbers `size_look.gd` uses, and for the same reason — a frame we show him is shot from where he sits.
##
## It rides a real skirmish (the [Show] adds it on `--show-look=<abs dir>`), pauses the tree, and then drives the
## show's clock BY HAND: `show.apply(t)` at each requested moment. That is why the strip is reproducible — the same
## commit gives the same frames on any machine, at any frame rate, instead of depending on how long a warmup slept.
## It is also the reason [method Show.apply] is public.
##
## It shoots the idle breathe AND the cues, because the idle is the ambience and the cues are the show: the lead is
## being asked whether it is beautiful, and a strip of only the slow breathe answers half the question.
##
## Flags: --show-look=<abs dir>  --show-look-times=0,8.1,16.3  --show-look-warmup=S (3)
##        --show-look-cues=fight,battle,last_stand,victory  --show-look-ripples=0.25,0.55,1.1
##        --show-style=outline (the variant)   --no-show (the BEFORE arm: no patch, every fixture at its identity)
##        --show-look-clip=<cue> --show-look-clip-frames=60 --show-look-clip-step=0.1 (a sequence, for ffmpeg)

const PITCH_DEG := 21.0
const DISTANCE_M := 49.0
const FOV_DEG := 35.0
## A second, closer pose at the same pitch and FOV: the venue read from where a fight actually happens.
const CLOSE_M := 22.0
## When a cue frame is taken. Far enough into the show's clock that no channel is sitting at its starting phase.
const CUE_T := 31.4
## How far into the kill ripple the frame is taken: the wavefront is 62 m/s, so this catches it crossing the blocks.
const RIPPLE_AGE_S := 0.55
## THE BRIGHTNESS HIERARCHY, and it is play rather than taste (feel, 2026-09-20; art_direction.md :72, the arena
## must be "lit well enough to read the fight"). The first strip inverted it: the brightest pixels in the frame were
## the building edges and the darkest were the arena floor and the vehicles. These two windows are sampled from
## every frame and compared -- RING is the middle of the frame, where the fight is; BAND is the top, where the
## blocks and the stands are. Fractions of the frame, as (x0, y0, x1, y1).
const RING_WINDOW := Rect2(0.28, 0.38, 0.44, 0.34)
const BAND_WINDOW := Rect2(0.00, 0.01, 1.00, 0.24)
## The WHOLE picture. A venue-wide cue -- a strobe, a chase round the rim -- does not live in either window: the
## rim is at the horizon and the parapets are wherever the buildings happen to be once the camera follows the
## army. Measuring a strobe in the band window returned the SAME 2.9% swing with the strobe on and off, which is
## the statistic looking in the wrong place rather than the cue failing to fire.
const FULL_WINDOW := Rect2(0.0, 0.0, 1.0, 1.0)
## Every Nth pixel in each direction: exact enough for a mean, cheap enough to run on every frame.
const LUMA_STRIDE := 8
## Arena -> an extra focus worth a frame, in metres. The Terminus street is the alley the lead said he could not see
## into; blocks sit at x = 20..60 and x = 80..120, so x = 70 is the middle of the 20 m street between them.
const FOCUS_POINTS := {
	"terminus": Vector3(70.0, 0.0, 0.0),
}

var out_dir := ""
var times: Array = [0.0, 8.1, 16.3]
## The cues worth a frame. `fight` is the moment the loading screen drops; `battle` and `victory` are the two the
## lead is most likely to judge the idea on.
var cues: Array = ["fight", "battle", "last_stand", "victory"]
## Wavefront ages for the kill ripple, in seconds. Shot against the IDLE rather than against `battle`: the first
## strip took the ripple under the battle cue, where the edge channel is already near its ceiling and there is no
## headroom left to ripple into, and the frame was indistinguishable from `cue_battle`.
var ripples: Array = [0.25, 0.55, 1.1]
## A cue to shoot as a SEQUENCE instead of a strip: stills cannot show a chase, a sweep or a strobe, because those
## are motion. Empty means shoot the strip.
var clip_cue := ""
var clip_frames := 60
var clip_step := 0.1
## Long enough for the armies to leave their spawns and CLOSE. At 3 s -- the old default -- they are still on the
## spawn line ~86 m from the arena centre, so every frame this stream shot before 2026-09-20 midday framed an
## empty control ring and called it the fight.
var warmup := 20.0
var _camera := Camera3D.new()


func _init() -> void:
	name = "ShowLook"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var flags := LaunchFlags.from_environment()
	out_dir = flags.text("show-look")
	warmup = float(flags.text("show-look-warmup", str(warmup)))
	var listed := flags.text("show-look-times")
	if listed != "":
		times = Array(listed.split(",", false)).map(func(v: String) -> float: return float(v))
	var wanted := flags.text("show-look-cues")
	if wanted != "":
		cues = Array(wanted.split(",", false))
	var ages := flags.text("show-look-ripples")
	if ages != "":
		ripples = Array(ages.split(",", false)).map(func(v: String) -> float: return float(v))
	clip_cue = flags.text("show-look-clip")
	clip_frames = int(flags.text("show-look-clip-frames", str(clip_frames)))
	clip_step = float(flags.text("show-look-clip-step", str(clip_step)))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_camera.name = "ShowLookCamera"
	_camera.fov = FOV_DEG
	_camera.far = 1200.0
	add_child(_camera)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(warmup, true, false, true).timeout
	var arena := str(Arena.active.get("name", "arena"))
	var show := get_parent() as Show
	var scene := get_tree().current_scene
	var rig := scene.get_node_or_null("RtsCamera") if scene != null else null
	var heading: float = rig.get("yaw") if rig != null else 0.0
	if rig != null:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
	_camera.current = true
	# Point the camera at the FIGHT, not at the middle of the map. The two are not the same place: the armies
	# spawn at the ends and the control ring is only where they eventually meet. A frame of the venue with no
	# vehicles in it cannot answer either question we shoot frames for -- how it looks, or whether it out-reads
	# the fight -- and the readability gate's "ring" window was measuring bare asphalt.
	var centre := _army_centre(scene)
	var poses := {"wide": [centre, DISTANCE_M], "close": [centre, CLOSE_M]}
	if FOCUS_POINTS.has(arena):
		poses["street"] = [FOCUS_POINTS[arena], CLOSE_M]
	get_tree().paused = true
	if clip_cue != "":
		await _shoot_clip(show, arena, heading)
		return
	# THE IDLE FRAMES MUST BE THE IDLE. The FIGHT cue holds for 5 s after the arena loads and the warmup is 3, so
	# without this the first strip shot three frames of FIGHT and labelled them the slow breathe -- the lead would
	# have judged the ambience by looking at the loudest cue in the book.
	if show != null:
		show.settle_into(ShowCues.IDLE_STATE, times[0] if not times.is_empty() else 0.0)
	for pose_name: String in poses:
		var focus: Vector3 = poses[pose_name][0]
		var distance: float = poses[pose_name][1]
		_camera.global_transform = RtsCamera.pose_at(focus, heading, distance, PITCH_DEG)
		for t: float in times:
			var writes := 0
			if show != null:
				show.now = t
				writes = show.apply(t)
			await _capture(show, arena, pose_name, "t%s" % ("%.1f" % t).replace(".", "_"), t, focus, distance, writes)
	# The cues. One frame each, at the pose the lead judges from, with the cue settled rather than mid-attack.
	var cue_frames := 0
	if show != null:
		for pose_name: String in poses:
			if pose_name == "close":
				continue  # the cues are a venue-wide effect; two poses is enough to read them
			var focus: Vector3 = poses[pose_name][0]
			_camera.global_transform = RtsCamera.pose_at(focus, heading, float(poses[pose_name][1]), PITCH_DEG)
			for cue: String in cues:
				show.settle_into(StringName(cue), CUE_T)
				show.now = CUE_T
				var writes := show.apply(CUE_T)
				cue_frames += await _capture(show, arena, pose_name, "cue_%s" % cue, CUE_T, focus,
						float(poses[pose_name][1]), writes)
			# The kill ripple, at several wavefront ages and against the IDLE, where the edge channel has
			# headroom. The first strip shot it under `battle`, where that channel sits at 0.96 of a 1.00
			# ceiling with nothing left to ripple into, and the frame was indistinguishable from cue_battle.
			for age: float in ripples:
				show.settle_into(ShowCues.IDLE_STATE, CUE_T)
				show.fire_event(Vector3(focus.x + 28.0, 0.0, focus.z + 16.0), 1.0)
				show.apply(CUE_T, age)
				var stamp := ("%.2f" % age).replace(".", "_")
				cue_frames += await _capture(show, arena, pose_name, "cue_kill_%ss" % stamp, CUE_T, focus,
						float(poses[pose_name][1]), show.writes_last_frame)
			show.settle_into(ShowCues.IDLE_STATE, CUE_T)
	get_tree().paused = false
	print("SHOW_LOOK_DONE arena=%s frames=%d" % [arena, poses.size() * times.size() + cue_frames])
	get_tree().quit()


## A cue as a SEQUENCE, at the wide pose: `clip_frames` frames `clip_step` seconds apart, numbered for ffmpeg.
## This is the only honest way to show a chase, a sweep or a strobe -- a still of a strobe at its trough simply
## reads as "dimmer", which is the opposite of the impression it gives in motion.
func _shoot_clip(show: Show, arena: String, heading: float) -> void:
	if show == null:
		print("SHOW_LOOK_DONE arena=%s frames=0" % arena)
		get_tree().quit()
		return
	var dir := out_dir.path_join("clips")
	DirAccess.make_dir_recursive_absolute(dir)
	_camera.global_transform = RtsCamera.pose_at(_army_centre(get_tree().current_scene), heading, DISTANCE_M, PITCH_DEG)
	var band_track: Array = []
	var full_track: Array = []
	show.settle_into(StringName(clip_cue), CUE_T)
	var t := CUE_T
	for i in clip_frames:
		if clip_cue == "kill" and i == 0:
			show.settle_into(ShowCues.IDLE_STATE, t)
			show.fire_event(Vector3(28.0, 0.0, 16.0), 1.0)
		show.now = t
		show.apply(t, clip_step)
		t += clip_step
		for _f in 2:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png(dir.path_join("%s_%s_%03d.png" % [arena, clip_cue, i]))
		band_track.append(_luma(image, BAND_WINDOW).x)
		full_track.append(_luma(image, FULL_WINDOW).x)
	# A clip pair is an arm like any other: it has to be shown to differ from its control. A strobe's signature is
	# not that it is brighter on average -- it is that the band SWINGS, so the spread over the clip is the number,
	# not the mean.
	var band := _swing(band_track)
	var full := _swing(full_track)
	print("SHOW_LOOK_CLIP " + JSON.stringify({"arena": arena, "cue": clip_cue, "frames": clip_frames,
			"step_s": clip_step, "fps": snappedf(1.0 / maxf(clip_step, 0.001), 0.1),
			"strobe": not LaunchFlags.from_environment().has("no-strobe"),
			"band_min": snappedf(band.x, 0.0001), "band_max": snappedf(band.y, 0.0001),
			"band_swing_pct": snappedf(band.z, 0.1),
			"full_min": snappedf(full.x, 0.0001), "full_max": snappedf(full.y, 0.0001),
			"full_swing_pct": snappedf(full.z, 0.1),
			"vehicles_in_frame": _vehicles_in_frame(get_tree().current_scene)}))
	print("SHOW_LOOK_DONE arena=%s frames=%d" % [arena, clip_frames])
	get_tree().quit()


## One frame, saved and reported. Returns 1 so callers can count.
func _capture(show: Show, arena: String, pose_name: String, label: String, t: float, focus: Vector3,
		distance: float, writes: int) -> int:
	var style := str(show.style_of(&"city_block")) if show != null else ""
	var suffix := "" if style in ["", "parapet"] else "_" + style
	var file := "%s_%s_%s%s.png" % [arena, pose_name, label, suffix]
	# THE BEFORE FRAME IS SHOT HERE, IN THIS PROCESS, AT THIS FROZEN MOMENT -- not in a separate run.
	# It is the same lesson as the `no_show` perf layer, in a second place: two runs are not the same run. These
	# frames ride a LIVE skirmish, so across two processes the vehicles are somewhere else, the effects are
	# different, and the fight ring's luminance moves by several percent for reasons that have nothing to do with
	# the light show. Toggling `driving` on a paused scene makes the two frames differ in the show and in nothing
	# else at all.
	var before := Vector2.ZERO
	var before_band := Vector2.ZERO
	var null_ring := Vector2.ZERO
	var null_band := Vector2.ZERO
	if show != null and style != "":
		show.driving = false
		var was_paused := get_tree().paused
		for _f in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var before_image := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(out_dir.path_join("before"))
		before_image.save_png(out_dir.path_join("before").path_join(file))
		before = _luma(before_image, RING_WINDOW)
		before_band = _luma(before_image, BAND_WINDOW)
		# THE NULL: the same half again, changing NOTHING. Whatever this pair differs by is the floor the real
		# comparison has to clear, and it is not zero even on a paused tree -- shader `TIME` keeps advancing, so
		# the neon flicker's 12.5 Hz dropouts, the crowd and the ad screens are all somewhere else a frame later.
		# Measuring it beats assuming it: a gate calibrated against a guessed noise floor fails on weather.
		for _f in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var null_image := get_viewport().get_texture().get_image()
		null_ring = _luma(null_image, RING_WINDOW)
		null_band = _luma(null_image, BAND_WINDOW)
		show.driving = true
		show.apply(t)
		get_tree().paused = was_paused
	for _f in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(file))
	var ring := _luma(image, RING_WINDOW)
	var band := _luma(image, BAND_WINDOW)
	print("SHOW_LOOK " + JSON.stringify({
		"arena": arena, "pose": pose_name, "label": label, "t": t, "file": file, "style": style,
		"pitch_deg": PITCH_DEG, "fov_deg": FOV_DEG, "distance_m": distance,
		"focus": [focus.x, focus.z], "writes": writes,
		"mood": str(show.mood_state) if show != null else "", "channels": _levels(show, t),
		"luma_ring": snappedf(ring.x, 0.0001), "luma_band": snappedf(band.x, 0.0001),
		"luma_ring_max": snappedf(ring.y, 0.0001), "luma_band_max": snappedf(band.y, 0.0001),
		"luma_ring_before": snappedf(before.x, 0.0001), "luma_band_before": snappedf(before_band.x, 0.0001),
		"luma_ring_max_before": snappedf(before.y, 0.0001), "luma_band_max_before": snappedf(before_band.y, 0.0001),
		"luma_ring_null": snappedf(null_ring.x, 0.0001), "luma_band_null": snappedf(null_band.x, 0.0001),
		"vehicles_in_frame": _vehicles_in_frame(get_tree().current_scene),
		"ring_wins": ring.x >= band.x,
	}))
	return 1


## (mean, max) perceptual luminance over a fraction of the frame. Both, because they answer different questions:
## the MEAN is "is this part of the picture brighter", and the MAX is feel's actual observation about the first
## strip -- "the brightest pixels in the image are the building edges".
func _luma(image: Image, window: Rect2) -> Vector2:
	var w := image.get_width()
	var h := image.get_height()
	var x0 := int(window.position.x * float(w))
	var y0 := int(window.position.y * float(h))
	var x1 := mini(int((window.position.x + window.size.x) * float(w)), w)
	var y1 := mini(int((window.position.y + window.size.y) * float(h)), h)
	var total := 0.0
	var highest := 0.0
	var count := 0
	var y := y0
	while y < y1:
		var x := x0
		while x < x1:
			var c := image.get_pixel(x, y)
			var luma := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			total += luma
			highest = maxf(highest, luma)
			count += 1
			x += LUMA_STRIDE
		y += LUMA_STRIDE
	return Vector2(total / maxf(float(count), 1.0), highest)


## (min, max, peak-to-peak as a percentage of the mean) over a clip's luminance track.
func _swing(track: Array) -> Vector3:
	if track.is_empty():
		return Vector3.ZERO
	var lo := 9.0
	var hi := 0.0
	var total := 0.0
	for value: float in track:
		lo = minf(lo, float(value))
		hi = maxf(hi, float(value))
		total += float(value)
	return Vector3(lo, hi, (hi - lo) / maxf(total / float(track.size()), 1e-6) * 100.0)


## The centroid of every vehicle still alive, or the arena centre when there are none (a gallery, an empty mode).
func _army_centre(scene: Node) -> Vector3:
	if scene == null:
		return Vector3.ZERO
	var tanks := scene.find_children("*", "Tank", true, false).filter(
			func(t: Node) -> bool: return t.is_inside_tree())
	if tanks.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for tank: Node3D in tanks:
		sum += tank.global_position
	return Vector3(sum.x / tanks.size(), 0.0, sum.z / tanks.size())


## How many vehicles this frame actually contains. Printed with every capture so a frame that claims to show the
## fight has to say so in a number -- the check that would have caught an empty ring the first time.
func _vehicles_in_frame(scene: Node) -> int:
	if scene == null:
		return 0
	var size := Vector2(get_viewport().get_visible_rect().size)
	var seen := 0
	for tank: Node3D in scene.find_children("*", "Tank", true, false):
		if not tank.is_inside_tree() or _camera.is_position_behind(tank.global_position):
			continue
		var at := _camera.unproject_position(tank.global_position)
		if at.x >= 0.0 and at.y >= 0.0 and at.x <= size.x and at.y <= size.y:
			seen += 1
	return seen


## What every channel is at, at this moment — so a frame that looks wrong can be traced to a number instead of to a
## guess (lesson 44: print every resolved knob into the output).
func _levels(show: Show, t: float) -> Dictionary:
	var out := {}
	if show == null:
		return out
	for key: Variant in show.channels:
		# The LIVE channel, not the patch's: under a cue they are different numbers, and the point of printing them
		# is so a frame that looks wrong can be traced to a value instead of to a guess (lesson 44).
		var channel: ShowChannel = show.live_channel(key)
		out[str(key)] = snappedf(channel.level(t), 0.001)
	return out
