extends TestCase
## Round 42, manoeuvre Q6 (C42.4; `--traffic-on=deckwait`, Traffic.DEFAULT_OFF until its bar is judged): the bridge rim crew. A
## WHEELED crew whose route turns at a bridge deck's mouth, with a friend ahead in its lane that is in that turn, lowers its SPEED
## WISH to a following speed before ORCA solves (speed only: ORCA's direction and steer point are its own answer to the lower wish);
## after WAIT_CAP_S on one friend it wishes for today's speed again. Tracked hulls, open ground, street corners that are not a deck's
## mouth and a clear lane are untouched. Q2's wait members carry the state; `wait` and `deckwait` are exclusive.
## Forward is -Z (trip-up 2); yaw -PI/2 faces +x (east). The Locks' east swing bridge: deck x 85..99, z -12..12 (the canal z -7..7).

var _lab: TacticsLab


func teardown() -> void:
	Movement.avoidance_on = true
	Traffic.set_off("deckwait", Traffic.DEFAULT_OFF.has("deckwait"))
	Traffic.set_off("wait", Traffic.DEFAULT_OFF.has("wait"))
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## My crew: a Law tank (wheels, 8 m turn radius) on the north bank 20 m west of the deck's mouth, facing east, ordered across the
## deck to the south bank. The friend: another Law tank in the mouth (by default facing south, parked unless ordered). Returns
## [me, friend].
func _stage(friend_order: Dictionary, friend_at := Vector3(87.5, 0.0, -8.5), friend_yaw := PI) -> Array:
	_lab = TacticsLab.create(self, 7, "locks")
	var me := _lab.gun(Match.Team.GREEN, "Green_Me", Vector3(66.0, 0.0, -10.0), -PI / 2.0, "law_tank")
	var friend := _lab.gun(Match.Team.GREEN, "Green_Friend", friend_at, friend_yaw, "law_tank")
	await _lab.start()
	if not friend_order.is_empty():
		Movement.of(friend).ctl.set_orders(friend_order, {"type": "fire_at_will"})
	Movement.of(me).ctl.set_orders({"type": "move_to", "x": 88.0, "z": 20.0}, {"type": "fire_at_will"})
	return [me, friend]


func test_off_by_default() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("deckwait"), "Q6 is opt-in until judged")


## The mouth test reads the live arena's decks: on the Locks the deck's west mouth is in, the bank 20 m west of it is not; on a
## map with no decks nothing is.
func test_a_deck_mouth_is_the_deck_grown_by_the_reach() -> void:
	_lab = TacticsLab.create(self, 7, "locks")
	await _lab.start()
	assert_true(Movement._in_a_deck_mouth(Vector3(86.0, 0.0, -10.5)), "the deck's north-west corner is the mouth")
	assert_true(Movement._in_a_deck_mouth(Vector3(86.3, 0.0, 11.7)), "and its south-west corner (the exit)")
	assert_true(Movement._in_a_deck_mouth(Vector3(92.0, 0.0, -16.0)), "the apron just north of the deck is in the mouth")
	assert_true(not Movement._in_a_deck_mouth(Vector3(92.0, 0.0, 0.0)), "over the water the crossing is under way: not the mouth")
	assert_true(not Movement._in_a_deck_mouth(Vector3(66.0, 0.0, -10.0)), "the bank 20 m west is not")
	assert_true(not Movement._in_a_deck_mouth(Vector3(0.0, 0.0, 40.0)), "nor the middle of the south half")
	_lab.dispose()
	_lab = TacticsLab.create(self, 7, "yard_open")
	await _lab.start()
	assert_true(not Movement._in_a_deck_mouth(Vector3.ZERO), "a map with no decks has no mouths")


## Live, the rim crew's case: a friend drives the deck slowly ahead of me. OFF, I arrive at the mouth at speed and ORCA carries my
## steer point out past it; ON, my speed wish follows the friend while it is in the mouth (queued ticks), and I still cross.
func test_on_follows_a_slow_friend_into_the_mouth() -> void:
	var out := {}
	for arm in ["off", "on"]:
		Traffic.set_off("deckwait", arm == "off")
		# The leader as the trace had it: on the apron facing east, still to make its 8 m turn south, slowly.
		var staged: Array = await _stage({"type": "move_to", "x": 88.0, "z": 20.0, "speed": 0.25}, Vector3(85.0, 0.0, -11.0), -PI / 2.0)
		var me := staged[0] as Tank
		var mover := Movement.of(me)
		Movement.reset_route_arms()
		var east_most := -INF
		var deflected_ticks := 0
		var fastest_in_mouth := 0.0
		var crossed_tick := -1
		for i in 30 * SimClock.TICK_RATE:
			await _lab.step()
			var here := me.global_position
			if here.z < -7.0 and here.x > 80.0:
				east_most = maxf(east_most, here.x)
				fastest_in_mouth = maxf(fastest_in_mouth, me.real_velocity.length())
				if mover._deflected:
					deflected_ticks += 1
			if here.z > 12.0 and crossed_tick < 0:
				crossed_tick = i
				break
		var arms := Movement.route_arms()
		out[arm] = {"east_most": snappedf(east_most, 0.1), "deflected": deflected_ticks, "fastest_in_mouth": snappedf(fastest_in_mouth, 0.1),
				"crossed_s": snappedf(crossed_tick / float(SimClock.TICK_RATE), 0.1) if crossed_tick >= 0 else -1.0,
				"queued": int(arms["deckwait_queued"]), "waits": int(arms["deckwait_waits"]), "timeouts": int(arms["deckwait_timeouts"])}
		print("MEASURE deckwait %s: %s" % [arm, out[arm]])
		_lab.dispose()
		_lab = null
	assert_eq(int(out["off"]["queued"]), 0, "OFF never queues")
	assert_true(int(out["on"]["queued"]) > 0, "ON queued behind the friend in the mouth: %s" % out["on"])
	assert_true(float(out["on"]["crossed_s"]) > 0.0, "ON still crosses within 30 s: %s" % out["on"])
	# Whether the follower is better off waiting on a slow leader in the mouth than passing it is the drill's question (Bar Q6),
	# not this test's: here the staged leader crawls at 3 m/s and ON costs the cap twice (printed above), as the rule says it should.


