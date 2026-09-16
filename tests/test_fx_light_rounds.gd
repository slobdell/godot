extends TestCase
## Feel X3: the IFV's 25 mm bursts and the scout's machine-gun stream. Tracer bursts with rhythm (every round counted:
## its own flash, tracer, and thump), small sparks and ricochets off armor, the stream as a wall of tracers with a
## flickering muzzle light, distinct sounds (thump-thump-thump vs brrrt), cheap enough for many at once.


func _round(model: String, id: int, shooter := "", from := Vector3(0, 1.3, 0), direction := Vector3.FORWARD) -> Dictionary:
	var weapon := "autocannon" if model == "burst" else "machine_gun"
	var event := K2Events.fired_event(10, shooter, weapon, Weapons.profile(weapon), from, direction, id)
	event["fire_model"] = model
	return event


func _hit(id: int, target := "Target", position := Vector3(0, 1.2, -25)) -> Dictionary:
	return K2Events.impact_event(12, id, position, Vector3.BACK, target, false)


func test_every_round_of_a_burst_is_counted() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var thumps := 0
	var flashes := 0
	for i in 4:
		var before := fx.bursts.started
		fx.weapons.fired(_round("burst", i + 1))
		flashes += 1 if fx.bursts.started > before else 0
		thumps += 1 if fx.weapons.last_pieces.has("sound:autocannon_shot") else 0
	assert_eq(flashes, 4, "four rounds, four muzzle flashes")
	assert_eq(thumps, 4, "four rounds, four thumps you can count")


func test_the_stream_is_a_wall_of_tracers_without_nodes() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var pool: LightPool = fx.lights
	var nodes := fx.tracers.get_child_count()
	for i in 12:
		fx.tracers.shoot(Vector3(i * 0.1, 1.2, 0), Vector3(i * 0.1, 1.2, -40), Color.CYAN, "stream", fx.now)
	fx.tracers.update(pool, fx.now + 0.05)
	assert_eq(fx.tracers.active_count(), 12, "a dozen rounds in the air draw a dozen tracers")
	assert_eq(fx.tracers.get_child_count(), nodes, "rounds are MultiMesh instances, not nodes")
	fx.tracers.update(pool, fx.now + 1.0)
	assert_eq(fx.tracers.active_count(), 0, "every round is gone once it reaches its end")


func test_a_hitscan_round_flies_to_where_it_hit() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	fx.tracers.shoot(Vector3(0, 1.2, 0), Vector3(0, 1.2, -20), Color.CYAN, "stream", 0.0)
	var head := fx.tracers.round_head(0, 0.02)
	assert_true(head.z < -1.0 and head.z > -20.0, "20 ms in, the round is on its way (%s)" % head)
	assert_near(fx.tracers.round_head(0, 0.5).z, -20.0, 0.001, "and it stops where it hit, not beyond")


func test_live_k2_hitscan_rounds_end_at_their_impact_or_at_range() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var weapon: Dictionary = Weapons.profile("machine_gun")
	fx.weapons.fired(_round("stream", 50))
	fx.weapons.impact(_hit(50, "", Vector3(0, 1.2, -18)))  # a wall: no ricochet to confuse the count
	fx.weapons.flush(fx.now)
	assert_eq(fx.tracers.active_count_at(fx.now + 0.01), 1, "the round that struck the wall draws one tracer")
	assert_near(fx.tracers.round_end(fx.tracers.newest_round()).z, -18.0, 0.01, "ending at the impact")
	fx.weapons.fired(_round("stream", 51))
	fx.weapons.flush(fx.now)
	assert_near(fx.tracers.round_end(fx.tracers.newest_round()).z, -float(weapon["range"]), 0.5, "a round that hit nothing flies its full range")


