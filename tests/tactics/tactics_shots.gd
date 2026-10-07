extends SceneTree
## `make tactics-shots` (doctrine X3/X5): doctrine in pictures. Stage an element on the real arena, draw the
## last few seconds of every vehicle's driving as a trail, and save frames to build/tactics-shots/, so a
## formation, a bound and an assault through an ambush can be judged from stills. Each frame also prints the
## element's shape, technique, drill and reason, so the picture and the decision can be read together.
## Needs a display: `make remote T=tactics-shots`. `--stage=<name>` runs one stage.

const OUT := "res://build/tactics-shots"
const STAGES := ["wedge_advance", "bounding", "near_ambush", "herringbone", "parity", "gang_pack", "pursuit"]
const TRAIL_SAMPLES := 90
const TRAIL_EVERY_TICKS := 4
const LANE_X := TacticsScenarios.LANE_X

var case: TestCase
var lab: TacticsLab
var camera: Camera3D
var trails := {}
var trail_mesh: ImmediateMesh
var green_material: StandardMaterial3D
var rust_material: StandardMaterial3D
var watched: Array = []
## Round 14 (squad Q1): `--pose=his` frames a stage from the skirmish camera's pose (formation_shots.gd: 21 deg pitch,
## FOV 35, 49 m) following `followed` from behind along `heading`, instead of the top-down orthographic view.
var followed: Array = []
var heading := Vector3.FORWARD
const HIS_PITCH_DEG := 21.0
const HIS_FOV_DEG := 35.0
const HIS_DISTANCE_M := 49.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			only = arg.trim_prefix("--stage=")
		# Round 15 (squad P4): the far-ambush turn-in as it was before (the mutation arm), for before/after frames.
		if arg == "--flank-turn-in=distance":
			ElementPlan.FLANK_TURN_IN_BY_BEARING = false
		# Round 21 (brains P2): round 20's attack on a running target, for before/after frames of the pursuit stage.
		if arg == "--pursuit=off":
			ElementPlan.PURSUIT_ENABLED = false
	for stage: String in STAGES:
		if only != "" and stage != only:
			continue
		case = TestCase.new()
		case.tree = self
		await call("_stage_" + stage)
		if lab != null:
			lab.dispose()
			lab = null
		case.teardown()
		trails.clear()
		watched.clear()
	RenderingServer.render_loop_enabled = true
	print("TACTICS_SHOTS_DONE")
	quit(0)


func _setup(center: Vector3, size: float, seed_value := 41, arena := "") -> void:
	lab = TacticsLab.create(case, seed_value, arena)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	case.add_to_tree(camera)
	camera.global_position = center + Vector3(0, 90, 0)
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


## Run `seconds`, sampling trails, and save a frame at each of `shots` (seconds), printing what the
## watched elements were doing at that moment.
func _play(stage: String, seconds: float, shots: Array, on_tick: Callable = Callable()) -> void:
	var next_shot := 0
	RenderingServer.render_loop_enabled = false
	for tick in roundi(seconds * SimClock.TICK_RATE) + 1:
		await lab.step()
		if on_tick.is_valid():
			on_tick.call(tick)
		if tick % TRAIL_EVERY_TICKS == 0:
			_sample_trails()
		if next_shot < shots.size() and tick >= roundi(float(shots[next_shot]) * SimClock.TICK_RATE):
			_sample_trails()
			if not followed.is_empty() and OS.get_cmdline_user_args().has("--pose=his"):
				_his_pose()
			RenderingServer.render_loop_enabled = true
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			RenderingServer.render_loop_enabled = false
			var path := "%s/%s_%02ds.png" % [OUT, stage, int(shots[next_shot])]
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			for element: Element in watched:
				print("TACTICS_SHOT %s %02ds %s" % [stage, int(shots[next_shot]), element.describe()])
			print("TACTICS_SHOT ", path)
			next_shot += 1


func _his_pose() -> void:
	var focus := lab.center_of(followed)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = HIS_FOV_DEG
	camera.global_position = focus - heading * HIS_DISTANCE_M * cos(deg_to_rad(HIS_PITCH_DEG)) \
			+ Vector3.UP * HIS_DISTANCE_M * sin(deg_to_rad(HIS_PITCH_DEG))
	camera.look_at(focus, Vector3.UP)


