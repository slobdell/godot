extends SceneTree
## Round 47 (spotter S3): ONE MOMENT AS A CLIP. Replays a CPU-v-CPU fight from its seed (the same showmatch the feature probe ran),
## fast-forwards with the render loop off to a few seconds before the moment, then renders every tick (30 a second) from a camera
## that follows the crew, with a marker over it and a caption, and saves the frames as JPGs for tools/spotter/clips.py to encode.
## The sim never reads the camera (C17.2), so the fight is the feature probe's fight: at --clip-check-tick the crew must stand where
## the table said (--clip-check=x,z); CLIP_CHECK says how far off it is (a clip that does not reproduce its moment is a bug).
##   DISPLAY=:N godot --path . --resolution 960x540 --fixed-fps 30 --script res://tests/spotter/clip_probe.gd -- --skirmish
##       --demo-match --clean --seed=S --arena=A --mute --clip-crew=NAME --clip-from=S0 --clip-to=S1 --clip-dir=/abs/frames
##       [--clip-check-tick=T --clip-check=x,z] [--clip-title=TEXT]   (seconds and ticks are the match's own, as the rows carry them)
## Prints CLIP_CHECK {...} and CLIP_DONE {...}.

## Nearly top-down (~75 degrees): the city's buildings hid a crew at a 50-degree pitch (crossing 13121, Burners2_4).
const CAMERA_BACK := 14.0
const CAMERA_UP := 52.0
const FOLLOW := 0.12
## Rendered but not saved before the clip starts (batch 1's clips opened on one frame of the showmatch's own view).
const WARM_TICKS := 4

var _camera: Camera3D
var _marker: MeshInstance3D
var _caption: Label


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	var crew_name := _flag("clip-crew", "")
	var from_tick := int(float(_flag("clip-from", "0")) * SimClock.TICK_RATE)
	var to_tick := int(float(_flag("clip-to", "5")) * SimClock.TICK_RATE)
	var check_tick := int(_flag("clip-check-tick", "-1"))
	var expect := _flag("clip-check", "").split(",")
	var dir := _flag("clip-dir", "/tmp/spotter-clip")
	DirAccess.make_dir_recursive_absolute(dir)
	RenderingServer.render_loop_enabled = false
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	_setup_view()
	_caption.text = _flag("clip-title", crew_name)
	var last_tick := -1
	var frames := 0
	var saved := 0
	var drift := -1.0
	var tank: Tank = null
	var died_at := -1
	while true:
		await physics_frame
		frames += 1
		if game_match == null or not is_instance_valid(game_match):
			break
		var tick := game_match.tick
		if tick == last_tick:
			if frames > 60 * 60 * 20:
				break
			continue
		last_tick = tick
		var rel := tick  # the match's own tick, as the feature probe's rows carry it
		if tank == null or not is_instance_valid(tank):
			tank = game_match.tanks.get_node_or_null(crew_name) as Tank
		if rel == check_tick and tank != null and expect.size() == 2:
			drift = Vector2(tank.global_position.x - float(expect[0]), tank.global_position.z - float(expect[1])).length()
			print("CLIP_CHECK " + JSON.stringify({"crew": crew_name, "tick": rel, "drift_m": snappedf(drift, 0.01),
					"at": [snappedf(tank.global_position.x, 0.1), snappedf(tank.global_position.z, 0.1)]}))
		if tank != null and not tank.is_alive() and died_at < 0:
			died_at = rel
		if rel < from_tick - WARM_TICKS:
			continue
		if not RenderingServer.render_loop_enabled:
			RenderingServer.render_loop_enabled = true
			_follow(tank, 1.0)
		_follow(tank, FOLLOW)
		await RenderingServer.frame_post_draw
		if rel < from_tick:
			continue  # the first frames after the render loop wakes can still show the showmatch's own camera
		root.get_texture().get_image().save_jpg("%s/f%05d.jpg" % [dir, saved], 0.88)
		saved += 1
		if rel >= to_tick:
			break
	print("CLIP_DONE " + JSON.stringify({"crew": crew_name, "frames": saved, "drift_m": snappedf(drift, 0.01),
			"died_at_s": snappedf(died_at / float(SimClock.TICK_RATE), 0.1) if died_at >= 0 else -1.0}))
	quit(0)


func _setup_view() -> void:
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.far = 900.0
	root.add_child(_camera)
	_marker = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.9
	cone.bottom_radius = 0.0
	cone.height = 2.4
	_marker.mesh = cone
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.92, 0.1)
	material.no_depth_test = true
	_marker.material_override = material
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(_marker)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(12, 8)
	_caption.size = Vector2(root.get_visible_rect().size.x - 24, 0)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_caption.add_theme_constant_override("outline_size", 6)
	layer.add_child(_caption)


func _follow(tank: Tank, blend: float) -> void:
	_camera.make_current()  # the showmatch's director may take the view back; this clip's camera wins every frame
	if tank == null or not is_instance_valid(tank):
		return
	var at := tank.global_position
	_marker.global_position = at + Vector3(0, 9.0, 0)
	_marker.visible = tank.is_alive()
	var want := at + Vector3(0, CAMERA_UP, CAMERA_BACK)
	_camera.global_position = _camera.global_position.lerp(want, blend) if blend < 1.0 else want
	_camera.look_at(at, Vector3.UP)
