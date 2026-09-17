extends TestCase
## Round-3 X1 (_agents/streams/archive/round3/ai.md): orders always win. The lead: *"the units just don't feel controllable right now,
## they seem to get stuck in some particular state and then not respond to my clicks; units within the same squad
## ended up getting separated and didn't rejoin."* Orders come through K1 (AiScenario.orders()). Open ground west of
## the walls (x ≈ -100) unless a scenario needs cover.

const PENDING := []
## K1 response guarantee: a brain starts executing a new order within this many ticks.
const RESPONSE_TICKS := 3


func _issue(orders: Object, units: Array, verb: String, extra := {}) -> void:
	var command := {"units": units.map(func(t: Tank) -> String: return String(t.name)), "verb": verb, "queue": false}
	command.merge(extra, true)
	var error: String = orders.call("issue", command)
	assert_eq(error, "", "order accepted: %s" % [command])


## Whether `brain` is carrying out a move to `goal`: its choice is MOVE and its standing move order points there.
static func _executing_move(brain: TankBrain, goal: Vector3) -> bool:
	if brain.choice.get("option", "") != "MOVE":
		return false
	var move := brain.move_order
	if move.get("type") == "stop":
		return Vector2(brain.tank.global_position.x - goal.x, brain.tank.global_position.z - goal.z).length() <= TankBrain.ORDER_ARRIVE
	return move.get("type") == "move_to" and Vector2(float(move["x"]) - goal.x, float(move["z"]) - goal.z).length() < 0.5


func test_a_move_order_is_executed_within_3_ticks_whatever_the_brain_was_doing() -> void:
	# A 4 v 4 brawl in the open: brains on both sides pick all sorts of options. Every 1.5 s one Green unit gets a move
	# order to a fresh spot; the response time and the option it interrupted are recorded.
	var s := AiScenario.create(self, 3)
	var greens: Array[Tank] = []
	for i in 4:
		greens.append(s.brain_tank(Match.Team.GREEN, "Green_A_%d" % (i + 1), Vector3(-100 + i * 10, 0, 40), 0.0, {},
				["tank", "ifv", "scout", "tank"][i]))
		s.brain_tank(Match.Team.RUST, "Rust_A_%d" % (i + 1), Vector3(-100 + i * 10, 0, -10), PI, {}, ["tank", "ifv", "scout", "ifv"][i])
	for tank in greens:
		# Hurt (retreats and cover are in the mix) but sturdy enough to outlive the orders whatever the weapons do.
		tank.max_health *= 4
		tank.health = roundi(tank.max_health * 0.4)
	var orders := s.orders()
	await s.start()
	var interrupted := {}
	var worst := 0
	var missed := 0
	var issued := 0
	for round_index in 14:
		for tick in 90:
			await s.step()
		var tank: Tank = null
		for offset in greens.size():
			var candidate := greens[(round_index + offset) % greens.size()]
			if candidate.is_alive():
				tank = candidate
				break
		if tank == null:
			break
		var brain := s.brain_of(tank)
		var was: String = brain.choice.get("option", "")
		var goal := Vector3(-110 + (round_index * 37) % 40, 0, 50 - (round_index * 23) % 70)
		_issue(orders, [tank], "move", {"to": [goal.x, goal.z]})
		issued += 1
		var took := -1
		for tick in range(1, 11):
			await s.step()
			if _executing_move(brain, goal):
				took = tick
				break
		interrupted[was] = took if took < 0 else maxi(int(interrupted.get(was, 0)), took)
		if took < 0:
			missed += 1
		else:
			worst = maxi(worst, took)
	print("MEASURE ai_order_response worst %d ticks over %d orders (%d missed); interrupted options (worst ticks, -1 = missed) %s" % [
			worst, issued, missed, interrupted])
	assert_true(issued >= 6, "enough orders landed on living units (%d)" % issued)
	assert_true(missed == 0 and worst <= RESPONSE_TICKS, "every order executed within %d ticks (worst %d, missed %d: %s)" % [
			RESPONSE_TICKS, worst, missed, interrupted])


