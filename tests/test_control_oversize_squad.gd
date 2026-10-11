extends TestCase
## Round 26 (perf, builder0 a5ab7518): `Elements.form` refuses a group of more than five (C19.1) and returns null, and
## the controls called `.assign` on it: a SCRIPT ERROR, and the order - even a plain right-click move - silently
## dropped. A move now goes to the crews directly; a task only a squad can carry is refused with the reason.
## A player's SELECTION of a group of six never gets here (`SelectionSquads.split` deals it into two squads of three, and
## `test_the_selection_path_deals_a_group_of_six_into_two_squads` pins that); these call the three places that form an
## element directly, as perf's run reached `assign_task`.

const Fixture := preload("res://tests/support/control_fixture.gd")
const SIX := 7  # the control group holding six vehicles


func _six(f: Fixture) -> Array:
	var names: Array = Array(f.controls.groups.members(1))
	var second: Array = Array(f.controls.groups.members(2))
	names.append(second.pop_front())
	# The six are ONE group and in no other (the laptop fold's squad of six, perf's case), not two squads' worth.
	f.controls.groups.save(1, [])
	f.controls.groups.save(2, second)
	f.controls.groups.save(SIX, names)
	f.controls.selection.set_units(names)
	assert_eq(names.size(), 6, "setup: six vehicles")
	assert_eq(f.controls.selected_group(), SIX, "setup: the six are one control group")
	return names


func test_a_move_for_a_group_too_big_for_one_squad_still_moves_every_crew() -> void:
	var f := Fixture.new(self)
	await f.build_scale(10)
	var names := _six(f)
	expect_error("more than one squad")
	assert_eq(f.controls.assign_task("move", {"to": [0.0, 0.0]}), "", "the move is taken")
	for unit_name: String in names:
		var order := f.orders.current(unit_name)
		assert_eq(String(order.get("verb", "")), "move", "%s was told to move (%s)" % [unit_name, order])
		assert_true(f.controls.elements.of(unit_name) == null, "%s is in no element: no squad of six was formed" % unit_name)


func test_a_task_for_a_group_too_big_for_one_squad_is_refused_with_the_reason() -> void:
	var f := Fixture.new(self)
	await f.build_scale(10)
	var names := _six(f)
	expect_error("more than one squad")
	var error := f.controls.assign_task("screen", {"to": [0.0, 0.0]})
	assert_eq(error, RtsControls.too_big_for_a_squad(6), "refused, and says why")
	assert_true(error.contains("split it"), "and what to do (%s)" % error)
	for unit_name: String in names:
		assert_true(f.orders.current(unit_name).is_empty(), "%s got nothing it cannot carry" % unit_name)


func test_the_per_squad_path_falls_back_the_same_way() -> void:
	var f := Fixture.new(self)
	await f.build_scale(10)
	var names := _six(f)
	expect_error("more than one squad")
	assert_eq(f.controls._task_squad({"units": names, "number": SIX}, "move", {"to": [0.0, 0.0]}), "",
			"a squad's move with no element to carry it goes to its crews")
	assert_eq(String(f.orders.current(names[0]).get("verb", "")), "move", "and they move")
	expect_error("more than one squad")
	assert_eq(f.controls._task_squad({"units": names, "number": SIX}, "ambush", {"to": [0.0, 0.0]}),
			RtsControls.too_big_for_a_squad(6), "an ambush is refused with the reason")


func test_a_formation_for_an_idle_group_too_big_for_one_squad_is_refused_not_an_error() -> void:
	var f := Fixture.new(self)
	await f.build_scale(10)
	var names := _six(f)
	expect_error("more than one squad")
	f.controls._give_formation({"units": names, "number": SIX}, "line")
	assert_eq(f.controls._last_refusal, RtsControls.too_big_for_a_squad(6), "he is told why it did not re-form")
	assert_eq(f.controls.groups.formation(SIX), "line", "the group keeps the shape for its next order")


func test_the_selection_path_deals_a_group_of_six_into_two_squads() -> void:
	var f := Fixture.new(self)
	await f.build_scale(10)
	_six(f)
	var found := f.controls.selection_squads()
	assert_eq((found["squads"] as Array).size(), 2, "a group of six is two squads to the order path")
	for squad: Dictionary in found["squads"]:
		assert_eq((squad["units"] as Array).size(), 3, "of three each")
