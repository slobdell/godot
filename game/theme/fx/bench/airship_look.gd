class_name AirshipLook
extends Node
## `make airship-look` (feel X7). The lead asked for an airship *"sometimes visible in the field of view"*, and that
## is exactly the class of claim that turns out false: round 8 shipped a camera fix for the HUD hiding his own
## selection and a facing feature that could not fire on his control scheme at all. **"Visible in a screenshot taken
## deliberately" is not visible.** So this answers the question as a number before it answers it as a picture.
##
## The method: park the real camera at HIS pose (pitch 21, FOV 35, 49 m, `RtsCamera.pose_at`) over the player's
## army, then sweep **every camera yaw a player can rotate to** against **every point of the airship's orbit**, and
## for each pair project the airship's bounds and ask whether any of it lands inside the viewport. That grid is the
## honest reading of "sometimes": too low and he will never see it, 100% and it is wallpaper.
##
## Then, and only then, frames: the widest sample, a mid sample, and one where it is off screen, so the number and
## the picture can be checked against each other.
##
## Flags: --airship-look=<abs dir>  --airship-look-warmup=S (6)  --airship-look-yaws=N (12)  --airship-look-steps=N (24)

const PITCH_DEG := 21.0
const DISTANCE_M := 49.0
const FOV_DEG := 35.0

var out_dir := ""
var warmup := 6.0
var yaws := 12
var steps := 24
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
	var per_yaw := []
	for y in yaws:
		var yaw := TAU * y / yaws
		_camera.global_transform = RtsCamera.pose_at(focus, yaw, DISTANCE_M, PITCH_DEG)
		await get_tree().process_frame
		var hits := 0
		for s in steps:
			var tick := int(lap * s / steps)
			airship.call("_place", tick)
			await get_tree().process_frame
			var reading := _on_screen(airship)
			total += 1
			if reading["visible"]:
				hits += 1
				seen += 1
				if int(reading["px_h"]) > int(best["px_h"]):
					best = {"px_h": reading["px_h"], "px_w": reading["px_w"], "yaw": yaw, "tick": tick}
			elif missed.is_empty():
				missed = {"yaw": yaw, "tick": tick}
			if mid.is_empty() and reading["visible"] and int(reading["px_h"]) > 8:
				mid = {"yaw": yaw, "tick": tick}
		per_yaw.append({"yaw_deg": roundi(rad_to_deg(yaw)), "seen_pct": snappedf(100.0 * hits / steps, 0.1)})
	print("AIRSHIP_LOOK " + JSON.stringify({"pitch_deg": PITCH_DEG, "fov_deg": FOV_DEG, "distance_m": DISTANCE_M,
			"yaws": yaws, "orbit_steps": steps, "samples": total,
			"visible_pct": snappedf(100.0 * seen / maxi(total, 1), 0.1),
			"orbit_radius_m": SyndicateAirship.ORBIT_RADIUS, "orbit_altitude_m": SyndicateAirship.ORBIT_ALTITUDE,
			"widest": best, "per_yaw": per_yaw}))
	var shots := {"widest": best, "mid": mid, "off_screen": missed}
	var written := PackedStringArray()
	for label in ["widest", "mid", "off_screen"]:
		var shot: Dictionary = shots[label]
		if shot.is_empty():
			continue
		_camera.global_transform = RtsCamera.pose_at(focus, float(shot["yaw"]), DISTANCE_M, PITCH_DEG)
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
