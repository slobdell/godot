class_name CameraTrace
extends Node
## Round 41 (camera K1): what moved the ground under the player's cursor, frame by frame, and who did it.
##
## The lead, after playing round-40 main: "it also jerks around a lot, which becomes problematic if I'm trying to command
## a bunch of units to attack a target, and then it's hard to click on the target because the camera jerks." Nothing on
## main could tell a jerk from a glide, so this measures what he sees: the SCREEN motion (pixels, at the window's size) of
## the ground point under the cursor. Every frame the camera's change is split into its parts, each replayed on its own
## through the same pose math the rig uses, so the parts add up to the whole:
##   focus / yaw / zoom / pitch  -> whoever last set that part of the wanted pose (RtsCamera.wrote: player, jump, follow,
##                                  order_track, auto_frame, yaw_follow, cap, frame)
##   solid                       -> the rig keeping the camera out of a building (clear_pose)
##   hull                        -> the damped move over the airship
##   shake                       -> CameraShake's view offset
## A JERK is a frame where one source's screen velocity changes faster than JERK_PX_S2 (an eased move never does; a
## lerp that starts from rest, a snap or a goal that jumps always does); a SNAP is one frame that moves the ground more
## than SNAP_PX; a REVERSAL is a source's velocity turning back on itself (jitter). The player's own input is counted
## under "player" and is not a defect. `--camera-trace=DIR` turns it on in any skirmish (CameraPlaytest drives one).

const SOURCES := ["player", "jump", "follow", "order_track", "auto_frame", "yaw_follow", "danger", "corner", "cap", "frame", "solid", "hull",
		"shake"]
## Screen acceleration of one source that counts as a jerk (px/s^2 at 1080 rows; scaled by the window's height). A
## critically damped move of 300 px peaks near 300 * omega^2 = 4,800 px/s^2 at omega 4/s; a lerp from rest at the rig's
## SMOOTHING 12 changes velocity by 12 * gap in ONE frame (60 fps: 216,000 px/s^2 for the same 300 px).
const JERK_PX_S2 := 15000.0
## One frame moving the ground this far (px at 1080 rows) is a snap whatever came before it.
const SNAP_PX := 24.0
## A reversal counts only when both velocities are at least this fast (px/s at 1080 rows): below it is sub-pixel drift.
const REVERSAL_PX_S := 30.0
## Frames of one source closer together than this are one event.
const MERGE_S := 0.15
const REFERENCE_ROWS := 1080.0

var rig: RtsCamera
## Where the cursor is (screen px); the playtest sets it. Null = the viewport's mouse, or the screen centre headless.
var cursor: Variant = null
## Extra ground points to follow (name -> Vector3): each gets its per-source screen motion summed in `anchor_motion`.
var anchors := {}
var anchor_motion := {}
## Per frame: {"t", "dt", "parts": {source: Vector2}} when `keep_frames` (for a frames log).
var keep_frames := false
var frames: Array = []
var events: Array = []

var _clock := 0.0
var _prev := {}
var _prev_velocity := {}
var _open := {}  # source -> the event still accumulating
var _moved := {}  # source -> total px
var _snaps := {}
var _reversals := {}
var _frames_seen := 0
var _scale := 1.0
var _held := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000  # after the rig (and CameraShake) have placed the camera this frame


## `--camera-trace=DIR` on the command line: attach a trace (and, with `--camera-autoplay`, the scripted player) to this
## rig. Called by RtsCamera._ready; does nothing without the flag.
static func attach_from_args(on_rig: RtsCamera) -> void:
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera-trace="):
			out_dir = arg.trim_prefix("--camera-trace=")
	if out_dir == "":
		return
	var trace := CameraTrace.new()
	trace.name = "CameraTrace"
	trace.rig = on_rig
	on_rig.add_child.call_deferred(trace)
	var playtest := CameraPlaytest.new()
	playtest.name = "CameraPlaytest"
	playtest.trace = trace
	playtest.rig = on_rig
	playtest.out_dir = out_dir
	playtest.autoplay = OS.get_cmdline_user_args().has("--camera-autoplay")
	# Round 42 (K4.1): where the view looks against where the danger is (the playtest gives it the feed).
	var look := CameraLook.new()
	look.name = "CameraLook"
	look.rig = on_rig
	look.keep_frames = OS.get_cmdline_user_args().has("--camera-trace-frames")
	playtest.look = look
	on_rig.add_child.call_deferred(look)
	on_rig.add_child.call_deferred(playtest)


