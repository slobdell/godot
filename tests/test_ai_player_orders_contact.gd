extends "res://tests/ai_scenarios/player_orders_case.gd"
## Round 31 (C31.9 / R31.9): split from one slow file; what its tests share is in player_orders_case.gd.


## The invariant (ruled 2026-09-17 after the lead's playtest): **a player's order outranks autonomy.** A unit ordered
## across a fight goes, and keeps going, however tempting the targets on the way. It may shoot while it drives and step
## around a wall of bullets, but it may not decide to stop and fight instead of arriving.
func test_a_unit_ordered_across_contact_arrives() -> void:
	add_to_tree(ARENA.instantiate())
	_match = add_to_tree(MATCH.instantiate())
	_match.seed_spawns(11, 0.0)
	_match.elimination = true
	_match.set_meta("player_team", Match.Team.GREEN)
	_orders = Orders.new(_match)
	Orders.attach(_match, _orders)
	var mover := _match.add_brain_tank(Match.Team.GREEN, "Alpha", "tank", [{}], "Green_A_1")
	mover.global_position = Vector3(-100, 0, 80)
	mover.rotation.y = PI
	mover.max_health = 100000  # the question is whether it arrives, not whether it survives
	mover.health = mover.max_health
	# Two enemies beside the route, close enough to shoot it the whole way.
	for i in 2:
		var gun := _match.add_brain_tank(Match.Team.RUST, "Guns", "tank", [{}], "Rust_G_%d" % (i + 1))
		gun.global_position = Vector3(-55.0, 0.0, 40.0 - i * 40.0)
		gun.max_health = 100000
		gun.health = gun.max_health
	await wait_physics_frames(SimClock.TICK_RATE)
	var goal := Vector3(-100, 0, -60)
	assert_eq(_orders.issue({"units": ["Green_A_1"], "verb": "move", "to": [goal.x, goal.z], "source": "player"},
			Match.Team.GREEN), "", "the order is accepted")
	var options := {}
	var arrived_after := -1.0
	for tick in SimClock.TICK_RATE * 40:
		await wait_physics_frames(1)
		var brain := _match.brains.get_node_or_null("Brain_Green_A_1") as TankBrain
		var option := String(brain.choice.get("option", ""))
		# What it chose WHILE carrying the player's order: once the order is finished it is free to fight from the
		# ground it was given (inside TankBrain.PLAYER_POST_LEASH of it), which the gap below holds it to.
		if not _orders.current("Green_A_1").is_empty():
			options[option] = int(options.get(option, 0)) + 1
		if arrived_after < 0.0 and Vector3(mover.global_position.x, 0.0, mover.global_position.z).distance_to(goal) <= 6.0:
			arrived_after = SimClock.seconds(tick)
	var gap := Vector3(mover.global_position.x, 0.0, mover.global_position.z).distance_to(goal)
	print("MEASURE ordered_across_contact arrived after %.1f s, %.0f m from the spot 40 s later; while it carried the order it spent its time on %s" % [
			arrived_after, gap, options])
	assert_true(arrived_after >= 0.0, "a unit ordered across a fight arrives (%.0f m short after 40 s)" % gap)
	for option: String in options:
		assert_true(["MOVE", "", "HOLD"].has(option),
				"and nothing else takes the wheel on the way: it spent %d ticks on %s" % [options[option], option])
	assert_true(gap <= TankBrain.PLAYER_POST_LEASH,
			"and it fights from the ground it was given rather than wandering off (%.0f m away)" % gap)
