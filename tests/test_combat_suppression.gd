extends TestCase
## L2 (round 4 combat X1): suppression and effective fire. The wall of bullets is a coarse decaying grid
## (ThreatField) that every resolved round stamps; units standing in it get suppressed, shoot worse, and count as
## pinned above a threshold. Brains and drills read `Match.threat_field` / `is_beaten_zone`.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Match:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	return game_match


# ---- The grid itself (no simulation needed) -----------------------------------------

func test_the_grid_covers_the_arena_and_ignores_what_is_outside() -> void:
	var field := ThreatField.new(120.0)
	assert_true(field.cols >= 40 and field.rows >= 40, "the grid spans the arena (%d x %d)" % [field.cols, field.rows])
	assert_near(field.at(Vector3(0, 0, 0)), 0.0, 0.0001, "a quiet arena has no fire anywhere")
	field.stamp_point(Vector3(500, 0, 500), 5.0)
	assert_near(field.total(), 0.0, 0.0001, "a round outside the grid is dropped, not wrapped around")


func test_a_round_stamps_every_cell_it_flies_through() -> void:
	var field := ThreatField.new(120.0)
	field.stamp_segment(Vector3(-40, 0, 0), Vector3(40, 0, 0), 1.0)
	assert_near(field.at(Vector3(0, 0, 0)), 1.0, 0.0001, "the middle of the lane is under fire")
	assert_near(field.at(Vector3(-30, 0, 0)), 1.0, 0.0001, "and so is the near end")
	assert_near(field.at(Vector3(30, 0, 0)), 1.0, 0.0001, "and the far end")
	assert_near(field.at(Vector3(0, 0, 40)), 0.0, 0.0001, "40 m off the lane is calm")
	assert_true(field.total() > 10.0, "a long burst marks a whole corridor, not one cell (%.1f)" % field.total())


func test_concentrated_fire_adds_up_and_decays_away() -> void:
	var field := ThreatField.new(120.0)
	for shooter in 3:
		field.stamp_segment(Vector3(-40, 0, 0), Vector3(40, 0, 0), 1.0)
	assert_near(field.at(Vector3.ZERO), 3.0, 0.0001, "three guns on one lane is three times the fire")
	field.decay(60)  # one second of quiet is one half-life
	assert_near(field.at(Vector3.ZERO), 1.5, 0.01, "fire halves every second once the guns stop")
	field.decay(60)
	assert_near(field.at(Vector3.ZERO), 0.75, 0.01, "and halves again")
	field.decay(60 * 20)
	assert_near(field.at(Vector3.ZERO), 0.0, 0.0001, "and is exactly zero after a while, not float dust")


func test_a_burst_marks_the_ground_around_where_it_lands() -> void:
	var field := ThreatField.new(120.0)
	field.stamp_burst(Vector3(20, 0, -20), 9.0, 3.0)
	assert_near(field.at(Vector3(20, 0, -20)), 3.0, 0.0001, "the impact point")
	assert_near(field.at(Vector3(25, 0, -20)), 3.0, 0.0001, "and inside the splash")
	assert_near(field.at(Vector3(60, 0, -20)), 0.0, 0.0001, "but not 40 m away")


func test_a_path_through_the_beaten_zone_reads_worse_than_a_way_around() -> void:
	var field := ThreatField.new(120.0)
	field.stamp_segment(Vector3(-60, 0, 0), Vector3(60, 0, 0), 2.0)
	var through := field.peak_along(Vector3(0, 0, -40), Vector3(0, 0, 40))
	var around := field.peak_along(Vector3(0, 0, -40), Vector3(-80, 0, -40))
	assert_near(through, 2.0, 0.0001, "crossing the lane walks into the fire")
	assert_near(around, 0.0, 0.0001, "going the long way round stays out of it")
	assert_true(field.mean_along(Vector3(-60, 0, 0), Vector3(60, 0, 0)) > 1.5, "driving up the lane is worse still")


