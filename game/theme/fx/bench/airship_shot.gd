class_name AirshipShot
extends Node
## `make airship-shot`: frames of the Syndicate broadcast airship AT THE LEAD'S POSE, deterministically.
##
## It replaced round 10's `blimp-look`, which swept the map counting how often the BLIMP was in frame. That bench is
## retired (verification.md): it was built on the blimp's own constants and on a route model the airship no longer
## has, its frames came back empty, and its pixel readings were wrong by a factor of three. This tool asks the
## smaller question it can actually answer: put the camera at his pitch, FOV and boom, aim it at the airship, and
## show what is there. `SyndicateAdAirship.advance_to` flies the pilot deterministically to any tick, so the pose is
## computed rather than hunted and the subject cannot be missing from the picture.
##
## It is a LOOK tool, not a visibility claim: it proves the art, the screens, the scale and the attitude, and says
## nothing about how often he sees it. `SyndicateAdAirship.seen_fraction` answers that one, in closed form.
##
## Flags: --airship-shot=<abs dir>  --airship-shot-warmup=S (6)  --airship-shot-ticks=a,b,c

const PITCH_DEG := 21.0
const FOV_DEG := 35.0
const DISTANCE_M := 49.0
## The camera looks at the ground directly under the hull, from square onto its flank -- that is the view the screens
## are for, and at his own 49 m boom a 38 m hull fills most of the frame (the sweep measures 1573 px of 1920).
## An "establishing" frame is also written at ESTABLISH_M, which is NOT his pose and is labelled so in the filename:
## it exists only so the whole airship can be seen at once.
const ESTABLISH_M := 105.0

var out_dir := ""
var warmup := 6.0
var ticks: Array[int] = [0, 900, 1800]
## Exact poses from `--airship-shot-pose`; when any are given they REPLACE the derived broadside framing.
var poses: Array[Dictionary] = []
var _camera: Camera3D


static func wanted() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--airship-shot="):
			return true
	return false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--airship-shot="):
			out_dir = arg.trim_prefix("--airship-shot=")
		elif arg.begins_with("--airship-shot-warmup="):
			warmup = float(arg.trim_prefix("--airship-shot-warmup="))
		elif arg.begins_with("--airship-shot-ticks="):
			ticks.clear()
			for piece in arg.trim_prefix("--airship-shot-ticks=").split(","):
				ticks.append(int(piece))
		elif arg.begins_with("--airship-shot-pose="):
			# An EXACT pose: x,z,yaw_deg,tick. Use it to re-shoot a sample `make blimp-look` measured, so the picture
			# and the number come from the same place instead of from two different framings.
			var parts := arg.trim_prefix("--airship-shot-pose=").split(",")
			if parts.size() == 4:
				poses.append({"focus": Vector3(float(parts[0]), 0.0, float(parts[1])),
						"yaw": deg_to_rad(float(parts[2])), "tick": int(parts[3])})
	if out_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(warmup, true, false, true).timeout
	var scene := get_tree().current_scene
	var ship := scene.find_child("SyndicateAdAirship", true, false) as SyndicateAdAirship if scene != null else null
	if ship == null:
		print("AIRSHIP_SHOT_MISSING no SyndicateAdAirship in the scene (LOW tier, or no arena)")
		print("AIRSHIP_SHOT_DONE files=0")
		get_tree().quit()
		return
	_camera = Camera3D.new()
	_camera.fov = FOV_DEG
	_camera.far = 1500.0
	add_child(_camera)
	_camera.current = true
	ship.set_process(false)
	get_tree().paused = true
	var written := 0
	for pose: Dictionary in poses:
		ship.advance_to(int(pose["tick"]))
		_camera.global_transform = RtsCamera.pose_at(pose["focus"], float(pose["yaw"]), DISTANCE_M, PITCH_DEG)
		_camera.current = true
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var name := "airship_pose_t%04d.png" % int(pose["tick"])
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))
		print("AIRSHIP_SHOT_FRAME %s tick=%d hull=%v boom=%.0f yaw=%.0f (exact pose)" % [name, int(pose["tick"]),
				ship.global_transform.origin, DISTANCE_M, rad_to_deg(float(pose["yaw"]))])
		written += 1
	for tick: int in (ticks if poses.is_empty() else [] as Array[int]):
		ship.advance_to(tick)
		var hull := ship.global_transform
		var focus := Vector3(hull.origin.x, 0.0, hull.origin.z)
		# Square onto the STARBOARD flank: the hull's heading turned a quarter turn, so the screen faces the lens.
		var heading := hull.basis.get_euler().y
		var yaw := heading + PI / 2.0
		for shot: Array in [["", DISTANCE_M], ["_wide", ESTABLISH_M]]:
			_camera.global_transform = RtsCamera.pose_at(focus, yaw, float(shot[1]), PITCH_DEG)
			_camera.current = true
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var file := "airship_t%04d%s.png" % [tick, shot[0]]
			get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
			var screens := ship.find_children("Screen*", "MeshInstance3D", true, false)
			print("AIRSHIP_SHOT_FRAME %s tick=%d hull=%v boom=%.0f yaw=%.0f screens=%d length=%.1f deck=%.1f belly=%.1f" % [
					file, tick, hull.origin, float(shot[1]), rad_to_deg(yaw), screens.size(),
					SyndicateAdAirship.LENGTH, SyndicateAdAirship.deck_y(), SyndicateAdAirship.belly_y()])
			written += 1
	get_tree().paused = false
	print("AIRSHIP_SHOT_DONE files=%d in %s" % [written, out_dir])
	get_tree().quit()