func test_a_moved_unit_arrives_and_its_order_completes() -> void:
	var s := AiScenario.create(self)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 60), 0.0)
	var orders := s.orders()
	await s.start()
	_issue(orders, [me], "move", {"to": [-80.0, 10.0]})
	var arrived := -1
	for tick in SimClock.TICK_RATE * 20:
		await s.step()
		if (orders.call("current", String(me.name)) as Dictionary).is_empty():
			arrived = tick
			break
	var gap := Vector2(me.global_position.x + 80.0, me.global_position.z - 10.0).length()
	print("MEASURE ai_order_arrival completed after %.1f s, %.1f m from the spot" % [arrived / float(SimClock.TICK_RATE), gap])
	assert_true(arrived > 0, "the move completed")
	assert_true(gap <= TankBrain.ORDER_ARRIVE + 0.5, "it stopped on its spot (%.1f m off)" % gap)


func test_attack_move_fights_on_the_way_then_arrives() -> void:
	var s := AiScenario.create(self)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 70), 0.0)
	AiScenario.make_durable(me)
	# A scout parked beside the route, facing away: easy prey met on the way.
	var prey := s.dummy(Match.Team.RUST, "Rust_Scout_1", Vector3(-88, 0, 10), 0.0, "scout")
	var orders := s.orders()
	await s.start()
	_issue(orders, [me], "attack_move", {"to": [-100.0, -60.0]})
	var done := -1
	for tick in SimClock.TICK_RATE * 45:
		await s.step()
		if (orders.call("current", String(me.name)) as Dictionary).is_empty():
			done = tick
			break
	var gap := Vector2(me.global_position.x + 100.0, me.global_position.z + 60.0).length()
	print("MEASURE ai_attack_move shots %d, prey alive %s (hull %d), arrived after %.1f s, %.1f m off" % [s.shots_by(me),
			prey.is_alive(), prey.health, done / float(SimClock.TICK_RATE), gap])
	assert_true(not prey.is_alive(), "the enemy met on the way was destroyed")
	assert_true(done > 0 and gap <= TankBrain.ORDER_ARRIVE + 0.5, "then it carried on and arrived (%.1f m off)" % gap)


func test_attack_fights_only_the_ordered_target() -> void:
	var s := AiScenario.create(self)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 40), 0.0, {}, "ifv")
	var near := s.dummy(Match.Team.RUST, "Rust_Near_1", Vector3(-104, 0, 5), PI)
	var far := s.dummy(Match.Team.RUST, "Rust_Far_1", Vector3(-90, 0, -12), PI, "ifv")
	AiScenario.make_durable(near)
	AiScenario.make_durable(far)
	var orders := s.orders()
	await s.start()
	_issue(orders, [me], "attack", {"target": String(far.name)})
	var controller := s.controller_of(me)
	var on_far := 0
	var on_near := 0
	for tick in SimClock.TICK_RATE * 8:
		await s.step()
		if controller.engaged_target == far.name:
			on_far += 1
		elif controller.engaged_target == near.name:
			on_near += 1
	print("MEASURE ai_attack_target ordered target %d ticks, nearer enemy %d ticks" % [on_far, on_near])
	assert_true(on_far > 60 and on_far > 4 * on_near, "its fire goes to the ordered target (%d vs %d ticks)" % [on_far, on_near])


func test_hold_stays_put_but_still_turns_and_shoots() -> void:
	var s := AiScenario.create(self)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 30), 0.0)
	AiScenario.make_durable(me)
	var spot := me.global_position
	var orders := s.orders()
	await s.start()
	_issue(orders, [me], "hold", {"to": [spot.x, spot.z]})
	for tick in 30:
		await s.step()
	# An enemy shows up behind it, well in range, then another shoots at it from the side.
	var behind := s.shooter(Match.Team.RUST, "Rust_Gun_1", Vector3(-100, 0, 70), PI)
	AiScenario.make_durable(behind)
	var worst_drift := 0.0
	for tick in SimClock.TICK_RATE * 12:
		await s.step()
		worst_drift = maxf(worst_drift, Vector2(me.global_position.x - spot.x, me.global_position.z - spot.z).length())
	var facing := -me.global_basis.z
	print("MEASURE ai_hold drift %.1f m, shots %d, hull facing (%.2f, %.2f)" % [worst_drift, s.shots_by(me), facing.x, facing.z])
	assert_true(worst_drift <= TankBrain.HOLD_TOLERANCE + 1.0, "it holds its spot (drifted %.1f m)" % worst_drift)
	assert_true(s.shots_by(me) >= 2, "and fights from there (%d shots)" % s.shots_by(me))


