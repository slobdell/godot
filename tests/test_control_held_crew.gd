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


## C23.2: until brains' `UnansweredFire.crew_reason` is on the build, the stub says nothing (and nothing is drawn);
## once it is, the adapter reads it (the live case, a hold under a Lancer at range, is tests/test_control_held_crew_live
## when B2 lands).
func test_the_adapter_reads_brains_crew_reason_when_it_is_on_the_build() -> void:
	CrewFire.source = Callable()
	var f := Fixture.new(self)
	await f.build_scale(4)
	var crew: String = f.controls.groups.members(1)[0]
	if not CrewFire.available():
		assert_eq(CrewFire.reason(f.game_match, crew), "", "C23.2 not landed: the stub says nothing")
		print("    (C23.2: UnansweredFire.crew_reason is not on this build; the stub is in use)")
		return
	assert_eq(CrewFire.reason(f.game_match, crew), "", "a crew nobody is shooting: brains says nothing")
