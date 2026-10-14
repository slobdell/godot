extends SceneTree
## `make planner-lab` (round 30, planner P3): **one real hull on a real arena cut, the planner's legs driven through the
## plant by PlannerExecutor, beside the same hull under today's code on the same fixture.** Frames at the start, the
## middle and the end of each arm with the paths drawn (the planner's in green, today's in orange, both on the final
## frame), one `PLANNER_LAB {json}` line per arm (seconds to the pose, legs, metres, wall and hull contact ticks, where
## it ended), `PLANNER_LAB_DONE` at the end. Needs a display (builder0's: `make remote LIGHT=1 T=planner-lab`).
##
##   godot --path . --fixed-fps 30 --resolution 1280x720 --script res://tests/planner/planner_lab.gd -- \
##       --fixtures=turnround,slot180,tjunction [--arms=planner,today] [--seconds=60] [--out=res://build/planner-lab]
##
## Fixtures (the Terminus unless said): `turnround` a War Rig in the west street heading north, wanted facing south on
## its spot (today: a `face` order); `slot180` a law_scout on the avenue 9 m short of a slot it must face back from
## (today: `move_to` with a facing, which is the gate); `tjunction` a War Rig in the west street 25 m short of the ring
## road, wanted on the ring road heading east (today: `move_to` with a facing); `yardcorner` a War Rig in the yard's
## inner west lane turning into the gap in the container row at z ~ 38 (today: `move_to` with a facing).

const PITCH_DEG := 50.0   # verification.md "Filming a march": 45-55 on a map with tall cover; 21 hides the street
const FOV_DEG := 35.0
const DISTANCE_M := 55.0
const TRAIL_EVERY_TICKS := 2
const ALIGNED_DEG := 8.0
const ARRIVE_M := 2.0
const CUSP_SPEED := 0.3

var case: TestCase
var lab: TacticsLab
var camera: Camera3D
var trail_mesh: ImmediateMesh
var materials := {}
var trails := {}      # arm -> Array[Vector3]
var out_dir := "res://build/planner-lab"
var movie := false


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


static func _fixtures() -> Dictionary:
	# Each: arena, unit, start (x, z, heading deg clockwise from north), goal pose, tolerance, today's order.
	return {
		"turnround": {"arena": "terminus", "unit": "gang_tank", "start": [-70.0, 0.0, 0.0], "goal": [-70.0, 0.0, 180.0],
				"tol_m": 2.0, "today": {"type": "face", "x": -70.0, "z": 100.0}, "camera_heading": 0.0},
		"slot180": {"arena": "terminus", "unit": "law_scout", "start": [0.0, 60.0, 0.0], "goal": [0.0, 51.0, 180.0],
				"tol_m": 1.0, "today": {"type": "move_to", "x": 0.0, "z": 51.0, "facing": [0.0, 1.0]}, "camera_heading": 0.0},
		"tjunction": {"arena": "terminus", "unit": "gang_tank", "start": [-70.0, 50.0, 0.0], "goal": [-48.0, 30.0, 90.0],
				"tol_m": 1.5, "today": {"type": "move_to", "x": -48.0, "z": 30.0, "facing": [1.0, 0.0]}, "camera_heading": 0.0},
		"yardcorner": {"arena": "yard", "unit": "gang_tank", "start": [-34.0, 60.0, 0.0], "goal": [-8.0, 38.0, 90.0],
				"tol_m": 1.5, "today": {"type": "move_to", "x": -8.0, "z": 38.0, "facing": [1.0, 0.0]}, "camera_heading": 0.0},
	}


func _run() -> void:
	BrainSwitches.ensure_parsed()
	out_dir = _flag("out", out_dir)
	movie = _flag("movie", "") != ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var arms := _flag("arms", "planner,today").split(",", false)
	var seconds := float(_flag("seconds", "60"))
	for name in _flag("fixtures", "turnround,slot180,tjunction").split(",", false):
		var fixture: Dictionary = _fixtures().get(name, {})
		if fixture.is_empty():
			push_error("planner-lab: no fixture %s" % name)
			continue
		trails.clear()
		for arm in arms:
			case = TestCase.new()
			case.tree = self
			await _stage(name, fixture, arm, seconds)
			if lab != null:
				lab.dispose()
				lab = null
			case.teardown()
	RenderingServer.render_loop_enabled = true
	print("PLANNER_LAB_DONE")
	quit(0)


static func _heading_deg(tank: Tank) -> float:
	var nose := -tank.global_basis.z
	return rad_to_deg(atan2(nose.x, -nose.z))


