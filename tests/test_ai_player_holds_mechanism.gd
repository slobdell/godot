extends TestCase
## Lesson 47 (round 6): the player's units hold until ordered, asserted as a MECHANISM. The round-5 test asserted the
## outcome (the unit ended near where it spawned) and passed for rounds while nothing enforced it: a held unit sat still
## only because a range heuristic happened to return "stop", and when CP4 changed ranges it held 21 s and then flanked.
## Here the brain is watched every tick: while it holds a player's post and nobody is shooting at it, it issues no move
## order at all — it may turn and shoot. The CPU control (same fight, no player) must move, or this test proves nothing.
## Do not "simplify" this back to a distance check: a unit that could not move at all would also end 0 m away, and do not
## "fix" a failure by restoring a range comparison in _combat_move — that restores the luck, not the rule (lesson 47).


func _run(player_holds: bool) -> Dictionary:
	var s := AiScenario.create(self, 4)
	if player_holds:
		s.game_match.set_meta("player_team", Match.Team.GREEN)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 40), PI)
	AiScenario.make_durable(me)
	# An enemy in plain sight, inside the gun's band, that never shoots: nothing here puts the unit under fire, so
	# nothing here licenses it to move.
	var target := s.dummy(Match.Team.RUST, "Rust_A_1", Vector3(-100, 0, 0), 0.0)
	AiScenario.make_durable(target)
	var brain := s.brain_of(me)
	var start := me.global_position
	var moves := 0
	await s.start()
	for tick in SimClock.TICK_RATE * 15:
		await s.step()
		if String(brain.move_order.get("type", "")) == "move_to":
			moves += 1
	var result := {"moves": moves, "moved_m": start.distance_to(me.global_position), "shots": s.shots_by(me),
			"refused": brain.held_moves_refused}
	s.dispose()
	return result


func test_a_held_player_unit_never_starts_moving_on_its_own() -> void:
	var held := await _run(true)
	var cpu := await _run(false)
	print("MEASURE ai_player_hold_mechanism held: %s; the same fight on the CPU side: %s" % [held, cpu])
	assert_eq(int(held["moves"]), 0, "not one tick with a move order while it holds the player's post (%d)" % held["moves"])
	assert_true(float(held["moved_m"]) < 2.0, "so it is where the player left it (%.1f m)" % held["moved_m"])
	assert_true(int(held["shots"]) > 0, "and it still fights from there (%d shots)" % held["shots"])
	assert_true(int(cpu["moves"]) > 0, "control: a CPU unit in the same fight does move (%d ticks) — so the rule, not the "
			% cpu["moves"] + "situation, is what kept the held one still")


func test_the_rule() -> void:
	assert_true(not TankBrain.held_may_move("ENGAGE", false, false), "no flank or advance of its own choosing")
	assert_true(not TankBrain.held_may_move("FLANK", true, false), "not even under fire: a flank is not cover")
	assert_true(TankBrain.held_may_move("TAKE_COVER", true, false), "under fire it may take cover")
	assert_true(not TankBrain.held_may_move("TAKE_COVER", false, false), "but not wander off to cover when nobody shoots")
	assert_true(TankBrain.held_may_move("ENGAGE", true, true), "an escape the brain marks to_safety, under fire")
	assert_true(TankBrain.held_may_move("REGROUP", false, false), "and it may always go back to its post")
