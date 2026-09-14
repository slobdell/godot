extends TestCase
## G3 (streams/gameplay.md): squads react to player orders like RTS units. Measures ticks from
## a command to visible movement, and whether ordered tanks follow the order or wander off to
## fight. Each test prints a MEASURE line so before/after numbers can be recorded.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const LANE_X := -100.0
## "Units visibly start moving within ~0.25 s" (the brief) at 60 ticks per second.
const RESPONSE_BUDGET_TICKS := 15


func _setup(count: int, formation := "wedge") -> Array:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tanks := []
	for i in count:
		tanks.append({"weapon": "cannon"})
	var doctrine := {"name": "Test", "squads": [{"name": "Alpha", "formation": formation, "verb": "hold",
			"directive": {"role": "assault"}, "tanks": tanks}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, doctrine), "", "setup: doctrine loads")
	return [game_match, game_match.squads["0/Alpha"]]


func _members(game_match: Match, squad: Squad) -> Array[Tank]:
	var result: Array[Tank] = []
	for member in squad.roster:
		result.append(game_match.tanks.get_node(member) as Tank)
	return result


func test_every_tank_reacts_to_a_move_order_within_a_quarter_second() -> void:
	var setup: Array = _setup(3)
	var game_match: Match = setup[0]
	var squad: Squad = setup[1]
	var tanks := _members(game_match, squad)
	for i in tanks.size():
		tanks[i].global_position = Vector3(LANE_X + (i - 1) * 12.0, 0.0, 40.0 + absf(i - 1) * 12.0)
	assert_eq(game_match.command_squad(Match.Team.GREEN, {"squad": "Alpha", "verb": "hold", "to": [LANE_X, 40.0], "facing": [0, -1]}), "",
			"setup: hold here")
	await wait_physics_frames(60 * 4)  # settle into the hold
	var start_positions := tanks.map(func(t: Tank) -> Vector3: return t.global_position)
	var start_yaws := tanks.map(func(t: Tank) -> float: return t.rotation.y)
	assert_eq(game_match.command_squad(Match.Team.GREEN, {"squad": "Alpha", "verb": "move", "to": [LANE_X, -20.0]}), "", "order accepted")
	var reacted := [-1, -1, -1]
	var lead := game_match.tanks.get_node(NodePath(squad.commander)) as Tank
	var lead_start := lead.global_position
	var lead_going := -1
	var lead_20 := -1
	for tick in 60 * 6:
		await tree.physics_frame
		for i in tanks.size():
			if reacted[i] < 0 and (tanks[i].global_position.distance_to(start_positions[i]) > 0.25
					or absf(angle_difference(tanks[i].rotation.y, start_yaws[i])) > deg_to_rad(2.0)):
				reacted[i] = tick + 1
		if lead_going < 0 and lead.global_position.distance_to(lead_start) > 5.0:
			lead_going = tick + 1
		if lead_20 < 0 and lead.global_position.distance_to(lead_start) > 20.0:
			lead_20 = tick + 1
	var slowest: int = reacted.max()
	print("MEASURE g3_ticks_to_react per tank %s, slowest %d; commander 5 m after %d ticks, 20 m after %d" % [reacted, slowest, lead_going, lead_20])
	assert_true(not reacted.has(-1), "every tank in the squad reacts (%s)" % [reacted])
	assert_true(slowest <= RESPONSE_BUDGET_TICKS, "the slowest tank reacts within %d ticks (%s)" % [RESPONSE_BUDGET_TICKS, reacted])
	assert_true(lead_going > 0 and lead_going <= 90, "the commander is 5 m on its way within 1.5 s (%d ticks)" % lead_going)


func test_ordered_tanks_follow_the_order_instead_of_chasing_a_fight() -> void:
	var setup: Array = _setup(2, "line")
	var game_match: Match = setup[0]
	var squad: Squad = setup[1]
	var tanks := _members(game_match, squad)
	for i in tanks.size():
		tanks[i].global_position = Vector3(LANE_X + i * 12.0, 0.0, 40.0)
	# A harmless enemy 45 m north, in sight and in range: a tempting fight.
	var enemy := game_match.spawn_tank("Rust_Bait_1", 0, Match.Team.RUST)
	enemy.global_position = Vector3(LANE_X + 6.0, 0.0, -5.0)
	enemy.rotation.y = PI
	enemy.max_health = 100000
	enemy.health = 100000
	# The player sent them in (assault), and they're fighting.
	assert_eq(game_match.command_squad(Match.Team.GREEN, {"squad": "Alpha", "verb": "assault", "to": [LANE_X + 6.0, 20.0]}), "",
			"setup: assault")
	await wait_physics_frames(60 * 3)
	var brains: Array[TankBrain] = []
	for tank in tanks:
		brains.append(game_match.brains.get_node("Brain_" + tank.name) as TankBrain)
	# Order them away to the west, past the fight.
	assert_eq(game_match.command_squad(Match.Team.GREEN, {"squad": "Alpha", "verb": "move", "to": [LANE_X - 10.0, 80.0]}), "", "order accepted")
	var first_follow := [-1, -1]
	var followed := 0
	var thinks := 0
	for tick in 60 * 5:
		await tree.physics_frame
		for i in brains.size():
			var option: String = brains[i].choice.get("option", "")
			var obeying := option == "KEEP_SLOT" or (option == "HOLD" and squad.arrived)
			if first_follow[i] < 0 and obeying:
				first_follow[i] = tick + 1
			if (game_match.tick + brains[i].think_offset) % TankBrain.THINK_EVERY_TICKS == 0:
				thinks += 1
				followed += 1 if obeying else 0
	var rate := float(followed) / maxf(thinks, 1)
	print("MEASURE g3_order_followed %.0f%% of thinks; ticks to first obey %s" % [rate * 100.0, first_follow])
	assert_true(not first_follow.has(-1) and first_follow.max() <= 2, "a new order is taken up on the very next tick (%s)" % [first_follow])
	assert_true(rate >= 0.9, "ordered tanks follow the order, not the fight (%.0f%% of thinks)" % (rate * 100.0))
