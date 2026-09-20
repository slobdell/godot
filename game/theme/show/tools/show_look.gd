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
##        --show-look-cues=fight,battle,last_stand,victory

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
var warmup := 3.0
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
	var poses := {"wide": [Vector3.ZERO, DISTANCE_M], "close": [Vector3.ZERO, CLOSE_M]}
	if FOCUS_POINTS.has(arena):
		poses["street"] = [FOCUS_POINTS[arena], CLOSE_M]
	get_tree().paused = true
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
			# A kill ripple, caught mid-flight: the one cue that is a place as well as a moment.
			show.settle_into(&"battle", CUE_T)
			show.fire_event(Vector3(focus.x + 28.0, 0.0, focus.z + 16.0), 1.0)
			show.apply(CUE_T, RIPPLE_AGE_S)
			cue_frames += await _capture(show, arena, pose_name, "cue_kill", CUE_T, focus,
					float(poses[pose_name][1]), show.writes_last_frame)
			show.settle_into(&"lull", CUE_T)
	get_tree().paused = false
	print("SHOW_LOOK_DONE arena=%s frames=%d" % [arena, poses.size() * times.size() + cue_frames])
	get_tree().quit()


## One frame, saved and reported. Returns 1 so callers can count.
func _capture(show: Show, arena: String, pose_name: String, label: String, t: float, focus: Vector3,
		distance: float, writes: int) -> int:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var style := str(show.style_of(&"city_block")) if show != null else ""
	var file := "%s_%s_%s%s.png" % [arena, pose_name, label, "" if style in ["", "parapet"] else "_" + style]
	image.save_png(out_dir.path_join(file))
	var ring := _mean_luma(image, RING_WINDOW)
	var band := _mean_luma(image, BAND_WINDOW)
	print("SHOW_LOOK " + JSON.stringify({
		"arena": arena, "pose": pose_name, "label": label, "t": t, "file": file, "style": style,
		"pitch_deg": PITCH_DEG, "fov_deg": FOV_DEG, "distance_m": distance,
		"focus": [focus.x, focus.z], "writes": writes,
		"mood": str(show.mood_state) if show != null else "", "channels": _levels(show, t),
		"luma_ring": snappedf(ring, 0.0001), "luma_band": snappedf(band, 0.0001),
		"ring_wins": ring >= band,
	}))
	return 1


## Mean perceptual luminance over a fraction of the frame. The comparison this feeds is the one hard requirement
## the look has: the fight must out-read the periphery.
func _mean_luma(image: Image, window: Rect2) -> float:
	var w := image.get_width()
	var h := image.get_height()
	var x0 := int(window.position.x * float(w))
	var y0 := int(window.position.y * float(h))
	var x1 := mini(int((window.position.x + window.size.x) * float(w)), w)
	var y1 := mini(int((window.position.y + window.size.y) * float(h)), h)
	var total := 0.0
	var count := 0
	var y := y0
	while y < y1:
		var x := x0
		while x < x1:
			var c := image.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			count += 1
			x += LUMA_STRIDE
		y += LUMA_STRIDE
	return total / maxf(float(count), 1.0)


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
