extends TestCase
## X6 (nav, round 6): N6's first job — a unit keeping its place in a moving formation. The lead: *"intuitively a PID
## loop would conceptually be useful for a unit trying to get back in his formation."* A slot rides along at 5 m/s,
## re-issued a few times a second the way a brain does; the follower should sit in it at the slot's speed, not
## drive-and-stop behind it.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## The open spawn apron behind foundry's green line.
const START := Vector3(-60, 0, 102)
const SLOT_SPEED := 5.0


func _run(station: bool) -> Dictionary:
	var arena := await ArenaFixture.build(self, "foundry")  # its OWN navmesh (tests/support/arena_fixture.gd)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Follower", 0, Match.Team.GREEN)
	tank.global_position = START
	tank.rotation.y = -PI / 2.0  # facing +x
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	var was := Movement.station_on
	Movement.station_on = station
	var gaps: Array[float] = []
	var slowdowns := 0
	var slow := false
	for tick in SimClock.TICK_RATE * 16:
		var slot := START + Vector3(6.0 + SLOT_SPEED * float(tick) / SimClock.TICK_RATE, 0, 0)
		if tick % 4 == 0:  # a brain re-issues its slot a few times a second
			orders.set_orders({"type": "move_to", "x": slot.x, "z": slot.z}, null)
		await tree.physics_frame
		if tick >= SimClock.TICK_RATE * 6:  # settled
			gaps.append(Vector2(slot.x - tank.global_position.x, slot.z - tank.global_position.z).length())
			var now_slow := tank.speed() < SLOT_SPEED * 0.5
			if now_slow and not slow:
				slowdowns += 1
			slow = now_slow
	Movement.station_on = was
	var total := 0.0
	var worst := 0.0
	for gap in gaps:
		total += gap
		worst = maxf(worst, gap)
	for node in [orders, game_match, arena]:
		node.queue_free()
	await wait_physics_frames(2)
	return {"mean_gap": total / gaps.size(), "worst_gap": worst, "slowdowns": slowdowns}


func test_pid_keeps_station_on_a_moving_slot() -> void:
	var p_only: Dictionary = await _run(false)
	var pid: Dictionary = await _run(true)
	print("MEASURE station_keeping p_only %s pid %s" % [p_only, pid])
	assert_true(float(pid["mean_gap"]) < 1.5, "with the PID it sits within 1.5 m of its slot on average (%s)" % pid)
	assert_eq(int(pid["slowdowns"]), 0, "and never drops below half the slot's speed once settled (%s)" % pid)
	assert_true(float(pid["mean_gap"]) < float(p_only["mean_gap"]), "closer than chasing the point (%s vs %s)" % [pid, p_only])


## X8: a slot that drives at SLOT_SPEED and then stops dead. Returns the tracking gap while it moves, how far the hull
## runs past the stopped slot (overshoot), and how long it takes to settle within 1 m of it.
func _drive_and_stop(gains: Dictionary) -> Dictionary:
	var arena := await ArenaFixture.build(self, "foundry")  # its OWN navmesh (tests/support/arena_fixture.gd)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Follower", 0, Match.Team.GREEN)
	tank.global_position = START
	tank.rotation.y = -PI / 2.0
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	orders.movement._station = Pid.new(gains)
	orders.movement._station_faction = String(Units.stat(tank.unit_id, "faction", ""))
	var moving_ticks := SimClock.TICK_RATE * 10
	var gaps := 0.0
	var samples := 0
	var overshoot := 0.0
	var settled_at := -1.0
	var slot := START
	for tick in SimClock.TICK_RATE * 16:
		if tick < moving_ticks:
			slot = START + Vector3(6.0 + SLOT_SPEED * float(tick) / SimClock.TICK_RATE, 0, 0)
		if tick % 4 == 0 or tick == moving_ticks:
			orders.set_orders({"type": "move_to", "x": slot.x, "z": slot.z, "arrive": 0.5}, null)
		await tree.physics_frame
		var ahead := tank.global_position.x - slot.x
		if tick >= SimClock.TICK_RATE * 5 and tick < moving_ticks:
			gaps += absf(ahead)
			samples += 1
		elif tick >= moving_ticks:
			overshoot = maxf(overshoot, ahead)
			if settled_at < 0.0 and absf(ahead) <= 1.0 and absf(tank.speed()) < 0.5:
				settled_at = float(tick - moving_ticks) / SimClock.TICK_RATE
	for node in [orders, game_match, arena]:
		node.queue_free()
	await wait_physics_frames(2)
	return {"gap": snappedf(gaps / maxf(samples, 1), 0.01), "overshoot": snappedf(overshoot, 0.01), "settle_s": snappedf(settled_at, 0.01)}


func test_factions_keep_station_each_in_their_own_way() -> void:
	var results := {}
	for faction: String in ["", "syndicate", "gangs", "law"]:
		results[faction if faction != "" else "default"] = await _drive_and_stop(ControlGains.for_loop("station", faction))
	print("MEASURE station_faction %s" % [results])
	assert_true(float(results["syndicate"]["gap"]) < float(results["default"]["gap"]), "the Syndicate sits tighter in its slot (%s)" % [results])
	assert_true(float(results["gangs"]["overshoot"]) > float(results["default"]["overshoot"]) + 0.3,
			"the gangs swing past a stopping slot (%s)" % [results])
	assert_true(float(results["law"]["overshoot"]) <= float(results["default"]["overshoot"]),
			"the Law never overshoots more than the reference crew (%s)" % [results])