func _sample_trails() -> void:
	trail_mesh.clear_surfaces()
	for node in lab.game_match.tanks.get_children():
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
		trail_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,
				green_material if tank.team == Match.Team.GREEN else rust_material)
		for point: Vector3 in points:
			trail_mesh.surface_add_vertex(point)
		trail_mesh.surface_end()


func _column(count: int, front: Vector3, unit_id := "tank") -> Array:
	var names: Array = []
	for i in count:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				front + Vector3(0.0, 0.0, i * 10.0), 0.0, unit_id).name))
	return names


## Round 21 (brains P2): HIS attack on a vehicle that runs (tests/test_tactics_pursuit.gd's stage: the open yard, five
## Rat Rods, vee, a Syndicate spotter 70 m ahead driving away at 8 m/s and bearing off right). The trails show a chase,
## or (`--pursuit=off`) the orbit he saw. Frames are named with the arm: pursuit_on_08s.png / pursuit_off_08s.png.
func _stage_pursuit() -> void:
	var arm := "off" if not ElementPlan.PURSUIT_ENABLED else "on"
	_setup(Vector3(40, 0, -10), 230.0, 3, "yard_open")
	lab.game_match.set_meta("player_team", Match.Team.GREEN)
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	home.y = 0.0
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	var names: Array = []
	for i in 5:
		var at := home + right * ((i - 2) * 6.0) - toward * (i % 2) * 4.0
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1), at, yaw, "gang_scout").name))
	var start := home + toward * 70.0
	var target := lab.gun(Match.Team.RUST, "Rust_Eyes_1", start, yaw, "syn_lancer")
	var waypoints: Array = []
	for w: Vector3 in [start + toward * 80.0, start + toward * 120.0 + right * 70.0, start + toward * 120.0 + right * 160.0]:
		waypoints.append(ElementPlan.clamp_to_arena(w))
	var controller := lab.game_match.brains.get_node("Orders_Rust_Eyes_1") as OrderController
	var pace := 8.0 / target.max_forward_speed
	await lab.start()
	var alpha := lab.elements.form(names, "Alpha")
	watched = [alpha]
	alpha.assign({"verb": "attack", "target": String(target.name), "formation": "vee"})
	var leg := [0]
	controller.set_orders({"type": "move_to", "x": waypoints[0].x, "z": waypoints[0].z, "speed": pace}, {"type": "fire_at_will"})
	await _play("pursuit_" + arm, 20.0, [4, 8, 12, 16, 20], func(_tick: int) -> void:
		if leg[0] < waypoints.size() and target.is_alive() \
				and Vector2(target.global_position.x - waypoints[leg[0]].x, target.global_position.z - waypoints[leg[0]].z).length() < 6.0:
			leg[0] += 1
			if leg[0] < waypoints.size():
				controller.set_orders({"type": "move_to", "x": waypoints[leg[0]].x, "z": waypoints[leg[0]].z, "speed": pace},
						{"type": "fire_at_will"}))


## An element crossing open ground in its doctrinal shape: a wedge, trail element overwatching.
func _stage_wedge_advance() -> void:
	_setup(Vector3(LANE_X + 8.0, 0, 12), 150.0)
	var names := _column(5, Vector3(LANE_X, 0.0, 50.0))
	lab.gun(Match.Team.RUST, "Rust_Far_1", Vector3(LANE_X + 10.0, 0.0, -75.0), PI)
	var alpha := lab.element(names, "Alpha")
	watched = [alpha]
	await lab.start()
	alpha.assign({"verb": "move", "to": [LANE_X, -35.0]})
	await _play("wedge_advance", 20.0, [4, 10, 16, 20])


## Bounding overwatch: half the element is always set, covering the other half's bound.
func _stage_bounding() -> void:
	_setup(Vector3(LANE_X + 8.0, 0, 15), 140.0)
	var names := _column(4, Vector3(LANE_X, 0.0, 50.0))
	lab.gun(Match.Team.RUST, "Rust_Far_1", Vector3(LANE_X, 0.0, -70.0), PI)
	var alpha := lab.element(names, "Alpha", TacticsLab.table_of("wedge", "bounding_overwatch"))
	watched = [alpha]
	await lab.start()
	alpha.assign({"verb": "move", "to": [LANE_X, -25.0]})
	await _play("bounding", 20.0, [5, 10, 15, 20])


