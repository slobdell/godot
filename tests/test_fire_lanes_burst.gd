extends TestCase
## Round 46 (engage L1b, R46.24 / R46.26): Bar L1 failed on friendly fire (1 -> 6 hits; 5 in one run, seed 11922). An
## IFV's 4-round autocannon burst is checked for friends on its FIRST round only; the hull pulled away mid-burst and the
## later rounds went into a squadmate. Two parts, both under `--lane-clear`: lane spots are kept clear by the MOVING spread
## (TankBrain._lane_spread), and each later burst round checks the line again (Tank._burst_into_friend).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


## An IFV on standing orders firing at a dummy 30 m off; the moment its first round leaves, a friend is
## dropped into the line 12 m out. {"rounds": rounds of that first burst, "hits": rounds that hit the friend}.
func _burst(arm: bool) -> Dictionary:
	var saved := TankBrain.LANE_CLEAR
	TankBrain.LANE_CLEAR = arm
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	game_match.seed_spawns(1, 0.0)
	game_match.elimination = true
	var s := AiScenario.new()
	s.case = self
	s.game_match = game_match
	var target := s.dummy(Match.Team.RUST, "Rust_Target_1", Vector3(-100, 0, 10), PI)
	AiScenario.make_durable(target)
	var gun := s.shooter(Match.Team.GREEN, "Green_Gun_1", Vector3(-100, 0, 40), 0.0, {"type": "stop"},
			{"type": "fire_at_will", "long_shot": true}, "ifv")
	var friend := s.dummy(Match.Team.GREEN, "Green_Friend_1", Vector3(-80, 0, 28), 0.0)
	AiScenario.make_durable(friend)
	var rounds := [0, -1]
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		if String(event.get("shooter", "")) != "Green_Gun_1":
			return
		if rounds[1] < 0:
			rounds[1] = game_match.tick
			friend.place(Vector3(-100, 0, 28), 0.0)  # into the line, 12 m out, as the burst starts
		if game_match.tick - rounds[1] < SimClock.TICK_RATE:  # the first burst only (0.36 s of rounds; reload 1.8 s)
			rounds[0] += 1)
	var hits := [0]
	game_match.friendly_fire.connect(func(_victim: Tank, shooter: String, _hull: int, _killed: bool) -> void:
		if shooter == "Green_Gun_1":
			hits[0] += 1)
	await s.start()
	for tick in SimClock.TICK_RATE * 4:
		await s.step()
	TankBrain.LANE_CLEAR = saved
	game_match.free()
	return {"rounds": rounds[0], "hits": hits[0], "fired": rounds[1] >= 0}


func test_a_friend_entering_the_line_ends_the_burst() -> void:
	var off := await _burst(false)
	var on := await _burst(true)
	print("MEASURE lane_burst off rounds %d hits %d | on rounds %d hits %d" % [off["rounds"], off["hits"], on["rounds"], on["hits"]])
	assert_true(bool(off["fired"]) and bool(on["fired"]), "setup: the gun fires in both arms")
	assert_eq(int(off["rounds"]), 4, "OFF (today): the burst is committed, all four rounds go")
	assert_eq(int(on["rounds"]), 1, "ON: the friend in the line ends the burst after its first round")
	# The first round was fired with the line clear and is already in flight when the friend is dropped into it: only it may
	# hit (OFF: all four).
	assert_true(int(on["hits"]) <= 1, "no round fired after the friend entered the line hits him (%d hits)" % on["hits"])


## Seed 11922 of Bar L1 as the probe placed it (Terminus; a law_ifv under his attack on a syn_scout 27 m off; three
## squadmates parked, Guns_2 near the line): 5 friendly hits on fa9c6ff3a. With both parts: none.
func test_bar_l1_seed_11922_hits_no_friend() -> void:
	var lab := TacticsLab.create(self, 11922, "terminus")
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var crew := lab.unit(Match.Team.GREEN, "Green_Hunters_1", Vector3(-81.8, 0, -84.0), -2.194, "law_ifv")
	for spot: Array in [[-72.2, -78.0, -2.009, "Green_Guns_1"], [-71.9, -70.1, -2.81, "Green_Guns_2"], [-61.5, -78.0, -2.937, "Green_Guns_3"]]:
		var friend := lab.gun(Match.Team.GREEN, String(spot[3]), Vector3(float(spot[0]), 0, float(spot[1])), float(spot[2]), "tank")
		game_match.brains.get_node("Orders_" + String(friend.name)).set_orders({"type": "stop"}, {"type": "hold_fire"})
	var target := lab.gun(Match.Team.RUST, "Rust_Eyes_3", Vector3(-59.9, 0, -68.3), 0.948, "syn_scout")
	var hits := [0]
	var shots := [0]
	game_match.friendly_fire.connect(func(_victim: Tank, shooter: String, _hull: int, _killed: bool) -> void:
		if shooter == "Green_Hunters_1":
			hits[0] += 1)
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		if String(event.get("shooter", "")) == "Green_Hunters_1":
			shots[0] += 1)
	await lab.start()
	for i in 3:
		await lab.step()
	lab.orders.call("issue", {"units": ["Green_Hunters_1"], "verb": "attack", "target": String(target.name), "source": "player"})
	for tick in SimClock.TICK_RATE * 30:
		await lab.step()
		if not crew.is_alive() or not target.is_alive():
			break
	print("MEASURE lane_11922 rounds %d friendly hits %d (fa9c6ff3a: 5)" % [shots[0], hits[0]])
	assert_true(shots[0] > 0, "setup: the crew fights (%d rounds)" % shots[0])
	assert_eq(hits[0], 0, "no round into a squadmate")
