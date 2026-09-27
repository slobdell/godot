extends TestCase
## Round 12 (fleet F1): THE BURNER IS A FIRE ENGINE. The lead, 2026-09-24, on the fleet page: *"We will want to create a
## different unit type for the burner because it looks identical to the tank"*, then *"To keep things ridiculous this
## should be based off of an actual fire engine."* He approved `burner_r11_b` (the turntable-ladder truck) at 17:27 UTC
## that day; round 12 found it had never been built (orchestration.md lesson 220).
##
## These hold the four things that make it HIS fire engine rather than a prison bus with a new name: it draws its own
## model; its box is that model's proportions at a real fire engine's length (the round-9 rule, never a stretch); the
## flamethrower head turns on its own pedestal; and the fire leaves the nozzle that is drawn.

## How close the turret art's lowest point must sit to the ring it turns on (m): the head is seated, not hovering.
const SEAT_M := 0.25
## How far the flame may start from the drawn nozzle's tip (m).
const FLAME_AT_TIP_M := 0.1


func _spawn(unit_id: String) -> Tank:
	var tank: Tank = (load("res://game/tank/tank.tscn") as PackedScene).instantiate()
	tank.unit_id = unit_id
	tank.simulate = false
	add_to_tree(tank)
	return tank


func _drawn_box(tank: Node3D, node: Node) -> AABB:
	var to_tank := tank.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null or mesh is ShieldEffect or not mesh.is_visible_in_tree():
			continue
		var box := (to_tank * mesh.global_transform) * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _model_scale(node: Node) -> float:
	var model := node.find_child("Model", true, false) as Node3D
	return model.global_basis.get_scale().x if model != null else 0.0


func test_the_burner_draws_its_own_fire_engine() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	for part in ["hull", "turret", "weapon"]:
		assert_true(GameTheme.slots.has("unit.burner.%s" % part), "the burner has its own %s art" % part)
	assert_true(SizeLook.natural_size("burner").z > 0.01, "and its hull measures as a model of its own")
	GameTheme.use(previous)


func test_the_burner_box_is_its_models_proportions_at_a_real_fire_engines_length() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var length := Units.target_length_m("burner")
	var derived := SizeLook.box_at_length("burner", length)
	var box: Array = Units.stat("burner", "hull_size")
	GameTheme.use(previous)
	for axis in 3:
		assert_near(float(box[axis]), float(derived[axis]), 0.011,
				"axis %d: the catalog box is the mesh's own proportion at %.2f m (derived %s)" % [axis, length, derived])
	assert_true(float(box[2]) > 6.89 + 0.3, "a ladder truck is longer than round 11's 6.89 m pumper box (%.2f m)" % box[2])
	var reference: Dictionary = Units.PROFILES["burner"]["scale_reference"]
	assert_true(String(reference["vehicle"]).to_lower().contains("aerial"), "its reference is a ladder truck: %s" % reference)


func test_every_part_is_drawn_at_the_hulls_one_scale() -> void:
	## The round-12 pipeline bug: turret art was placed at a scale the wrapper then undid, so the head floated 1.39 m
	## over its pedestal. Whatever the turret node's scale, the hull, head and nozzle models are drawn at ONE scale.
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var tank := _spawn("burner")
	await wait_physics_frames(2)
	await tree.process_frame
	var hull := _model_scale(tank.get_node("HullVisual"))
	assert_true(hull > 0.0, "the hull model is drawn")
	assert_true(absf(tank.turret.scale.x - 1.0) > 0.1, "and the turret node IS scaled (%.2f), so this can fail" % tank.turret.scale.x)
	for part in ["TurretVisual", "WeaponVisual"]:
		assert_near(_model_scale(tank.find_child(part, true, false)), hull, hull * 0.01,
				"%s's model is drawn at the hull's scale" % part)
	tank.queue_free()
	GameTheme.use(previous)


func test_the_flamethrower_head_turns_on_its_own_pedestal() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var tank := _spawn("burner")
	await wait_physics_frames(2)
	await tree.process_frame
	var mount: Array = Units.PROFILES["burner"]["turret_mount"]
	var head := _drawn_box(tank, tank.find_child("TurretVisual", true, false))
	assert_true(head.size.y > 0.2, "the head is drawn (%s)" % head)
	assert_near(head.position.y, float(mount[1]), SEAT_M,
			"its lowest point sits on the ring at %.2f m, not over it (drawn from %.2f m)" % [mount[1], head.position.y])
	assert_near(tank.turret.position.z, float(mount[2]), 0.001, "the simulated pivot is the ring's")
	var hull := _drawn_box(tank, tank.get_node("HullVisual"))
	assert_true(hull.end.y <= float(mount[1]) + 0.15, "and the ring is the hull's top (roof %.2f m)" % hull.end.y)
	tank.queue_free()
	GameTheme.use(previous)


func test_the_fire_leaves_the_drawn_nozzle() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var tank := _spawn("burner")
	await wait_physics_frames(2)
	await tree.process_frame
	await tree.process_frame
	var weapon := tank.find_child("WeaponVisual", true, false)
	var part: Node3D = null
	for child in weapon.get_children():
		if child.has_method("nozzle_tip"):
			part = child
	assert_true(part != null, "the burner's weapon is the fire engine's nozzle part")
	if part != null:
		var tip: Vector3 = part.global_transform * (part.call("nozzle_tip") as Vector3)
		var fire := part.get("fire") as Node3D
		var start := fire.global_transform * Vector3(0.0, 0.05, -1.8)
		assert_true(tip.distance_to(start) < FLAME_AT_TIP_M,
				"the flame starts at the nozzle's tip (%.2f m away)" % tip.distance_to(start))
		assert_near(fire.global_basis.get_scale().x, 1.0, 0.01, "and burns at the weapon's own length, not the hull's scale")
		var nozzle := _drawn_box(tank, weapon)
		assert_true(nozzle.end.y > 2.5, "the nozzle is up on the turntable (%.2f m), not at the dozer's roof" % nozzle.end.y)
	tank.queue_free()
	GameTheme.use(previous)


func test_the_pipeline_places_turret_art_where_the_tank_draws_it() -> void:
	## `AssetContracts.unit_pivot` is the tank's own pose, read -- not a second formula.
	var pose := Tank.turret_pose(Units.PROFILES["burner"])
	var placement := AssetContracts.unit_pivot("burner")
	assert_eq(placement["pivot"], (pose["pivot"] as Vector3) + Vector3(0.0, float(pose["lift"]), 0.0),
			"the art's anchor is the pivot raised by its lift")
	assert_eq(float(placement["turret_scale"]), 1.0, "at the scale the wrapper draws every part")
