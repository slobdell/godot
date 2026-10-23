extends TestCase
## X4 (round 4 combat): the two mechanics the new factions needed. Everything else about them is costs and stats in
## the catalog — a faction is a combination of the shared vocabulary, never a faction-wide bonus (game_design.md
## *Factions*).
##
##   HOVER (the Syndicate): a hull that swings to face at any speed but has nothing gripping the ground, so its
##   momentum carries. It strafes, and it drifts through a turn.
##   FIELD REPAIR (the road gangs' resupply tanker): the gangs have no shields anywhere, so they get hit points back
##   from a vehicle that mends its neighbours — and that vehicle is easy to kill.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Match:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	game_match.elimination = true
	return game_match


func _dispose(game_match: Match) -> void:
	(game_match.get_meta("arena") as Node).queue_free()
	game_match.queue_free()
	await wait_physics_frames(2)


# ---- Hover ------------------------------------------------------------------------

func test_a_hover_hull_turns_standing_still_where_wheels_cannot() -> void:
	# A wheeled hull needs speed to steer (a turning circle); hover has no wheels to need it.
	var turned := {}
	for unit_id in ["syn_scout", "gang_scout", "tank"]:
		var state := TankMotion.state_for(unit_id, Vector3.ZERO, Vector3.FORWARD, 0.0)
		for tick in 30:
			TankMotion.step_in_place(state, 0.0, 1.0, SimClock.TICK_SECONDS)
		var forward: Vector3 = state["forward"]
		turned[unit_id] = snappedf(rad_to_deg(absf(Vector3.FORWARD.signed_angle_to(forward, Vector3.UP))), 0.1)
	print("MEASURE yaw_from_a_standstill_over_half_a_second %s" % [turned])
	# Wheels don't sit still: with no throttle and full lock a wheeled hull shuffles through a multi-point turn
	# (TankMotion's creep), so the honest comparison is how much FASTER hover and tracks come round.
	assert_true(float(turned["syn_scout"]) >= 39.0, "a skimmer spins on the spot (%.0f deg)" % turned["syn_scout"])
	assert_true(float(turned["tank"]) >= 39.0, "so do tracks (%.0f deg)" % turned["tank"])
	assert_true(float(turned["syn_scout"]) > float(turned["gang_scout"]) * 2.0,
			"a rat rod on wheels needs far longer (%.0f deg vs %.0f)" % [turned["gang_scout"], turned["syn_scout"]])


func test_a_hover_hull_keeps_its_momentum_through_a_turn() -> void:
	# Drive a skimmer up to speed, then swing it hard: it should end up facing one way and still travelling another.
	var state := TankMotion.state_for("syn_scout", Vector3.ZERO, Vector3.FORWARD, 0.0)
	for tick in 120:
		TankMotion.step_in_place(state, 1.0, 0.0, SimClock.TICK_SECONDS)
	var straight_line: Vector3 = state["velocity"]
	for tick in 30:
		TankMotion.step_in_place(state, 1.0, 1.0, SimClock.TICK_SECONDS)
	var forward: Vector3 = state["forward"]
	var velocity: Vector3 = state["velocity"]
	var drift := absf(velocity.normalized().dot(Vector3(-forward.z, 0.0, forward.x)))
	print("MEASURE hover_drift travelling %.1f m/s at %.0f deg off its own nose (was %.1f m/s straight)"
			% [velocity.length(), rad_to_deg(asin(clampf(drift, 0.0, 1.0))), straight_line.length()])
	assert_true(straight_line.length() > 14.0, "it gets up to speed first (%.1f m/s)" % straight_line.length())
	assert_true(drift > 0.25, "and slides sideways while its nose comes round (%.2f of its travel)" % drift)

	# Tracks, by contrast, only ever go where they point.
	var tracked := TankMotion.state_for("tank", Vector3.ZERO, Vector3.FORWARD, 0.0)
	for tick in 120:
		TankMotion.step_in_place(tracked, 1.0, 0.0, SimClock.TICK_SECONDS)
	for tick in 30:
		TankMotion.step_in_place(tracked, 1.0, 1.0, SimClock.TICK_SECONDS)
	var tracked_forward: Vector3 = tracked["forward"]
	var tracked_velocity: Vector3 = tracked["velocity"]
	assert_near(absf(tracked_velocity.normalized().dot(Vector3(-tracked_forward.z, 0.0, tracked_forward.x))), 0.0, 0.001,
			"a dozer travels exactly where its nose points")


func test_hover_units_drive_in_a_real_match() -> void:
	var game_match := _setup()
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "G", "squads": [{"name": "A",
			"units": [{"unit": "syn_scout"}, {"unit": "syn_tank"}]}]}), "", "a Syndicate pair loads")
	for brain in game_match.brains.get_children():
		brain.queue_free()
	await wait_physics_frames(1)
	var skimmer := game_match.tanks.get_node("Green_A_1") as Tank
	skimmer.place(Vector3(-90.0, 0.0, 0.0), 0.0)
	var start := skimmer.global_position
	for tick in 120:
		skimmer.command = TankCommand.new(1.0, 0.0, start + Vector3(0.0, 0.0, -50.0), false)
		await wait_physics_frames(1)
	var travelled := start.distance_to(skimmer.global_position)
	print("MEASURE hover_in_match skimmer travelled %.1f m in 2 s, on the ground at y=%.2f"
			% [travelled, skimmer.global_position.y])
	assert_true(travelled > 20.0, "a skimmer actually moves under the real physics body (%.1f m)" % travelled)
	assert_near(skimmer.global_position.y, 0.0, 0.5, "and stays on the deck (hover is a driving model, not flight)")
	await _dispose(game_match)


