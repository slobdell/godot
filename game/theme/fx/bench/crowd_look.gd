class_name CrowdLook
extends Node
## `make crowd-look` (feel X1, round 6): can a player see the crowd? The lead played round 5 and called the crowd in
## the stands "non-existent", four days after it shipped. This rides a real skirmish (FxWorld adds it on
## `--crowd-look=<abs dir>`) and answers with pictures and numbers instead of guesses:
##
##   1. `player.png`: the frame the game's own camera shows after the warm-up (what the lead saw).
##   2. A grid of poses over the player's army (RtsCamera's own poses and cutaway: every zoom level at the default pitch,
##      and pitch x distance at FOV 60; facing the enemy and facing home),
##      each shot with the crowd, without it, and without fog. The tree is paused while a pose is shot so the only
##      difference between the with/without frames is the crowd.
##
## Per pose it prints `CROWD_LOOK {json}`: `crowd_px` (pixels the crowd changes by more than CHANGED in luminance),
## `noise_px` (the same count between two identical frames: the floor under crowd_px), `contrast` (mean luminance change
## on those pixels, 0..1), `figure_px` (median on-screen height of a drawn person inside the frame), `seats_in_view`,
## and the same crowd count with the fog off. `<pose>.png` is the frame, `<pose>-crowd.png` the crowd's pixels marked
## in magenta over a darkened frame. Then `CROWD_LOOK_DONE` and quit.
##
## Flags: --crowd-look=<abs dir>  --crowd-look-warmup=S (6)  --crowd-look-zooms=0.1,0.3 (ZOOMS)
##        --crowd-look-only=behind-p35,ahead-p22 (only poses whose name contains one of these)

const ZOOMS := [0.08, 0.2, 0.35, 0.5, 0.7, 0.9]
## Control X3 took pitch off the zoom slider. The lead picked 25 degrees, 50 m, FOV 60 (2026-09-18) and keeps a 22-50
## degree tilt; 15 is here because he picked the floor of the range he was offered. [pitch degrees, distance m].
## Then he settled on 12 degrees, 50 m (2026-09-18).
const LOW_POSES := [[12.0, 50.0], [12.0, 70.0], [15.0, 50.0], [25.0, 50.0], [25.0, 90.0], [35.0, 60.0], [35.0, 120.0],
		[50.0, 80.0], [50.0, 160.0]]
## The low poses' field of view (the lead's pick); the zoom-slider poses keep RtsCamera's own.
const LOW_FOV_DEG := 60.0
## A pixel is the crowd's when its luminance moves by more than this with the crowd hidden.
const CHANGED := 0.04
const PAUSE_FRAMES := 3

var out_dir := ""
var warmup := 6.0
var zooms: Array = ZOOMS.duplicate()
var only: Array = []
var _camera := Camera3D.new()