func _controller_of(tank: Tank) -> OrderController:
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			return child
	return null


func _stage(name: String, fixture: Dictionary, arm: String, seconds: float) -> void:
	lab = TacticsLab.create(case, 31, String(fixture["arena"]))
	var start: Array = fixture["start"]
	var goal: Array = fixture["goal"]
	var yaw := -deg_to_rad(float(start[2]))  # rotation.y: positive turns LEFT; a heading clockwise from north is -yaw
	var tank := lab.gun(Match.Team.GREEN, "Green_P_1", Vector3(float(start[0]), 0.0, float(start[1])), yaw, String(fixture["unit"]))
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
	for key_color: Array in [["planner", Color(0.3, 1.0, 0.5)], ["today", Color(1.0, 0.6, 0.15)], ["goal", Color(1.0, 0.9, 0.2)]]:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = key_color[1]
		m.no_depth_test = true
		materials[key_color[0]] = m
	await lab.start()
	var ctl := _controller_of(tank)
	var goal_f := Vector2(sin(deg_to_rad(float(goal[2]))), -cos(deg_to_rad(float(goal[2]))))
	var executor: PlannerExecutor = null
	var plan: PackedPlan = null
	var plan_ms := 0.0
	if arm == "planner":
		ctl.set_physics_process(false)  # the harness writes the command; today's drive is out of the loop
		var world := PlannerNavWorld.for_tank(tank, lab.game_match.tanks)
		var f := -tank.global_basis.z
		var req := PlanRequest.for_unit(tank.unit_id).at(tank.global_position.x, tank.global_position.z, f.x, f.z) \
				.to(float(goal[0]), float(goal[1]), goal_f.x, goal_f.y, float(fixture["tol_m"]), ALIGNED_DEG).in_world(world)
		req.budget = 6000
		var started := Time.get_ticks_usec()
		plan = Planner.plan(req)
		plan_ms = (Time.get_ticks_usec() - started) / 1000.0
		print("PLANNER_LAB_PLAN %s: %s %s | %s | %d expansions %.1f ms on %s" % [name, plan.code, plan.describe(), plan.why, plan.expansions, plan_ms, OS.get_environment("HOSTNAME")])
		var x0 := tank.global_position.x - 25.0
		var z0 := tank.global_position.z - 25.0
		print(plan.ascii(world, x0, z0, x0 + 50.0, z0 + 50.0, req.start_x, req.start_z, req.goal_x, req.goal_z))
		executor = PlannerExecutor.new()
		executor.start(plan, tank)
	else:
		ctl.set_orders(fixture["today"], {"type": "fire_at_will"})
	if not movie:
		RenderingServer.render_loop_enabled = false
	var ticks := int(SimClock.TICK_RATE * seconds)
	var done_s := -1.0
	var legs := 0
	var gear := 0
	var metres := 0.0
	var last := tank.global_position
	var wall_ticks := 0
	var hull_ticks := 0
	var creep_ticks := 0
	var goal_pos := Vector3(float(goal[0]), 0.0, float(goal[1]))
	var shots := {0: "start", int(ticks / 2): "mid"}
	var trail: Array = trails.get_or_add(arm, [])
	var end_tick := ticks
	for tick in ticks:
		if executor != null:
			tank.command = executor.tick(SimClock.TICK_SECONDS)
		await lab.step()
		var here := tank.global_position
		metres += Vector2(here.x - last.x, here.z - last.z).length()
		last = here
		if tick % TRAIL_EVERY_TICKS == 0:
			trail.append(here + Vector3.UP * 0.4)
		var v := tank.speed()
		if absf(v) > CUSP_SPEED:
			var g := 1 if v > 0.0 else -1
			if g != gear:
				legs += 1
				gear = g
		for i in tank.get_slide_collision_count():
			var hit := tank.get_slide_collision(i)
			if hit.get_collider() is Tank:
				hull_ticks += 1
			elif absf(hit.get_normal().y) < 0.5:
				wall_ticks += 1
		var motion: Variant = tank.get("_motion")
		if motion is Dictionary and int((motion as Dictionary).get("creep_dir", 0)) != 0:
			creep_ticks += 1
		var off := Vector2(here.x - goal_pos.x, here.z - goal_pos.z).length()
		var err := rad_to_deg(absf(angle_difference(deg_to_rad(_heading_deg(tank)), deg_to_rad(float(goal[2])))))
		if done_s == -1.0 and off <= float(fixture["tol_m"]) + ARRIVE_M and err <= ALIGNED_DEG and absf(v) < CUSP_SPEED:
			done_s = (tick + 1) / float(SimClock.TICK_RATE)
			end_tick = mini(tick + 2 * SimClock.TICK_RATE, ticks - 1)
			shots[end_tick] = "end"
		elif executor != null and (executor.done or executor.aborted) and done_s == -1.0 and absf(v) < CUSP_SPEED:
			# the executor finished short of the pose: still an end frame, two seconds on
			end_tick = mini(tick + 2 * SimClock.TICK_RATE, ticks - 1)
			shots[end_tick] = "end"
			done_s = -2.0  # finished, not at the pose
		if (tick + 1) % SimClock.TICK_RATE == 0:
			print("PLANNER_LAB_T %s %s t %.0f at (%.1f, %.1f) hdg %.0f v %.1f off %.1f err %.0f legs %d%s" % [name, arm, (tick + 1) / float(SimClock.TICK_RATE),
					here.x, here.z, _heading_deg(tank), v, off, err, legs, (" exec leg %d %s" % [executor.leg_index + 1, executor.reason]) if executor != null else ""])
		if shots.has(tick):
			await _capture(name, arm, String(shots[tick]), goal_pos, goal_f, fixture)
		if tick >= end_tick and shots.has(end_tick):
			break
	if not shots.values().has("end"):
		await _capture(name, arm, "end", goal_pos, goal_f, fixture)
	var here := tank.global_position
	var row := {"fixture": name, "arm": arm, "unit": tank.unit_id, "done_s": done_s, "legs": legs, "metres": snappedf(metres, 0.1),
			"wall_contact_ticks": wall_ticks, "hull_contact_ticks": hull_ticks, "creep_ticks": creep_ticks,
			"end_at": [snappedf(here.x, 0.1), snappedf(here.z, 0.1)], "end_hdg": snappedf(_heading_deg(tank), 1.0),
			"end_off_m": snappedf(Vector2(here.x - goal_pos.x, here.z - goal_pos.z).length(), 0.1), "limit_s": seconds}
	if plan != null:
		row["plan"] = {"code": plan.code, "legs": plan.describe(), "n": plan.legs.size(), "metres": snappedf(plan.metres, 0.1),
				"cost_s": snappedf(plan.cost_s, 0.1), "expansions": plan.expansions, "ms": snappedf(plan_ms, 0.1),
				"executor": executor.reason, "legs_driven": executor.legs_driven, "cusps": executor.cusps}
	print("PLANNER_LAB %s" % JSON.stringify(row))


