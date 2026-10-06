extends SceneTree
## `make unit-thumbs` (garage, round 20, R2; contract C20.4). The lead, after playing round 19: *"We should incorporate
## the graphics of the vehicles we're adding to the squads"* (2026-10-06). One picture per unit (each faction's units
## have their own ids, so per unit is per faction), rendered from the REAL vehicle: `tank.tscn` with `unit_id` set and
## `simulate` off, exactly as `make class-look` spawns one, dressed in its faction's accent (CyberKit.FACTION_COLORS,
## the colour its garage card wears). One angle: three-quarter front, from the right and above. Transparent background,
## no floor, no sky: the card behind it is the backdrop. Each vehicle fills its frame (the card says its length).
##
## Rendered once at MASTER and scaled down (Lanczos), which is the anti-aliasing: two files per unit,
## `<out>/<unit>.png` (the card, CARD) and `<out>/<unit>_chip.png` (the squad chip, CHIP). `make unit-thumbs-adopt`
## copies them into `assets/units/thumbs/`, where they are committed; nothing is rendered at runtime (C20.4).
## Needs a display (a SubViewport does not draw headless). Flags: --thumbs-dir=<abs dir> [--thumbs-units=a,b]

const MASTER := Vector2i(1280, 800)
const CARD := Vector2i(320, 200)
const CHIP := Vector2i(128, 80)
## Where the camera looks from, relative to the vehicle (forward is -Z, trip-up 2): its front-right, above.
const VIEW_DIR := Vector3(0.78, 0.52, -1.0)
const FOV_DEG := 26.0
## Of the frame the vehicle's projected box may fill: a first framing only. The box's corners stand off the real
## silhouette at this angle, so the picture is then cropped to the pixels the vehicle drew (UnitThumbs.crop_to_vehicle).
const FILL := 0.9
## The margin left around the drawn vehicle, as a share of the crop's height.
const MARGIN := 0.06

var _viewport: SubViewport
var _camera: Camera3D
var _out := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	_out = flags.text("thumbs-dir", "/tmp/unit_thumbs")
	DirAccess.make_dir_recursive_absolute(_out)
	GameTheme.use("cyberpunk")
	var units: Array = Units.PROFILES.keys()
	if flags.text("thumbs-units") != "":
		units = Array(flags.text("thumbs-units").split(",", false))
	_build_stage()
	var made := 0
	for unit_id: String in units:
		if not Units.exists(unit_id):
			push_error("unit-thumbs: no unit '%s'" % unit_id)
			continue
		if await _shoot(unit_id):
			made += 1
	print("UNIT_THUMBS_DONE made=%d of=%d dir=%s" % [made, units.size(), _out])
	quit(0 if made == units.size() else 1)


func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.size = MASTER
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	# A key from the camera's side and above, a cool fill from the left, a rim from behind: a studio three-point, so
	# every faction's paint reads the way the arena's night shows it brightest.
	for light: Array in [[Vector3(-50, 35, 0), 1.6, Color(1.0, 0.96, 0.9)], [Vector3(-20, -60, 0), 0.5,
			Color(0.6, 0.75, 1.0)], [Vector3(-35, 160, 0), 1.1, Color(0.8, 0.9, 1.0)]]:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = light[0]
		sun.light_energy = light[1]
		sun.light_color = light[2]
		_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = FOV_DEG
	_camera.far = 500.0
	_viewport.add_child(_camera)
	_camera.current = true


func _shoot(unit_id: String) -> bool:
	var tank := (load("res://game/tank/tank.tscn") as PackedScene).instantiate() as Node3D
	tank.set("unit_id", unit_id)
	tank.set("simulate", false)
	tank.set("team", 0)
	_viewport.add_child(tank)
	tank.call("set_team_accent", CyberKit.faction_color(Units.faction_of(unit_id)))
	for label in tank.find_children("*", "Label3D", true, false):
		(label as Node3D).visible = false
	# A replica eases toward its synced pose every drawn frame (tank.gd): hold it at yaw 0, turret forward.
	tank.set("sync_yaw", 0.0)
	tank.set("sync_turret_yaw", 0.0)
	for i in 8:
		await process_frame
	# A class lamp's flare is additive light (ClassMark, built once the hull's model is in): over a transparent
	# background it draws its black quad. The lamp's dome stays.
	for flare in tank.find_children("ClassFlare", "", true, false):
		(flare as Node3D).visible = false
	var box := _drawn_bounds(tank)
	if box.size.length() < 0.1:
		push_error("unit-thumbs: %s drew nothing" % unit_id)
		tank.queue_free()
		return false
	_frame(box)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	image = UnitThumbs.crop_to_vehicle(image, float(CARD.x) / float(CARD.y), MARGIN)
	var ok := true
	for spec: Array in [["%s.png" % unit_id, CARD], ["%s_chip.png" % unit_id, CHIP]]:
		var copy := image.duplicate() as Image
		copy.resize(spec[1].x, spec[1].y, Image.INTERPOLATE_LANCZOS)
		var path := _out.path_join(spec[0])
		var error := copy.save_png(path)
		ok = ok and error == OK
		print("UNIT_THUMB unit=%s faction=%s size=%dx%d path=%s %s" % [unit_id, Units.faction_of(unit_id), spec[1].x,
				spec[1].y, path, "ok" if error == OK else "FAILED %d" % error])
	tank.queue_free()
	await process_frame
	return ok


## Aim the camera along VIEW_DIR at the box's centre and back it off until all eight corners sit inside FILL of the
## frame (both axes; the frame is wider than tall).
func _frame(box: AABB) -> void:
	var centre := box.get_center()
	var direction := VIEW_DIR.normalized()
	var distance := box.size.length() * 2.0
	for i in 24:
		_camera.look_at_from_position(centre + direction * distance, centre, Vector3.UP)
		var worst := 0.0
		for corner in 8:
			var point := box.get_endpoint(corner)
			var local := _camera.global_transform.affine_inverse() * point
			if local.z >= -0.01:
				worst = INF
				break
			var half_v := tan(deg_to_rad(FOV_DEG) / 2.0) * -local.z
			var half_h := half_v * float(MASTER.x) / float(MASTER.y)
			worst = maxf(worst, maxf(absf(local.x) / half_h, absf(local.y) / half_v))
		if worst == INF:
			distance *= 1.5
			continue
		distance *= worst / FILL
		if absf(worst - FILL) < 0.005:
			break
	_camera.look_at_from_position(centre + direction * distance, centre, Vector3.UP)


## The union of the vehicle's visible meshes in world space (the tank sits at the origin).
static func _drawn_bounds(tank: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in tank.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
