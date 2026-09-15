extends TestCase
## Stretch: the CPU commander turns team intel into squad orders.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Array:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var army := {"name": "CPU", "squads": [{"name": "Guns", "units": [{"unit": "tank"}, {"unit": "tank"}, {"unit": "tank"}]}, {"name": "Eyes", "units": [{"unit": "scout"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.RUST, army), "", "setup: CPU army")
	var commander := CpuCommander.new()
	commander.game_match = game_match
	commander.team = Match.Team.RUST
	commander.policy = "v2"  # these test v2's squad-by-squad planner (v3+ are in test_ai_commander_v3.gd)
	add_to_tree(commander)
	await wait_physics_frames(2)
	return [game_match, commander]


func _spot(game_match: Match, count: int, at: Vector3) -> void:
	for i in count:
		game_match.intel[Match.Team.RUST]["Green_X_%d" % i] = {"position": at + Vector3(i * 5, 0, 0), "velocity": Vector3.ZERO,
				"forward": Vector3.FORWARD, "turret_forward": Vector3.FORWARD, "health": 300, "shield": 150, "weapon": "cannon",
				"visible": true, "seen_tick": game_match.tick}


func test_plans_follow_the_strength_of_what_it_sees() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var commander: CpuCommander = setup[1]
	var guns: Squad = game_match.squads["1/Guns"]
	var by_name := game_match.tanks_by_name()
	var quiet := commander.plan_for(guns, by_name)
	assert_eq(quiet["verb"], "move", "nothing known: move out")
	assert_true(float(quiet["to"][1]) > (by_name[guns.commander] as Tank).global_position.z, "toward the enemy (south for Rust)")
	_spot(game_match, 1, Vector3(0, 0, 20))
	assert_eq(commander.plan_for(guns, by_name)["verb"], "assault", "3 tanks + a scout against 1 tank: assault")
	game_match.intel[Match.Team.RUST].clear()
	_spot(game_match, 6, Vector3(-10, 0, 20))
	assert_eq(commander.plan_for(guns, by_name)["verb"], "break_contact", "against 6 tanks: pull back")
	game_match.intel[Match.Team.RUST].clear()
	_spot(game_match, 3, Vector3(-10, 0, 20))
	assert_eq(commander.plan_for(guns, by_name)["verb"], "assault", "an even fight: take it to them (holding lost 30 of 32)")


func test_it_commands_gun_squads_only_and_does_not_spam_orders() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var commander: CpuCommander = setup[1]
	commander.think()
	assert_eq(game_match.squads["1/Guns"].verb, "move", "the gun squad got an order")
	assert_eq(game_match.squads["1/Eyes"].verb, "", "the scouts are left to their brains")
	var serial: int = game_match.squads["1/Guns"].order_serial
	commander.think()
	assert_eq(game_match.squads["1/Guns"].order_serial, serial, "the same plan isn't re-sent (it would reset commitment)")


func test_v2_fights_it_out_up_close_and_chases_fresh_contacts() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var commander: CpuCommander = setup[1]
	var guns: Squad = game_match.squads["1/Guns"]
	var by_name := game_match.tanks_by_name()
	var lead := by_name[guns.commander] as Tank
	_spot(game_match, 6, lead.global_position + Vector3(-12, 0, 25))
	assert_eq(commander.plan_for(guns, by_name)["verb"], "assault", "6 tanks 25 m away: too close to turn and run, fight")
	game_match.intel[Match.Team.RUST].clear()
	_spot(game_match, 1, Vector3(40, 0, 10))
	for contact in game_match.intel[Match.Team.RUST].values():
		contact["visible"] = false
	assert_eq(commander.plan_for(guns, by_name)["verb"], "assault", "a contact seen a moment ago: go get it (the brains hunt inside an assault)")
