extends TestCase
## Round 34 (traffic T6, R34.15; `--traffic-on=underfire`, DEFAULT_OFF until judged): a crew UNDER FIRE does not give way; it
## holds its lane and the asker goes round or waits. T5's census on main (144 fights, 5984 deaths): 337 crews died jammed by
## friendly traffic, 83 % of them GIVING WAY, for a median 1.5 s, 77 % already under fire (the last hit landed during the
## give-way for 63 %): the step aside is what exposed them. Under fire = hit within UNDER_FIRE_S (5 s: T5's hit cadence is one
## hit every ~2.5 s, so the brain's 2 s ENGAGED window would lapse between hits). Three places, one rule: `ask()` refuses, the
## asker's own step aside (`_begin_yield`) is held, and a give-way already begun finishes (T6b, R34.17).
##
## Round 35 (T7, C35.8): T6b moved the dying one for one into crews stalled behind the refuser. So the refusal (and the hold)
## happens ONLY when the asker has a way round: a pass lane beside the refuser swept for the asker's hull. The refused asker
## then PASSES (steers by the lane, <= PASS_MAX_S). With no lane (a one-hull neck, a third hull in it) it gives way as today.

var _lab: TacticsLab
var _was_native := BrainSwitches.native


func teardown() -> void:
	BrainSwitches.native = _was_native
	Traffic.set_off("underfire", Traffic.DEFAULT_OFF.has("underfire"))  # the default back, whichever it is
	Traffic.set_off("setup", false)
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## A Law tank parked on open ground (yard_open's band) and a Law tank 12 m south of it heading north.
func _stage(blockers: Array = []) -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var parked := _lab.unit(Match.Team.GREEN, "Green_Parked", Vector3(0.0, 0.0, 0.0), 0.0, "law_tank")
	var asker := _lab.unit(Match.Team.GREEN, "Green_Asker", Vector3(0.0, 0.0, 12.0), 0.0, "law_tank")
	for i in blockers.size():
		_lab.unit(Match.Team.GREEN, "Green_Block_%d" % i, blockers[i], 0.0, "law_tank")
	await _lab.start()
	for i in 3:
		await _lab.step()
	var mover := Movement.of(parked)
	mover.ctl.move_order = {"type": "stop"}
	mover.idle()
	return [parked, asker, mover]


func _hit(tank: Tank, seconds_ago: float) -> void:
	tank.ticks_since_hit = int(seconds_ago * SimClock.TICK_RATE)


func test_on_a_crew_hit_two_seconds_ago_refuses_to_give_way() -> void:
	Traffic.set_off("underfire", false)
	var units: Array = await _stage()
	var parked: Tank = units[0]
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	_hit(parked, 2.0)
	assert_true(mover.under_fire(), "hit 2 s ago: under fire")
	var refused := Movement.underfire_refusals
	var plain := Movement.asks_refused
	assert_true(not mover.ask(String(asker.name), asker.global_position, Vector2(0.0, -1.0)), "asked, it refuses")
	assert_eq(mover.yield_to, "", "and is not giving way")
	assert_eq(Movement.underfire_refusals, refused + 1, "counted as an under-fire refusal")
	assert_eq(Movement.asks_refused, plain, "not as a plain refusal")


func test_on_a_crew_hit_six_seconds_ago_gives_way_as_today() -> void:
	Traffic.set_off("underfire", false)
	var units: Array = await _stage()
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	_hit(units[0], 6.0)
	assert_true(not mover.under_fire(), "6 s since the last hit: not under fire (window %.0f s)" % Movement.UNDER_FIRE_S)
	assert_true(mover.ask(String(asker.name), asker.global_position, Vector2(0.0, -1.0)), "asked, it gives way")
	assert_eq(mover.yield_to, String(asker.name), "to the asker")


func test_on_a_crew_hit_while_giving_way_finishes_its_step_aside() -> void:
	# T6b (R34.17): the first try ended the give-way on the hit and put the crew back into the asker's path (contacts in the
	# 3 s after tripled on 140 fights). Now a give-way begun is finished; only a NEW one is refused under fire.
	Traffic.set_off("underfire", false)
	var units: Array = await _stage()
	var parked: Tank = units[0]
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	assert_true(mover.ask(String(asker.name), asker.global_position, Vector2(0.0, -1.0)), "setup: it gives way")
	await _lab.step()
	assert_eq(mover.phase, "yielding", "setup: driving to its spot (%s)" % mover.phase)
	var aborts := Movement.underfire_aborts
	parked.ticks_since_hit = 0  # a hit lands this tick
	for i in 3:
		await _lab.step()
	assert_eq(mover.yield_to, String(asker.name), "the give-way goes on after the hit")
	assert_eq(mover.phase, "yielding", "still stepping aside (%s)" % mover.phase)
	assert_eq(Movement.underfire_aborts, aborts, "no abort counted")
	assert_true(mover.under_fire(), "and the crew is under fire, so a NEW ask would be refused")


