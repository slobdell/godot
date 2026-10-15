extends "res://tests/ai_scenarios/player_orders_case.gd"
## Round 31 (C31.9 / R31.9): split from one slow file; what its tests share is in player_orders_case.gd.


func test_three_squads_ordered_one_after_another_go_and_stay() -> void:
	var squads := await _setup()
	_match.elimination = true
	var goals := {"Alpha": Vector3(-60, 0, 20), "Bravo": Vector3(0, 0, 20), "Charlie": Vector3(60, 0, 20)}
	var spawned := {}
	for squad_name: String in squads:
		spawned.merge(_positions(squads[squad_name]))
	# The lead's sequence: order a squad, watch it go, order the next.
	for squad_name: String in squads:
		var goal: Vector3 = goals[squad_name]
		var error: String = _orders.issue({"units": squads[squad_name], "verb": "move", "to": [goal.x, goal.z],
				"source": "player"}, Match.Team.GREEN)
		assert_eq(error, "", "squad %s accepts a move order" % squad_name)
		for unit_name: String in squads[squad_name]:
			var given: Dictionary = _orders.current(unit_name)
			_given[unit_name] = OrderFeed.point(given.get("goal")) if not given.is_empty() else null
		await wait_physics_frames(SimClock.TICK_RATE * MOVE_SECONDS)
	# Everyone has now had an order and time to carry it out: this is the mark drift is measured from (the last squad
	# ordered is still driving at the moment the last order goes in, and that journey is not drift).
	await wait_physics_frames(SimClock.TICK_RATE * MOVE_SECONDS)
	var arrived := {}
	for squad_name: String in squads:
		arrived.merge(_positions(squads[squad_name]))
	# Then nobody touches anything.
	await wait_physics_frames(SimClock.TICK_RATE * SETTLE_SECONDS)
	var settled := {}
	for squad_name: String in squads:
		settled.merge(_positions(squads[squad_name]))
	var worst_gap := 0.0
	var worst_drift := 0.0
	var toward_spawn := 0
	for squad_name: String in squads:
		for unit_name: String in squads[squad_name]:
			var goal: Vector3 = _given[unit_name]
			var gap: float = (settled[unit_name] as Vector3).distance_to(goal)
			var drift: float = (settled[unit_name] as Vector3).distance_to(arrived[unit_name])
			var homeward: bool = (settled[unit_name] as Vector3).distance_to(spawned[unit_name]) \
					< (arrived[unit_name] as Vector3).distance_to(spawned[unit_name]) - DRIFT_M
			toward_spawn += 1 if homeward else 0
			worst_gap = maxf(worst_gap, gap)
			worst_drift = maxf(worst_drift, drift)
			print("      %s sent to %v: %.0f m away when the last order went out, %.0f m away after %d s%s" % [
					unit_name, goal, (arrived[unit_name] as Vector3).distance_to(goal), gap, SETTLE_SECONDS,
					", drifting back toward its spawn" if homeward else ""])
	print("MEASURE player_orders worst gap to the spot it was sent %.0f m, worst drift after the orders stopped %.0f m, %d of %d units heading back toward their spawn" % [
			worst_gap, worst_drift, toward_spawn, spawned.size()])
	assert_eq(toward_spawn, 0, "no unit walks back toward its spawn once it has been ordered somewhere")
	assert_true(worst_gap < ARRIVED_M, "every unit is on the slot its squad's order gave it (worst %.0f m)" % worst_gap)
	assert_true(worst_drift < TankBrain.PLAYER_POST_LEASH,
			"and none of them wanders off the ground it was given (worst %.0f m)" % worst_drift)


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
