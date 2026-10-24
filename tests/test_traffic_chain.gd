extends TestCase
## Round 39, manoeuvre M1 (R38.26 / C39.2; `--giveway-chain` = `--traffic-on=givewaychain`, Traffic.DEFAULT_OFF until its bar is
## judged): a PARKED crew already more than Movement.CHAIN_M off its seat takes no give-way spot farther from that seat than it
## stands; with none left it refuses (the asker then treats it as parked and goes round). s3866: Alpha_3 gave way four times in
## 10 s, each from where the last left it, 2.9 -> ~20 m from its seat. The stage is M5's (round 37 seatstep, tests/test_traffic_seatstep.gd
## on lab/manoeuvre-r38-m5): a parked tank at the origin, a squadmate 12 m south asking along -Z; today's first whole spot on
## yard_open is spot(0,-8) = (-8, 0, 0), a side step west.

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("givewaychain", Traffic.DEFAULT_OFF.has("givewaychain"))
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## `seat` is the parked crew's face slot. Returns [mover, ask's answer].
func _stage(seat: Vector3) -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var parked := _lab.gun(Match.Team.GREEN, "Green_Parked", Vector3.ZERO, 0.0, "tank")
	var asker := _lab.unit(Match.Team.GREEN, "Green_Asker", Vector3(0.0, 0.0, 12.0), 0.0, "tank")
	await _lab.start()
	for i in 3:
		await _lab.step()
	_lab.element([String(asker.name)], "Go").assign({"verb": "move", "to": [0.0, -30.0]})
	for i in 2:
		await _lab.step()
	var mover := Movement.of(parked)
	mover.ctl.face_slot = seat
	assert_true(not mover.is_under_way(), "setup: the crew is parked (phase %s)" % mover.phase)
	var gave := mover.ask(String(asker.name), asker.global_position, Vector2(0.0, -1.0))
	return [mover, gave]


## Today's first whole spot on this stage, and a seat 6 m east of the crew: that spot is 14 m from it.
const TODAY := Vector3(-8.0, 0.0, 0.0)
const SEAT_EAST := Vector3(6.0, 0.0, 0.0)


func test_off_a_crew_off_its_seat_gives_way_farther_from_it() -> void:
	Traffic.set_off("givewaychain", true)
	var in_play := Movement.chain_in_play
	var staged: Array = await _stage(SEAT_EAST)
	var mover: Movement = staged[0]
	assert_true(bool(staged[1]), "today it gives way")
	assert_true(Movement._flat_distance(mover._yield_point, SEAT_EAST) > 10.0,
			"today: spot %s %s, 14 m from the seat" % [mover.yield_spot, mover._yield_point])
	assert_eq(Movement.chain_in_play, in_play, "and the rule never runs")


func test_on_a_crew_off_its_seat_gives_way_toward_it() -> void:
	Traffic.set_off("givewaychain", false)
	var before := [Movement.chain_in_play, Movement.chain_spots_skipped, Movement.chain_refusals]
	var staged: Array = await _stage(SEAT_EAST)
	var mover: Movement = staged[0]
	print("MEASURE givewaychain seat east 6 m: ON %s %s %.1f m from the seat" % [mover.yield_spot, mover._yield_point,
			Movement._flat_distance(mover._yield_point, SEAT_EAST)])
	assert_true(bool(staged[1]), "it still gives way")
	assert_true(Movement._flat_distance(mover._yield_point, SEAT_EAST) <= 6.0 + Movement.CHAIN_SLACK_M,
			"to a spot no farther from its seat: %s %s" % [mover.yield_spot, mover._yield_point])
	assert_eq(Movement.chain_in_play, before[0] + 1, "the rule ran")
	assert_true(Movement.chain_spots_skipped > before[1], "today's spot was skipped as farther")
	assert_eq(Movement.chain_refusals, before[2], "no refusal")
	var asker := _lab.tank_of("Green_Asker")
	assert_true(Movement._flat_distance(mover._yield_point, asker.global_position)
			>= Movement._flat_distance(_lab.tank_of("Green_Parked").global_position, asker.global_position),
			"and never toward the asker (today's test holds)")


func test_on_with_every_spot_farther_it_refuses() -> void:
	Traffic.set_off("givewaychain", false)
	# The seat 8 m back toward the asker: every side and ahead spot is farther, and backing up is toward the asker.
	var seat := Vector3(0.0, 0.0, 8.0)
	var refusals := Movement.chain_refusals
	var staged: Array = await _stage(seat)
	var mover: Movement = staged[0]
	assert_true(not bool(staged[1]), "it refuses (spot %s %s)" % [mover.yield_spot, mover._yield_point])
	assert_eq(mover.yield_to, "", "and is not giving way")
	assert_eq(Movement.chain_refusals, refusals + 1, "counted as the chain's refusal")


func test_on_a_crew_by_its_seat_gives_way_as_today() -> void:
	Traffic.set_off("givewaychain", false)
	var seat := Vector3(-3.0, 0.0, 0.0)
	assert_true(Vector2(seat.x, seat.z).length() <= Movement.CHAIN_M, "setup: within CHAIN_M of the seat")
	var in_play := Movement.chain_in_play
	var staged: Array = await _stage(seat)
	var mover: Movement = staged[0]
	assert_true(bool(staged[1]), "it gives way")
	assert_true(Movement._flat_distance(mover._yield_point, TODAY) < 0.5,
			"today's first spot: %s %s" % [mover.yield_spot, mover._yield_point])
	assert_eq(Movement.chain_in_play, in_play, "the rule does not run")


func test_the_switch_routes_asks_through_the_gdscript_rule() -> void:
	var was := BrainSwitches.native_yield
	Traffic.set_off("givewaychain", false)
	assert_true(Movement.giveway_chain_on(), "on")
	assert_true(not BrainSwitches.native_yield, "native's yield port is off while the rule is on (no C++ mirror yet)")
	Traffic.set_off("givewaychain", true)
	assert_true(not Movement.giveway_chain_on(), "off")
	assert_eq(BrainSwitches.native_yield, was, "and back as it was")
	assert_true(Traffic.DEFAULT_OFF.has("givewaychain"), "DEFAULT_OFF until judged")
