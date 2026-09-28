extends SceneTree
## `make formation-shots` (round 12, S5): a squad's plain move at HIS pose -- the skirmish camera's 21 deg pitch, FOV 35,
## 49 m from what it looks at -- following the squad from behind, with its last seconds of driving drawn as trails.
## Frames at t = 10 s and at arrival for each arena x shape, so a column and a wedge on the same order, the same seed,
## can be judged side by side: build/formation-shots/<arena>_<shape>_{10s,arrival}.png.
## Needs a display: `make remote T=formation-shots`. ARENAS= / SHAPES= narrow it; SEED= (default 3).
## Round 13 (squad Q2, S6): UNITS=scout:scout:ifv:ifv:tank picks the squad; IDLE_FACE=off|on sets
## TankBrain.IDLE_FACE_NO_PIVOT and adds `_face-<arm>` to the file names; SETTLE=on adds two more frames, when every crew
## has stopped (`settled`: under 0.3 m/s for 1 s after arrival, the settle probe's rule) and at t = 25 s (`25s`: both
## arms long settled), with each crew's SLOT drawn as a yellow cross, so a scout skewed or off its slot shows.

const OUT := "res://build/formation-shots"
const PITCH_DEG := 21.0
const FOV_DEG := 35.0
const DISTANCE_M := 49.0
const TRAIL_SAMPLES := 120
const TRAIL_EVERY_TICKS := 3
const START_JITTER_M := 1.5

var case: TestCase
var lab: TacticsLab
var camera: Camera3D
var trails := {}
var trail_mesh: ImmediateMesh
var trail_material: StandardMaterial3D
var slot_material: StandardMaterial3D
var slots_to_draw := {}


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if _flag("idle-face", "default") != "default":
		TankBrain.IDLE_FACE_NO_PIVOT = _flag("idle-face", "default") == "on"
	for arena_name in _flag("arenas", "yard terminus").split(" ", false):
		for shape in _flag("shapes", "column wedge").split(" ", false):
			case = TestCase.new()
			case.tree = self
			await _stage(arena_name, shape, int(_flag("seed", "3")))
			if lab != null:
				lab.dispose()
				lab = null
			case.teardown()
			trails.clear()
	RenderingServer.render_loop_enabled = true
	print("FORMATION_SHOTS_DONE")
	quit(0)