func _init() -> void:
	name = "CrowdLook"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var flags := LaunchFlags.from_environment()
	out_dir = flags.text("crowd-look")
	warmup = float(flags.text("crowd-look-warmup", str(warmup)))
	if flags.text("crowd-look-zooms") != "":
		zooms = Array(flags.text("crowd-look-zooms").split(",", false)).map(func(z: String) -> float: return float(z))
	only = Array(flags.text("crowd-look-only").split(",", false))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_camera.name = "CrowdLookCamera"
	_camera.fov = RtsCamera.FOV_DEG
	_camera.far = 1200.0
	add_child(_camera)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(warmup, true, false, true).timeout
	var crowd := _crowd()
	var environment := _environment()
	print("CROWD_LOOK_INFO " + JSON.stringify(_info(crowd, environment)))
	# 1. What the player's own camera shows.
	var player_camera := get_viewport().get_camera_3d()
	await _frames(PAUSE_FRAMES)
	_save(_grab(), "player")
	if crowd != null and player_camera != null:
		print("CROWD_LOOK " + JSON.stringify(await _measure("player", player_camera, crowd, environment)))
	# 2. The grid, from the rig's own focus and heading.
	var rig := get_tree().current_scene.get_node_or_null("RtsCamera") if get_tree().current_scene != null else null
	var focus: Vector3 = rig.get("focus") if rig != null else Vector3.ZERO
	var heading: float = rig.get("yaw") if rig != null else 0.0
	if rig != null:
		rig.process_mode = Node.PROCESS_MODE_DISABLED  # the rig runs while paused and would move the player's shots
	_camera.current = true
	for turn in [0.0, PI]:
		for level: float in zooms:
			var pose := "%s-z%02d" % ["ahead" if turn == 0.0 else "behind", int(round(level * 100.0))]
			if not _wanted(pose):
				continue
			_camera.global_transform = RtsCamera.pose_for(focus, heading + turn, level)
			_camera.fov = RtsCamera.FOV_DEG
			_camera.near = RtsCamera.cutaway_near(focus, heading + turn, RtsCamera.distance_for(level),
					RtsCamera.DEFAULT_PITCH_DEG, RtsCamera.perimeter_half())
			await _frames(PAUSE_FRAMES)
			if crowd != null:
				print("CROWD_LOOK " + JSON.stringify(await _measure(pose, _camera, crowd, environment)))
			else:
				_save(_grab(), pose)
		for low: Array in LOW_POSES:
			var pose := "%s-p%02d-d%03d" % ["ahead" if turn == 0.0 else "behind", int(low[0]), int(low[1])]
			if not _wanted(pose):
				continue
			# Control's own pose and cutaway (lesson 53: an approximation of another stream's system measures the
			# approximation; round 6's first 12 degree frame showed a grandstand fascia the game never draws).
			_camera.global_transform = RtsCamera.pose_at(focus, heading + turn, low[1], low[0])
			_camera.fov = LOW_FOV_DEG
			_camera.near = RtsCamera.cutaway_near(focus, heading + turn, low[1], low[0], RtsCamera.perimeter_half())
			await _frames(PAUSE_FRAMES)
			if crowd != null:
				print("CROWD_LOOK " + JSON.stringify(await _measure(pose, _camera, crowd, environment)))
	print("CROWD_LOOK_DONE")
	get_tree().quit()


func _wanted(pose: String) -> bool:
	return only.is_empty() or only.any(func(part: String) -> bool: return pose.contains(part))


## Shoot a pose with the crowd, again with it (noise floor), without it, and without fog.
func _measure(pose: String, camera: Camera3D, crowd: CrowdSystem, environment: Environment) -> Dictionary:
	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	await _frames(PAUSE_FRAMES)
	var with_crowd := _grab()
	await _frames(1)
	var again := _grab()
	crowd.multimesh_instance.visible = false
	await _frames(PAUSE_FRAMES)
	var without := _grab()
	var fog_px := -1
	if environment != null and environment.fog_enabled:
		environment.fog_enabled = false
		await _frames(PAUSE_FRAMES)
		var fogless_without := _grab()
		crowd.multimesh_instance.visible = true
		await _frames(PAUSE_FRAMES)
		fog_px = int(CrowdLook.compare(_grab(), fogless_without)["changed"])
		_save(_grab(), pose + "-nofog")
		environment.fog_enabled = true
	crowd.multimesh_instance.visible = true
	tree.paused = was_paused
	var result := CrowdLook.compare(with_crowd, without, true, again)
	_save(with_crowd, pose)
	(result["marked"] as Image).save_png(out_dir.path_join(pose + "-crowd.png"))
	var sizes := _figure_sizes(camera, crowd)
	return {"pose": pose, "crowd_px": result["changed"], "noise_px": CrowdLook.compare(with_crowd, again)["changed"],
			"contrast": result["contrast"], "crowd_px_nofog": fog_px, "figure_px": sizes["median_px"],
			"seats_in_view": sizes["in_view"], "nearest_m": sizes["nearest_m"], "pitch_deg": snappedf(rad_to_deg(-camera.global_rotation.x), 0.1),
			"height_m": snappedf(camera.global_position.y, 0.1)}