func _process(delta: float) -> void:
	if rig == null or rig.camera == null or rig.layers.is_empty() or delta <= 0.0:
		return
	_clock += delta
	var camera := rig.camera
	var size := camera.get_viewport().get_visible_rect().size if camera.get_viewport() != null else Vector2(1920, 1080)
	_scale = REFERENCE_ROWS / maxf(size.y, 1.0)
	var cur: Dictionary = rig.layers.duplicate()
	cur["h"] = camera.h_offset
	cur["v"] = camera.v_offset
	cur["pr"] = rig._shown_pitch
	cur["w"] = rig.wrote.duplicate()
	cur["T"] = camera.get_camera_transform()  # what was really drawn: a pivoted shake turns the camera (the residual)
	if rig.holding:
		_held += delta
	if not _prev.is_empty():
		var at: Vector2 = _cursor(size)
		var ground: Variant = CameraTrace.ground_at(_prev, size, at)
		if ground == null:
			ground = CameraTrace.ground_at(_prev, size, size * 0.5)
		if ground != null:
			_frame(CameraTrace.parts(_prev, cur, ground as Vector3, size), delta)
		for key: String in anchors:
			var parts := CameraTrace.parts(_prev, cur, anchors[key] as Vector3, size)
			var sums: Dictionary = anchor_motion.get(key, {})
			for source: String in parts:
				sums[source] = (sums.get(source, Vector2.ZERO) as Vector2) + parts[source]
			anchor_motion[key] = sums
	_prev = cur


func _cursor(size: Vector2) -> Vector2:
	if cursor is Vector2:
		return cursor
	if DisplayServer.get_name() != "headless" and rig.camera.get_viewport() != null:
		return rig.camera.get_viewport().get_mouse_position()
	return size * 0.5


func _frame(parts: Dictionary, delta: float) -> void:
	_frames_seen += 1
	var total := Vector2.ZERO
	for source: String in parts:
		total += parts[source]
	parts["all"] = total
	if keep_frames:
		var row := {}
		for source: String in parts:
			var v: Vector2 = parts[source] * _scale
			if v.length() > 0.01:
				row[source] = [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]
		frames.append({"t": snappedf(_clock, 0.001), "dt": snappedf(delta, 0.0001), "parts": row})
	for source: String in parts:
		var moved: Vector2 = parts[source] * _scale
		var velocity := moved / delta
		var before: Vector2 = _prev_velocity.get(source, Vector2.ZERO)
		var accel := (velocity - before).length() / delta
		_moved[source] = float(_moved.get(source, 0.0)) + moved.length()
		if moved.length() > SNAP_PX:
			_snaps[source] = int(_snaps.get(source, 0)) + 1
		if velocity.length() > REVERSAL_PX_S and before.length() > REVERSAL_PX_S and velocity.dot(before) < 0.0:
			_reversals[source] = int(_reversals.get(source, 0)) + 1
		if accel > JERK_PX_S2 or moved.length() > SNAP_PX:
			var open: Dictionary = _open.get(source, {})
			if open.is_empty() or _clock - float(open["end"]) > MERGE_S:
				open = {"source": source, "t": snappedf(_clock, 0.001), "end": _clock, "frames": 0, "peak_px_s2": 0.0,
						"dv_px_s": 0.0, "px": 0.0}
				events.append(open)
				_open[source] = open
			open["end"] = _clock
			open["frames"] = int(open["frames"]) + 1
			open["peak_px_s2"] = maxf(float(open["peak_px_s2"]), roundf(accel))
			open["dv_px_s"] = maxf(float(open["dv_px_s"]), roundf((velocity - before).length()))
			open["px"] = snappedf(float(open["px"]) + moved.length(), 0.1)
		_prev_velocity[source] = velocity


## Every source's events, snaps, reversals and pixels moved, per minute of trace. `seconds` = how long it ran.
func summary() -> Dictionary:
	var minutes := maxf(_clock / 60.0, 1e-6)
	var by := {}
	for source: String in SOURCES + ["all"]:
		var mine := events.filter(func(e: Dictionary) -> bool: return e["source"] == source)
		var sizes: Array = mine.map(func(e: Dictionary) -> float: return float(e["dv_px_s"]))
		sizes.sort()
		by[source] = {"events": mine.size(), "per_min": snappedf(mine.size() / minutes, 0.01),
				"dv_p50": CameraTrace.quantile(sizes, 0.5), "dv_max": sizes.back() if not sizes.is_empty() else 0.0,
				"snaps": int(_snaps.get(source, 0)), "reversals": int(_reversals.get(source, 0)),
				"px_per_min": snappedf(float(_moved.get(source, 0.0)) / minutes, 1.0)}
	return {"seconds": snappedf(_clock, 0.01), "frames": _frames_seen, "held_s": snappedf(_held, 0.01), "by_source": by}


