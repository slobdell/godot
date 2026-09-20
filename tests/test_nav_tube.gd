extends TestCase
## Round 9 (nav, A1 — Tabuada 2007, *Event-Triggered Real-Time Scheduling of Stabilizing Control Tasks*): a route is
## re-planned when the STATE has drifted far enough to make the plan stale, not every `REPATH_SECONDS` regardless.
##
## P1 decomposes as **70% of direction churn being re-planning inside one unchanged decision**. That is a cadence
## problem, not a decision problem, and the smallest mechanism that addresses it is a norm comparison against a radius
## stored when the plan was made.
##
## **The latency test is written FIRST and on purpose** (the brief's instruction, and round 8's cautionary case): the
## hold-hysteresis A/B cut churn 6-22% and still failed its bar. *If churn falls and reaction time rises, this is
## stubbornness wearing a hat and it reverts.* So the first thing asserted is that a unit still reacts in <= 2 ticks.

const MATCH := preload("res://game/match/match.tscn")
const START := Vector3(-100, 0, 60)
const FAR := Vector3(-100, 0, -40)


func _mover(unit_id := "tank") -> Array:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Mover", 0, Match.Team.GREEN, unit_id)
	tank.global_position = START
	tank.rotation.y = 0.0
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	return [tank, ctl]


## A1 is OPT-IN: `--nav-off=a1` turns it ON (`Movement.a1_on()` reads `switched_off("a1")`). The first version of
## this helper had it the other way round and the arm counters came back inverted — which is the whole reason the
## counters exist, and a reminder that a test helper is as capable of lying about the arm as a probe's header is.
static func _tube(on: bool) -> PackedStringArray:
	var was := Movement._off
	Movement._off = PackedStringArray(["a1"]) if on else PackedStringArray()
	Movement._off_parsed = true
	Movement.reset_route_arms()
	return was


## THE LATENCY FALSIFIER, first. A goal that jumps is an EVENT, never gated by the tube: a unit told to go somewhere
## else must be driving somewhere else within 2 ticks, whatever the tube says about its own drift.
func test_a_goal_that_jumps_is_answered_within_two_ticks() -> void:
	var was := _tube(true)
	var made: Array = await _mover()
	var tank: Tank = made[0]
	var ctl: OrderController = made[1]
	assert_eq(ctl.set_orders({"type": "move_to", "x": FAR.x, "z": FAR.z}, {"type": "hold_fire"}), "", "ordered")
	for frame in 90:
		await tree.physics_frame
	var before: Vector3 = Movement.state(tank).get("steer_to", Vector3.ZERO)
	# Somewhere else entirely, at a right angle to the way it is going.
	assert_eq(ctl.set_orders({"type": "move_to", "x": START.x + 90.0, "z": START.z}, {"type": "hold_fire"}), "", "re-ordered")
	var answered := -1
	for tick in 6:
		await tree.physics_frame
		if (Movement.state(tank).get("steer_to", Vector3.ZERO) as Vector3).distance_to(before) > 1.0:
			answered = tick + 1
			break
	Movement._off = was
	assert_true(answered >= 0 and answered <= 2,
			"a new destination is being driven within 2 ticks (took %d)" % answered)


## The point of the row: far fewer plans for the same drive, measured against what the fixed cadence would have done
## on the very same run rather than against a separate one.
func test_a_clear_route_replans_far_less_than_the_fixed_cadence_would() -> void:
	var was := _tube(true)
	var made: Array = await _mover()
	var ctl: OrderController = made[1]
	assert_eq(ctl.set_orders({"type": "move_to", "x": FAR.x, "z": FAR.z}, {"type": "hold_fire"}), "", "ordered")
	for frame in int(SimClock.TICK_RATE * 12):
		await tree.physics_frame
	var arms := Movement.route_arms()
	Movement._off = was
	assert_true(int(arms["a1_cadence_due"]) > 0, "the fixed cadence would have fired (%s)" % arms)
	assert_true(int(arms["a1_tube_skips"]) > 0, "and the tube held instead at least once (%s)" % arms)
	# The pre-registered bar is a 60% cut in re-plans inside one unchanged decision.
	var kept := float(arms["a1_replans"]) / maxf(1.0, float(arms["a1_cadence_due"]))
	assert_true(kept <= 0.4, "re-plans cut by at least 60%% of the cadence's (%.2f of them, %s)" % [kept, arms])


