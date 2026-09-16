extends TestCase
## Feel X2: the tank shell. A deep muzzle blast (flash, smoke ring, dust kicked up, the tank rocking back), a glowing
## shell that lights the ground under it, and an impact that sells devastation (shockwave, sparks, debris, scorch,
## distance-scaled shake), heavier for a kill; a miss throws dirt; a boom with a tail, a whine for a near miss.


func _shot(id: int, shooter := "", from := Vector3(0, 1.3, 0), direction := Vector3.FORWARD) -> Dictionary:
	return K2Events.fired_event(10, shooter, "cannon", Weapons.profile("cannon"), from, direction, id)


func _landing(id: int, position: Vector3, target := "", killed := false) -> Dictionary:
	return K2Events.impact_event(40, id, position, Vector3.BACK, target, killed)


func _world_with_match() -> Array:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	fx.link.attach(game_match)
	return [fx, game_match]


func test_a_tank_shot_is_a_deep_muzzle_blast() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var before := fx.bursts.started
	fx.weapons.fired(_shot(1))
	for piece in ["muzzle_fireball", "smoke_ring", "dust_kick", "sound:tank_boom"]:
		assert_true(fx.weapons.last_pieces.has(piece), "a tank shot has %s (%s)" % [piece, fx.weapons.last_pieces])
	assert_true(fx.bursts.started - before >= 12, "the blast is many pooled pieces, not one flash (%d)" % (fx.bursts.started - before))


func test_the_shooter_rocks_back_then_settles_without_touching_the_simulation() -> void:
	var setup := _world_with_match()
	var fx: FxWorld = setup[0]
	var game_match: Match = setup[1]
	var tank := game_match.spawn_tank("Rocker", 0, Match.Team.GREEN, "tank")
	await wait_physics_frames(1)
	var hull := tank.get_node("HullVisual") as Node3D
	var base := hull.transform
	var body := tank.global_transform
	var turret_yaw := tank.turret.rotation.y
	tank.fired.emit(tank.muzzle_position(), tank.turret_forward())
	assert_true(fx.weapons.last_pieces.has("recoil"), "the shooter is found and rocked (%s)" % [fx.weapons.last_pieces])
	fx.jolts.update(fx.now + 0.08)
	var pitched := hull.transform.basis.get_euler().x
	assert_true(pitched > 0.02, "80 ms after firing forward the nose has lifted (%.3f rad)" % pitched)
	assert_eq(tank.global_transform, body, "the tank body itself never moves (visual only)")
	assert_eq(tank.turret.rotation.y, turret_yaw, "the simulated turret yaw is untouched")
	fx.jolts.update(fx.now + 3.0)
	assert_eq(hull.transform, base, "after the rock settles the hull art is exactly where it was")
	assert_eq(fx.jolts.active_count(), 0, "a settled vehicle costs nothing per frame")


func test_a_tank_shell_glows_brighter_and_lights_more_ground_than_bullets() -> void:
	var shell: Dictionary = TracerSystem.STYLES["shell"]
	for small in ["burst", "stream"]:
		var other: Dictionary = TracerSystem.STYLES[small]
		assert_true(float(shell["width"]) > float(other["width"]) * 2.0, "a shell's tracer is much fatter than a %s's" % small)
		assert_true(float(shell["splat_length"]) > float(other["splat_length"]), "and lights a longer patch of ground than a %s" % small)
	assert_true(float(shell["priority"]) > LightPool.PRIORITY_MUZZLE, "a shell in flight wins a real light over muzzle flashes")


func test_a_shell_hit_sells_devastation() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	fx.weapons.fired(_shot(2))
	var trauma := fx.shake.trauma
	fx.weapons.impact(_landing(2, Vector3(0, 1.2, -30), "Victim"))
	for piece in ["shockwave", "sparks", "debris", "smoke", "sound:shell_hit_armor"]:
		assert_true(fx.weapons.last_pieces.has(piece), "a shell hit has %s (%s)" % [piece, fx.weapons.last_pieces])
	assert_true(fx.shake.trauma > trauma, "a shell hit shakes the camera")


