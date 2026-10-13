extends SceneTree
## Round 26 (traffic T0/T2): his case as he would see it — the two squads meeting, from his camera (pitch 21 deg, 49 m,
## FOV 35: tactics_shots' HIS_ pose) on the meeting point, a frame every --every ticks for --seconds. Needs a display
## (make remote T=traffic-clip). The arm is the command line's --traffic-off=..., named by --tag.
##
##   godot --path . --resolution 1280x720 --fixed-fps 30 --script res://tests/traffic/traffic_clip.gd -- --arena=yard_open
##         --kind=head --seed=1 --seconds=40 --every=3 --tag=main --out=/abs/dir --traffic-off=slide,keepright,crossing

const HIS_PITCH_DEG := 21.0
const HIS_FOV_DEG := 35.0
const HIS_DISTANCE_M := 49.0

var case: TestCase
var camera: Camera3D
var out := ""
var tag := ""
var every := 3
var focus := Vector3.ZERO
var heading := Vector3.RIGHT


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
	TacticsFlags.requested()
	var arena := _flag("arena", "yard_open")
	var kind := _flag("kind", "head")
	out = _flag("out", ProjectSettings.globalize_path("res://build/traffic-clip"))
	tag = _flag("tag", "arm")
	every = int(_flag("every", "3"))
	DirAccess.make_dir_recursive_absolute(out)
	focus = TrafficStage.meeting_point(arena, kind)
	# Side-on to a head-on meeting (both squads cross the frame); from the corner of a crossing.
	heading = Vector3(1.0, 0.0, 0.0) if kind == "head" else Vector3(1.0, 0.0, -1.0).normalized()
	var pitch := HIS_PITCH_DEG
	var distance := HIS_DISTANCE_M
	if arena == "terminus":
		# Round 28: his pose from the side puts the camera inside the blocks of an 18 m street (round 26's Terminus clips
		# showed a roof). Look down the street from above instead: along it for head-on, from the corner for the crossing.
		heading = Vector3(0.0, 0.0, -1.0) if kind == "head" else Vector3(1.0, 0.0, -1.0).normalized()
		pitch = 58.0
		distance = 95.0
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = HIS_FOV_DEG
	case.add_to_tree(camera)
	camera.global_position = focus - heading * distance * cos(deg_to_rad(pitch)) \
			+ Vector3.UP * distance * sin(deg_to_rad(pitch))
	camera.look_at(focus, Vector3.UP)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, 30, 0)
	light.light_energy = 0.9
	case.add_to_tree(light)
	var report := await TrafficStage.run(case, int(_flag("seed", "1")), arena, kind, "both", float(_flag("seconds", "40")),
			"green", false, _frame)
	report["tag"] = tag
	print("TRAFFIC_CLIP " + JSON.stringify(report))
	case.teardown()
	quit(0)


func _frame(_lab: TacticsLab, now: int) -> void:
	if now % every != 0:
		return
	camera.current = true
	var path := "%s/%s_%05d.png" % [out, tag, now / every]
	root.get_texture().get_image().save_png(path)
