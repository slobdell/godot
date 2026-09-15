extends TestCase
## Feel X4: hits that read. Armor hits spark; weak-spot hits (K2 `weak_spot`) get their own flare and sting; shield hits
## splash on the shield instead of sparking steel; every kill (any weapon, or none) blows the vehicle up and leaves a
## burning wreck site that smokes and cooks off.


func _shot(model: String, id: int, shooter := "") -> Dictionary:
	var weapon: String = {"shell": "cannon", "burst": "autocannon", "stream": "machine_gun", "beam": "laser", "arc": "mortar"}[model]
	var event := K2Events.fired_event(10, shooter, weapon, Weapons.profile(weapon), Vector3(0, 1.3, 0), Vector3.FORWARD, id)
	event["fire_model"] = model
	return event


func _hit(id: int, target: String, weak_spot := false, killed := false, position := Vector3(0, 1.2, -25)) -> Dictionary:
	var event := K2Events.impact_event(12, id, position, Vector3.BACK, target, killed)
	event["weak_spot"] = weak_spot
	event["face"] = "rear" if weak_spot else "front"
	return event


func _match_world() -> Array:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	fx.link.attach(game_match)
	return [fx, game_match]


func test_a_weak_spot_hit_looks_and_sounds_different_from_an_armor_hit() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	for model in ["shell", "burst", "stream"]:
		fx.weapons.fired(_shot(model, 1))
		fx.weapons.impact(_hit(1, "Victim"))
		var armor := fx.weapons.last_pieces
		fx.weapons.fired(_shot(model, 2))
		fx.weapons.impact(_hit(2, "Victim", true))
		assert_true(fx.weapons.last_pieces.has("weak_spot_flare"), "a %s weak-spot hit flares (%s)" % [model, fx.weapons.last_pieces])
		assert_true(fx.weapons.last_pieces.has("sound:weak_spot_hit"), "and stings")
		assert_true(not armor.has("weak_spot_flare"), "a %s armor hit doesn't" % model)


func test_weak_spot_flares_get_through_the_small_round_spark_budget() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	fx.weapons.fired(_shot("stream", 1))
	fx.weapons.impact(_hit(1, "Victim"))
	fx.weapons.fired(_shot("stream", 2))
	fx.weapons.impact(_hit(2, "Victim", true))
	assert_true(fx.weapons.last_pieces.has("weak_spot_flare"), "a weak spot right after an armor hit still flares")


func test_a_shield_hit_splashes_the_shield_instead_of_sparking_steel() -> void:
	var setup := _match_world()
	var fx: FxWorld = setup[0]
	var game_match: Match = setup[1]
	var victim := game_match.spawn_tank("Shielded", 0, Match.Team.RUST, "tank")
	await wait_physics_frames(1)
	var shell: ShieldEffect = null
	for node in victim.get_node("HullVisual").find_children("*", "MeshInstance3D", true, false):
		if node is ShieldEffect:
			shell = node
	if shell == null:  # a theme whose hull has no shield shell of its own
		shell = ShieldEffect.new()
		victim.get_node("HullVisual").add_child(shell)
	victim.shield = 80.0
	victim.sync_shield = 80
	fx.weapons.fired(_shot("burst", 3))
	fx.weapons.impact(_hit(3, "Shielded", false, false, victim.global_position + Vector3(0, 1.2, 2.0)))
	assert_true(fx.weapons.last_pieces.has("shield_splash"), "a hit on a shielded vehicle splashes its shield (%s)" % [fx.weapons.last_pieces])
	assert_true(not fx.weapons.last_pieces.has("armor_sparks"), "no steel sparks while the shield holds")
	assert_true(shell.state()["ripple"] > 0.0, "the shield ripples out from where it was struck")
	victim.shield = 0.0
	victim.sync_shield = 0
	fx.weapons.fired(_shot("burst", 4))
	fx.weapons.impact(_hit(4, "Shielded", false, false, victim.global_position + Vector3(0, 1.2, 2.0)))
	assert_true(fx.weapons.last_pieces.has("armor_sparks"), "with the shield down, rounds spark on the armor")


func test_every_kill_blows_the_vehicle_up_whatever_killed_it() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	for model in ["stream", "beam", "burst"]:
		fx.weapons.fired(_shot(model, 5))
		fx.weapons.impact(_hit(5, "Victim_" + model, false, true))
		assert_true(fx.weapons.last_pieces.has("secondary_blast"), "a %s kill still cooks the vehicle off (%s)" % [model, fx.weapons.last_pieces])


func test_every_unit_destroyed_explodes_once_and_burns_along_its_hull() -> void:
	var setup := _match_world()
	var fx: FxWorld = setup[0]
	var game_match: Match = setup[1]
	var sites := fx.fires.burning_count()
	game_match.unit_destroyed.emit({"tick": 1, "unit": "Burned", "unit_id": "ifv", "team": 0, "killer": "hazard:fire_pit",
			"cause": "hazard", "position": [40.0, 0.0, 0.0], "forward": [1.0, 0.0, 0.0], "hull_size": [2.4, 1.6, 3.8]})
	assert_true(fx.weapons.last_pieces.has("kill_explosion"), "a vehicle that dies in a fire pit explodes (%s)" % [fx.weapons.last_pieces])
	assert_eq(fx.fires.burning_count(), sites + 1, "and leaves a burning wreck site")
	var site: Dictionary = fx.fires.sites[-1]
	assert_near((site["forward"] as Vector3).x, 1.0, 0.01, "the fire follows the wreck's facing")
	assert_near((site["half"] as Vector2).y, 1.9, 0.01, "over the length of its hull")
	fx.weapons.impact(_hit(9, "Shot", false, true, Vector3(-40, 1.2, 0)))
	var events := fx.weapons.events
	game_match.unit_destroyed.emit({"tick": 2, "unit": "Shot", "unit_id": "scout", "team": 1, "killer": "Gunner",
			"cause": "enemy", "position": [-40.0, 0.0, 0.0], "forward": [0.0, 0.0, -1.0], "hull_size": [2.0, 1.4, 3.0]})
	assert_eq(fx.weapons.events, events, "a death its killing hit already blew up doesn't explode twice")


func test_a_wreck_burns_smokes_and_cooks_off_then_goes_out() -> void:
	var bursts: BurstSystem = add_to_tree(BurstSystem.new(256))
	var lights: LightPool = add_to_tree(LightPool.new(4))
	var fires := FireSites.new()
	fires.ignite(Vector3(10, 0, 5), 0.0, bursts)
	for step in 120:
		fires.update(step * 0.1, bursts, lights)
	assert_true(fires.smoke_puffs >= 8, "12 s of burning sends up a smoke column (%d puffs)" % fires.smoke_puffs)
	assert_true(fires.cook_offs >= 2, "and ammunition cooks off now and then (%d pops)" % fires.cook_offs)
	fires.update(FireSites.BURN_SECONDS + 1.0, bursts, lights)
	assert_eq(fires.burning_count(), 0, "then the wreck burns out")