## A parked head: the friend sits in the mouth and never moves. ON, I wait WAIT_CAP_S on it and then wish for today's speed again
## (a time-out, the friend refused for WAIT_COOLDOWN_S), so a head that never clears is passed as today.
func test_a_head_that_never_clears_is_passed_after_the_cap() -> void:
	Traffic.set_off("deckwait", false)
	var staged: Array = await _stage({})
	var me := staged[0] as Tank
	var mover := Movement.of(me)
	Movement.reset_route_arms()
	var first_wait := -1
	var released := -1
	for i in 20 * SimClock.TICK_RATE:
		await _lab.step()
		if i % 6 == 0 and i < 12 * SimClock.TICK_RATE:
			var leader := mover._lane_friend(me.global_position, Vector2(-me.global_basis.z.x, -me.global_basis.z.z))
			print("DECKWAIT_TRACE t=%d at=(%.1f,%.1f) v=%.1f phase=%s wait_for=%s since=%d leader=%s steer=%s" % [
					i, me.global_position.x, me.global_position.z, me.real_velocity.length(), mover.phase, mover._wait_for, mover._wait_since,
					leader.name if leader != null else "-", Movement.state(me).get("steer_to")])
		if first_wait < 0 and mover._wait_for != "":
			first_wait = i
		if first_wait >= 0 and released < 0 and int(Movement.route_arms()["deckwait_timeouts"]) > 0:
			released = i
			break
	var arms := Movement.route_arms()
	print("MEASURE deckwait parked head: first wait tick %d, released tick %d, queued %d, timeouts %d, refused %s until %d" % [
			first_wait, released, int(arms["deckwait_queued"]), int(arms["deckwait_timeouts"]), mover._wait_refused, mover._wait_refused_until])
	assert_true(first_wait >= 0, "the parked head in the mouth is waited on first")
	assert_true(released >= 0, "and handed back after the cap")
	assert_true(released - first_wait <= int(Movement.DECKWAIT_CAP_S * SimClock.TICK_RATE) + 2, "the cap is DECKWAIT_CAP_S")
	assert_eq(mover._wait_for, "", "the wait ended")
	assert_eq(mover._wait_refused, "Green_Friend", "that friend is refused for the cooldown")


## Untouched cases: a tracked crew (no wheels) never queues; a clear lane never queues; with `wait` also named, `wait` wins and this
## rule stays off.
func test_tracked_crews_clear_lanes_and_the_wait_switch_leave_it_off() -> void:
	Traffic.set_off("deckwait", false)
	_lab = TacticsLab.create(self, 7, "locks")
	var me := _lab.gun(Match.Team.GREEN, "Green_Me", Vector3(70.0, 0.0, -10.0), -PI / 2.0, "tank")
	var friend := _lab.gun(Match.Team.GREEN, "Green_Friend", Vector3(87.5, 0.0, -8.5), PI, "law_tank")
	await _lab.start()
	Movement.of(me).ctl.set_orders({"type": "move_to", "x": 88.0, "z": 20.0}, {"type": "fire_at_will"})
	Movement.reset_route_arms()
	for i in 4 * SimClock.TICK_RATE:
		await _lab.step()
	assert_eq(int(Movement.route_arms()["deckwait_queued"]), 0, "a tracked crew is not a wheeled follower")
	assert_true(friend.is_alive(), "the friend stood")
	_lab.dispose()
	_lab = null
	var staged: Array = await _stage({}, Vector3(60.0, 0.0, 30.0), PI)
	Movement.reset_route_arms()
	for i in 4 * SimClock.TICK_RATE:
		await _lab.step()
	assert_eq(int(Movement.route_arms()["deckwait_queued"]), 0, "a clear lane at the mouth never queues (friend %s)" % staged[1].global_position)
	_lab.dispose()
	_lab = null
	Traffic.set_off("wait", false)
	staged = await _stage({})
	Movement.reset_route_arms()
	for i in 4 * SimClock.TICK_RATE:
		await _lab.step()
	assert_eq(int(Movement.route_arms()["deckwait_queued"]), 0, "with `wait` named too, `wait` wins")


## The timer artefact (round 41's known issue): a wait begun in the mouth ends on the first drive tick that does not weigh it (here:
## a new order to a goal within reach), so `_wait_since` never carries across a gap.
func test_a_wait_ends_on_a_tick_that_never_weighs_it() -> void:
	Traffic.set_off("deckwait", false)
	var staged: Array = await _stage({})
	var me := staged[0] as Tank
	var mover := Movement.of(me)
	var waited := false
	for i in 8 * SimClock.TICK_RATE:
		await _lab.step()
		if mover._wait_for != "":
			waited = true
			break
	assert_true(waited, "the parked head in the mouth is waited on")
	# Avoidance off for a tick: the drive runs and never weighs the wait; it must not linger with its timer running.
	Movement.avoidance_on = false
	await _lab.step()
	Movement.avoidance_on = true
	assert_eq(mover._wait_for, "", "a tick that never weighed the wait ended it")
	assert_eq(mover._wait_since, -1, "and its timer")
