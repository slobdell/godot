extends TestCase
## Feel X1: effects are driven by K2 weapon events (`Match.weapon_fired`, `Match.projectile_impact`), one effect family
## per fire_model, pooled. Until combat's CP2 lands, a stub adapter turns today's Tank.fired signals and Impact hits into
## the same event shapes, so the effects are built once against the contract.


func _fired(fire_model: String, weapon := "cannon", projectile_id := 1) -> Dictionary:
	return {"tick": 10, "shooter": "", "weapon": weapon, "fire_model": fire_model, "muzzle": [0.0, 1.3, 0.0],
			"direction": [0.0, 0.0, -1.0], "projectile_id": projectile_id}


func _impact(projectile_id := 1, killed := false, target: Variant = null, weak_spot := false) -> Dictionary:
	var event := {"tick": 20, "projectile_id": projectile_id, "position": [0.0, 1.0, -30.0], "normal": [0.0, 0.0, 1.0],
			"weak_spot": weak_spot, "damage": 40.0, "killed": killed}
	if target != null:
		event["target"] = target
		event["face"] = "rear" if weak_spot else "front"
	return event


func test_todays_weapons_map_to_k2_fire_models() -> void:
	assert_eq(K2Events.fire_model(Weapons.profile("cannon")), "shell", "the tank cannon fires shells")
	assert_eq(K2Events.fire_model(Weapons.profile("autocannon")), "burst", "the IFV's autocannon fires bursts")
	assert_eq(K2Events.fire_model(Weapons.profile("machine_gun")), "stream", "the scout's machine gun is a stream")
	assert_eq(K2Events.fire_model(Weapons.profile("laser")), "beam", "the Lancer's laser is a beam")
	assert_eq(K2Events.fire_model(Weapons.profile("mortar")), "arc", "the mortar lobs arcs")
	assert_eq(K2Events.fire_model({"fire_model": "stream", "kind": Weapons.Kind.PROJECTILE}), "stream",
			"a v3 profile's own fire_model wins over the stub mapping")
	assert_eq(K2Events.to_vector([1.0, 2.0, 3.0]), Vector3(1, 2, 3), "K2 positions arrive as [x, y, z] arrays")
	assert_eq(K2Events.to_vector(Vector3(4, 5, 6)), Vector3(4, 5, 6), "and vectors pass through")


func test_every_fire_model_has_its_own_effect_family() -> void:
	var sounds := {}
	for model in K2Events.FIRE_MODELS:
		assert_true(WeaponFx.FAMILIES.has(model), "fire model %s has an effect family" % model)
		sounds[String(WeaponFx.FAMILIES[model]["fire_sound"])] = model
	assert_eq(sounds.size(), K2Events.FIRE_MODELS.size(), "each family sounds different when it fires")


func test_a_fired_event_starts_its_familys_muzzle_effects_from_the_pools() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var before := fx.bursts.started
	fx.weapons.fired(_fired("shell"))
	assert_true(fx.bursts.started > before, "a tank shot starts pooled bursts")
	assert_true(fx.weapons.last_pieces.has("muzzle_fireball"), "a tank shot gets the heavy muzzle blast (%s)" % [fx.weapons.last_pieces])
	fx.weapons.fired(_fired("stream", "machine_gun", 2))
	assert_true(not fx.weapons.last_pieces.has("muzzle_fireball"), "a machine-gun round gets a light flash, not the tank's blast")


func test_an_impact_uses_the_family_of_the_projectile_that_caused_it() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	fx.weapons.fired(_fired("shell", "cannon", 7))
	fx.weapons.fired(_fired("stream", "machine_gun", 8))
	fx.weapons.impact(_impact(8))
	var stream_pieces := fx.weapons.last_pieces
	fx.weapons.impact(_impact(7))
	assert_true(fx.weapons.last_pieces != stream_pieces, "a shell and a bullet landing at the same spot look different")
	assert_eq(fx.weapons.last_family, "shell", "impact 7 was the tank shell's")


