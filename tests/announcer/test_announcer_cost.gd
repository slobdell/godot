extends TestCase
## Round 16 (booth B6): the booth's own cost per physics tick at his army size. The brief's budget is 0.1 ms a frame
## for the booth and the voice on his laptop; this times the booth's tick (the adapter's poll, the mood, the director)
## on a 26 v 26 match whose hulls keep changing, and prints the number for the brief's Status. The assert is the
## budget with the laptop's ~2.75× and a shared machine's noise allowed for, so it catches a regression by an order
## of magnitude, not a wobble.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const PER_SIDE := 26
const TICKS := 600


func _army(name: String) -> Dictionary:
	var squads: Array = []
	for squad in PER_SIDE / 2:
		squads.append({"name": "%s%d" % [name, squad], "units": [{"unit": "tank"}, {"unit": "scout"}]})
	return {"name": name, "squads": squads}


func test_the_booth_costs_well_under_a_tenth_of_a_millisecond_a_tick() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _army("G")), "", "setup: green")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _army("R")), "", "setup: rust")
	game_match.elimination = true
	var booth := AnnouncerBooth.new()
	booth.game_match = game_match
	booth.history_path = "off"
	booth.setup("foundry", 3)
	booth.set_physics_process(false)  # driven by hand below, so the clock measures only the booth
	booth.set_process(false)
	game_match.add_child(booth)
	var tanks: Array = game_match.tanks.get_children()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spent := 0
	var worst := 0
	for tick in TICKS:
		game_match.tick += 1
		# A firefight: a few hulls change every tick (damage events, close calls, the nearest-enemy search).
		for hit in 3:
			var tank: Tank = tanks[rng.randi() % tanks.size()]
			if tank.is_alive() and tank.health > 40:
				tank.health -= 7
		var start := Time.get_ticks_usec()
		booth._physics_process(1.0 / Engine.physics_ticks_per_second)
		var took := Time.get_ticks_usec() - start
		spent += took
		worst = maxi(worst, took)
	var parts := {"poll": 0, "mood": 0, "director": 0}
	for tick in TICKS:
		game_match.tick += 1
		for hit in 3:
			var tank: Tank = tanks[rng.randi() % tanks.size()]
			if tank.is_alive() and tank.health > 40:
				tank.health -= 7
		var t0 := Time.get_ticks_usec()
		var events := booth.adapter.poll()
		var t1 := Time.get_ticks_usec()
		for event in events:
			booth.mood.push_event(event)
		booth.mood.advance(booth.adapter.seconds())
		var t2 := Time.get_ticks_usec()
		for event in events:
			booth.director.push_event(event)
		booth.director.advance(booth.adapter.seconds())
		var t3 := Time.get_ticks_usec()
		parts["poll"] += t1 - t0
		parts["mood"] += t2 - t1
		parts["director"] += t3 - t2
	print("BOOTH_PARTS %s" % [parts])
	var mean_ms := spent / 1000.0 / TICKS
	print("BOOTH_COST mean_ms=%.4f worst_ms=%.3f ticks=%d units=%d cues=%d" % [mean_ms, worst / 1000.0, TICKS,
			tanks.size(), booth.director.cues.size()])
	assert_true(booth.director.cues.size() > 0, "the booth was talking while it was timed")
	assert_true(mean_ms < 0.3, "the booth's tick costs %.4f ms on average (budget 0.1 ms on his laptop)" % mean_ms)