func _capture(name: String, arm: String, stem: String, goal_pos: Vector3, goal_f: Vector2, fixture: Dictionary) -> void:
	var start: Array = fixture["start"]
	var focus := (Vector3(float(start[0]), 0.0, float(start[1])) + goal_pos) * 0.5
	var heading := deg_to_rad(float(fixture.get("camera_heading", 0.0)))
	var back := Vector3(-sin(heading), 0.0, cos(heading)) * DISTANCE_M * cos(deg_to_rad(PITCH_DEG))
	camera.global_position = focus + back + Vector3.UP * DISTANCE_M * sin(deg_to_rad(PITCH_DEG))
	camera.look_at(focus, Vector3.UP)
	_draw(goal_pos, goal_f)
	RenderingServer.render_loop_enabled = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if not movie:
		RenderingServer.render_loop_enabled = false
	var path := "%s/%s_%s_%s.png" % [out_dir, name, arm, stem]
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("PLANNER_LAB_SHOT %s" % path)


func _draw(goal_pos: Vector3, goal_f: Vector2) -> void:
	trail_mesh.clear_surfaces()
	for arm: String in trails:
		var trail: Array = trails[arm]
		if trail.size() < 2:
			continue
		trail_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, materials[arm])
		for point: Vector3 in trail:
			trail_mesh.surface_add_vertex(point)
		trail_mesh.surface_end()
	# The goal pose: a cross and an arrow the way it should face.
	var at := goal_pos + Vector3.UP * 0.4
	var f := Vector3(goal_f.x, 0.0, goal_f.y)
	trail_mesh.surface_begin(Mesh.PRIMITIVE_LINES, materials["goal"])
	for arm: Vector3 in [Vector3(1.5, 0, 1.5), Vector3(1.5, 0, -1.5)]:
		trail_mesh.surface_add_vertex(at - arm)
		trail_mesh.surface_add_vertex(at + arm)
	trail_mesh.surface_add_vertex(at)
	trail_mesh.surface_add_vertex(at + f * 6.0)
	trail_mesh.surface_end()