func test_on_a_set_up_battery_under_fire_refuses_by_the_battery_rule_not_twice() -> void:
	Traffic.set_off("underfire", false)
	var units: Array = await _stage()
	var parked: Tank = units[0]
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	parked.deploy_ratio = 1.0
	mover.ctl.weapon_order = {"type": "target"}
	_hit(parked, 1.0)
	var setup := Movement.setup_refusals
	var fire := Movement.underfire_refusals
	assert_true(not mover.ask(String(asker.name), asker.global_position, Vector2(0.0, -1.0)), "it refuses")
	assert_eq(Movement.setup_refusals, setup + 1, "as a set-up battery on its fire order")
	assert_eq(Movement.underfire_refusals, fire, "not counted again as under fire")


func test_on_a_crew_under_fire_does_not_step_aside_itself_for_one_that_can_pass_it() -> void:
	Traffic.set_off("underfire", false)
	var units: Array = await _stage()
	var parked: Tank = units[0]
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	var holds := Movement.underfire_holds
	_hit(parked, 1.0)
	# The other (12 m south, facing north) wants to go NORTH, through me, on open ground: it has a lane round me.
	assert_true(not mover._begin_yield(String(asker.name), asker.global_position, Vector2(0.0, -1.0)),
			"under fire, my own step aside is held: the other can pass me")
	assert_eq(Movement.underfire_holds, holds + 1, "counted as an under-fire hold")
	assert_eq(mover.yield_to, "", "it is not giving way")
	assert_true(not mover._yield_unfit_last, "a hold is not 'nothing fits' (no swap ask follows)")
	_hit(parked, 8.0)
	assert_true(mover._begin_yield(String(asker.name), asker.global_position, Vector2(0.0, -1.0)),
			"8 s after the last hit it steps aside as today")


func test_on_a_crew_under_fire_steps_aside_for_one_that_has_no_way_past_it() -> void:
	# The other is going NORTH, away from me: a pass is forward, so there is no lane round me for it; I step aside as today.
	Traffic.set_off("underfire", false)
	var units: Array = await _stage()
	var parked: Tank = units[0]
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	var holds := Movement.underfire_holds
	_hit(parked, 1.0)
	assert_eq(mover._pass_lane(String(asker.name), asker.global_position, Vector2(0.0, 1.0)), 0.0,
			"the other is going away from me: a pass is forward, so no lane")
	mover._begin_yield(String(asker.name), asker.global_position, Vector2(0.0, 1.0))
	assert_eq(Movement.underfire_holds, holds, "no hold counted")


func test_on_open_ground_the_refusal_offers_a_side_and_the_asker_passes() -> void:
	Traffic.set_off("underfire", false)
	var units: Array = await _stage()
	var parked: Tank = units[0]
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	_hit(parked, 1.0)
	assert_true(not mover.ask(String(asker.name), asker.global_position, Vector2(0.0, -1.0)), "refused under fire")
	assert_true(mover.pass_offer != 0.0, "with a side offered (%.0f)" % mover.pass_offer)


## The whole drive. The crew under fire is a hull on standing orders (a brain hit every tick would run for cover): it is hit
## every tick and never moves; a squadmate is sent 30 m north straight through it on open ground.
func test_on_open_ground_the_asker_drives_round_the_crew_under_fire() -> void:
	Traffic.set_off("underfire", false)
	_was_native = BrainSwitches.native
	BrainSwitches.native = false  # the GDScript reference (native's twin compares the mirror)
	_lab = TacticsLab.create(self, 7, "yard_open")
	var post := Vector3(0.0, 0.0, 0.0)
	var parked := _lab.gun(Match.Team.GREEN, "Green_Parked", post, 0.0, "law_tank")
	var asker := _lab.unit(Match.Team.GREEN, "Green_Asker", Vector3(0.0, 0.0, 14.0), 0.0, "law_tank")
	await _lab.start()
	for i in 3:
		await _lab.step()
	var mover := Movement.of(parked)
	post = parked.global_position
	var passes := Movement.passes
	var done := Movement.passes_done
	var refusals := Movement.underfire_refusals
	_lab.element([String(asker.name)], "Go").assign({"verb": "move", "to": [0.0, -30.0]})
	var yielded := false
	for tick in SimClock.TICK_RATE * 25:
		parked.ticks_since_hit = 0
		await _lab.step()
		yielded = yielded or mover.yield_to != ""
		if tick % 15 == 0:
			print("T7PASS t=%d asker=(%.1f,%.1f) %s by=%s parked=(%.1f,%.1f) %s" % [tick, asker.global_position.x,
					asker.global_position.z, Movement.of(asker).phase, Movement.of(asker)._pass_by, parked.global_position.x,
					parked.global_position.z, mover.phase])
		if asker.global_position.z < -12.0:
			break
	assert_true(Movement.underfire_refusals > refusals, "the asker asked and was refused (%d)" % (Movement.underfire_refusals - refusals))
	assert_true(Movement.passes > passes, "and passed (%d passes)" % (Movement.passes - passes))
	assert_true(Movement.passes_done > done, "a pass ended abreast (%d)" % (Movement.passes_done - done))
	assert_true(asker.global_position.z < -12.0, "the asker is past the crew (z %.1f)" % asker.global_position.z)
	assert_true(not yielded, "the crew under fire never stepped aside")
	assert_true(Movement._flat_distance(parked.global_position, post) < 1.5, "and holds its spot (moved %.1f m)"
			% Movement._flat_distance(parked.global_position, post))