## Pixels whose luminance differs by more than CHANGED, their mean change, and (if `mark`) the frame darkened with
## those pixels in magenta. With `noise` (a second shot of `a`), pixels that also change between `a` and `noise` are
## animation, not the crowd, and are left out. Pure, for tests.
static func compare(a: Image, b: Image, mark := false, noise: Image = null) -> Dictionary:
	var first := a.duplicate() as Image
	var second := b.duplicate() as Image
	first.convert(Image.FORMAT_RGB8)
	second.convert(Image.FORMAT_RGB8)
	var da := first.get_data()
	var db := second.get_data()
	var dn := PackedByteArray()
	if noise != null:
		var third := noise.duplicate() as Image
		third.convert(Image.FORMAT_RGB8)
		dn = third.get_data()
	var out := PackedByteArray()
	if mark:
		out.resize(da.size())
	var changed := 0
	var total := 0.0
	var n := mini(da.size(), db.size())
	for i in range(0, n - 2, 3):
		var la := (0.2126 * da[i] + 0.7152 * da[i + 1] + 0.0722 * da[i + 2]) / 255.0
		var lb := (0.2126 * db[i] + 0.7152 * db[i + 1] + 0.0722 * db[i + 2]) / 255.0
		var hit := absf(la - lb) > CHANGED
		if hit and i + 2 < dn.size():
			var ln := (0.2126 * dn[i] + 0.7152 * dn[i + 1] + 0.0722 * dn[i + 2]) / 255.0
			hit = absf(la - ln) <= CHANGED
		if hit:
			changed += 1
			total += absf(la - lb)
		if mark:
			out[i] = 255 if hit else da[i] / 3
			out[i + 1] = 0 if hit else da[i + 1] / 3
			out[i + 2] = 255 if hit else da[i + 2] / 3
	var result := {"changed": changed, "contrast": snappedf(total / maxf(changed, 1), 0.001)}
	if mark:
		result["marked"] = Image.create_from_data(first.get_width(), first.get_height(), false, Image.FORMAT_RGB8, out)
	return result


## On-screen height of drawn people inside the frame: the median, how many, and the nearest one's distance.
func _figure_sizes(camera: Camera3D, crowd: CrowdSystem) -> Dictionary:
	var multimesh := crowd.multimesh_instance.multimesh
	var rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var heights: Array[float] = []
	var nearest := INF
	for i in multimesh.visible_instance_count:
		var xform := multimesh.get_instance_transform(i)
		var feet := xform.origin
		var head := feet + Vector3(0.0, xform.basis.get_scale().y, 0.0)
		if camera.is_position_behind(feet):
			continue
		var a := camera.unproject_position(feet)
		var b := camera.unproject_position(head)
		if not rect.has_point(a) and not rect.has_point(b):
			continue
		heights.append(a.distance_to(b))
		nearest = minf(nearest, camera.global_position.distance_to(feet))
	heights.sort()
	return {"median_px": snappedf(heights[heights.size() / 2], 0.1) if not heights.is_empty() else 0.0,
			"in_view": heights.size(), "nearest_m": snappedf(nearest, 1.0) if nearest < INF else -1.0}


func _info(crowd: CrowdSystem, environment: Environment) -> Dictionary:
	var info := {"tier": FxQuality.tier_name(), "window": str(DisplayServer.window_get_size()), "crowd": crowd != null}
	if crowd != null:
		info["seats"] = crowd.seats.size()
		info["drawn"] = crowd.drawn_count()
		info["bounds"] = str(crowd.multimesh_instance.custom_aabb)
		info["visible_in_tree"] = crowd.multimesh_instance.is_visible_in_tree()
		info["voice"] = crowd.voice != null
		if crowd.voice != null:
			info["murmur_stream"] = crowd.voice.murmur.stream != null
			info["murmur_playing"] = crowd.voice.murmur.playing
			info["murmur_db"] = snappedf(crowd.voice.murmur.volume_db, 0.1)
	if environment != null:
		info["fog"] = environment.fog_enabled
		info["fog_density"] = environment.fog_density
		info["fog_height_density"] = environment.fog_height_density
		info["background"] = str(environment.background_color)
	return info


func _crowd() -> CrowdSystem:
	var found := get_tree().root.find_children("Crowd", "Node3D", true, false)
	for node in found:
		if node is CrowdSystem:
			return node as CrowdSystem
	return null


func _environment() -> Environment:
	for world in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		if (world as WorldEnvironment).environment != null:
			return (world as WorldEnvironment).environment
	return null


func _frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw


func _grab() -> Image:
	return get_viewport().get_texture().get_image()


func _save(image: Image, pose: String) -> void:
	image.save_png(out_dir.path_join(pose + ".png"))