## Events are not gated by the tube: a hull shoved off its route re-plans whatever its drift budget says.
func test_a_hull_pushed_off_its_route_still_replans() -> void:
	var was := _tube(true)
	var made: Array = await _mover()
	var tank: Tank = made[0]
	var ctl: OrderController = made[1]
	assert_eq(ctl.set_orders({"type": "move_to", "x": FAR.x, "z": FAR.z}, {"type": "hold_fire"}), "", "ordered")
	for frame in 60:
		await tree.physics_frame
	var before := int(Movement.route_arms()["a1_replans"])
	tank.global_position += Vector3(Movement.OFF_PATH_REPATH + 4.0, 0.0, 0.0)
	for frame in 4:
		await tree.physics_frame
	var after := int(Movement.route_arms()["a1_replans"])
	Movement._off = was
	assert_true(after > before, "off-path is an event, not a drift budget (%d -> %d)" % [before, after])


## The arm, provable from outside (lesson 147).
func test_the_arm_counter_distinguishes_the_tube_from_the_cadence() -> void:
	var was := _tube(false)
	var made: Array = await _mover()
	var ctl: OrderController = made[1]
	assert_eq(ctl.set_orders({"type": "move_to", "x": FAR.x, "z": FAR.z}, {"type": "hold_fire"}), "", "ordered")
	for frame in int(SimClock.TICK_RATE * 8):
		await tree.physics_frame
	var arms := Movement.route_arms()
	Movement._off = was
	assert_eq(int(arms["a1_tube_skips"]), 0, "the cadence arm never skips on a tube it does not have (%s)" % arms)
	assert_true(int(arms["a1_replans"]) > 0, "and it does re-plan (%s)" % arms)


## THE GUARANTEE THAT STOPS A FLAG HIDING A REGRESSION (squad's, adopted): **the tube may only ever hold a plan
## LONGER than the cadence would, never shorter.** It may skip a re-plan; it may never add one. Turning A1 on must
## not make the layer re-plan MORE, whatever the state has done — otherwise the row achieves the opposite of its
## purpose in some regime and the switch conceals it.
##
## This caught a real bug: the first version read `drifted = _path.size() < 2` on its own, independent of the
## cadence, so a hull with no route yet re-planned on ticks where the blend would not have.
func test_the_tube_can_only_hold_a_plan_longer_never_shorter() -> void:
	# One arena, one match, a fresh hull per arm from the same start — ArenaFixture may only be built once per test.
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var counts := {}
	for arm in [false, true]:
		var on: bool = arm
		var was := _tube(on)
		var tank := game_match.spawn_tank("Mover_%s" % on, 0, Match.Team.GREEN, "tank")
		tank.global_position = START
		tank.rotation.y = 0.0
		var ctl := OrderController.new()
		ctl.tank = tank
		ctl.tanks_root = game_match.tanks
		add_to_tree(ctl)
		assert_eq(ctl.set_orders({"type": "move_to", "x": FAR.x, "z": FAR.z}, {"type": "hold_fire"}), "", "ordered")
		for frame in int(SimClock.TICK_RATE * 10):
			await tree.physics_frame
		counts[on] = Movement.route_arms()
		Movement.cancel(tank)
		tank.queue_free()
		ctl.queue_free()
		await tree.physics_frame
		Movement._off = was
	var off: Dictionary = counts[false]
	var tube: Dictionary = counts[true]
	assert_true(int(tube["a1_replans"]) <= int(off["a1_replans"]),
			"A1 never re-plans MORE than the cadence it replaces (%d with the tube, %d without)" % [
					int(tube["a1_replans"]), int(off["a1_replans"])])
	assert_true(int(tube["a1_tube_skips"]) > 0, "and it did hold at least once, so this is not a vacuous pass (%s)" % tube)
