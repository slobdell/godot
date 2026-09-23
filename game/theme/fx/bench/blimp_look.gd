class_name BlimpLook
extends Node
## `make blimp-look` (feel, round 10, R7): is the low ad blimp in the lead's frame while he PLAYS, and how often?
## The airship-look method (lesson: "visible in a screenshot taken deliberately" is not visible), moved to where the
## blimp lives. At HIS pose only (21 deg, FOV 35, 49 m): every focus point he could be looking at (a 20 m grid over
## the arena's playable ground) x four camera yaws x the blimp's whole lap. A sample is ON SCREEN when the blimp's drawn
## bounds land in the viewport, and SEEN when also at least one of six points on it (centre, nose, tail, top, the two
## screens) has a clear physics ray from the camera -- the city blocks' colliders are their full 40 x 24 x 40 m boxes,
## so the ray is the honest occluder. (The first version tested mesh AABBs; StaticBatcher's merged meshes span whole
## districts and swallowed every sight line: 0% seen with the blimp 366 px wide on screen. Both counts are printed.)
##
## Reported three ways, because the honest reading of "sometimes" depends on where he looks: over the whole map,
## over the middle band where fights happen (|z| <= 60 m), and at the skirmish's starting yaw only. Then frames:
## the widest seen sample, a typical one, and the opening view.
##
## Flags: --blimp-look=<abs dir>  --blimp-look-warmup=S (6)  --blimp-look-steps=N (24)  --blimp-look-grid=M (20)

const PITCH_DEG := 21.0
const DISTANCE_M := 49.0
const FOV_DEG := 35.0
const MIDDLE_BAND_M := 60.0

var out_dir := ""
var warmup := 6.0
var steps := 24
var grid := 20.0
var _camera := Camera3D.new()
## The first few blocked rays are printed with what blocked them, so a 0% can be told from a broken occluder.
var _hits_logged := 0


func _init() -> void:
	name = "BlimpLook"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var flags := LaunchFlags.from_environment()
	out_dir = flags.text("blimp-look")
	warmup = float(flags.text("blimp-look-warmup", str(warmup)))
	steps = maxi(1, int(flags.text("blimp-look-steps", str(steps))))
	grid = maxf(5.0, float(flags.text("blimp-look-grid", str(grid))))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_camera.fov = FOV_DEG
	_camera.far = 1200.0
	add_child(_camera)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(warmup, true, false, true).timeout
	var scene := get_tree().current_scene
	var blimp := scene.find_child("AdBlimp", true, false) as AdBlimp if scene != null else null
	if blimp == null:
		print("BLIMP_LOOK_MISSING no AdBlimp in the scene (LOW tier, or a map without a route)")
		print("BLIMP_LOOK_DONE")
		get_tree().quit()
		return
	var rig := scene.get_node_or_null("RtsCamera")
	var start_yaw := float(rig.get("yaw")) if rig != null else 0.0
	var start_focus: Vector3 = rig.get("focus") if rig != null else Vector3.ZERO
	if rig != null:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
	_camera.current = true
	get_tree().paused = true
	# Posed by hand from here on: its own _process would put it back at the (paused) match tick before a frame is shot,
	# which is how the first frames of the widest and typical samples came out showing a different pose.
	blimp.set_process(false)
	var lap := blimp.lap_ticks()
	var half := float(Arena.active.get("half_size", 120.0))
	var foci: Array[Vector3] = []
	var x := -half
	while x <= half:
		var z := -half
		while z <= half:
			var at := Vector3(x, 0.0, z)
			if Arena.contains(at):
				foci.append(at)
			z += grid
		x += grid
	var yaws := [start_yaw, start_yaw + PI / 2.0, start_yaw + PI, start_yaw + 1.5 * PI]
	var tally := {"all": [0, 0], "middle": [0, 0], "start_yaw": [0, 0], "middle_start_yaw": [0, 0]}
	var on_screen := 0
	var skipped_poses := 0
	var best := {"px_w": -1}
	var typical := {}
	var sizes: Array = []
	for focus: Vector3 in foci:
		for yi in yaws.size():
			_camera.global_transform = RtsCamera.pose_at(focus, float(yaws[yi]), DISTANCE_M, PITCH_DEG)
			# Only poses his camera can take: the camera itself over the arena. From the grid's edge foci a yawed camera
			# stands out in the stands, where the crowd and railings (no colliders, so the ray passes them) hide
			# everything -- the first avenue sweep's "widest" sample was one of those.
			var eye := _camera.global_position
			if not Arena.contains(Vector3(eye.x, 0.0, eye.z)):
				skipped_poses += 1
				continue
			for s in steps:
				var tick := int(lap * s / steps)
				blimp.call("_place", tick)
				var reading := _reading(blimp)
				var seen: bool = reading["seen"]
				if bool(reading["on"]):
					on_screen += 1
				var middle := absf(focus.z) <= MIDDLE_BAND_M
				_count(tally, "all", seen)
				if middle:
					_count(tally, "middle", seen)
				if yi == 0:
					_count(tally, "start_yaw", seen)
					if middle:
						_count(tally, "middle_start_yaw", seen)
				if seen:
					sizes.append(int(reading["px_w"]))
					if int(reading["px_w"]) > int(best["px_w"]):
						best = {"px_w": reading["px_w"], "px_h": reading["px_h"], "focus": focus, "yaw": yaws[yi], "tick": tick}
	sizes.sort()
	var median_px: int = sizes[sizes.size() / 2] if not sizes.is_empty() else 0
	# The "typical" frame: the first seen sample at the start yaw whose width is near the median.
	for focus: Vector3 in foci:
		if not typical.is_empty():
			break
		_camera.global_transform = RtsCamera.pose_at(focus, start_yaw, DISTANCE_M, PITCH_DEG)
		var typical_eye := _camera.global_position
		if not Arena.contains(Vector3(typical_eye.x, 0.0, typical_eye.z)):
			continue
		for s in steps:
			var tick := int(lap * s / steps)
			blimp.call("_place", tick)
			var reading := _reading(blimp)
			if reading["seen"] and absi(int(reading["px_w"]) - median_px) <= maxi(20, median_px / 5):
				typical = {"focus": focus, "yaw": start_yaw, "tick": tick}
				break
	var report := {"pitch_deg": PITCH_DEG, "fov_deg": FOV_DEG, "distance_m": DISTANCE_M, "grid_m": grid,
			"foci": foci.size(), "yaws": yaws.size(), "lap_steps": steps, "lap_s": snappedf(lap / SimClock.TICK_RATE, 0.1),
			"altitude_m": AdBlimp.ALTITUDE, "speed_mps": AdBlimp.SPEED_MPS, "median_px_w": median_px, "widest": best,
			"on_screen_pct_all": snappedf(100.0 * on_screen / maxi(int(tally["all"][1]), 1), 0.1),
			"camera_poses_outside_the_arena_skipped": skipped_poses}
	for key: String in tally:
		var pair: Array = tally[key]
		report["seen_pct_" + key] = snappedf(100.0 * pair[0] / maxi(pair[1], 1), 0.1)
		report["samples_" + key] = pair[1]
	print("BLIMP_LOOK " + JSON.stringify(report))
	var shots := {"widest": best, "typical": typical, "opening": {"focus": start_focus, "yaw": start_yaw, "tick": 0}}
	var written := 0
	for label: String in shots:
		var shot: Dictionary = shots[label]
		if not shot.has("focus"):
			continue
		_camera.global_transform = RtsCamera.pose_at(shot["focus"], float(shot["yaw"]), DISTANCE_M, PITCH_DEG)
		# The dressing REBUILDS the blimp when the adaptive quality tier changes, which happens once frames render again
		# after the sweep: re-find it before every shot and pose that one (the first frames posed a freed instance, and
		# only the tick-0 opening shot matched, because a fresh blimp starts at tick 0).
		for i in 3:
			await get_tree().process_frame
		blimp = scene.find_child("AdBlimp", true, false) as AdBlimp
		if blimp == null:
			continue
		blimp.set_process(false)
		blimp.call("_place", int(shot["tick"]))
		for i in 2:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var file := "blimp_%s.png" % label
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
		var reading := _reading(blimp)
		print("BLIMP_LOOK_FRAME %s focus=%s yaw=%.0f tick=%d seen=%s px_w=%d" % [file, shot["focus"],
				rad_to_deg(float(shot["yaw"])), int(shot["tick"]), str(reading["seen"]), int(reading["px_w"])])
		written += 1
	get_tree().paused = false
	print("BLIMP_LOOK_DONE files=%d in %s" % [written, out_dir])
	get_tree().quit()


