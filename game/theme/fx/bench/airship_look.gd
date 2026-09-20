class_name AirshipLook
extends Node
## `make airship-look` (feel X7). The lead asked for an airship *"sometimes visible in the field of view"*, and that
## is exactly the class of claim that turns out false: round 8 shipped a camera fix for the HUD hiding his own
## selection and a facing feature that could not fire on his control scheme at all. **"Visible in a screenshot taken
## deliberately" is not visible.** So this answers the question as a number before it answers it as a picture.
##
## The method: park the real camera over the player's army and sweep **every tilt a player can reach** x **every
## camera yaw** x **every point of the airship's orbit**, projecting the airship's bounds each time to ask whether
## any of it lands inside the viewport. That grid is the honest reading of "sometimes": too low and he will never
## see it, 100% and it is wallpaper. His own 21 deg is reported as its own row, because that is the number that
## decides whether the feature exists for him or only for a screenshot.
##
## Then, and only then, frames: the widest sample, a mid sample, and one where it is off screen, so the number and
## the picture can be checked against each other.
##
## Flags: --airship-look=<abs dir>  --airship-look-warmup=S (6)  --airship-look-yaws=N (8)  --airship-look-steps=N (16)

const PITCH_DEG := 21.0
## The tilts a player can actually reach (control: 8-70), with his own 21 first. The sweep runs all of them because
## the arithmetic says the answer changes sign inside this range: the top of the frame sits at
## `pitch - FOV/2` degrees of depression, so at any pitch above 17.5 the horizon is OFF the top of the screen and
## nothing in the sky can be drawn at all. If that is right, "sometimes visible" is false at his pose and true at
## the bottom of his tilt range -- which is a finding, not a failure, and it is the whole reason this sweeps.
const PITCHES := [21.0, 8.0, 12.0, 17.0, 30.0, 45.0]
const DISTANCE_M := 49.0
const FOV_DEG := 35.0

var out_dir := ""
var warmup := 6.0
var yaws := 8
var steps := 16
var _camera := Camera3D.new()


