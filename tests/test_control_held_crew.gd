extends TestCase
## Round 23 (orders O3; contract C23.2; brains' known issue from round 22): H on ONE vehicle takes the direct path, the
## crew leaves its element, and the panel's footer said nothing while a laser from beyond its range hit it. Now the
## footer (the doctrine line's place) says what the element's line would: UnansweredFire.WHY_HELD, brains' words read
## through `CrewFire.reason` (brains' `UnansweredFire.crew_reason` when it is on the build; a stub, "", until then;
## a fake here).

const Fixture := preload("res://tests/support/control_fixture.gd")

var _under_fire: Array[String] = []


func _fake(_game_match: Match, unit_name: String) -> String:
	return UnansweredFire.WHY_HELD if _under_fire.has(unit_name) else ""


func _setup() -> Fixture:
	var f := Fixture.new(self)
	await f.build_scale(10)
	CrewFire.source = _fake
	return f


func _teardown_source() -> void:
	CrewFire.source = Callable()


func test_one_held_crew_under_fire_it_cannot_answer_says_so_in_the_footer() -> void:
	var f := await _setup()
	var crew: String = f.controls.groups.members(1)[0]
	f.controls.recall_group(1)
	f.controls.order_selection("move", {"to": [0.0, 0.0]})  # the squad has an element to leave
	await wait_physics_frames(2)
	f.controls.selection.set_units([crew])
	assert_eq(f.controls.order_selection("hold"), "", "H on one vehicle is taken")
	await wait_physics_frames(2)
	assert_true(f.controls.elements.of(crew) == null, "setup: the held crew left its element (the direct path)")
	assert_eq(f.controls.doctrine_line(), "", "not under fire: the footer says nothing")
	_under_fire = [crew]
	assert_eq(f.controls.doctrine_line(), UnansweredFire.WHY_HELD, "under fire it cannot answer: brains' words, at once")
	var panel := SelectionPanel.new()
	panel.controls = f.controls
	add_to_tree(panel)
	await tree.process_frame
	assert_eq(String(panel.summary()["doctrine"]), UnansweredFire.WHY_HELD, "the panel's footer shows them")
	_under_fire = []
	await tree.process_frame
	assert_eq(String(panel.summary()["doctrine"]), "", "the fire stops: the footer clears")
	_teardown_source()


func test_a_crew_under_fire_on_a_move_or_in_its_squad_is_not_called_held() -> void:
	var f := await _setup()
	var one := f.controls.groups.members(1)
	_under_fire = [one[0]]
	f.controls.selection.set_units([one[0]])
	f.controls.order_selection("move", {"to": [0.0, 0.0]})
	await wait_physics_frames(2)
	assert_eq(f.controls.doctrine_line(), "", "a crew driving on his order is not 'holding on your order'")
	f.controls.recall_group(1)
	f.controls.order_selection("hold")  # the whole squad: an element task, the element's own line
	await wait_physics_frames(2)
	assert_eq(f.controls.held_crew_line(), "", "a crew held inside its element is the element's line to tell")
	_teardown_source()


func test_several_held_crews_count_the_ones_under_fire() -> void:
	var f := await _setup()
	var one := f.controls.groups.members(1)
	var three: Array[String] = [one[0], one[1], one[2]]
	f.controls.selection.set_units(three)
	f.controls.order_selection("hold")
	await wait_physics_frames(2)
	for crew in three:
		assert_true(f.controls.elements.of(crew) == null, "setup: %s left its element" % crew)
	_under_fire = [one[0], one[2]]
	assert_eq(f.controls.doctrine_line(), "2 of 3 " + UnansweredFire.WHY_HELD, "two of the three held crews are under fire they cannot answer")
	_under_fire = [one[1]]
	assert_eq(f.controls.doctrine_line(), "1 of 3 " + UnansweredFire.WHY_HELD, "one of three")
	_teardown_source()


## C23.2 landed (brains B2): the live case, on brains' own stage (tests/test_ai_crew_reason.gd): a Syndicate gunship
## (pulse cannon, 55 m) under a Lancer's laser from 84 m, held with H as ONE vehicle through the controls, no element.
## The panel's footer says brains' words within the grace plus half a second of the first hit, and clears once the
## Lancer is dead and the quiet has passed.
const GUNSHIP := "Rust_Hunters_2"
const LANCER := "Green_Charlie_1"


func test_one_vehicle_held_under_a_lancer_at_range_reads_holding_on_your_order() -> void:
	CrewFire.source = Callable()
	var lab := TacticsLab.create(self, 1, "foundry")
	lab.game_match.set_meta("player_team", Match.Team.RUST)
	var toward := (DuckStage.LANCER_AT - DuckStage.GUNSHIP_AT).normalized()
	var duck := lab.unit(Match.Team.RUST, GUNSHIP, DuckStage.GUNSHIP_AT, atan2(-toward.x, -toward.z), "syn_ifv")
	lab.gun(Match.Team.GREEN, LANCER, DuckStage.LANCER_AT, atan2(toward.x, toward.z), "lancer")
	await lab.start()
	var controls := RtsControls.new()
	controls.game_match = lab.game_match
	controls.orders = lab.orders
	controls.elements = lab.elements
	controls.team = Match.Team.RUST
	controls.reveal_all = true
	add_to_tree(controls)
	await tree.process_frame
	controls.selection.set_units([GUNSHIP])
	assert_eq(controls.order_selection("hold"), "", "H on the gunship is taken")
	var panel := SelectionPanel.new()
	panel.controls = controls
	add_to_tree(panel)
	var first_hit := -1
	var said := -1
	for tick in 12 * SimClock.TICK_RATE:
		await lab.step()
		if first_hit < 0 and duck.ticks_since_hit < 2:
			first_hit = tick
		var line := String(panel.summary()["doctrine"])
		if first_hit < 0 or tick - first_hit < UnansweredFire.GRACE_TICKS - 2:
			assert_eq(line, "", "inside the grace the footer says nothing (tick %d, hit at %d)" % [tick, first_hit])
		elif line == UnansweredFire.WHY_HELD and said < 0:
			said = tick
		if said >= 0 and tick - said > SimClock.TICK_RATE:
			break
	assert_true(first_hit >= 0, "the Lancer hits it")
	assert_true(said >= 0 and said - first_hit <= UnansweredFire.GRACE_TICKS + SimClock.TICK_RATE / 2,
			"the footer reads brains' words within half a second of the grace (first hit %d, said %d)" % [first_hit, said])
	assert_eq(String(controls.orders.current(GUNSHIP).get("verb", "")), "hold", "still on his hold")
	lab.tank_of(LANCER).apply_damage(100000)
	for tick in UnansweredFire.QUIET_TICKS + 5:
		await lab.step()
	assert_eq(String(panel.summary()["doctrine"]), "", "the fire has stopped: the footer clears")
	lab.dispose()