func _count(tally: Dictionary, key: String, seen: bool) -> void:
	var pair: Array = tally[key]
	pair[1] += 1
	if seen:
		pair[0] += 1


func _reading(blimp: Node3D) -> Dictionary:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var any_ahead := false
	for node in blimp.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
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
	var size := get_viewport().get_visible_rect().size
	var on := any_ahead and hi.x > 0.0 and lo.x < size.x and hi.y > 0.0 and lo.y < size.y
	if not on:
		return {"seen": false, "on": false, "px_w": 0, "px_h": 0}
	# Clip to the viewport for the size that is actually on screen.
	var w := minf(hi.x, size.x) - maxf(lo.x, 0.0)
	var h := minf(hi.y, size.y) - maxf(lo.y, 0.0)
	var xf := blimp.global_transform
	var probes := [xf.origin, xf * Vector3(0, 0, -AdBlimp.ENVELOPE_LENGTH * 0.45),
			xf * Vector3(0, 0, AdBlimp.ENVELOPE_LENGTH * 0.45), xf * Vector3(0, AdBlimp.ENVELOPE_DIAMETER * 0.45, 0),
			xf * Vector3(AdBlimp.ENVELOPE_DIAMETER * 0.55, 0.9, 0), xf * Vector3(-AdBlimp.ENVELOPE_DIAMETER * 0.55, 0.9, 0)]
	var eye := _camera.global_position
	var space := blimp.get_world_3d().direct_space_state
	var clear := false
	for p: Vector3 in probes:
		if _camera.is_position_behind(p) or not get_viewport().get_visible_rect().has_point(_camera.unproject_position(p)):
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, p, 1)  # layer 1: the arena's static world, not tanks
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			clear = true
			break
		if _hits_logged < 12:
			_hits_logged += 1
			var who: Object = hit.get("collider")
			print("BLIMP_LOOK_BLOCKED by %s (%s) at %s, eye %s -> %s" % [(who as Node).name if who is Node else str(who),
					who.get_class() if who != null else "?", hit.get("position"), eye, p])
	return {"seen": clear, "on": true, "px_w": roundi(w), "px_h": roundi(h)}
