extends TestCase
## Round 34 (traffic T6, R34.15; `--traffic-on=underfire`, DEFAULT_OFF until judged): a crew UNDER FIRE does not give way; it
## holds its lane and the asker goes round or waits. T5's census on main (144 fights, 5984 deaths): 337 crews died jammed by
## friendly traffic, 83 % of them GIVING WAY, for a median 1.5 s, 77 % already under fire (the last hit landed during the
## give-way for 63 %): the step aside is what exposed them. Under fire = hit within UNDER_FIRE_S (5 s: T5's hit cadence is one
## hit every ~2.5 s, so the brain's 2 s ENGAGED window would lapse between hits). Three places, one rule: `ask()` refuses, the
## asker's own step aside (`_begin_yield`) is held, and a give-way under way ends the tick a hit lands.

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("underfire", Traffic.DEFAULT_OFF.has("underfire"))  # the default back, whichever it is
	Traffic.set_off("setup", false)
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## A Law tank parked on open ground (yard_open's band) and a Law tank 12 m south of it heading north.
func _stage() -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var parked := _lab.unit(Match.Team.GREEN, "Green_Parked", Vector3(0.0, 0.0, 0.0), 0.0, "law_tank")
	var asker := _lab.unit(Match.Team.GREEN, "Green_Asker", Vector3(0.0, 0.0, 12.0), 0.0, "law_tank")
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


func test_on_a_crew_hit_while_giving_way_ends_it_and_drives_its_own_route() -> void:
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
	assert_eq(mover.yield_to, "", "the give-way ended when the hit landed")
	assert_true(mover.phase != "yielding", "and the crew is back on its own route (%s)" % mover.phase)
	assert_eq(Movement.underfire_aborts, aborts + 1, "counted as an under-fire abort")


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


func test_on_an_asker_under_fire_does_not_step_aside_itself() -> void:
	Traffic.set_off("underfire", false)
	var units: Array = await _stage()
	var parked: Tank = units[0]
	var asker: Tank = units[1]
	var asker_mover := Movement.of(asker)
	var holds := Movement.underfire_holds
	_hit(asker, 1.0)
	assert_true(not asker_mover._begin_yield(String(parked.name), parked.global_position, Vector2(0.0, -1.0)),
			"under fire, the asker's own step aside is held")
	assert_eq(Movement.underfire_holds, holds + 1, "counted as an under-fire hold")
	assert_eq(asker_mover.yield_to, "", "it is not giving way")
	_hit(asker, 8.0)
	assert_true(asker_mover._begin_yield(String(parked.name), parked.global_position, Vector2(0.0, -1.0)),
			"8 s after the last hit it steps aside as today")


func test_off_a_crew_hit_two_seconds_ago_gives_way_as_before() -> void:
	Traffic.set_off("underfire", true)
	var units: Array = await _stage()
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	_hit(units[0], 2.0)
	assert_true(not mover.under_fire(), "the switch off: never under fire for the give-way")
	assert_true(mover.ask(String(asker.name), asker.global_position, Vector2(0.0, -1.0)), "asked, it gives way as before")