func test_follow_keeps_station_on_a_moving_friend() -> void:
	var s := AiScenario.create(self)
	var lead := s.shooter(Match.Team.GREEN, "Green_Lead_1", Vector3(-100, 0, 80), 0.0,
			{"type": "move_to", "x": -100.0, "z": -80.0, "speed": 0.6}, {"type": "hold_fire"}, "ifv")
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-80, 0, 95), 0.0)
	var orders := s.orders()
	await s.start()
	_issue(orders, [me], "follow", {"target": String(lead.name)})
	var close_ticks := 0
	var counted := 0
	var worst := 0.0
	for tick in SimClock.TICK_RATE * 20:
		await s.step()
		if tick < SimClock.TICK_RATE * 6:
			continue  # catching up
		counted += 1
		var gap := Vector2(me.global_position.x - lead.global_position.x, me.global_position.z - lead.global_position.z).length()
		worst = maxf(worst, gap)
		if gap <= TankBrain.FOLLOW_DISTANCE + 8.0:
			close_ticks += 1
	var share := float(close_ticks) / maxf(counted, 1)
	print("MEASURE ai_follow within %.0f m %.0f%% of the time, worst gap %.1f m" % [TankBrain.FOLLOW_DISTANCE + 8.0, share * 100.0, worst])
	assert_true(share >= 0.85, "it keeps station behind the friend (%.0f%%)" % (share * 100.0))


func test_an_idle_unit_pushed_off_its_post_regroups() -> void:
	var s := AiScenario.create(self)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 60), 0.0)
	var orders := s.orders()
	await s.start()
	_issue(orders, [me], "move", {"to": [-100.0, 40.0]})
	for tick in SimClock.TICK_RATE * 8:
		await s.step()
	assert_true((orders.call("current", String(me.name)) as Dictionary).is_empty(), "setup: the move finished")
	# Separated from its post (as if it chased something), no personal order: it goes back on its own.
	me.global_position = Vector3(-60, 0, 0)
	var back := -1
	for tick in SimClock.TICK_RATE * 20:
		await s.step()
		if Vector2(me.global_position.x + 100.0, me.global_position.z - 40.0).length() <= 6.0:
			back = tick
			break
	print("MEASURE ai_regroup back at its post after %.1f s" % (back / float(SimClock.TICK_RATE)))
	assert_true(back > 0, "it rejoined its post")


func test_no_option_is_kept_forever() -> void:
	var s := AiScenario.create(self)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 60), 0.0)
	await s.start()
	var brain := s.brain_of(me)
	var now := s.game_match.tick
	brain.choice = {"option": "COVER_FIRE", "target": "Rust_A_1", "since": now - 60}
	brain.ticks_since_fire = 30
	assert_eq(brain._timed_out(), "", "a fight that keeps shooting is fine")
	brain.ticks_since_fire = TankBrain.OPTION_TIMEOUT_TICKS["COVER_FIRE"] + 10
	brain.choice["since"] = now - 2000
	assert_eq(brain._timed_out(), "COVER_FIRE", "hiding with no shot for 10 s times out")
	brain.choice = {"option": "TAKE_COVER", "target": "", "since": now - 30}
	brain.move_order = {"type": "move_to", "x": 0.0, "z": 0.0}
	brain.stalled_ticks = TankBrain.STALL_TICKS
	assert_eq(brain._timed_out(), "TAKE_COVER", "a move that makes no progress for 3 s times out")
	brain.choice = {"option": "MOVE", "target": "", "since": now - 5000}
	assert_eq(brain._timed_out(), "", "a player's order never times out")


func test_queued_orders_run_in_order() -> void:
	var s := AiScenario.create(self)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 60), 0.0, {}, "ifv")
	var orders := s.orders()
	await s.start()
	_issue(orders, [me], "move", {"to": [-100.0, 30.0]})
	_issue(orders, [me], "move", {"to": [-80.0, 30.0], "queue": true})
	var passed_first := false
	for tick in SimClock.TICK_RATE * 25:
		await s.step()
		if Vector2(me.global_position.x + 100.0, me.global_position.z - 30.0).length() <= 5.0:
			passed_first = true
		if (orders.call("current", String(me.name)) as Dictionary).is_empty():
			break
	var gap := Vector2(me.global_position.x + 80.0, me.global_position.z - 30.0).length()
	assert_true(passed_first, "it went to the first waypoint")
	assert_true(gap <= TankBrain.ORDER_ARRIVE + 0.5, "then to the queued one (%.1f m off)" % gap)