func test_a_kill_is_heavier_than_a_hit() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	fx.weapons.fired(_shot(3))
	fx.shake.trauma = 0.0
	var before := fx.bursts.started
	fx.weapons.impact(_landing(3, Vector3(0, 1.2, -30), "Victim"))
	var hit_pieces := fx.bursts.started - before
	var hit_shake := fx.shake.trauma
	fx.weapons.fired(_shot(4))
	fx.shake.trauma = 0.0
	before = fx.bursts.started
	var scorches := fx.decals.started
	fx.weapons.impact(_landing(4, Vector3(0, 1.2, -30), "Victim", true))
	assert_true(fx.bursts.started - before > hit_pieces, "a kill throws more pieces than a hit (%d vs %d)" % [fx.bursts.started - before, hit_pieces])
	assert_true(fx.shake.trauma > hit_shake, "a kill shakes harder than a hit (%.2f vs %.2f)" % [fx.shake.trauma, hit_shake])
	assert_true(fx.weapons.last_pieces.has("secondary_blast"), "a kill cooks off a second blast")
	assert_true(fx.decals.started > scorches, "a kill leaves a scorch mark in the long-lived decal pool")


func test_a_miss_throws_dirt_and_leaves_a_small_scorch() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	fx.weapons.fired(_shot(5))
	fx.weapons.impact(_landing(5, Vector3(0, 0.2, -60)))
	for piece in ["dirt_spray", "dust_cloud", "scorch", "sound:dirt_impact"]:
		assert_true(fx.weapons.last_pieces.has(piece), "a miss has %s (%s)" % [piece, fx.weapons.last_pieces])
	assert_true(not fx.weapons.last_pieces.has("sparks"), "dirt doesn't spark like armor")


func test_scorch_marks_outlive_a_firefight_of_small_effects() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	fx.weapons.fired(_shot(6))
	fx.weapons.impact(_landing(6, Vector3(0, 0.2, -60)))
	var scorches := fx.decals.started
	for i in 500:
		fx.bursts.spawn(BurstSystem.Kind.STAR, Vector3.ZERO, 1.0, 0.05, Color.WHITE, fx.now)
	assert_eq(fx.decals.started, scorches, "sparks and flashes never recycle the scorch pool")


func test_a_shell_passing_close_to_a_vehicle_whines() -> void:
	var setup := _world_with_match()
	var fx: FxWorld = setup[0]
	var game_match: Match = setup[1]
	var shooter := game_match.spawn_tank("Gunner", 0, Match.Team.GREEN, "tank")
	var bystander := game_match.spawn_tank("Bystander", 0, Match.Team.RUST, "tank")
	await wait_physics_frames(1)
	shooter.global_position = Vector3(0, 0, 0)
	bystander.global_position = Vector3(4, 0, -30)
	fx.weapons.fired(_shot(7, "Gunner"))
	fx.weapons.impact(_landing(7, Vector3(0, 1.3, -70)))
	assert_true(fx.weapons.last_pieces.has("sound:shell_whine"), "a shell missing a vehicle by 4 m whines past it (%s)" % [fx.weapons.last_pieces])
	fx.weapons.fired(_shot(8, "Gunner", Vector3(60, 1.3, 0)))
	fx.weapons.impact(_landing(8, Vector3(60, 1.3, -70)))
	assert_true(not fx.weapons.last_pieces.has("sound:shell_whine"), "a shell far from everyone lands without a whine")


func test_the_hit_shake_falls_off_with_distance_from_the_view() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var camera: Camera3D = add_to_tree(Camera3D.new())
	camera.position = Vector3(0, 40, 30)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	fx.weapons.fired(_shot(9))
	fx.shake.trauma = 0.0
	fx.weapons.impact(_landing(9, Vector3(0, 1, 0), "Near", true))
	var near := fx.shake.trauma
	fx.weapons.fired(_shot(10))
	fx.shake.trauma = 0.0
	fx.weapons.impact(_landing(10, Vector3(0, 1, -110), "Far", true))
	assert_true(near > 0.3, "a kill in the middle of the view jolts it (%.2f)" % near)
	assert_true(fx.shake.trauma < near * 0.5, "a kill far from the view barely shakes it (%.2f vs %.2f)" % [fx.shake.trauma, near])


func test_a_shell_that_flies_out_of_range_still_lands_in_the_dirt() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var before := fx.decals.started
	fx.weapons.fizzle(Vector3(0, 1.3, -75), Vector3.FORWARD, "shell", Vector3(0, 1.3, 0), "Gunner")
	assert_true(fx.weapons.last_pieces.has("dirt_spray"), "a round-2 shell expiring in mid-air drops into the dirt (%s)" % [fx.weapons.last_pieces])
	assert_true(fx.decals.started > before, "and leaves a mark")
