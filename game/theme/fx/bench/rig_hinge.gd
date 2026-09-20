class_name RigHinge
extends Node
## `make rig-hinge` (feel, round 9, contract S2; the lead, twice: "the semi trucks for the road gangs are still one
## long box itself of a truck / trailer combination"). The frames are the deliverable: the War Rig bending at the
## fifth wheel, shot with HIS camera (pitch 21, 49 m, FOV 35) and again from higher up, where the bend's angle reads.
##
## Two parts, and they answer two different questions:
##
## 1. `live.json` / `RIG_HINGE_LIVE` -- **does it articulate in a real match?** Every frame of a live skirmish, the
##    largest |trailer angle| over every War Rig on the field, reported as min / mean / max with the sample count.
##    This is the honest evidence: nothing here poses anything, the rigs are being driven by the game.
## 2. `corner_<pitch>_<deg>.png` and `strip_<pitch>.png` -- **what does it look like?** The match is paused and one
##    rig is driven round a constant-radius corner at a fixed speed, a frame at each milestone of the turn. The arc
##    is prescribed, and says so: it exists so the lead sees the bend at a known angle rather than whatever the
##    fight happened to be doing. The hinge itself is not posed -- it integrates from the drawn pose exactly as it
##    does in play (DozerPart._drive_trailer).
##
## Flags: --rig-hinge=<abs dir>  --rig-hinge-warmup=S (6)  --rig-hinge-radius=M (26)  --rig-hinge-speed=M/S (9)
##        --rig-hinge-live=S (8)

const RIG := "gang_tank"
const DISTANCE_M := 49.0
const FOV_DEG := 35.0
## The lead's pose first (pitch 21, FOV 35, 49 m -- the one he found with the live controls and sent back), then a
## higher angle that reads the bend's geometry. NOT 12 degrees: that is the camera he played and rejected ("I was
## totally wrong about the camera, the game is unplayable now with low field of view"), and 45 is inside the tilt
## range he can actually reach (control: the player can tilt 8-70). This bench sets its own camera through
## RtsCamera.pose_at, so the far-range tilt FLOOR (RtsCamera.FAR_TILT_FROM_M: past 70 m the rig lifts the tilt
## whatever the player set, to 40 by 160 m) does not apply here -- at 49 m it would not bite anyway, but the next
## agent will read the number and not the mechanism, so: these pitches are the pitches, not the floor's.
const PITCHES := [21.0, 45.0]
const MILESTONES := [0.0, 10.0, 25.0, 45.0, 70.0, 100.0]  # degrees through the corner
const REVERSE_M := [3.0, 8.0, 16.0, 30.0]  # metres backed up, for the creep case

var out_dir := ""
var warmup := 6.0
var live_seconds := 8.0
var radius := 26.0
var speed := 9.0
var _camera := Camera3D.new()


func _init() -> void:
	name = "RigHinge"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var flags := LaunchFlags.from_environment()
	out_dir = flags.text("rig-hinge")
	warmup = float(flags.text("rig-hinge-warmup", str(warmup)))
	live_seconds = float(flags.text("rig-hinge-live", str(live_seconds)))
	radius = float(flags.text("rig-hinge-radius", str(radius)))
	speed = float(flags.text("rig-hinge-speed", str(speed)))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_camera.name = "RigHingeCamera"
	_camera.fov = FOV_DEG
	_camera.far = 1200.0
	add_child(_camera)
	_run.call_deferred()


## Every War Rig hull part on the field that can report its hinge.
static func rigs_in(scene: Node) -> Array:
	if scene == null:
		return []
	var parts := []
	for node in scene.find_children("*", "Tank", true, false):
		if String(node.get("unit_id")) != RIG or not node.is_inside_tree():
			continue
		for child in node.find_children("*", "Node3D", true, false):
			if child.has_method("articulation"):
				parts.append(child)
	return parts


