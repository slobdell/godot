extends TestCase
## Control X7 (round 6 stretch): "why did my element do that". Every decision an element's leader makes is kept with
## its match time, and hovering the card's doctrine line shows the last few.

const Fixture := preload("res://tests/support/control_fixture.gd")


func test_an_elements_decisions_are_kept_and_shown_on_the_card() -> void:
	var f := Fixture.new(self)
	await f.build(true)
	var elements := Elements.install(f.game_match, f.orders)
	f.controls.elements = elements
	f.controls.element_log.attach(elements, f.game_match)
	f.controls.groups.save(1, ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	await f.select(["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	assert_eq(f.controls.assign_task("hold", {}), "", "the group takes a hold task, forming its element")
	await wait_physics_frames(Elements.UPDATE_TICKS * 3)
	var element := f.controls.selected_element()
	assert_true(element != null, "setup: the selection is an element")
	var recent := f.controls.element_log.lines(element.id)
	assert_true(not recent.is_empty(), "the leader's decision is logged (%s)" % [recent])
	assert_true(recent[0].begins_with("0:"), "with the match time it was made (%s)" % recent[0])
	assert_true(not recent[0].contains(element.element_name + ":"), "without repeating the element's name")
	assert_true(f.controls.element_log.history(element.id).size() <= ElementLog.KEEP, "and only the last few are kept")
	var panel := SelectionPanel.new()
	panel.controls = f.controls
	f.controls.add_child(panel)
	await tree.process_frame
	await tree.process_frame
	f.motion(panel.get_global_rect().position + panel.doctrine_rect().get_center(), false, 0)
	await tree.process_frame
	var tip := panel.tooltip()
	assert_eq(tip.get("id", ""), "doctrine", "hovering the doctrine line shows the log")
	assert_eq(tip.get("lines", []), recent, "the same lines")
