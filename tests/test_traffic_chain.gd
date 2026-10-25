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
	Traffic.set_off("chainrelease", Traffic.DEFAULT_OFF.has("chainrelease"))
	Traffic.set_off("chainside", Traffic.DEFAULT_OFF.has("chainside"))
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## `seat` is the parked crew's face slot; `stalled_s`, how long the asker has made no progress (M1 v2's wedged asker). Returns
## [mover, ask's answer].
func _stage(seat: Vector3, stalled_s := 0.0) -> Array:
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
	Movement.of(asker).stalled_ticks = int(stalled_s * SimClock.TICK_RATE)
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


func test_the_switch_leaves_native_yield_alone() -> void:
	# Round 39 (native N3): drive_native.cpp mirrors the rule (chain_in_play / chain_far; twin: test_native_yield's chain
	# stages), so the switch no longer turns BrainSwitches.native_yield off.
	var was := BrainSwitches.native_yield
	Traffic.set_off("givewaychain", false)
	assert_true(Movement.giveway_chain_on(), "on")
	assert_eq(BrainSwitches.native_yield, was, "native's yield port is left as it was (the C++ mirror runs the rule)")
	Traffic.set_off("givewaychain", true)
	assert_true(not Movement.giveway_chain_on(), "off")
	assert_eq(BrainSwitches.native_yield, was, "and back as it was")
	assert_true(Traffic.DEFAULT_OFF.has("givewaychain"), "DEFAULT_OFF until judged")


# ---- Round 40 (M1 v2, `--giveway-chain=v2` = givewaychain + chainrelease): the reach is lifted for a WEDGED asker -------------
# Bar M1's G5: the last squad in wedged behind seated crews M1 held, in streets with no way round. An asker that has made no
# progress for Movement.CHAIN_RELEASE_S is let through as today; one that is still getting somewhere sees M1's reach.

func _v2() -> void:
	Traffic.set_off("givewaychain", false)
	Traffic.set_off("chainrelease", false)


func test_v2_a_wedged_asker_gets_todays_spot() -> void:
	_v2()
	var releases := Movement.chain_releases
	var staged: Array = await _stage(SEAT_EAST, Movement.CHAIN_RELEASE_S + 0.5)
	var mover: Movement = staged[0]
	assert_true(bool(staged[1]), "it gives way")
	assert_true(Movement._flat_distance(mover._yield_point, TODAY) < 0.5,
			"today's spot, 14 m from the seat: %s %s" % [mover.yield_spot, mover._yield_point])
	assert_eq(Movement.chain_releases, releases + 1, "counted as a release")


func test_v2_an_asker_still_getting_somewhere_sees_the_reach() -> void:
	_v2()
	var releases := Movement.chain_releases
	var staged: Array = await _stage(SEAT_EAST, Movement.CHAIN_RELEASE_S - 1.0)
	var mover: Movement = staged[0]
	assert_true(bool(staged[1]), "it gives way")
	assert_true(Movement._flat_distance(mover._yield_point, SEAT_EAST) <= 6.0 + Movement.CHAIN_SLACK_M,
			"M1's reach: a spot no farther from its seat: %s %s" % [mover.yield_spot, mover._yield_point])
	assert_eq(Movement.chain_releases, releases, "no release")


func test_v2_a_wedged_asker_is_let_past_where_m1_refused() -> void:
	_v2()
	var staged: Array = await _stage(Vector3(0.0, 0.0, 8.0), Movement.CHAIN_RELEASE_S + 0.5)
	assert_true(bool(staged[1]), "M1 refused this one (every spot farther); wedged, it gives way")


func test_v2_without_release_is_m1() -> void:
	Traffic.set_off("givewaychain", false)
	var staged: Array = await _stage(Vector3(0.0, 0.0, 8.0), Movement.CHAIN_RELEASE_S + 0.5)
	assert_true(not bool(staged[1]), "chainrelease off: M1 refuses a wedged asker too")


func test_side_allows_a_step_across_not_down_the_street() -> void:
	Traffic.set_off("givewaychain", false)
	Traffic.set_off("chainside", false)
	var sides := Movement.chain_side_spots
	# The seat 8 m back toward the asker, which travels -Z: today's side step west (-8, 0, 0) is no farther along its travel from
	# the seat than the crew stands (8 m), so it is allowed; spots ahead (down the street) stay refused.
	var staged: Array = await _stage(Vector3(0.0, 0.0, 8.0))
	var mover: Movement = staged[0]
	assert_true(bool(staged[1]), "it gives way (spot %s %s)" % [mover.yield_spot, mover._yield_point])
	var seat := Vector3(0.0, 0.0, 8.0)
	assert_true(Vector2(mover._yield_point.x - seat.x, mover._yield_point.z - seat.z).dot(Vector2(0.0, -1.0))
			<= 8.0 + Movement.CHAIN_SLACK_M, "across the street, not down it: %s" % mover._yield_point)
	assert_true(Movement.chain_side_spots > sides, "a side spot past the reach was allowed")


func test_v2_switches_turn_native_yield_off_until_twinned() -> void:
	var was := BrainSwitches.native_yield
	Traffic.set_off("chainrelease", false)
	assert_true(Movement.chain_release_on(), "on")
	assert_true(not BrainSwitches.native_yield, "asks run the GDScript rule (no C++ mirror of chainrelease yet)")
	Traffic.set_off("chainrelease", true)
	assert_eq(BrainSwitches.native_yield, was, "and back as it was")
	Traffic.set_off("chainside", false)
	assert_true(not BrainSwitches.native_yield, "chainside too")
	Traffic.set_off("chainside", true)
	assert_eq(BrainSwitches.native_yield, was, "and back")
	assert_true(Traffic.DEFAULT_OFF.has("chainrelease") and Traffic.DEFAULT_OFF.has("chainside"), "DEFAULT_OFF until judged")