func _run() -> void:
	await get_tree().create_timer(warmup, true, false, true).timeout
	var scene := get_tree().current_scene
	var rig_camera := scene.get_node_or_null("RtsCamera") if scene != null else null
	var heading: float = rig_camera.get("yaw") if rig_camera != null else 0.0
	var live := await _watch_live(scene)
	print("RIG_HINGE_LIVE " + JSON.stringify(live))
	var file := FileAccess.open(out_dir.path_join("live.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(live, "  "))
		file.close()
	if rig_camera != null:
		rig_camera.process_mode = Node.PROCESS_MODE_DISABLED
	_camera.current = true
	for pitch: float in PITCHES:
		await _shoot_corner(scene, heading, pitch)
	print("RIG_HINGE_DONE")
	get_tree().quit()


## The largest hinge angle on the field, frame by frame, while the match plays. No posing: if this reports zeros the
## hinge is not reaching the game, whatever the corner frames look like.
func _watch_live(scene: Node) -> Dictionary:
	var parts := RigHinge.rigs_in(scene)
	var samples := PackedFloat32Array()
	var until := Time.get_ticks_msec() + int(live_seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		var peak := 0.0
		for part: Node in parts:
			if is_instance_valid(part) and part.is_inside_tree():
				peak = maxf(peak, absf(rad_to_deg(float(part.call("articulation")))))
		if not parts.is_empty():
			samples.append(peak)
	var total := 0.0
	var high := 0.0
	var low := 180.0
	for value in samples:
		total += value
		high = maxf(high, value)
		low = minf(low, value)
	return {"rigs": parts.size(), "frames": samples.size(),
			"peak_deg": snappedf(high, 0.1) if samples.size() > 0 else 0.0,
			"mean_peak_deg": snappedf(total / maxi(samples.size(), 1), 0.1),
			"min_peak_deg": snappedf(low, 0.1) if samples.size() > 0 else 0.0,
			"limit_deg": float(FactionArt.trailer_cut(RIG).get("jackknife_deg", 0.0))}


## One rig driven round a constant-radius corner with the match paused, shot at each milestone of the turn.
func _shoot_corner(scene: Node, heading: float, pitch: float) -> void:
	var where := _clear_ground(scene)
	var tank := (load("res://game/tank/tank.tscn") as PackedScene).instantiate() as Node3D
	tank.set("unit_id", RIG)
	tank.set("simulate", false)
	scene.add_child(tank)
	for label in tank.find_children("*", "Label3D", true, false):
		(label as Node3D).visible = false
	# The rest of the match holds still; the rig and its hinge keep running, so the bend is integrated from real
	# frame deltas and a real speed, not posed.
	tank.process_mode = Node.PROCESS_MODE_ALWAYS
	_place(tank, where, heading, 0.0)
	get_tree().paused = true
	var hidden := _hud_layers(scene)
	var turned := 0.0
	var shots := []
	var report := []
	var reverse_shots := []
	var reverse_report := []
	for milestone: float in MILESTONES:
		# The corner: a left-hand arc of `radius`, entered heading along the camera's right so the whole rig is
		# side-on to him at the start and swings through the frame.
		while turned < milestone:
			await get_tree().process_frame
			var delta := get_process_delta_time()
			turned += rad_to_deg(speed * delta / maxf(radius, 1.0))
			_place(tank, where, heading, minf(turned, milestone))
		_place(tank, where, heading, milestone)
		_camera.global_transform = RtsCamera.pose_at(tank.global_position, heading, DISTANCE_M, pitch)
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var cornering := _hull_of(tank)
		var bend := rad_to_deg(float(cornering.call("articulation"))) if cornering != null else 0.0
		var shot_name := "corner_%d_%d.png" % [int(pitch), int(milestone)]
		image.save_png(out_dir.path_join(shot_name))
		shots.append(image)
		report.append({"turn_deg": milestone, "hinge_deg": snappedf(bend, 0.1), "frame": shot_name})
	# The creep case: back it up in a straight line from a kinked start and let the law diverge, which is what a
	# jackknife IS. Same camera, same rig, so the two strips are comparable.
	var backed := 0.0
	var from := tank.global_position
	var yaw := tank.rotation.y
	for milestone: float in REVERSE_M:
		while backed < milestone:
			await get_tree().process_frame
			backed += speed * 0.5 * get_process_delta_time()
			_place_reverse(tank, from, yaw, minf(backed, milestone))
		_place_reverse(tank, from, yaw, milestone)
		_camera.global_transform = RtsCamera.pose_at(tank.global_position, heading, DISTANCE_M, pitch)
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var hull := _hull_of(tank)
		var bend := rad_to_deg(float(hull.call("articulation"))) if hull != null else 0.0
		var shot_name := "reverse_%d_%d.png" % [int(pitch), int(milestone)]
		image.save_png(out_dir.path_join(shot_name))
		reverse_shots.append(image)
		reverse_report.append({"reversed_m": milestone, "hinge_deg": snappedf(bend, 0.1), "frame": shot_name})
	for layer: CanvasLayer in hidden:
		layer.visible = true
	get_tree().paused = false
	tank.queue_free()
	await get_tree().process_frame
	_save_strip(shots, out_dir.path_join("strip_%d.png" % int(pitch)))
	_save_strip(reverse_shots, out_dir.path_join("strip_reverse_%d.png" % int(pitch)))
	print("RIG_HINGE " + JSON.stringify({"pitch_deg": pitch, "distance_m": DISTANCE_M, "fov_deg": FOV_DEG,
			"radius_m": radius, "speed_mps": speed, "corner": report, "reverse": reverse_report}))


## The rig `turn` degrees into a left-hand arc of `radius` that starts at `where` heading across the camera.
func _place(tank: Node3D, where: Vector3, heading: float, turn: float) -> void:
	var entry := heading - PI / 2.0  # nose along the camera's right at the start of the corner
	var turned := deg_to_rad(turn)
	var left := Vector3.LEFT.rotated(Vector3.UP, entry)
	var centre := where + left * radius
	var at := centre + (where - centre).rotated(Vector3.UP, turned)
	at.y = where.y
	_pose(tank, at, entry + turned)


## The rig reversed `back` metres along its own heading FROM WHERE THE CORNER ENDED -- no teleport, so the lag the
## corner built is still in the hinge when the reverse starts. That matters: reversing from a dead-straight hinge is
## an unstable equilibrium and would never diverge, which would have made this frame a lie.
## The case metrics asked for: 56% of all reversals in a fight are the wheeled creep, so in today's game the rig
## jackknifes far more often than it corners, and a review frame that only shows a clean corner shows the rare case.
func _place_reverse(tank: Node3D, from: Vector3, yaw: float, back: float) -> void:
	_pose(tank, from - Vector3.FORWARD.rotated(Vector3.UP, yaw) * back, yaw)  # FORWARD is the nose: minus is reverse


## Put a NON-SIMULATING tank somewhere. It is a replica: every rendered frame it eases its own position and yaw
## toward `sync_position` / `sync_yaw` (tank.gd), so setting the transform alone is undone within a frame and the
## hinge reads a drift to the origin instead of the drive. This cost the first run of this bench: rigs 0 in the live
## sample and 0.0 degrees at every milestone of a corner that visibly happened.
func _pose(tank: Node3D, at: Vector3, yaw: float) -> void:
	tank.set("sync_position", at)
	tank.set("sync_yaw", yaw)
	tank.global_position = at
	tank.rotation.y = yaw


func _hull_of(tank: Node3D) -> Node:
	for child in tank.find_children("*", "Node3D", true, false):
		if child.has_method("articulation"):
			return child
	return null


## Somewhere with room for the corner: the player's deployment pushed OUTWARD, away from the arena centre, so the
## corner sweeps across open ground behind the army instead of through the middle of it. (First run: the rig was
## parked inside its own deployment and the frames were 40 vehicles and a HUD with the rig off the edge.)
func _clear_ground(scene: Node) -> Vector3:
	var army := scene.find_children("*", "Tank", true, false).filter(
			func(t: Node) -> bool: return int(t.get("team")) == 0 and t.is_inside_tree()) if scene != null else []
	var centre := Vector3.ZERO
	for tank: Node3D in army:
		centre += tank.global_position
	if not army.is_empty():
		centre /= army.size()
	centre.y = 0.0
	var outward := centre.normalized() if centre.length() > 1.0 else Vector3.BACK
	return centre + outward * (radius + 22.0)


## The HUD, hidden while the corner is shot and put back afterwards. These frames are an ART review -- the question
## is whether the rig reads as a truck and a trailer -- and a command card over the bottom third answers a different
## one. The live sample and the match behind the rig are untouched.
func _hud_layers(scene: Node) -> Array:
	var hidden := []
	for node in (scene.get_tree().root.find_children("*", "CanvasLayer", true, false) if scene != null else []):
		var layer := node as CanvasLayer
		if layer.visible:
			layer.visible = false
			hidden.append(layer)
	return hidden


## The milestones side by side in one image, so the bend is read as a sequence rather than six files.
func _save_strip(shots: Array, path: String) -> void:
	if shots.is_empty():
		return
	var columns := 3
	var rows := int(ceil(float(shots.size()) / columns))
	var first: Image = shots[0]
	var scale := 0.5  # a six-up strip at full 1080p is 5760 px wide and nobody can see it
	var width := int(first.get_width() * scale)
	var height := int(first.get_height() * scale)
	var sheet := Image.create(width * columns, height * rows, false, first.get_format())
	for i in shots.size():
		var shot: Image = (shots[i] as Image).duplicate()
		shot.resize(width, height, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(shot, Rect2i(0, 0, width, height), Vector2i((i % columns) * width, (i / columns) * height))
	sheet.save_png(path)
