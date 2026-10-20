extends SceneTree
## Round 35 (traffic T7): his view of the pass. A crew on open ground under fire (a hull on standing orders, hit every tick)
## and a squadmate sent 30 m straight through it: with `underfire` on, the crew holds and the squadmate drives round it; off,
## the crew steps aside as before. His camera (pitch 21 deg, 49 m, FOV 35: traffic_clip's pose), side-on. A frame every
## --every ticks for --seconds. Needs a display (make remote T=traffic-t7-clip). GDScript path (the drive test's).
##
##   godot --path . --resolution 1280x720 --fixed-fps 30 --script res://tests/traffic/t7_clip.gd -- --tag=on --out=/abs/dir
##         [--traffic-on=underfire | --traffic-off=underfire]

const HIS_PITCH_DEG := 21.0
const HIS_FOV_DEG := 35.0
const HIS_DISTANCE_M := 49.0

var case: TestCase
var camera: Camera3D
var lab: TacticsLab


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	BrainSwitches.ensure_parsed()
	BrainSwitches.native = false
	var out := _flag("out", ProjectSettings.globalize_path("res://build/traffic-t7-clip"))
	var tag := _flag("tag", "arm")
	var every := int(_flag("every", "3"))
	var seconds := float(_flag("seconds", "14"))
	DirAccess.make_dir_recursive_absolute(out)
	lab = TacticsLab.create(case, 7, "yard_open")
	var parked := lab.gun(Match.Team.GREEN, "Green_Parked", Vector3.ZERO, 0.0, "law_tank")
	var asker := lab.unit(Match.Team.GREEN, "Green_Asker", Vector3(0.0, 0.0, 14.0), 0.0, "law_tank")
	await lab.start()
	for i in 3:
		await lab.step()
	var focus := Vector3(parked.global_position.x, 0.0, parked.global_position.z - 4.0)
	var heading := Vector3(1.0, 0.0, 0.0)
	camera = Camera3D.new()
	camera.fov = HIS_FOV_DEG
	case.add_to_tree(camera)
	camera.global_position = focus - heading * HIS_DISTANCE_M * cos(deg_to_rad(HIS_PITCH_DEG)) \
			+ Vector3.UP * HIS_DISTANCE_M * sin(deg_to_rad(HIS_PITCH_DEG))
	camera.look_at(focus, Vector3.UP)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, 30, 0)
	light.light_energy = 0.9
	case.add_to_tree(light)
	lab.element([String(asker.name)], "Go").assign({"verb": "move", "to": [0.0, -30.0]})
	var post := parked.global_position
	var mover := Movement.of(parked)
	var yielded := false
	var ticks := int(seconds * SimClock.TICK_RATE)
	for now in ticks:
		parked.ticks_since_hit = 0
		await lab.step()
		yielded = yielded or mover.yield_to != ""
		if now % every == 0:
			root.get_texture().get_image().save_png("%s/%s_%05d.png" % [out, tag, now / every])
	print("T7_CLIP " + JSON.stringify({"tag": tag, "underfire": not Traffic.off("underfire"), "yielded": yielded,
			"refuser_moved_m": snappedf(Movement._flat_distance(parked.global_position, post), 0.1),
			"asker_at": [snappedf(asker.global_position.x, 0.1), snappedf(asker.global_position.z, 0.1)],
			"passes": Movement.passes, "passes_done": Movement.passes_done, "refusals": Movement.underfire_refusals}))
	lab.dispose()
	case.teardown()
	quit(0)
