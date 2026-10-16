extends "res://tests/nav/terminus_drive.gd"
## Round 31 (manoeuvre, CP-H's clip for the lead): the Terminus drive, filmed. The SAME run `make nav-terminus-drive`
## measures (this script only adds a camera, a caption and a stop time; nothing it adds touches the sim), with a chase
## camera on one crew (`--follow=<unit name>`, framed with `--follow2=<unit name>` when given: the pinned crew and the
## squadmate it is pinned on). The caption is the arm (`--caption=`), the sim clock, and the followed crew's plant speed
## against its real speed: the reading H1's honest escape is about. `--clip-to=<s>` quits that many sim seconds in.
## Run it windowed with --write-movie (`make manoeuvre-pin-clip`, builder0's display).

var _camera: Camera3D
var _caption: Label
var _follow: Tank
var _follow2: Tank
var _clip_to := 0.0


func _initialize() -> void:
	super()
	_clip_to = float(_flag("clip-to", "0"))
	process_frame.connect(_film)


func _find(unit_name: String) -> Tank:
	if unit_name == "" or game_match == null:
		return null
	for tank: Tank in game_match.tanks.get_children():
		if String(tank.name) == unit_name:
			return tank
	return null


func _film() -> void:
	if game_match == null or not is_instance_valid(game_match):
		return
	if _camera == null:
		_follow = _find(_flag("follow", ""))
		if _follow == null:
			return
		_follow2 = _find(_flag("follow2", ""))
		_camera = Camera3D.new()
		_camera.fov = 50.0
		root.add_child(_camera)
		_camera.make_current()
		var layer := CanvasLayer.new()
		root.add_child(layer)
		_caption = Label.new()
		_caption.position = Vector2(20, 64)
		_caption.add_theme_font_size_override("font_size", 24)
		_caption.add_theme_color_override("font_outline_color", Color.BLACK)
		_caption.add_theme_constant_override("outline_size", 8)
		layer.add_child(_caption)
	var at := _follow.global_position
	if _follow2 != null and is_instance_valid(_follow2):
		at = (at + _follow2.global_position) * 0.5
	_camera.global_position = at + Vector3(0.0, 38.0, 30.0)
	_camera.look_at(at, Vector3.UP)
	var seconds := float(game_match.tick) / float(SimClock.TICK_RATE)
	var plant := Vector2(_follow.estimated_velocity.x, _follow.estimated_velocity.z).length()
	var real := Vector2(_follow.real_velocity.x, _follow.real_velocity.z).length()
	_caption.text = "%s\n%s  t %3.0f s\nspeed it reads %4.1f m/s, really %4.1f m/s" % [
			_flag("caption", ""), _follow.name, seconds, plant, real]
	if _clip_to > 0.0 and seconds >= _clip_to:
		print("PIN_CLIP_DONE t %.1f" % seconds)
		quit(0)