func _init() -> void:
	name = "AirshipLook"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var flags := LaunchFlags.from_environment()
	out_dir = flags.text("airship-look")
	warmup = float(flags.text("airship-look-warmup", str(warmup)))
	yaws = maxi(1, int(flags.text("airship-look-yaws", str(yaws))))
	steps = maxi(1, int(flags.text("airship-look-steps", str(steps))))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_camera.name = "AirshipLookCamera"
	_camera.fov = FOV_DEG
	_camera.far = 1200.0
	add_child(_camera)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(warmup, true, false, true).timeout
	var scene := get_tree().current_scene
	var airship := scene.find_child("SyndicateAirship", true, false) as Node3D if scene != null else null
	if airship == null:
		print("AIRSHIP_LOOK_MISSING no SyndicateAirship in the scene (LOW tier builds have none)")
		print("AIRSHIP_LOOK_DONE")
		get_tree().quit()
		return
	var rig := scene.get_node_or_null("RtsCamera")
	if rig != null:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
	_camera.current = true
	var focus := _army_centre(scene)
	get_tree().paused = true
	# The airship keeps flying while the match is frozen, so the sweep is over ITS orbit and nothing else moves.
	airship.process_mode = Node.PROCESS_MODE_ALWAYS
	var lap := int(SyndicateAirship.ORBIT_TICKS)
	var seen := 0
	var total := 0
	var best := {"px_h": -1}
	var mid := {}
	var missed := {}
	var per_pitch := []
	for pitch: float in PITCHES:
		var pitch_seen := 0
		var pitch_total := 0
		var pitch_best := 0
		for y in yaws:
			var yaw := TAU * y / yaws
			_camera.global_transform = RtsCamera.pose_at(focus, yaw, DISTANCE_M, pitch)
			await get_tree().process_frame
			for s in steps:
				var tick := int(lap * s / steps)
				airship.call("_place", tick)
				await get_tree().process_frame
				var reading := _on_screen(airship)
				total += 1
				pitch_total += 1
				if reading["visible"]:
					pitch_seen += 1
					seen += 1
					pitch_best = maxi(pitch_best, int(reading["px_h"]))
					if int(reading["px_h"]) > int(best["px_h"]):
						best = {"px_h": reading["px_h"], "px_w": reading["px_w"], "yaw": yaw, "tick": tick, "pitch": pitch}
					if mid.is_empty() and int(reading["px_h"]) > 8:
						mid = {"yaw": yaw, "tick": tick, "pitch": pitch}
				elif missed.is_empty():
					missed = {"yaw": yaw, "tick": tick, "pitch": pitch}
		# WHY, not just how often. A bare 0% is correct and useless: it cannot tell "the airship is in the wrong
		# place" from "the camera can never look there". Both are one line of geometry, so report both.
		var camera_y := DISTANCE_M * sin(deg_to_rad(pitch))
		var frame_top := FOV_DEG / 2.0 - pitch  # degrees ABOVE the horizontal; negative = the horizon is off-screen
		var rise := SyndicateAirship.ORBIT_ALTITUDE - camera_y
		var near := maxf(absf(SyndicateAirship.ORBIT_RADIUS - focus.length()), 1.0)
		var far := SyndicateAirship.ORBIT_RADIUS + focus.length()
		var needed := (camera_y + far * tan(deg_to_rad(maxf(frame_top, 0.01)))) if frame_top > 0.0 else -1.0
		per_pitch.append({"pitch_deg": pitch, "seen_pct": snappedf(100.0 * pitch_seen / maxi(pitch_total, 1), 0.1),
				"widest_px_h": pitch_best, "frame_top_deg_above_horizon": snappedf(frame_top, 0.1),
				"camera_altitude_m": snappedf(camera_y, 0.1),
				"airship_elevation_deg": [snappedf(rad_to_deg(atan(rise / far)), 0.1),
						snappedf(rad_to_deg(atan(rise / near)), 0.1)],
				"altitude_that_would_fit_m": snappedf(needed, 0.1)})
		print("AIRSHIP_LOOK_PITCH %.0f seen=%.1f%% widest_px_h=%d frame_top=%+.1f deg elevation=%.1f..%.1f deg %s" % [
				pitch, 100.0 * pitch_seen / maxi(pitch_total, 1), pitch_best, frame_top,
				rad_to_deg(atan(rise / far)), rad_to_deg(atan(rise / near)),
				"(horizon OFF the top of frame)" if frame_top <= 0.0 else "(fits below %.0f m altitude)" % needed])
	print("AIRSHIP_LOOK " + JSON.stringify({"his_pitch_deg": PITCH_DEG, "fov_deg": FOV_DEG, "distance_m": DISTANCE_M,
			"yaws": yaws, "orbit_steps": steps, "samples": total,
			"visible_pct": snappedf(100.0 * seen / maxi(total, 1), 0.1),
			"orbit_radius_m": SyndicateAirship.ORBIT_RADIUS, "orbit_altitude_m": SyndicateAirship.ORBIT_ALTITUDE,
			"widest": best, "per_pitch": per_pitch}))
	var shots := {"widest": best, "mid": mid, "off_screen": missed}
	var written := PackedStringArray()
	for label in ["widest", "mid", "off_screen"]:
		var shot: Dictionary = shots[label]
		# `widest` starts as a sentinel with no pose in it, so a sweep that never saw the airship has nothing to
		# shoot for that label. The first run crashed here -- a measurement tool that only works when the answer is
		# positive is worse than no tool, because the one result you cannot read is the one you did not expect.
		if shot.is_empty() or not shot.has("yaw"):
			continue
		_camera.global_transform = RtsCamera.pose_at(focus, float(shot["yaw"]), DISTANCE_M, float(shot.get("pitch", PITCH_DEG)))
		airship.call("_place", int(shot["tick"]))
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "airship_%s.png" % label
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(path))
		written.append(path)
	get_tree().paused = false
	var missing := PackedStringArray()
	for path in written:
		if not FileAccess.file_exists(out_dir.path_join(path)):
			missing.append(path)
	if missing.is_empty():
		print("AIRSHIP_LOOK_DONE files=%d in %s" % [written.size(), out_dir])
	else:
		print("AIRSHIP_LOOK_FAILED missing=%s" % ", ".join(missing))
	get_tree().quit()


## The airship's drawn bounds projected into the viewport: whether any of it is on screen, and how big.
func _on_screen(airship: Node3D) -> Dictionary:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var any_ahead := false
	for node in airship.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		for c in 8:
			var corner := box.get_endpoint(c)
			if _camera.is_position_behind(corner):
				continue
			any_ahead = true
			var point := _camera.unproject_position(corner)
			lo = lo.min(point)
			hi = hi.max(point)
	if not any_ahead:
		return {"visible": false, "px_w": 0, "px_h": 0}
	var size := get_viewport().get_visible_rect().size
	var on := hi.x > 0.0 and lo.x < size.x and hi.y > 0.0 and lo.y < size.y
	return {"visible": on, "px_w": roundi(hi.x - lo.x), "px_h": roundi(hi.y - lo.y)}


func _army_centre(scene: Node) -> Vector3:
	var army := scene.find_children("*", "Tank", true, false).filter(
			func(t: Node) -> bool: return int(t.get("team")) == 0 and t.is_inside_tree()) if scene != null else []
	var centre := Vector3.ZERO
	for tank: Node3D in army:
		centre += tank.global_position
	if not army.is_empty():
		centre /= army.size()
	centre.y = 0.0
	return centre