## The lead's drill: ambushed at close range, the element turns into it and assaults through.
func _stage_near_ambush() -> void:
	_setup(Vector3(LANE_X + 14.0, 0, 8), 140.0)
	var names := _column(4, Vector3(LANE_X, 0.0, 40.0))
	var alpha := lab.element(names, "Alpha")
	watched = [alpha]
	await lab.start()
	alpha.assign({"verb": "move", "to": [LANE_X, -40.0]})
	var sprung := [false]
	await _play("near_ambush", 22.0, [4, 8, 12, 16, 22], func(_tick: int) -> void:
		if sprung[0]:
			return
		var center := lab.center_of(names)
		if center.z < 12.0:
			sprung[0] = true
			for i in 2:
				lab.gun(Match.Team.RUST, "Rust_Ambush_%d" % (i + 1),
						Vector3(LANE_X + 25.0, 0.0, center.z - 6.0 + i * 8.0), -PI * 0.5))



## Round 14 (squad Q1): the gang-pack drill in pictures -- the same four vehicles, the same two guns and the same seed
## as `TacticsScenarios.gang_pack` (make tactics-drills), so the frames show the fight the assertions judge: does the
## pack ring the guns, or line up and trade? `--table=standard` stages the comparison element; `--chasers` the
## bait_chase variant; `--pose=his` the lead's camera.
func _stage_gang_pack() -> void:
	var table_name := "gangs"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--table="):
			table_name = arg.trim_prefix("--table=")
	_setup(Vector3(LANE_X, 0, 5), 150.0, 53)
	var names: Array = []
	for i in 4:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				Vector3(LANE_X - 12.0 + i * 8.0, 0.0, 45.0), 0.0, "scout" if i > 0 else "ifv").name))
	# `--chasers` stages bait_chase's enemy instead: two brain-driven IFVs that follow a lure.
	var chasers := OS.get_cmdline_user_args().has("--chasers")
	var enemy: Array = []
	for i in 2:
		var spot := Vector3(LANE_X - 6.0 + i * 12.0, 0.0, -35.0)
		if chasers:
			enemy.append(String(lab.unit(Match.Team.RUST, "Rust_Hunt_%d" % (i + 1), spot, PI, "ifv").name))
		else:
			enemy.append(String(lab.gun(Match.Team.RUST, "Rust_Gun_%d" % (i + 1), spot, PI,
					"lancer" if i == 0 else "artillery").name))
	var pack := lab.element(names, "Pack", TacticsScenarios.table_for(table_name))
	watched = [pack]
	followed = names
	heading = Vector3.FORWARD
	await lab.start()
	pack.assign({"verb": "attack", "target": enemy[0]})
	await _play("gang_pack_%s%s%s" % [table_name, "_chasers" if chasers else "",
			"_his" if OS.get_cmdline_user_args().has("--pose=his") else ""], 26.0, [3, 6, 10, 16, 26])


## A halt: the herringbone, every flank watched.
func _stage_herringbone() -> void:
	_setup(Vector3(LANE_X + 6.0, 0, 20), 80.0)
	var names := _column(4, Vector3(LANE_X, 0.0, 20.0))
	lab.gun(Match.Team.RUST, "Rust_Far_1", Vector3(LANE_X, 0.0, -75.0), PI)
	var alpha := lab.element(names, "Alpha")
	watched = [alpha]
	await lab.start()
	alpha.assign({"verb": "hold"})
	await _play("herringbone", 10.0, [4, 10])


## Both sides commanded the same way: elements with tasks, doctrine below the line.
func _stage_parity() -> void:
	_setup(Vector3(0, 0, 0), 230.0, 5)
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		var loaded := Doctrine.load_file("res://doctrines/%s.json"
				% ("combined_arms" if team == Match.Team.GREEN else "anvil_hammer"))
		lab.game_match.load_doctrine(team, loaded["doctrine"])
	await lab.start()
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		var commander := ElementCommander.install(lab.game_match, team, lab.elements)
		commander.form_elements()
	watched = lab.elements.all()
	await _play("parity", 45.0, [5, 15, 25, 35, 45])
