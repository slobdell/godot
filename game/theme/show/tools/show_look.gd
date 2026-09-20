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
## Flags: --show-look=<abs dir>  --show-look-times=0,8.1,16.3  --show-look-warmup=S (3)

const PITCH_DEG := 21.0
const DISTANCE_M := 49.0
const FOV_DEG := 35.0
## A second, closer pose at the same pitch and FOV: the venue read from where a fight actually happens.
const CLOSE_M := 22.0
## Arena -> an extra focus worth a frame, in metres. The Terminus street is the alley the lead said he could not see
## into; blocks sit at x = 20..60 and x = 80..120, so x = 70 is the middle of the 20 m street between them.
const FOCUS_POINTS := {
	"terminus": Vector3(70.0, 0.0, 0.0),
}

var out_dir := ""
var times: Array = [0.0, 8.1, 16.3]
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
	for pose_name: String in poses:
		var focus: Vector3 = poses[pose_name][0]
		var distance: float = poses[pose_name][1]
		_camera.global_transform = RtsCamera.pose_at(focus, heading, distance, PITCH_DEG)
		for t: float in times:
			var writes := 0
			if show != null:
				show.now = t
				writes = show.apply(t)
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var stamp := ("%.1f" % t).replace(".", "_")
			var file := "%s_%s_t%s.png" % [arena, pose_name, stamp]
			get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
			print("SHOW_LOOK " + JSON.stringify({
				"arena": arena, "pose": pose_name, "t": t, "file": file,
				"pitch_deg": PITCH_DEG, "fov_deg": FOV_DEG, "distance_m": distance,
				"focus": [focus.x, focus.z], "writes": writes, "channels": _levels(show, t),
			}))
	get_tree().paused = false
	print("SHOW_LOOK_DONE arena=%s frames=%d" % [arena, poses.size() * times.size()])
	get_tree().quit()


## What every channel is at, at this moment — so a frame that looks wrong can be traced to a number instead of to a
## guess (lesson 44: print every resolved knob into the output).
func _levels(show: Show, t: float) -> Dictionary:
	var out := {}
	if show == null:
		return out
	for key: Variant in show.channels:
		var channel: ShowChannel = show.channels[key]
		out[str(key)] = snappedf(channel.level(t), 0.001)
	return out
