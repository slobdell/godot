extends TestCase
## Round 17 (brains T1-T3): the decision levers (BrainLevers) are OFF for the champion, each `l17*` variant is the
## champion plus exactly one lever, the A/B's gate closes them all, and each lever does what its row on the lead's page
## says. The prices are not asserted here (they are measured, `make ai-ab-match` and the ladder); the MECHANISM is.

const LEVER_VARIANTS := {"l17i2": "far_idle_hz", "l17i1": "far_idle_hz", "l17k": "kturn_check_ticks",
		"l17c": "chord_samples", "l17o": "orca_neighbours"}


func teardown() -> void:
	BrainVariants.reset()
	BrainLevers.gate = true
	BrainLevers.split = false
	BrainLevers.split_flip = 0
	TankBrain.census = false
	super.teardown()


func test_the_champion_carries_no_lever() -> void:
	BrainVariants.reset()
	for team in 2:
		assert_eq(BrainLevers.of_variant(team), {}, "team %d's default brain has no lever ON" % team)
		assert_eq(BrainLevers.far_idle_hz(team), 0.0, "no far-and-idle rate")
		assert_eq(BrainLevers.kturn_check_ticks(team), Movement.KTURN_CHECK_TICKS, "the k-turn check every 6 ticks")
		assert_eq(BrainLevers.chord_samples(team), Movement.CHORD_SAMPLES.size(), "both chord samples")
		assert_eq(BrainLevers.orca_neighbours(team), Avoidance.MAX_NEIGHBOURS, "ORCA against six")


func test_each_lever_variant_is_the_champion_plus_one_lever() -> void:
	var champion: Dictionary = BrainVariants.PROFILES[BrainVariants.CHAMPION]
	for variant: String in LEVER_VARIANTS:
		var profile: Dictionary = BrainVariants.PROFILES[variant]
		var lever: String = LEVER_VARIANTS[variant]
		var rest := profile.duplicate()
		rest.erase(lever)
		assert_eq(rest, champion, "%s is the champion apart from %s" % [variant, lever])
		BrainVariants.use(Match.Team.GREEN, variant)
		assert_eq(BrainLevers.of_variant(Match.Team.GREEN).keys(), [lever], "%s turns on %s and nothing else" % [variant, lever])
		assert_eq(BrainLevers.of_variant(Match.Team.RUST), {}, "and only on its own team")
		BrainVariants.reset()


func test_a_closed_gate_reads_every_default() -> void:
	BrainVariants.use(Match.Team.GREEN, "l17i1")
	BrainLevers.gate = false
	assert_eq(BrainLevers.far_idle_hz(Match.Team.GREEN), 0.0, "the A/B's OFF arm: the champion's rate")
	BrainLevers.gate = true
	assert_eq(BrainLevers.far_idle_hz(Match.Team.GREEN), 1.0, "and the variant's when open")
	BrainVariants.use(Match.Team.GREEN, "l17o")
	BrainLevers.gate = false
	assert_eq(BrainLevers.orca_neighbours(Match.Team.GREEN), Avoidance.MAX_NEIGHBOURS, "closed: six")
	BrainLevers.gate = true
	assert_eq(BrainLevers.orca_neighbours(Match.Team.GREEN), 4, "open: four")


func test_the_split_ab_opens_the_lever_for_half_the_units_and_swaps_them() -> void:
	BrainVariants.use(Match.Team.GREEN, "l17o")
	var names := []
	for i in 40:
		names.append("Green_A_%d" % i)
	assert_eq(BrainLevers.orca_neighbours(Match.Team.GREEN, names[0]), 4, "outside a split every unit has the lever")
	BrainLevers.split = true
	var open := []
	for unit: String in names:
		if BrainLevers.orca_neighbours(Match.Team.GREEN, unit) == 4:
			open.append(unit)
	assert_true(open.size() >= 10 and open.size() <= 30, "about half the units are ON (%d of 40)" % open.size())
	BrainLevers.split_flip = 1
	for unit: String in names:
		assert_eq(BrainLevers.orca_neighbours(Match.Team.GREEN, unit) == 4, not open.has(unit), "%s swaps halves" % unit)
	assert_eq(BrainLevers.orca_neighbours(Match.Team.GREEN), 4, "asked without a unit: the gate alone")


func test_orca_with_fewer_neighbours_keeps_the_nearest() -> void:
	var rows := []
	for i in 9:
		rows.append([float((i * 7) % 9) + 0.5, "U%d" % i, i])  # distances in a scrambled order
	var six: Array = []
	var four: Array = []
	for row: Array in rows:
		Avoidance._insert_nearest(six, row[0], row[1], row[2])
		Avoidance._insert_nearest(four, row[0], row[1], row[2], 4)
	assert_eq(six.size(), 6, "the default keeps six")
	assert_eq(four, six.slice(0, 4), "the lever keeps the four NEAREST of the same six, in the same order")


## A CPU brain alone on the map (nothing known within LOD_RADIUS, no order): how many times it thinks in `seconds`.
func _thinks_alone(variant: String, player_side: bool, seconds: int) -> Dictionary:
	var s := AiScenario.create(self, 3)
	if player_side:
		s.game_match.set_meta("player_team", Match.Team.GREEN)
	BrainVariants.use(Match.Team.GREEN, variant)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 40), PI)
	var brain := s.brain_of(me)
	await s.start()
	for tick in SimClock.TICK_RATE:
		await s.step()  # past the first intel refresh and the first think
	TankBrain.census = true
	TankBrain.lod_ticks = {}
	TankBrain.lod_thinks = {}
	for tick in SimClock.TICK_RATE * seconds:
		await s.step()
	TankBrain.census = false
	var thinks := 0
	for key: String in TankBrain.lod_thinks:
		thinks += int(TankBrain.lod_thinks[key])
	var result := {"thinks": thinks, "lod": brain._lod, "ticks": TankBrain.lod_ticks.duplicate()}
	# K1 must not move at all: an order issued now is taken up on the next tick, whatever the rate.
	s.orders().issue({"units": [String(me.name)], "verb": "move", "to": [-100.0, 0.0]})
	await s.step()
	result["order_taken"] = not brain.order.is_empty()
	s.dispose()
	BrainVariants.reset()
	return result


func test_far_and_idle_thinks_at_its_own_rate_and_still_takes_an_order_at_once() -> void:
	var champion := await _thinks_alone(BrainVariants.CHAMPION, false, 6)
	var lever := await _thinks_alone("l17i1", false, 6)
	var player := await _thinks_alone("l17i1", true, 6)
	print("MEASURE ai_far_idle thinks in 6 s alone: champion %s; l17i1 %s; l17i1 on the player's side %s" % [champion, lever, player])
	assert_eq(String(champion["lod"]), "idle", "control: alone on the map the champion is at the idle rate")
	assert_true(int(champion["thinks"]) >= 18 and int(champion["thinks"]) <= 22, "the idle rate is 3.3/s (%d in 6 s)" % champion["thinks"])
	assert_eq(String(lever["lod"]), "far_idle", "the lever puts a far CPU brain in its own bucket")
	assert_true(int(lever["thinks"]) >= 5 and int(lever["thinks"]) <= 7, "and it thinks once a second (%d in 6 s)" % lever["thinks"])
	assert_true(int(player["thinks"]) >= 18, "never the player's own units (%d in 6 s)" % player["thinks"])
	for result: Dictionary in [champion, lever, player]:
		assert_true(bool(result["order_taken"]), "K1: a new order is taken up on the next tick (%s)" % result)
