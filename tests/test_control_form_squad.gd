extends TestCase
## Round 10, R1 (narrowed by the lead, 2026-09-20 night): *"If I select a group of units composed of multiple squads, I
## complained how the formation options went away. I see now that if I just regroup the unit, they can operate as a
## formation. That is good behavior, but the UX just needs to clarify that."* So a selection that cannot take a task
## says why in words on the card (no tooltip needed), the card offers one click - Form squad - that makes it the next
## empty control group, and the task buttons are enabled in that same frame. The keys and the radar say the same words.

const Fixture := preload("res://tests/support/control_fixture.gd")


func _setup() -> Array:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.elements = Elements.install(f.game_match, f.orders)
	f.controls.groups.save(1, ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	f.controls.groups.label(1, "Alpha")
	f.controls.groups.save(2, ["Green_Bravo_1", "Green_Bravo_2"])
	f.controls.groups.label(2, "Bravo")
	var panel := SelectionPanel.new()
	panel.controls = f.controls
	f.controls.add_child(panel)
	await tree.process_frame
	return [f, panel]


func _enabled(panel: SelectionPanel, id: String) -> bool:
	for command: Dictionary in panel.summary()["commands"]:
		if String(command["id"]) == id:
			return bool(command["enabled"])
	return false


## The brief's test: a box-drag across two squads, Form squad, support by fire enabled and issued within one frame.
func test_a_box_across_two_squads_becomes_a_squad_in_one_click() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var panel: SelectionPanel = setup[1]
	var left := f.screen("Green_Alpha_3") - Vector2(30, 30)
	var right := f.screen("Green_Bravo_1") + Vector2(30, 30)
	await f.drag(left, right)
	assert_eq(f.controls.selection.units, ["Green_Alpha_3", "Green_Bravo_1"], "the box took one unit of each squad")
	await tree.process_frame
	assert_true(not _enabled(panel, "support_by_fire"), "support by fire is greyed for a mixed selection")
	var reason := String(panel.summary()["reason"])
	assert_true(reason.contains("different squads") and reason.contains("Form squad"),
			"and the card says why, and what to press (%s)" % reason)
	var button := panel.form_squad_rect()
	assert_true(button.size.x > 60.0 and button.size.y > 10.0, "the Form squad button is on the card (%s)" % button)
	await f.click(panel.get_global_rect().position + button.get_center())
	assert_eq(f.controls.selected_group(), 3, "one click made it the next empty group")
	assert_eq(f.controls.selection.units, ["Green_Alpha_3", "Green_Bravo_1"], "without touching the selection")
	assert_true(_enabled(panel, "support_by_fire"), "support by fire is enabled in the same frame")
	assert_eq(String(panel.summary()["reason"]), "", "and the reason is gone")
	assert_true(not panel.form_squad_rect().has_area(), "and so is the button")
	panel.press_command("support_by_fire")
	assert_eq(f.controls.mode, "support_by_fire", "the button arms")
	await f.click(f.ground(Vector3(0, 0, 0)))
	var element := f.controls.elements.of("Green_Alpha_3")
	assert_true(element != null and element == f.controls.elements.of("Green_Bravo_1"), "the two are one element")
	assert_eq(String(element.task.get("verb", "")) if element != null else "", "support_by_fire", "carrying the task")


func test_the_reason_names_what_the_selection_is() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	f.controls.selection.set_units(["Green_Alpha_1", "Green_Alpha_2"])
	var part := f.controls.task_refusal()
	assert_true(part.contains("Alpha") and part.contains("press 1"), "part of one squad: press its number (%s)" % part)
	f.controls.groups.save(1, ["Green_Alpha_2", "Green_Alpha_3"])
	f.controls.selection.set_units(["Green_Alpha_1"])
	assert_true(f.controls.task_refusal().contains("no squad"), "a unit in no group says so (%s)" % f.controls.task_refusal())
	f.controls.selection.set_units(["Green_Bravo_1", "Green_Bravo_2"])
	assert_eq(f.controls.task_refusal(), "", "a whole squad has nothing to explain")


func test_a_task_key_on_a_mixed_selection_is_refused_at_the_key_in_the_same_words() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var heard: Array = []
	f.controls.command_issued.connect(func(_command: Dictionary, error: String) -> void: heard.append(error))
	await f.select(["Green_Alpha_1", "Green_Bravo_1"])
	await f.key(KEY_R)
	assert_eq(f.controls.mode, "", "R does not arm a task the selection cannot take")
	assert_eq(heard, [f.controls.task_refusal()], "and the refusal says why, in the card's words (%s)" % [heard])
	heard.clear()
	f.controls.armed_world_order(Vector3(0, 0, 0))
	f.controls.mode = "screen"
	f.controls.armed_world_order(Vector3(0, 0, 0))
	assert_eq(heard, [f.controls.task_refusal()], "the radar says the same (%s)" % [heard])


func test_form_squad_takes_the_lowest_empty_group_and_says_so() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var told: Array = []
	f.controls.notice.connect(func(text: String, _warning: bool) -> void: told.append(text))
	f.controls.selection.set_units(["Green_Alpha_1", "Green_Bravo_2"])
	assert_eq(f.controls.form_squad(), 3, "groups 1 and 2 are squads: the next empty one is 3")
	assert_eq(told, ["Squad 3 formed: press 3 to select it"], "the player is told which number it is")
	assert_eq(f.controls.groups.members(1).size(), 3, "Ctrl+N's rule: the units stay in their old groups too")
	assert_eq(f.controls.form_squad(), 3, "pressing it again on the same selection changes nothing")
	for number in range(4, ControlGroups.COUNT + 1):
		f.controls.groups.save(number, ["Green_Alpha_1"])
	f.controls.selection.set_units(["Green_Alpha_2", "Green_Bravo_1"])
	assert_eq(f.controls.form_squad(), 0, "with all nine groups used there is no free number")


## Round 10 (item 4): the header counts the selected units that are on no number key.
func test_the_panel_counts_units_in_no_squad() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var panel: SelectionPanel = setup[1]
	f.controls.groups.save(2, ["Green_Bravo_1"])
	f.controls.selection.set_units(["Green_Alpha_1", "Green_Bravo_1", "Green_Bravo_2"])
	assert_eq(int(panel.summary()["ungrouped"]), 1, "Bravo_2 left group 2: one unit in no squad")
	f.controls.form_squad()
	assert_eq(int(panel.summary()["ungrouped"]), 0, "Form squad puts it on a number key")
