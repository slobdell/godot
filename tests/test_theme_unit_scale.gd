extends TestCase
## Feel (round 6; the lead: "Our semi truck for the gang that was supposed to be a huge tank is tiny compared to the
## other vehicles ... Scouts are small, the IFVs are bigger, the tanks bigger than that (everything drawn to scale)").
## hull_size (C1) is the size of a unit; the art must draw it.


func _spawn(unit_id: String) -> Tank:
	var tank: Tank = (load("res://game/tank/tank.tscn") as PackedScene).instantiate()
	tank.unit_id = unit_id
	tank.simulate = false
	add_to_tree(tank)
	return tank


## The drawn hull's length (m) along the tank's -Z, from the visual's meshes in tank space.
func _drawn_length(tank: Tank) -> float:
	var hull: Node = tank.get_node("HullVisual")
	var models := hull.find_children("Model", "Node3D", true, false)
	if not models.is_empty():
		hull = models[0]  # the model only: a shielded unit's shield shell is bigger than its hull
	var result := AABB()
	var first := true
	for child in hull.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null or not instance.is_visible_in_tree() or instance.mesh.get_surface_count() == 0:
			continue
		var box := (tank.global_transform.affine_inverse() * instance.global_transform) * instance.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result.size.z


func test_every_faction_draws_its_units_at_their_hull_size() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	for faction in ["gangs", "law", "syndicate"]:
		var lengths := {}
		for unit_id in Units.roster(faction):
			if not GameTheme.slots.has("unit.%s.hull" % unit_id):
				continue
			var tank := _spawn(unit_id)
			await wait_physics_frames(1)
			var drawn := _drawn_length(tank)
			var wanted := float(Units.stat(unit_id, "hull_size")[2])
			assert_near(drawn, wanted, wanted * 0.05, "%s draws its %.1f m hull (drew %.2f m)" % [unit_id, wanted, drawn])
			lengths[Units.role_of(unit_id)] = drawn
			tank.queue_free()
		if lengths.has("scout") and lengths.has("tank"):
			assert_true(lengths["scout"] < lengths["tank"], "%s: the scout is smaller than the tank %s" % [faction, lengths])
	GameTheme.use(previous)


func test_a_turret_scales_with_its_hull() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var tank := _spawn("gang_tank")  # the semi: its model was 3.6 m of a 5.6 m hull
	await wait_physics_frames(2)
	GameTheme.use(previous)
	var fit := float(Units.stat("gang_tank", "hull_size")[2]) / FactionArt.hull_length("gang_tank")
	for part in tank.get_node("Turret").find_children("Model", "Node3D", true, false):
		var total := (tank.global_transform.affine_inverse() * (part as Node3D).global_transform).basis.get_scale().x
		assert_near(total, fit, 0.01, "the turret part takes the hull's scale (%.2f)" % total)


func test_the_gang_ifv_and_the_syndicate_lancer_face_forward() -> void:
	## Round 7 (the lead, three times: "the gang's IFV drives backwards"); make facing-audit then found the Syndicate
	## lancer the same way round (its approved concept has the nose and the emitter's lens leading).
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	for unit_id in ["gang_ifv", "syn_lancer"]:
		var tank := _spawn(unit_id)
		await wait_physics_frames(1)
		var model := tank.get_node("HullVisual").find_children("Model", "Node3D", true, false)[0] as Node3D
		assert_near(absf(wrapf(model.rotation.y, -PI, PI)), PI, 0.01, "%s's hull model is turned round to face -Z" % unit_id)
		tank.queue_free()
	GameTheme.use(previous)


func test_a_gun_baked_into_its_hull_turns_with_the_turret() -> void:
	## Round 7 (the lead: "the turrets on the gang tanks didn't rotate"): the gang tank's gun was generated as part of its
	## hull, with a nub for a turret part. The gun is cut out of the hull and yaws with the tank's turret.
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var tank := _spawn("gang_tank")
	await wait_physics_frames(2)
	GameTheme.use(previous)
	var pivots := tank.get_node("HullVisual").find_children("GunPivot", "Node3D", true, false)
	assert_eq(pivots.size(), 1, "the hull gave its gun a pivot of its own")
	var gun_meshes := (pivots[0] as Node3D).find_children("Gun", "MeshInstance3D", true, false)
	assert_true(gun_meshes.size() >= 1, "with the gun's triangles in it")
	var turret_models := tank.get_node("Turret").find_children("Model", "Node3D", true, false)
	for model in turret_models:
		assert_true(not (model as Node3D).is_visible_in_tree(), "the stand-in nub is hidden")
	tank.turret.rotation.y = 1.0
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	assert_true(absf(tank.turret.rotation.y) > 0.1, "the turret is turned")
	assert_near((pivots[0] as Node3D).rotation.y, tank.turret.rotation.y, 0.05, "the gun follows the turret's yaw")