# ---- Field repair ------------------------------------------------------------------

func test_a_resupply_tanker_mends_the_pack_around_it() -> void:
	var game_match := _setup()
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "G", "squads": [{"name": "A",
			"units": [{"unit": "gang_ifv"}, {"unit": "gang_support"}, {"unit": "gang_ifv"}]}]}), "", "a gang pack loads")
	for brain in game_match.brains.get_children():
		brain.queue_free()
	await wait_physics_frames(1)
	var near_unit := game_match.tanks.get_node("Green_A_1") as Tank
	var tanker := game_match.tanks.get_node("Green_A_2") as Tank
	var far_unit := game_match.tanks.get_node("Green_A_3") as Tank
	# Well away from either base, so this measures the tanker and not the home repair zone.
	tanker.place(Vector3(-90.0, 0.0, 0.0), tanker.rotation.y)
	near_unit.place(Vector3(-80.0, 0.0, 0.0), near_unit.rotation.y)
	far_unit.place(Vector3(-40.0, 0.0, 0.0), far_unit.rotation.y)
	for unit in [near_unit, far_unit]:
		unit.health = 60
	await wait_physics_frames(1)
	assert_true(not Match.in_resupply_zone(Match.Team.GREEN, tanker.global_position), "setup: nowhere near a base")
	for tick in SimClock.TICK_RATE * 10:
		for unit in [near_unit, tanker, far_unit]:
			unit.command = TankCommand.new()
		await wait_physics_frames(1)
	print("MEASURE field_repair over 10 s: beside the tanker %d hp, 50 m away %d hp (both started at 60)"
			% [near_unit.health, far_unit.health])
	assert_true(near_unit.health >= 100, "the gun truck beside the tanker mends (%d hp)" % near_unit.health)
	assert_eq(far_unit.health, 60, "the one 50 m away does not")
	assert_true(near_unit.health < near_unit.max_health, "and it is a trickle, not a reset (%d of %d)"
			% [near_unit.health, near_unit.max_health])
	await _dispose(game_match)


## Round 38 (feedback F3, C38.4; his answer 2026-10-22, "yes it also repair during combat"): under fire the Tanker still mends,
## at Match.REPAIR_UNDER_FIRE_FACTOR of its rate (`--repair-under-fire`, ON since its bar passed). Both arms: the old rule
## (OFF) still holds the hull, the new one mends it slower than the quiet rate would.
func test_field_repair_stops_while_the_fire_is_landing() -> void:
	var was := Match.repair_under_fire_on
	Match.repair_under_fire_on = false
	var off: int = await _hp_after_six_seconds_under_fire()
	Match.repair_under_fire_on = true
	var on: int = await _hp_after_six_seconds_under_fire()
	Match.repair_under_fire_on = was
	assert_true(off <= 60, "without round 38's rule a crew under fire does not get out and mend the hull (%d hp)" % off)
	var quiet_rate := float(Units.stat("gang_support", "repair_hp_per_second"))
	assert_true(on > 60, "with it the Tanker keeps mending under fire (%d hp)" % on)
	assert_true(on < 60 + int(quiet_rate * 6.0), "but slower than once quiet (%d hp, quiet would be +%d)" % [on, int(quiet_rate * 6.0)])


func _hp_after_six_seconds_under_fire() -> int:
	var game_match := _setup()
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "G", "squads": [{"name": "A",
			"units": [{"unit": "gang_ifv"}, {"unit": "gang_support"}]}]}), "", "a gang pair loads")
	for brain in game_match.brains.get_children():
		brain.queue_free()
	await wait_physics_frames(1)
	var hurt := game_match.tanks.get_node("Green_A_1") as Tank
	var tanker := game_match.tanks.get_node("Green_A_2") as Tank
	tanker.place(Vector3(-90.0, 0.0, 0.0), tanker.rotation.y)
	hurt.place(Vector3(-80.0, 0.0, 0.0), hurt.rotation.y)
	hurt.health = 60
	await wait_physics_frames(1)
	for tick in SimClock.TICK_RATE * 6:
		hurt.command = TankCommand.new()
		tanker.command = TankCommand.new()
		if tick % 30 == 0:
			hurt.take_hit(1.0, 1.0, 1.0)  # somebody keeps putting rounds into it
		await wait_physics_frames(1)
	print("MEASURE field_repair_under_fire %d hp after 6 s of being shot at (started at 60, under-fire rule %s)" % [hurt.health,
			Match.repair_under_fire_on])
	var hp := hurt.health
	await _dispose(game_match)
	return hp


func test_only_the_units_that_carry_a_repair_crew_mend_anyone() -> void:
	var carriers: Array = []
	for unit_id in Units.ids():
		if float(Units.stat(unit_id, "repair_hp_per_second", 0.0)) > 0.0:
			carriers.append(unit_id)
			assert_true(float(Units.stat(unit_id, "repair_radius_m", 0.0)) > 0.0,
					"%s repairs, so it needs a radius" % unit_id)
	assert_eq(carriers, ["gang_support"], "exactly one unit mends its neighbours today (%s)" % [carriers])
