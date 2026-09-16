extends TestCase
## Control X3: the player commands tasks, not geometry. With a whole element selected, the command card and the
## mouse issue L1 tasks and the element's leader decides the formation, the technique and the drills; an ad-hoc
## selection still gets direct K1 orders. The HUD reads back what the leader chose, and G overrides it.

const Fixture := preload("res://tests/support/control_fixture.gd")


func _frames(count := 2) -> void:
	for i in count:
		await tree.process_frame


## The fixture with L1 elements installed: Alpha (three units) and Bravo (two), also groups 1 and 2.
func _setup() -> Fixture:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.elements = Elements.install(f.game_match, f.orders)
	# Elements are formed on demand by the first task, so the player's groups are all the setup there is.
	f.controls.groups.save(1, ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	f.controls.groups.label(1, "Alpha")
	f.controls.groups.save(2, ["Green_Bravo_1", "Green_Bravo_2"])
	f.controls.groups.label(2, "Bravo")
	await _frames(2)
	return f


func test_a_whole_element_is_recognised_and_a_handful_of_units_is_not() -> void:
	var f := await _setup()
	await f.select(["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	assert_eq(f.controls.selected_group(), 1, "selecting every member of a group selects that element")
	assert_true(f.controls.selected_element() == null, "which has no leader until it is given a task")
	await f.right_click(f.ground(Vector3(-20, 0, -20)))
	var element := f.controls.selected_element()
	assert_true(element != null, "the first task forms it")
	assert_eq(element.element_name, "Alpha", "under the group's name")
	await f.select(["Green_Alpha_1", "Green_Alpha_2"])
	assert_true(f.controls.selected_element() == null, "part of an element is not the element")
	assert_eq(f.controls.selected_group(), 0, "and not a group either")
	await f.select(["Green_Alpha_1", "Green_Bravo_1"])
	assert_true(f.controls.selected_element() == null, "units from two groups are not one element")


func test_right_clicking_the_ground_with_an_element_gives_its_leader_a_task() -> void:
	var f := await _setup()
	await f.select(["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	await f.right_click(f.ground(Vector3(-20, 0, -20)))
	var element := f.controls.elements.of("Green_Alpha_1")
	assert_eq(element.task.get("verb", ""), "move", "the element is given a move task")
	var to: Array = element.task.get("to", [])
	assert_true(Vector2(to[0], to[1]).distance_to(Vector2(-20, -20)) < 1.5, "at the clicked spot (%s)" % [to])
	await f.right_click(f.screen("Rust_Alpha_1"))
	assert_eq(f.controls.elements.of("Green_Alpha_1").task.get("verb", ""), "attack", "an enemy becomes an attack task")
	assert_eq(f.controls.elements.of("Green_Alpha_1").task.get("target", ""), "Rust_Alpha_1", "on that enemy")


func test_a_handful_of_units_still_gets_a_direct_order() -> void:
	var f := await _setup()
	await f.select(["Green_Alpha_1", "Green_Alpha_2"])
	await f.right_click(f.ground(Vector3(-20, 0, -20)))
	assert_true(f.controls.elements.of("Green_Alpha_1") == null, "no element is formed for a handful of units")
	for unit_name in ["Green_Alpha_1", "Green_Alpha_2"]:
		assert_eq(f.orders.current(unit_name).get("verb", ""), "move", "%s is ordered directly" % unit_name)
	# Alpha_3 keeps whatever its own leader is doing with it (an element always runs its SOP): what must not
	# happen is the player's click reaching it.
	var goal: Variant = f.orders.goal_position("Green_Alpha_3")
	assert_true(goal == null or (goal as Vector3).distance_to(Vector3(-20, 0, -20)) > 5.0,
			"the unit you left out is not sent to the clicked spot (%s)" % [goal])


func test_screen_and_support_by_fire_are_tasks_you_can_actually_give() -> void:
	var f := await _setup()
	await f.select(["Green_Bravo_1", "Green_Bravo_2"])
	await f.key(KEY_E)
	assert_eq(f.controls.mode, "screen", "E arms a screen task")
	await f.click(f.ground(Vector3(30, 0, 10)))
	assert_eq(f.controls.elements.of("Green_Bravo_1").task.get("verb", ""), "screen", "the click screens that flank")
	assert_eq(f.controls.mode, "", "and disarms")
	await f.key(KEY_R)
	assert_eq(f.controls.mode, "support_by_fire", "R arms support by fire")
	await f.click(f.ground(Vector3(-30, 0, 10)))
	assert_eq(f.controls.elements.of("Green_Bravo_1").task.get("verb", ""), "support_by_fire", "the click sets the base of fire")
	await f.key(KEY_H)
	assert_eq(f.controls.elements.of("Green_Bravo_1").task.get("verb", ""), "hold", "H holds the element where it is")


func test_a_direct_order_dissolves_the_element_so_its_leader_stops_fighting_the_player() -> void:
	var f := await _setup()
	await f.select(["Green_Bravo_1", "Green_Bravo_2"])
	await f.right_click(f.ground(Vector3(10, 0, 20)))
	assert_true(not f.controls.elements.of("Green_Bravo_1").task.is_empty(), "it has a task")
	await f.key(KEY_S)
	assert_true(f.controls.elements.of("Green_Bravo_1") == null,
			"S takes the wheel back: the element is dissolved so its leader stops re-issuing orders")
	await f.right_click(f.ground(Vector3(10, 0, 20)))
	assert_true(f.controls.elements.of("Green_Bravo_1") != null, "and the next task forms it again")


func test_the_hud_reads_back_what_the_leader_decided() -> void:
	var f := await _setup()
	await f.select(["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	await f.right_click(f.ground(Vector3(-20, 0, -20)))
	await wait_physics_frames(Element.UPDATE_TICKS + 2)
	var doctrine := f.controls.element_state()
	assert_eq(doctrine.get("name", ""), "Alpha", "the panel knows which element it is showing")
	assert_true(String(doctrine.get("formation", "")) != "", "and the formation its leader picked")
	assert_true(String(doctrine.get("technique", "")) != "", "and the movement technique")
	var line := f.controls.doctrine_line()
	assert_true(line.begins_with("Alpha:"), "one line for the HUD, named: %s" % line)
	assert_true(line.length() > 8, "with something in it: %s" % line)


func test_the_player_can_override_the_formation_and_hand_it_back() -> void:
	var f := await _setup()
	await f.select(["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	assert_eq(f.controls.formation, UnitCommand.AUTO, "elements run on doctrine by default")
	f.controls.formation = "line"
	await f.right_click(f.ground(Vector3(-20, 0, -20)))
	assert_true(f.controls.elements.of("Green_Alpha_1") == null, "an overridden formation is geometry, not a task")
	assert_eq(f.orders.current("Green_Alpha_1").get("verb", ""), "move", "so the units are ordered directly")
	assert_eq(f.orders.current("Green_Alpha_1").get("formation", ""), "line", "in the formation the player asked for")
	f.controls.formation = UnitCommand.AUTO
	await f.right_click(f.ground(Vector3(-25, 0, -25)))
	assert_eq(f.controls.elements.of("Green_Alpha_1").task.get("verb", ""), "move", "back to auto, back to doctrine")