func _stage(arena_name: String, shape: String, seed_value: int) -> void:
	lab = TacticsLab.create(case, seed_value, arena_name)
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var names: Array = []
	var units := Array(_flag("units", "tank:tank:ifv:ifv").split(":", false))
	var tag := shape + ("_face-%s" % _flag("idle-face", "") if _flag("idle-face", "default") != "default" else "")
	var settle := _flag("settle", "off") == "on"
	for i in units.size():
		var at := home + right * ((i - (units.size() - 1) * 0.5) * 8.0) \
				+ right * jitter.randf_range(-START_JITTER_M, START_JITTER_M) + toward * jitter.randf_range(-START_JITTER_M, START_JITTER_M)
		names.append(String(lab.unit(Match.Team.GREEN, "Green_F_%d" % (i + 1), at, atan2(-toward.x, -toward.z), units[i]).name))
	camera = Camera3D.new()
	camera.fov = FOV_DEG
	case.add_to_tree(camera)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, 30, 0)
	light.light_energy = 0.9
	case.add_to_tree(light)
	var drawer := MeshInstance3D.new()
	trail_mesh = ImmediateMesh.new()
	drawer.mesh = trail_mesh
	drawer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	case.add_to_tree(drawer)
	trail_material = StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.albedo_color = Color(0.3, 1.0, 0.5)
	trail_material.no_depth_test = true
	slot_material = trail_material.duplicate()
	slot_material.albedo_color = Color(1.0, 0.85, 0.1)
	slots_to_draw = {}
	await lab.start()
	var element := lab.elements.form(names, "Alpha")
	var goal := lab.center_of(names) + toward * 80.0
	var task := {"verb": "move", "to": [goal.x, goal.z], "drills": false}
	if shape != "auto":
		task["formation"] = shape
	element.assign(task)
	var shots := {10 * SimClock.TICK_RATE: "10s"}
	if settle:
		shots[25 * SimClock.TICK_RATE] = "25s"
	var arrival_shot := -1
	var still_since := -1
	var settled := false
	RenderingServer.render_loop_enabled = false
	for tick in 40 * SimClock.TICK_RATE:
		await lab.step()
		if tick % TRAIL_EVERY_TICKS == 0:
			_sample_trails(names)
		if arrival_shot < 0 and element.arrived:
			arrival_shot = tick + 2 * SimClock.TICK_RATE  # two seconds after arrival: the shape as it stands
			shots[arrival_shot] = "arrival"
		if settle and not settled and element.arrived:
			var fastest := 0.0
			for unit_name: String in names:
				var tank := lab.tank_of(unit_name)
				if tank != null:
					fastest = maxf(fastest, tank.estimated_velocity.length())
			if fastest >= 0.3:
				still_since = -1
			elif still_since < 0:
				still_since = tick
			elif tick - still_since >= SimClock.TICK_RATE:
				settled = true
				print("FORMATION_SETTLED %s %s at %.1f s" % [arena_name, tag, still_since / float(SimClock.TICK_RATE)])
				slots_to_draw = element.slots.duplicate()
				await _capture(names, toward, "%s_%s_settled" % [arena_name, tag], element)
		if shots.has(tick):
			if settle:
				slots_to_draw = element.slots.duplicate()
			await _capture(names, toward, "%s_%s_%s" % [arena_name, tag, shots[tick]], element)
			if shots[tick] == "25s" or (shots[tick] == "arrival" and not settle):
				break
	if arrival_shot < 0:
		await _capture(names, toward, "%s_%s_arrival" % [arena_name, tag], element)


func _capture(names: Array, toward: Vector3, stem: String, element: Element) -> void:
	var focus := lab.center_of(names)
	var back := -toward * DISTANCE_M * cos(deg_to_rad(PITCH_DEG))
	camera.global_position = focus + back + Vector3.UP * DISTANCE_M * sin(deg_to_rad(PITCH_DEG))
	camera.look_at(focus, Vector3.UP)
	_draw_trails(names)
	RenderingServer.render_loop_enabled = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = false
	var path := "%s/%s.png" % [OUT, stem]
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("FORMATION_SHOT %s %s | %s" % [path, element.describe(), CommandIcons.formation_readout(
			String(element.task.get("formation", UnitCommand.AUTO)), element.state())["label"]])


func _sample_trails(names: Array) -> void:
	for unit_name: String in names:
		var tank := lab.tank_of(unit_name)
		if tank == null:
			continue
		var trail: Array = trails.get_or_add(unit_name, [])
		trail.append(tank.global_position + Vector3.UP * 0.3)
		if trail.size() > TRAIL_SAMPLES:
			trail.pop_front()


func _draw_trails(_names: Array) -> void:
	trail_mesh.clear_surfaces()
	for unit_name: String in trails:
		var trail: Array = trails[unit_name]
		if trail.size() < 2:
			continue
		trail_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, trail_material)
		for point: Vector3 in trail:
			trail_mesh.surface_add_vertex(point)
		trail_mesh.surface_end()
	for unit_name: String in slots_to_draw:
		var slot: Variant = slots_to_draw[unit_name]
		if not slot is Vector3:
			continue
		var at: Vector3 = (slot as Vector3) + Vector3.UP * 0.3
		trail_mesh.surface_begin(Mesh.PRIMITIVE_LINES, slot_material)
		for arm: Vector3 in [Vector3(1.2, 0, 1.2), Vector3(1.2, 0, -1.2)]:
			trail_mesh.surface_add_vertex(at - arm)
			trail_mesh.surface_add_vertex(at + arm)
		trail_mesh.surface_end()
