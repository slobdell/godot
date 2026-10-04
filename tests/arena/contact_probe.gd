extends SceneTree
## Yard (round 17, CP1's question from brains): do turned containers give a long hull's planned k-turn something to
## plant into? Boots the real match (main.tscn with the flags after `--`, headless, fixed fps) and reads every hull's
## `Movement.state()` on every physics tick -- the same reading tests/nav/test_nav_back_and_fill.gd counts -- and
## splits the wall-contact ticks by cause x driver, by whether the hull is long (>= 9 m: the Condemned tank, the War
## Rig) and by whether the thing touched is a container. One line per match:
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/arena/contact_probe.gd -- --match --arena=yard \
##       --green-faction=gangs --rust-faction=condemned --budget=5200 --time-limit=180 --seed=1 --probe-tag=turned
##
## CONTACT_PROBE {"arena", "tag", "seed", "ticks", "long_plant_kturn", "long_steer", "long_container", ...}

const LONG_M := 9.0

var _match: Node = null
var _counts := {}
var _ticks := 0
var _tag := ""
var _seed := ""
var _arena := ""
var _limit_ticks := 0
var _steer_by := {}  # collider name -> steer contact ticks of long hulls
var _where := {}  # collider name -> [x, z, yaw_deg]
var _shot_collider := ""
var _shot_out := ""
var _shot_taken := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	_tag = flags.text("probe-tag", "")
	_seed = flags.text("seed", "1")
	# A few ticks before the match's own time limit, which ends the run (no --elimination: the fight runs its length).
	_limit_ticks = int(float(flags.text("time-limit", "180")) * SimClock.TICK_RATE) - 10
	# --shot-collider=NAME[,NAME...] --shot-out=/abs.jpg: the first time a long hull scrapes one of them, a frame at his pose over the
	# contact (needs a display; the run is then not headless).
	_shot_collider = flags.text("shot-collider", "")
	_shot_out = flags.text("shot-out", "")
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(_tick)


func _tick() -> void:
	if _match == null:
		var found := _all(root, func(n: Node) -> bool: return n is Match)
		if found.is_empty():
			return
		_match = found[0]
		_arena = String(Arena.active.get("name", ""))
	_ticks += 1
	var tanks: Node = _match.get("tanks")
	if tanks != null:
		for tank: Node in tanks.get_children():
			if not tank is Tank or not is_instance_valid(tank):
				continue
			var reading := Movement.state(tank)
			if not bool(reading.get("wall_contact", false)):
				continue
			var long := float(Movement.hull_box((tank as Tank).unit_id)[2]) >= LONG_M
			var cause := String(reading.get("wall_contact_cause", "?"))
			var driver := String(reading.get("wall_contact_driver", "?"))
			var collider := String(reading.get("wall_contact_collider", ""))
			var what := "container" if collider.begins_with("Container") else "other"
			_add("%s|%s|%s|%s" % ["long" if long else "short", cause, driver, what])
			if long and cause == "steer":
				_steer_by[collider] = int(_steer_by.get(collider, 0)) + 1
				if not _where.has(collider):
					var body := _find(root, collider)
					if body is Node3D:
						var b := body as Node3D
						_where[collider] = [snappedf(b.global_position.x, 0.01), snappedf(b.global_position.z, 0.01),
								snappedf(rad_to_deg(b.global_rotation.y), 0.01)]
				if _shot_out != "" and not _shot_taken and collider in _shot_collider.split(","):
					_shot_taken = true
					_shoot.call_deferred((tank as Node3D).global_position)
	if _ticks >= _limit_ticks:
		_report()


func _add(key: String) -> void:
	_counts[key] = int(_counts.get(key, 0)) + 1


func _sum(keep: Callable) -> int:
	var total := 0
	for key: String in _counts:
		if keep.call(key.split("|")):
			total += int(_counts[key])
	return total


## The match ends the run itself (a side eliminated, or its time limit): report on the way out, whichever comes first.
func _finalize() -> void:
	if not _reported:
		_report()


var _reported := false


func _report() -> void:
	_reported = true
	if physics_frame.is_connected(_tick):
		physics_frame.disconnect(_tick)
	var out := {"arena": _arena, "tag": _tag, "seed": _seed, "ticks": _ticks,
		"long_plant_kturn": _sum(func(k: PackedStringArray) -> bool: return k[0] == "long" and k[1] == "plant" and k[2] == "kturn"),
		"long_plant_kturn_container": _sum(func(k: PackedStringArray) -> bool: return k[0] == "long" and k[1] == "plant" and k[2] == "kturn" and k[3] == "container"),
		"long_kturn_any": _sum(func(k: PackedStringArray) -> bool: return k[0] == "long" and k[2] == "kturn"),
		"long_steer": _sum(func(k: PackedStringArray) -> bool: return k[0] == "long" and k[1] == "steer"),
		"long_container": _sum(func(k: PackedStringArray) -> bool: return k[0] == "long" and k[3] == "container"),
		"all": _sum(func(_k: PackedStringArray) -> bool: return true),
		"by_key": _counts, "steer_by_collider": _steer_by, "where": _where}
	print("CONTACT_PROBE " + JSON.stringify(out))
	quit(0)  # harmless from _finalize


func _find(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var hit := _find(child, wanted)
		if hit != null:
			return hit
	return null


## A frame at his pose over `at`, the match frozen for it (HUD and airship hidden, as tests/arena/container_frames.gd).
func _shoot(at: Vector3) -> void:
	paused = true
	for layer in _all(root, func(n: Node) -> bool: return n is CanvasLayer):
		(layer as CanvasLayer).visible = false
	for ship in _all(root, func(n: Node) -> bool: return n is SyndicateAdAirship):
		(ship as Node3D).visible = false
	for label in _all(root, func(n: Node) -> bool: return n is Label3D):
		(label as Label3D).visible = false  # the match runner's debug captions
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	if camera == null:
		paused = false
		return
	for rig in _all(root, func(n: Node) -> bool: return n is RtsCamera):
		rig.set_process(false)
		rig.set_physics_process(false)
	camera.current = true
	camera.fov = RtsCamera.FOV_DEG
	camera.global_transform = RtsCamera.pose_at(Vector3(at.x, 0, at.z), 0.0, 49.0, RtsCamera.DEFAULT_PITCH_DEG)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_jpg(_shot_out, 0.9)
		print("CONTACT_SHOT %s at %s" % [_shot_out, at])
	var close := RtsCamera.pose_at(Vector3(at.x, 0, at.z), 0.0, 22.0, RtsCamera.DEFAULT_PITCH_DEG)
	camera.global_transform = close
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	image = root.get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_jpg(_shot_out.replace(".jpg", "_close.jpg"), 0.9)
	paused = false


func _all(node: Node, keep: Callable) -> Array:
	var out: Array = []
	if keep.call(node):
		out.append(node)
	for child in node.get_children():
		out.append_array(_all(child, keep))
	return out