func test_on_a_third_hull_in_both_lanes_the_crew_under_fire_gives_way_as_today() -> void:
	Traffic.set_off("underfire", false)
	var lateral := Avoidance.radius_of("law_tank") * 2.0 + Movement.YIELD_LINE_MARGIN
	var units: Array = await _stage([Vector3(lateral, 0.0, 0.0), Vector3(-lateral, 0.0, 0.0)])
	var parked: Tank = units[0]
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	Avoidance.refresh(mover.ctl.tanks_root)
	_hit(parked, 1.0)
	assert_eq(mover._pass_lane(String(asker.name), asker.global_position, Vector2(0.0, -1.0)), 0.0, "no lane: both sides taken")
	var gives := Movement.underfire_gives
	mover.ask(String(asker.name), asker.global_position, Vector2(0.0, -1.0))
	assert_eq(Movement.underfire_gives, gives + 1, "under fire with no lane: counted as given way anyway")
	assert_eq(mover.pass_offer, 0.0, "and nothing offered")


func test_on_a_one_hull_neck_the_crew_under_fire_gives_way_as_today() -> void:
	# test_traffic_neck's place (crossing, seed 403): a scout in a one-hull neck, a tank coming through from the west.
	Traffic.set_off("underfire", false)
	_lab = TacticsLab.create(self, 403, "crossing")
	var neck := Vector3(54.1, 0.0, 56.5)
	var from := Vector3(44.0, 0.0, 58.0)
	var scout := _lab.unit(Match.Team.GREEN, "Green_Eyes_1", neck, PI / 2.0, "scout")
	var tank := _lab.unit(Match.Team.GREEN, "Green_Guns_1", from, -PI / 2.0, "tank")
	await _lab.start()
	for pair: Array in [[scout, neck, PI / 2.0], [tank, from, -PI / 2.0]]:
		var hull: Tank = pair[0]
		hull.global_position = pair[1]
		hull.rotation.y = pair[2]
		hull.velocity = Vector3.ZERO
	for i in 3:
		await _lab.step()
	var mover := Movement.of(scout)
	mover.ctl.move_order = {"type": "stop"}
	mover.idle()
	_hit(scout, 1.0)
	var way := Vector2(neck.x - from.x, neck.z - from.z).normalized()
	assert_eq(mover._pass_lane(String(tank.name), tank.global_position, way), 0.0, "no lane round the scout in the neck")
	mover.ask(String(tank.name), tank.global_position, way)
	assert_eq(mover.pass_offer, 0.0, "nothing offered: the give-way proceeds as today")


func test_on_an_unsticking_crew_asking_behind_is_never_refused_for_fire() -> void:
	Traffic.set_off("underfire", false)
	var units: Array = await _stage()
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	_hit(units[0], 1.0)
	var refusals := Movement.underfire_refusals
	assert_true(mover.ask(String(asker.name), asker.global_position, Vector2(0.0, -1.0), "behind"), "a 'behind' ask: gives way")
	assert_eq(Movement.underfire_refusals, refusals, "no under-fire refusal")


func test_on_a_pass_runs_out_of_clock_and_that_crew_is_not_passed_again() -> void:
	Traffic.set_off("underfire", false)
	var units: Array = await _stage()
	var parked: Tank = units[0]
	var asker_mover := Movement.of(units[1])
	assert_true(asker_mover._pass_start(String(parked.name), 1.0, Vector2(0.0, -1.0)), "a pass starts")
	assert_true(asker_mover._pass_point() != Vector3.INF, "and steers")
	var timeouts := Movement.passes_timeout
	asker_mover._pass_left = 0
	assert_eq(asker_mover._pass_point(), Vector3.INF, "out of clock: no steering point")
	assert_eq(Movement.passes_timeout, timeouts + 1, "counted")
	assert_true(not asker_mover._pass_start(String(parked.name), 1.0, Vector2(0.0, -1.0)), "the same crew is not passed again")


func test_off_a_crew_hit_two_seconds_ago_gives_way_as_before() -> void:
	Traffic.set_off("underfire", true)
	var units: Array = await _stage()
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	_hit(units[0], 2.0)
	assert_true(not mover.under_fire(), "the switch off: never under fire for the give-way")
	assert_true(mover.ask(String(asker.name), asker.global_position, Vector2(0.0, -1.0)), "asked, it gives way as before")
