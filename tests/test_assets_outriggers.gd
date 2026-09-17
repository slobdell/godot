extends TestCase
## Assets X5: the crane carrier's four outrigger legs become rigid parts cut from its generated hull, animated by the
## hull slot's `set_deployed(ratio)` (combat's X5 deploy state): 0 = stowed (legs slid in and lifted), 0.5 = slid out,
## 1 = jacks down on the ground, the pose the model was generated in.

const HULL := "res://game/theme/cyberpunk/units/unit_artillery_hull.tscn"


## A 2 × 1 × 4 body with a 0.2 m cube hanging off each corner.
func _toy_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := BoxMesh.new()
	body.size = Vector3(2, 1, 4)
	tool.append_from(body, 0, Transform3D(Basis(), Vector3(0, 0.5, 0)))
	var foot := BoxMesh.new()
	foot.size = Vector3(0.2, 0.2, 0.2)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			tool.append_from(foot, 0, Transform3D(Basis(), Vector3(sx * 1.4, 0.1, sz * 1.5)))
	return tool.commit()


func test_cutting_separates_each_leg_and_keeps_every_triangle() -> void:
	var mesh := _toy_mesh()
	var total := (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	# Boxes in fractions of the whole mesh's bounds (x 0 = -X … 1 = +X, y up, z 0 = -Z … 1 = +Z).
	var boxes: Array[AABB] = [AABB(Vector3(0.0, 0.0, 0.0), Vector3(0.15, 0.5, 1.0)), AABB(Vector3(0.85, 0.0, 0.0), Vector3(0.15, 0.5, 1.0))]
	var cut := OutriggerRig.cut(mesh, boxes)
	var legs: Array = cut["legs"]
	assert_eq(legs.size(), 4, "every box splits front from rear: four legs")
	var count := func(m: ArrayMesh) -> int: return (m.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if m.get_surface_count() > 0 else 0
	var sum: int = count.call(cut["rest"])
	for leg: Dictionary in legs:
		sum += count.call(leg["mesh"])
		assert_eq(count.call(leg["mesh"]), 12, "a leg is its whole cube (%s)" % leg["side"])
	assert_eq(sum, total, "no triangle is lost or doubled")
	var sides := legs.map(func(leg: Dictionary) -> Vector2: return leg["side"])
	for expected in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		assert_true(sides.has(expected), "a leg at %s" % expected)
	assert_true(OutriggerRig.cut(mesh, boxes)["rest"] == cut["rest"], "a mesh is cut once and shared by every vehicle")


func test_the_pose_slides_legs_out_then_lowers_them() -> void:
	var stowed := OutriggerRig.offset(Vector2(1, -1), 0.0)
	var half := OutriggerRig.offset(Vector2(1, -1), 0.5)
	var deployed := OutriggerRig.offset(Vector2(1, -1), 1.0)
	assert_true(stowed.x < -0.2 and stowed.y > 0.2, "stowed: a right-side leg is pulled in and lifted (%s)" % stowed)
	assert_near(half.x, 0.0, 0.001, "halfway: the beam is fully out")
	assert_true(half.y > 0.2, "halfway: the jack is still up")
	assert_true(deployed.is_zero_approx(), "deployed: the generated pose, pads on the ground")
	assert_true(OutriggerRig.offset(Vector2(-1, 1), 0.0).x > 0.2, "a left-side leg pulls in the other way")


func test_the_artillery_hull_drives_its_legs_from_set_deployed() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var hull: Node3D = add_to_tree((load(HULL) as PackedScene).instantiate())
	GameTheme.use(previous)
	var legs := hull.find_children("Outrigger*", "MeshInstance3D", true, false)
	assert_eq(legs.size(), 4, "four outrigger legs cut from the crane carrier")
	var rest: Array = legs.map(func(leg: MeshInstance3D) -> Vector3: return leg.position)
	hull.call("set_deployed", 0.0)
	for i in legs.size():
		var leg := legs[i] as MeshInstance3D
		assert_true(leg.position.y > rest[i].y + 0.2, "stowed legs are lifted off the ground")
		assert_true(absf(leg.position.x) < absf(rest[i].x) or signf(leg.position.x - rest[i].x) != signf(leg.get_meta("side").x),
				"and pulled in toward the chassis")
	hull.call("set_deployed", 1.0)
	for i in legs.size():
		assert_true((legs[i] as MeshInstance3D).position.is_equal_approx(rest[i]), "deployed legs return to the generated pose")
	var skinned: Array = hull.get("skinned")
	for leg in legs:
		assert_true(skinned.has(leg), "legs wear the unit material (team neon, paint) like the rest of the hull")


func test_a_real_battery_lowers_its_legs_as_combat_deploys_it() -> void:
	# Integration with combat's X5 (CP2): Tank calls set_deployed(deploy_ratio) on its hull slot every frame.
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	add_to_tree(preload("res://game/arena/arena.tscn").instantiate())
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	game_match.seed_spawns(2, 0.0)
	var gun := game_match.spawn_tank("Gun", 0, Match.Team.GREEN, "artillery")
	GameTheme.use(previous)
	gun.global_position = Vector3(-100.0, 0.0, 60.0)
	await wait_physics_frames(2)
	var hull := gun.get_node("HullVisual") as VisualSlot
	var legs := hull.visual.find_children("Outrigger*", "MeshInstance3D", true, false) if hull.visual != null else []
	assert_eq(legs.size(), 4, "the spawned battery wears the rigged hull")
	if legs.is_empty():
		return
	# process_frame fires before nodes' _process, and a loaded machine can run several physics ticks in one iteration:
	# wait for whole frames so Tank._process has pushed set_deployed to the visual.
	for i in 3:
		await tree.process_frame
	var packed_y := (legs[0] as MeshInstance3D).position.y
	assert_true(packed_y > 0.2, "a battery that hasn't deployed drives with its legs up (%.2f)" % packed_y)
	var aim := gun.global_position + Vector3(0.0, 0.0, -90.0)
	for tick in roundi(float(Units.stat("artillery", "deploy_seconds")) * SimClock.TICK_RATE) + 10:
		gun.command = TankCommand.new(0.0, 0.0, aim, true)
		await tree.physics_frame
	for i in 3:
		await tree.process_frame
	assert_near(gun.deploy_ratio, 1.0, 0.001, "combat deployed it")
	assert_near((legs[0] as MeshInstance3D).position.y, 0.0, 0.01, "and the jacks are down on the ground")
