extends TestCase
## Round 37 (feedback, C37.6): FeedbackReader reads the four facts the player is shown -- a hit's face, a pinned crew, a
## Tanker mending, an Emitter's cone -- exactly as the rules decide them, and writes nothing.


func _match() -> Match:
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	game_match.elimination = true
	return game_match


## Away from both bases (the home base mends faster than a Tanker, so the Tanker would not be the one mending).
const FIELD := Vector3(60.0, 0.0, 0.0)


func test_a_hit_reads_as_its_face_and_the_engine_deck_as_its_own() -> void:
	assert_eq(FeedbackReader.hit_kind({"target": "A", "face": "front", "weak_spot": false}), "front", "front")
	assert_eq(FeedbackReader.hit_kind({"target": "A", "face": "side", "weak_spot": false}), "side", "a flank hit")
	assert_eq(FeedbackReader.hit_kind({"target": "A", "face": "rear", "weak_spot": false}), "rear", "a rear hit")
	assert_eq(FeedbackReader.hit_kind({"target": "A", "face": "rear", "weak_spot": true}), "deck",
			"the engine deck is its own kind, whatever the face")
	assert_eq(FeedbackReader.hit_kind({"face": "rear", "weak_spot": false}), "", "a round into a wall hit no vehicle")
	assert_eq(FeedbackReader.hit_kind({"target": "A"}), "front", "a hit with no face reads as front, never as a flank")


func test_a_stray_round_does_not_pin_and_real_fire_pins_fully() -> void:
	assert_eq(FeedbackReader.pinned_level(0.0), 0.0, "untouched")
	assert_eq(FeedbackReader.pinned_level(FeedbackReader.PIN_SHOW), 0.0, "a stray burst shows nothing")
	assert_true(FeedbackReader.pinned_level(0.5) > 0.0 and FeedbackReader.pinned_level(0.5) < 1.0, "half pinned in between")
	assert_eq(FeedbackReader.pinned_level(FeedbackReader.PIN_FULL), 1.0, "pinned hard")
	assert_eq(FeedbackReader.pinned_level(1.0), 1.0, "capped")
	assert_true(FeedbackReader.pinned_level(0.6) > FeedbackReader.pinned_level(0.4), "more fire, more pinned")


func test_slowed_is_zero_until_the_rules_slow_a_pinned_crew() -> void:
	var tank := Node.new()
	assert_eq(FeedbackReader.slowed(tank), 0.0, "no pin_slow() yet (rules' R3): nothing is slowed")
	tank.free()


func test_a_tanker_mends_a_quiet_hurt_friend_in_its_radius_at_its_rate() -> void:
	var game_match := _match()
	var tanker := game_match.spawn_tank("Tanker", 0, Match.Team.GREEN, "gang_support")
	var patient := game_match.spawn_tank("Patient", 1, Match.Team.GREEN, "gang_tank")
	tanker.global_position = FIELD
	patient.global_position = FIELD + Vector3(10.0, 0.0, 0.0)
	patient.health = patient.max_health / 2
	patient.ticks_since_hit = 1_000_000
	var menders := FeedbackReader.menders([tanker, patient])
	assert_eq(menders.size(), 1, "only the Tanker mends")
	var link := FeedbackReader.mending(patient, menders)
	assert_eq(link.get("node"), tanker, "the Tanker is the one mending it")
	assert_eq(float(link.get("rate", 0.0)), float(Units.stat("gang_support", "repair_hp_per_second")), "at the catalogue's rate")
	assert_eq(game_match.repair_rate_for(patient, menders), float(link["rate"]), "the rate the rules give it")


func test_nothing_is_drawn_mending_what_the_rules_do_not_mend() -> void:
	var game_match := _match()
	var tanker := game_match.spawn_tank("Tanker", 0, Match.Team.GREEN, "gang_support")
	var patient := game_match.spawn_tank("Patient", 1, Match.Team.GREEN, "gang_tank")
	var enemy := game_match.spawn_tank("Enemy", 0, Match.Team.RUST, "gang_tank")
	tanker.global_position = FIELD
	patient.global_position = FIELD + Vector3(10.0, 0.0, 0.0)
	enemy.global_position = FIELD + Vector3(-10.0, 0.0, 0.0)
	for tank in [patient, enemy]:
		tank.health = tank.max_health / 2
		tank.ticks_since_hit = 1_000_000
	var menders := FeedbackReader.menders([tanker, patient, enemy])
	assert_true(FeedbackReader.mending(enemy, menders).is_empty(), "never the enemy's")
	patient.ticks_since_hit = 10
	var was := Match.repair_under_fire_on
	Match.repair_under_fire_on = false
	assert_true(FeedbackReader.mending(patient, menders).is_empty(), "without round 38's rule: not while it is still being hit")
	Match.repair_under_fire_on = true
	assert_true(bool(FeedbackReader.mending(patient, menders).get("under_fire", false)), "with it (F3): the slower beam")
	Match.repair_under_fire_on = was
	patient.ticks_since_hit = 1_000_000
	patient.global_position = FIELD + Vector3(30.0, 0.0, 0.0)
	assert_true(FeedbackReader.mending(patient, menders).is_empty(), "not out of the Tanker's 18 m")
	patient.global_position = FIELD + Vector3(10.0, 0.0, 0.0)
	patient.health = patient.max_health
	assert_true(FeedbackReader.mending(patient, menders).is_empty(), "not at full health")
	patient.health = patient.max_health / 2
	tanker.global_position = Match.resupply_center(Match.Team.GREEN)
	patient.global_position = tanker.global_position + Vector3(5.0, 0.0, 0.0)
	assert_true(FeedbackReader.mending(patient, FeedbackReader.menders([tanker])).is_empty(),
			"inside its own base the base mends faster: the Tanker is not the one doing it")


func test_a_sound_cone_blows_while_its_puffs_arrive_and_the_flame_is_not_one() -> void:
	var reader := FeedbackReader.new()
	reader.fired({"shooter": "Emitter", "weapon": "sonic_emitter", "muzzle": [0.0, 1.0, 0.0], "direction": [0.0, 0.0, -1.0]}, 1.0)
	reader.fired({"shooter": "Burner", "weapon": "flamethrower", "muzzle": [5.0, 1.0, 0.0], "direction": [0.0, 0.0, -1.0]}, 1.0)
	var cones := reader.active_cones(1.1)
	assert_eq(cones.size(), 1, "only the sound weapon is drawn as a sound cone")
	assert_eq(String(cones[0]["shooter"]), "Emitter", "the Emitter's")
	assert_eq(float(cones[0]["range"]), float(Weapons.profile("sonic_emitter")["range"]), "the cone's reach is the weapon's")
	assert_eq(float(cones[0]["cone_deg"]), float(Weapons.profile("sonic_emitter")["cone_deg"]), "and its width")
	assert_eq(reader.active_cones(1.0 + FeedbackReader.CONE_HOLD_S + 0.05).size(), 0, "quiet once the puffs stop")