# ---- Suppression on units ----------------------------------------------------------

## A shooter and a victim facing each other `apart` meters along z, the shooter holding the trigger.
func _duel(game_match: Match, shooter_unit: String, apart: float) -> Array:
	var army := {"name": "T", "squads": [{"name": "A", "units": [{"unit": shooter_unit}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, army), "", "shooter loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, {"name": "T", "squads": [{"name": "A", "units": [{"unit": "tank"}]}]}),
			"", "victim loads")
	var shooter := game_match.tanks.get_node("Green_A_1") as Tank
	var victim := game_match.tanks.get_node("Rust_A_1") as Tank
	for brain in game_match.brains.get_children():
		brain.queue_free()  # scripted: no brains deciding anything
	await wait_physics_frames(1)
	shooter.global_position = Vector3(-100.0, 0.0, 0.0)
	victim.global_position = Vector3(-100.0, 0.0, -apart)
	victim.max_shield = 0.0
	victim.shield = 0.0
	return [shooter, victim]


func _hold_trigger(shooter: Tank, victim: Tank, ticks: int) -> void:
	for tick in ticks:
		shooter.command = TankCommand.new(0.0, 0.0, victim.global_position, true)
		victim.command = TankCommand.new(0.0, 0.0, shooter.global_position, false)
		await wait_physics_frames(1)


func test_a_machine_gun_stream_suppresses_what_it_is_aimed_at() -> void:
	var game_match := _setup()
	var pair: Array = await _duel(game_match, "scout", 30.0)
	var victim: Tank = pair[1]
	victim.max_health = 100000  # measuring suppression, not death
	victim.health = 100000
	assert_near(victim.suppression, 0.0, 0.0001, "nobody starts suppressed")
	await _hold_trigger(pair[0], victim, 120)
	assert_true(victim.suppression > 0.2, "two seconds of machine-gun fire rattles a crew (%.2f)" % victim.suppression)
	assert_true(game_match.threat_field(Match.Team.RUST).at(victim.global_position) > 0.5,
			"and the lane it came down is marked as incoming fire for Rust")
	assert_near(game_match.threat_field(Match.Team.GREEN).at(victim.global_position), 0.0, 0.0001,
			"the shooter's own team has nothing incoming there")


func test_suppression_fades_once_the_shooting_stops() -> void:
	var game_match := _setup()
	var pair: Array = await _duel(game_match, "scout", 30.0)
	var victim: Tank = pair[1]
	victim.max_health = 100000
	victim.health = 100000
	await _hold_trigger(pair[0], victim, 120)
	var under_fire := victim.suppression
	for tick in 300:
		pair[0].command = TankCommand.new()
		await wait_physics_frames(1)
	assert_true(victim.suppression < under_fire * 0.2, "five quiet seconds and the crew is back at its gun (%.2f -> %.2f)"
			% [under_fire, victim.suppression])


func test_being_pinned_spoils_a_crews_aim() -> void:
	# Same shot, fired cold and fired pinned: the pinned one scatters.
	var cold := Match.shot_spread(Weapons.profile("cannon"), 0.0, 0.0)
	var moving := Match.shot_spread(Weapons.profile("cannon"), 1.0, 0.0)
	var pinned := Match.shot_spread(Weapons.profile("cannon"), 0.0, 1.0)
	assert_true(pinned > cold * 2.0, "a pinned gunner's shots scatter (%.2f deg vs %.2f cold)"
			% [rad_to_deg(pinned), rad_to_deg(cold)])
	assert_true(moving > cold, "firing on the move still costs accuracy too")
	assert_true(Match.shot_spread(Weapons.profile("cannon"), 0.0, Tank.PINNED_SUPPRESSION) > cold,
			"and the penalty scales in, it isn't a switch at the pin threshold")


func test_pinned_is_a_state_others_can_read() -> void:
	var game_match := _setup()
	var pair: Array = await _duel(game_match, "scout", 30.0)
	var victim: Tank = pair[1]
	assert_true(not victim.is_pinned(), "a fresh unit is not pinned")
	victim.suppress(1.0)
	assert_true(victim.is_pinned(), "a fully suppressed unit is")
	assert_true(victim.suppression <= 1.0, "suppression never runs past 1")
	victim.suppression = Tank.PINNED_SUPPRESSION - 0.01
	assert_true(not victim.is_pinned(), "just under the threshold it isn't")


func test_a_pinned_battery_cannot_get_its_legs_down() -> void:
	var game_match := _setup()
	var army := {"name": "T", "squads": [{"name": "A", "units": [{"unit": "artillery"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, army), "", "battery loads")
	var battery := game_match.tanks.get_node("Green_A_1") as Tank
	for brain in game_match.brains.get_children():
		brain.queue_free()
	await wait_physics_frames(1)
	battery.suppress(1.0)
	for tick in 240:
		battery.suppression = 1.0  # held down by a machine gun somewhere
		battery.command = TankCommand.new(0.0, 0.0, Vector3(0, 0, -100), true)
		await wait_physics_frames(1)
	assert_true(not battery.is_deployed(), "outriggers stay up while the rounds come in (%.2f)" % battery.deploy_ratio)
	for tick in 240:
		battery.suppression = 0.0
		battery.command = TankCommand.new(0.0, 0.0, Vector3(0, 0, -100), true)
		await wait_physics_frames(1)
	assert_true(battery.is_deployed(), "and go down once the fire lifts")


func test_a_dead_crew_is_not_suppressed() -> void:
	var game_match := _setup()
	var pair: Array = await _duel(game_match, "scout", 30.0)
	var victim: Tank = pair[1]
	victim.suppress(1.0)
	victim.apply_damage(victim.health)
	await wait_physics_frames(Match.SUPPRESSION_SAMPLE_TICKS * 2)
	assert_near(victim.suppression, 0.0, 0.0001, "a wreck's suppression is cleared (it must not read as pinned)")


# ---- What the AI and the drills ask ------------------------------------------------

func test_the_match_answers_whether_a_move_crosses_a_beaten_zone() -> void:
	var game_match := _setup()
	var pair: Array = await _duel(game_match, "scout", 30.0)
	await _hold_trigger(pair[0], pair[1], 120)
	var shooter: Tank = pair[0]
	var victim: Tank = pair[1]
	var across := (shooter.global_position + victim.global_position) * 0.5
	assert_true(game_match.is_beaten_zone(Match.Team.RUST, across + Vector3(-30, 0, 0), across + Vector3(30, 0, 0)),
			"crossing a live lane is a beaten zone for the side being shot at")
	assert_true(not game_match.is_beaten_zone(Match.Team.RUST, Vector3(80, 0, 80), Vector3(80, 0, 40)),
			"the far corner is not")
	assert_true(not game_match.is_beaten_zone(Match.Team.GREEN, across + Vector3(-30, 0, 0), across + Vector3(30, 0, 0)),
			"and the shooting side's own rounds don't scare it off its own lane")


func test_k2_events_report_the_suppression_a_round_applied() -> void:
	var game_match := _setup()
	var pair: Array = await _duel(game_match, "tank", 40.0)
	var fired: Array = []
	var impacts: Array = []
	game_match.weapon_fired.connect(func(event: Dictionary) -> void: fired.append(event))
	game_match.projectile_impact.connect(func(event: Dictionary) -> void: impacts.append(event))
	await _hold_trigger(pair[0], pair[1], 120)
	assert_true(not fired.is_empty(), "the tank fired")
	assert_true(fired[0].has("suppression_applied"), "weapon_fired says how suppressive the round is")
	assert_true(float(fired[0]["suppression_applied"]) > 0.0, "a tank shell is suppressive")
	assert_true(not impacts.is_empty(), "and something was struck")
	assert_true(impacts[0].has("suppression_applied"), "projectile_impact reports what the round laid down")
