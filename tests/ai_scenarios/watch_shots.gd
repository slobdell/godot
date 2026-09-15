extends SceneTree
## `make ai-shots` (round-3 X4, _agents/streams/ai.md): stage AI fights on the real arena in a window, draw every unit's
## last few seconds of driving as a trail, and save frames to build/ai-shots/<stage>_<seconds>s.png, so a behavior can
## be judged from stills: does it circle, dodge, run at the rear, break away? Nameplates show each brain's intent.
## Needs a display: `make remote T=ai-shots` uses builder0's desktop. `--stage=<name>` runs one stage.
##
## Stages: duel (two x3 tanks), scout_runs (an x3 scout ordered onto a tank), brawl (3 v 3 mixed, x3 vs a6),
## cpu_charge (a CPU swarm army under CpuCommander v3 charging a small army with artillery: the scout V).

const OUT := "res://build/ai-shots"
const STAGES := ["duel", "scout_runs", "brawl", "cpu_charge"]
## Trail length (samples, one every TRAIL_EVERY_TICKS).
const TRAIL_SAMPLES := 90
const TRAIL_EVERY_TICKS := 4

var case: TestCase
var scenario: AiScenario
var camera: Camera3D
var trails := {}
var trail_mesh: ImmediateMesh
var green_material: StandardMaterial3D
var rust_material: StandardMaterial3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			only = arg.trim_prefix("--stage=")
	for stage: String in STAGES:
		if only != "" and stage != only:
			continue
		case = TestCase.new()
		case.tree = self
		await call("_stage_" + stage)
		case.teardown()
		BrainVariants.reset()
		trails.clear()
	RenderingServer.render_loop_enabled = true
	print("AI_SHOTS_DONE")
	quit(0)


func _setup(center: Vector3, size: float) -> void:
	scenario = AiScenario.create(case, 5)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	case.add_to_tree(camera)
	camera.global_position = center + Vector3(0, 80, 0)
	camera.look_at(center, Vector3.FORWARD)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-70, 30, 0)
	light.light_energy = 0.9
	case.add_to_tree(light)
	var drawer := MeshInstance3D.new()
	trail_mesh = ImmediateMesh.new()
	drawer.mesh = trail_mesh
	drawer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	case.add_to_tree(drawer)
	green_material = _line_material(Color(0.3, 1.0, 0.5))
	rust_material = _line_material(Color(1.0, 0.45, 0.2))


static func _line_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	return material


## Run `seconds` of simulation, sampling trails, and save a frame at each of `shots` (seconds).
func _play(stage: String, seconds: float, shots: Array) -> void:
	await scenario.start()
	var next_shot := 0
	# Draw only the frames we save: the arena at full quality renders slowly on builder0's integrated GPU.
	RenderingServer.render_loop_enabled = false
	for tick in roundi(seconds * 60.0) + 1:
		await scenario.step()
		if tick % TRAIL_EVERY_TICKS == 0:
			_sample_trails()
		if next_shot < shots.size() and tick >= roundi(float(shots[next_shot]) * 60.0):
			_sample_trails()
			RenderingServer.render_loop_enabled = true
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			RenderingServer.render_loop_enabled = false
			var path := "%s/%s_%02ds.png" % [OUT, stage, int(shots[next_shot])]
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			print("AI_SHOT ", path)
			next_shot += 1


func _sample_trails() -> void:
	trail_mesh.clear_surfaces()
	for node in scenario.game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null:
			continue
		var points: Array = trails.get_or_add(String(tank.name), [])
		if tank.is_alive():
			points.append(tank.global_position + Vector3(0, 0.3, 0))
		if points.size() > TRAIL_SAMPLES:
			points.pop_front()
		if points.size() < 2:
			continue
		trail_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, green_material if tank.team == Match.Team.GREEN else rust_material)
		for point: Vector3 in points:
			trail_mesh.surface_add_vertex(point)
		trail_mesh.surface_end()


func _stage_duel() -> void:
	BrainVariants.use(Match.Team.GREEN, "x3")
	BrainVariants.use(Match.Team.RUST, "x3")
	_setup(Vector3(-98, 0, 2), 70.0)
	scenario.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 25), 0.0)
	scenario.brain_tank(Match.Team.RUST, "Rust_A_1", Vector3(-96, 0, -20), PI)
	await _play("duel", 16.0, [4, 8, 12, 16])


func _stage_scout_runs() -> void:
	BrainVariants.use(Match.Team.GREEN, "x3")
	_setup(Vector3(-100, 0, 5), 70.0)
	var tank := scenario.shooter(Match.Team.RUST, "Rust_Tank_1", Vector3(-100, 0, -10), 0.0)
	AiScenario.make_durable(tank)
	var scout := scenario.brain_tank(Match.Team.GREEN, "Green_Scout_1", Vector3(-100, 0, 45), 0.0, {}, "scout")
	AiScenario.make_durable(scout)
	var orders := scenario.orders()
	await scenario.start()
	orders.call("issue", {"units": [String(scout.name)], "verb": "attack", "target": String(tank.name), "queue": false})
	await _play("scout_runs", 16.0, [5, 10, 16])


func _stage_brawl() -> void:
	BrainVariants.use(Match.Team.GREEN, "x3")
	BrainVariants.use(Match.Team.RUST, "a6")
	_setup(Vector3(-95, 0, 10), 90.0)
	var units := ["tank", "ifv", "scout"]
	for i in 3:
		scenario.brain_tank(Match.Team.GREEN, "Green_A_%d" % (i + 1), Vector3(-108 + i * 9, 0, 45), 0.0, {}, units[i], "", "Alpha")
		scenario.brain_tank(Match.Team.RUST, "Rust_A_%d" % (i + 1), Vector3(-104 + i * 9, 0, -25), PI, {}, units[i], "", "Alpha")
	await _play("brawl", 24.0, [6, 12, 18, 24])


func _stage_cpu_charge() -> void:
	_setup(Vector3(0, 0, 10), 150.0)
	var swarm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/ai_scenarios/armies/swarm.json"))
	scenario.game_match.load_doctrine(Match.Team.RUST, swarm)
	var defenders := {"name": "Defenders", "squads": [{"name": "Guns", "units": [{"unit": "tank"}, {"unit": "tank"}]},
			{"name": "Battery", "units": [{"unit": "artillery"}]}]}
	scenario.game_match.load_doctrine(Match.Team.GREEN, defenders)
	for tank: Tank in scenario.game_match.tanks_by_name().values():
		trails.get_or_add(String(tank.name), [])
	var commander := CpuCommander.new()
	commander.game_match = scenario.game_match
	commander.team = Match.Team.RUST
	commander.policy = "v3"
	case.add_to_tree(commander)
	await _play("cpu_charge", 30.0, [8, 14, 20, 26, 30])