static func quantile(sorted_values: Array, q: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	return float(sorted_values[clampi(int(ceil(q * sorted_values.size())) - 1, 0, sorted_values.size() - 1)])


# ---- The pose replay (pure, for tests) --------------------------------------------------------------------------

## The camera transform a layers record stands for (RtsCamera._apply's, without the overview inset): the shown pose,
## then the solid and airship moves on top, then the shake offset (Camera3D.get_camera_transform's h/v offset).
static func pose_of(layers: Dictionary) -> Transform3D:
	var distance := float(layers["d"])
	var tilt: float = RtsCamera.tilt_at(float(layers["pr"]), distance) if layers.has("pr") else float(layers["p"])
	var pose := RtsCamera.pose_at(layers["f"], float(layers["y"]), distance + float(layers.get("sd", 0.0)) + float(layers.get("hd", 0.0)),
			tilt + float(layers.get("sp", 0.0)) + float(layers.get("hp", 0.0)))
	pose.origin += pose.basis.x * float(layers.get("h", 0.0)) + pose.basis.y * float(layers.get("v", 0.0))
	return pose


## Where a world point lands on a screen of `size` (px), or null behind the camera. Godot's perspective keeps the
## vertical field of view (Camera3D.KEEP_HEIGHT).
static func project(layers: Dictionary, size: Vector2, point: Vector3) -> Variant:
	return CameraTrace.project_pose(CameraTrace.pose_of(layers), float(layers["fov"]), size, point)


static func project_pose(pose: Transform3D, fov_deg: float, size: Vector2, point: Vector3) -> Variant:
	var c := pose.affine_inverse() * point
	if c.z >= -0.01:
		return null
	var tan_half := tan(deg_to_rad(fov_deg) * 0.5)
	var x := (c.x / -c.z) / (tan_half * size.x / size.y)
	var y := (c.y / -c.z) / tan_half
	return Vector2((x * 0.5 + 0.5) * size.x, (0.5 - y * 0.5) * size.y)


## The ground point (y = 0) under screen pixel `at`, or null for sky.
static func ground_at(layers: Dictionary, size: Vector2, at: Vector2) -> Variant:
	var pose := CameraTrace.pose_of(layers)
	var tan_half := tan(deg_to_rad(float(layers["fov"])) * 0.5)
	var x := (at.x / size.x * 2.0 - 1.0) * tan_half * size.x / size.y
	var y := (1.0 - at.y / size.y * 2.0) * tan_half
	var direction := (pose.basis * Vector3(x, y, -1.0)).normalized()
	return Plane(Vector3.UP, 0.0).intersects_ray(pose.origin, direction)


## How far (screen px) each source moved `point` between two layer records: the parts are applied one after another
## in a fixed order, so they sum exactly to the whole move. {source: Vector2}; sources that did nothing are left out.
## With the drawn transforms ("T") recorded, whatever the replay cannot explain is CameraShake's pivot turn: "shake".
static func parts(before: Dictionary, after: Dictionary, point: Vector3, size: Vector2) -> Dictionary:
	var writers: Dictionary = after.get("w", {})
	var steps := [["f", writers.get("focus", "frame")], ["y", writers.get("yaw", "frame")], ["d", writers.get("zoom", "frame")],
			["pr", writers.get("pitch", "frame")], ["fov", "player"], ["sd", "solid"], ["sp", "solid"], ["hd", "hull"], ["hp", "hull"],
			["h", "shake"], ["v", "shake"]]
	if bool(after.get("overview", false)) or bool(before.get("overview", false)):
		return {"jump": Vector2.ZERO}  # the overview's inset re-aims the lens outside this replay; it is a key he pressed
	var state := before.duplicate()
	var out := {}
	var at: Variant = CameraTrace.project(state, size, point)
	for step: Array in steps:
		var key: String = step[0]
		if not after.has(key) or state.get(key) == after[key]:
			continue
		state[key] = after[key]
		var next: Variant = CameraTrace.project(state, size, point)
		if at != null and next != null:
			var source: String = step[1]
			out[source] = (out.get(source, Vector2.ZERO) as Vector2) + ((next as Vector2) - (at as Vector2))
		at = next
	if before.has("T") and after.has("T"):
		var drawn_before: Variant = CameraTrace.project_pose(before["T"], float(before["fov"]), size, point)
		var drawn_after: Variant = CameraTrace.project_pose(after["T"], float(after["fov"]), size, point)
		if drawn_before != null and drawn_after != null:
			var replayed := Vector2.ZERO
			for source: String in out:
				replayed += out[source]
			var rest: Vector2 = (drawn_after as Vector2) - (drawn_before as Vector2) - replayed
			if rest.length() > 0.05:
				out["shake"] = (out.get("shake", Vector2.ZERO) as Vector2) + rest
	return out
