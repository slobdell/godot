extends TestCase
## Round 38 (feedback F3, C38.4; his answer 2026-10-22, "yes it also repair during combat"): the Resupply Tanker keeps mending a
## friend under fire at half its rate (2.5 hp/s), full after Match.REPAIR_QUIET_SECONDS as before, behind `--repair-under-fire`.
## Real match ticks: the rule is Match._resupply's.

## Away from both bases (the home base mends faster than a Tanker).
const FIELD := Vector3(60.0, 0.0, 0.0)
const TICKS := 60


func teardown() -> void:
	Match.repair_under_fire_on = Match._repair_under_fire_flag()
	super()


func _pair() -> Array:
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	game_match.elimination = true
	var tanker := game_match.spawn_tank("Tanker", 0, Match.Team.GREEN, "gang_support")
	var patient := game_match.spawn_tank("Patient", 1, Match.Team.GREEN, "gang_tank")
	tanker.global_position = FIELD
	patient.global_position = FIELD + Vector3(10.0, 0.0, 0.0)
	patient.health = patient.max_health / 2
	tanker.health = tanker.max_health / 2
	return [game_match, tanker, patient]


## Mended hp over TICKS ticks, with both kept under fire (`shot`) or left quiet.
func _mend(shot: bool) -> Array:
	var setup: Array = _pair()
	var game_match: Match = setup[0]
	var tanker: Tank = setup[1]
	var patient: Tank = setup[2]
	var before := [patient.health, tanker.health]
	for tank: Tank in [patient, tanker]:
		tank.ticks_since_hit = 0 if shot else 1_000_000
	for i in TICKS:
		if shot:
			patient.ticks_since_hit = 0
			tanker.ticks_since_hit = 0
		await wait_physics_frames(1)
	return [patient.health - before[0], tanker.health - before[1], game_match]


func test_off_a_friend_under_fire_is_not_mended() -> void:
	Match.repair_under_fire_on = false
	var got: Array = await _mend(true)
	assert_eq(got[0], 0, "today's rule: nothing under fire")


func test_on_a_friend_under_fire_mends_at_half_rate() -> void:
	Match.repair_under_fire_on = true
	var got: Array = await _mend(true)
	var expected := float(Units.stat("gang_support", "repair_hp_per_second")) * Match.REPAIR_UNDER_FIRE_FACTOR * TICKS / SimClock.TICK_RATE
	assert_near(float(got[0]), expected, 1.01, "about 2.5 hp/s under fire")
	assert_eq(got[1], 0, "the Tanker does not mend ITSELF while it is shot")
	var game_match: Match = got[2]
	assert_eq(int(game_match.stats["hp_mended_under_fire"][Match.Team.GREEN]), int(got[0]), "counted as under fire")


func test_on_quiet_is_still_full_rate() -> void:
	Match.repair_under_fire_on = true
	var got: Array = await _mend(false)
	var expected := float(Units.stat("gang_support", "repair_hp_per_second")) * TICKS / SimClock.TICK_RATE
	assert_near(float(got[0]), expected, 1.01, "5 hp/s once quiet, as today")
	var game_match: Match = got[2]
	assert_eq(int(game_match.stats["hp_mended_under_fire"][Match.Team.GREEN]), 0, "nothing under fire")
	assert_true(int(game_match.stats["hp_mended"][Match.Team.GREEN]) >= int(got[0]), "all mending counted")


func test_on_the_base_still_waits_for_quiet() -> void:
	Match.repair_under_fire_on = true
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	game_match.elimination = true
	var tank := game_match.spawn_tank("Home", 0, Match.Team.GREEN, "gang_tank")
	tank.global_position = Match.resupply_center(Match.Team.GREEN)
	tank.health = tank.max_health / 2
	var before := tank.health
	for i in TICKS:
		tank.ticks_since_hit = 0
		await wait_physics_frames(1)
	assert_eq(tank.health - before, 0, "no field mender, no mending under fire")
	assert_eq(game_match.repair_under_fire_rate_for(tank, game_match._field_menders()), 0.0, "the base is not a field mender")


func test_the_beam_reads_the_same_rule() -> void:
	var setup: Array = _pair()
	var tanker: Tank = setup[1]
	var patient: Tank = setup[2]
	patient.ticks_since_hit = 0
	tanker.ticks_since_hit = 0
	var menders := FeedbackReader.menders([tanker, patient])
	Match.repair_under_fire_on = false
	assert_true(FeedbackReader.mending(patient, menders).is_empty(), "off: no beam under fire, as the rules")
	Match.repair_under_fire_on = true
	var link := FeedbackReader.mending(patient, menders)
	assert_eq(link.get("node"), tanker, "on: the Tanker's beam under fire")
	assert_eq(float(link.get("rate", 0.0)), float(Units.stat("gang_support", "repair_hp_per_second")) * Match.REPAIR_UNDER_FIRE_FACTOR,
			"at the half rate the rules give")
	assert_true(bool(link.get("under_fire", false)), "drawn as the slower beam")
	assert_true(FeedbackReader.mending(tanker, menders).is_empty(), "no beam to itself while shot")
	patient.ticks_since_hit = 1_000_000
	assert_true(not bool(FeedbackReader.mending(patient, menders).get("under_fire", true)), "quiet: the full beam")