func test_small_rounds_spark_off_armor_and_sometimes_ricochet_within_a_budget() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var sparks := 0
	var ricochets := 0
	var before := fx.bursts.started
	for i in 40:
		fx.weapons.fired(_round("stream", 100 + i))
		fx.weapons.impact(_hit(100 + i))
		sparks += 1 if fx.weapons.last_pieces.has("armor_sparks") else 0
		ricochets += 1 if fx.weapons.last_pieces.has("ricochet") else 0
	assert_true(sparks >= 1, "bullets on armor spark")
	assert_true(ricochets >= 1 and ricochets < 20, "some rounds ricochet, not all (%d of 40)" % ricochets)
	assert_true(fx.bursts.started - before < 40 * 3, "a 40-round stream on one hull stays inside a small effect budget (%d pieces)" % (fx.bursts.started - before))


func test_the_machine_gun_is_a_loop_per_gunner_not_a_click_per_round() -> void:
	var setup := _match_world()
	var fx: FxWorld = setup[0]
	var game_match: Match = setup[1]
	var gunners: Array[Tank] = []
	for i in 6:
		gunners.append(game_match.spawn_tank("Gunner%d" % i, 0, Match.Team.GREEN, "scout"))
	await wait_physics_frames(1)
	var played := fx.sfx.played
	for round_index in 30:
		fx.weapons.fired(_round("stream", 200 + round_index, "Gunner0"))
	fx.gunfire.update(Vector3.ZERO, fx.now)
	assert_eq(fx.gunfire.active_count(), 1, "one scout streaming holds one loop voice")
	assert_true(fx.sfx.played - played < 5, "30 rounds don't start 30 one-shot sounds (%d)" % (fx.sfx.played - played))
	for gunner in gunners:
		fx.weapons.fired(_round("stream", 300, String(gunner.name)))
	fx.gunfire.update(Vector3.ZERO, fx.now)
	assert_eq(fx.gunfire.active_count(), GunfireLoops.VOICES, "six gunners share the %d loop voices" % GunfireLoops.VOICES)
	fx.gunfire.update(Vector3.ZERO, fx.now + 1.0)
	assert_eq(fx.gunfire.active_count(), 0, "when the shooting stops, the brrrt stops")


func test_burst_and_stream_tracers_have_their_own_rhythm_and_look() -> void:
	var burst: Dictionary = TracerSystem.STYLES["burst"]
	var stream: Dictionary = TracerSystem.STYLES["stream"]
	assert_true(float(burst["width"]) > float(stream["width"]), "a 25 mm tracer is fatter than a machine-gun tracer")
	assert_true(float(WeaponFx.FAMILIES["burst"]["flash_size"]) > float(WeaponFx.FAMILIES["stream"]["flash_size"]),
			"and flashes bigger at the muzzle")


func _match_world() -> Array:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	fx.link.attach(game_match)
	return [fx, game_match]


func test_a_real_scout_s_rounds_fly_to_where_the_rules_say_they_hit() -> void:
	var setup := _match_world()
	var fx: FxWorld = setup[0]
	var game_match: Match = setup[1]
	game_match.elimination = true
	var scout := game_match.spawn_tank("Scout", 0, Match.Team.GREEN, "scout")
	var victim := game_match.spawn_tank("Victim", 0, Match.Team.RUST, "ifv")
	await wait_physics_frames(1)
	scout.global_position = Vector3(0, 0, 0)
	scout.rotation.y = 0.0
	victim.global_position = Vector3(0, 0, -20)
	await wait_physics_frames(2)
	game_match.seed_spawns(4, 0.0)  # the MG's spread is seeded (trip-up 38)
	var muzzle := scout.muzzle_position()
	var at_victim := Vector3(victim.global_position.x, muzzle.y, victim.global_position.z) - muzzle
	scout.fired.emit(muzzle, at_victim.normalized())
	assert_eq(fx.weapons.last_family, "stream", "the rules' impact on the IFV uses the stream family")
	fx.weapons.flush(fx.now)
	var end := fx.tracers.round_end(fx.tracers.newest_round())
	assert_true(end.z > -21.5 and end.z < -17.0, "the tracer ends on the IFV the rules hit, not at full range (%s)" % end)