func test_the_link_listens_to_real_k2_signals_when_the_match_has_them() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var fake_match: Node = add_to_tree(Node.new())
	fake_match.add_user_signal("weapon_fired", [{"name": "event", "type": TYPE_DICTIONARY}])
	fake_match.add_user_signal("projectile_impact", [{"name": "event", "type": TYPE_DICTIONARY}])
	fx.link.attach(fake_match)
	assert_true(fx.link.live, "a match with K2 signals is used live, not stubbed")
	var before := fx.weapons.events
	fake_match.emit_signal("weapon_fired", _fired("burst", "autocannon", 3))
	fake_match.emit_signal("projectile_impact", _impact(3))
	assert_eq(fx.weapons.events, before + 2, "both K2 signals reach the effect families")


func test_a_real_match_s_shots_reach_the_effects_live() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	game_match.elimination = true
	fx.link.attach(game_match)
	assert_true(fx.link.live, "combat's Match emits K2: the effects follow it live")
	var tank := game_match.spawn_tank("Gunner", 0, Match.Team.GREEN, "ifv")
	await wait_physics_frames(1)
	var before := fx.weapons.events
	tank.fired.emit(tank.muzzle_position(), tank.turret_forward())
	assert_true(fx.weapons.events > before, "the rules' weapon_fired reaches the effect families")
	assert_eq(fx.weapons.last_family, "burst", "the IFV's round uses the burst family")


func test_a_match_that_does_not_simulate_is_not_live() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	game_match.simulate = false
	fx.link.attach(game_match)
	assert_true(not fx.link.live, "a networked client gets no events, so it keeps the legacy effects")


func test_a_long_firefight_adds_no_nodes() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	fx.weapons.fired(_fired("shell", "cannon", 1))
	fx.weapons.impact(_impact(1, true, "Victim"))
	var nodes := _count_nodes(fx)
	for i in 300:
		var model: String = K2Events.FIRE_MODELS[i % K2Events.FIRE_MODELS.size()]
		fx.weapons.fired(_fired(model, "cannon", 100 + i))
		fx.weapons.impact(_impact(100 + i, i % 7 == 0, "Victim" if i % 2 == 0 else null, i % 5 == 0))
	assert_eq(_count_nodes(fx), nodes, "300 shots and hits allocate no effect nodes (everything is pooled)")
	assert_true(fx.weapons.tracked_projectiles() <= WeaponFx.MAX_TRACKED, "projectile bookkeeping stays bounded")


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


func test_every_sound_the_effects_ask_for_is_a_loaded_sound() -> void:
	var names := {GunfireLoops.SOUND: true}
	for family: Dictionary in WeaponFx.FAMILIES.values():
		for key in ["fire_sound", "hit_sound", "miss_sound"]:
			if String(family.get(key, "")) != "":
				names[String(family[key])] = true
	var regex := RegEx.create_from_string('_sound\\("([a-z_]+)"')
	for script_path in ["res://game/theme/fx/weapon_fx.gd", "res://game/theme/fx/fire_sites.gd"]:
		for found in regex.search_all(FileAccess.get_file_as_string(script_path)):
			names[found.get_string(1)] = true
	for sound in names:
		assert_true(SfxSystem.SOUNDS.has(sound), "the effects play %s, and SfxSystem loads it" % sound)


func test_flamethrower_puffs_reported_as_stream_events_draw_no_machine_gun_rounds() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var before := fx.weapons.events
	fx.weapons.fired({"tick": 1, "shooter": "", "weapon": "flamethrower", "fire_model": "stream", "muzzle": [0.0, 1.0, 0.0],
			"direction": [0.0, 0.0, -1.0], "projectile_id": 5, "speed_mps": 0.0, "range": 20.0})
	assert_eq(fx.weapons.events, before, "a flame puff is the flame slot's to draw")
	fx.weapons.fired({"tick": 1, "shooter": "", "weapon": "machine_gun", "fire_model": "stream", "muzzle": [0.0, 1.0, 0.0],
			"direction": [0.0, 0.0, -1.0], "projectile_id": 6, "speed_mps": 0.0, "range": 33.0})
	fx.weapons.flush(fx.now)
	assert_near(fx.tracers.round_end(fx.tracers.newest_round()).z, -33.0, 0.5, "a K2 event's own range wins over the profile's")


func test_re_attaching_a_match_on_its_way_out_never_double_connects() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	fx.link.attach(game_match)
	game_match.queue_free()  # a scene change: the match lingers until the end of the frame
	fx.link.attach(game_match)  # the engine logs "already connected" (a test failure) if the old connections stayed
	assert_eq(game_match.get_signal_connection_list("weapon_fired").size(), 1, "one connection, not two")
