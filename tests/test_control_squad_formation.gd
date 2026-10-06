extends TestCase
## Round 19 (orders, O2). The lead: *"It seems that I can't assign different formations to different squads. It looks
## like if I apply a formation to one squad, when I select another squad, that same formation was applied."* A
## formation belongs to the squad he gave it to: a pick applies to the selected squad at once, selecting another shows
## that one's own, G cycles the selected squad's, and AUTO is a value per squad too. Asserted through the squads'
## elements and orders, never through a controller field.

const Fixture := preload("res://tests/support/control_fixture.gd")
const WEST := Vector3(-40, 0, 40)
const EAST := Vector3(40, 0, 40)


func _setup() -> Fixture:
	var f := Fixture.new(self)
	await f.build_scale(10)
	for entry: Array in [[1, WEST], [2, EAST]]:
		var names := f.controls.groups.members(int(entry[0]))
		for i in names.size():
			f.place(names[i], (entry[1] as Vector3) + Vector3((i - 2) * 6.0, 0, 0))
	await wait_physics_frames(2)
	return f


func _element(f: Fixture, number: int) -> Element:
	return f.controls.elements.of(f.controls.groups.members(number)[0])


func _task_formation(f: Fixture, number: int) -> String:
	var element := _element(f, number)
	return String(element.task.get("formation", UnitCommand.AUTO)) if element != null else "(no element)"


func test_a_pick_belongs_to_the_squad_it_was_made_for() -> void:
	var f: Fixture = await _setup()
	f.controls.recall_group(1)
	assert_eq(f.controls.formation, UnitCommand.AUTO, "a squad starts on AUTO")
	f.controls.set_formation("line")
	assert_eq(_task_formation(f, 1), "line", "the pick reaches squad 1 at once (re-formed where it stands)")
	f.controls.recall_group(2)
	assert_eq(f.controls.formation, UnitCommand.AUTO, "selecting squad 2 shows squad 2's formation, not squad 1's")
	f.controls.order_selection("move", {"to": [EAST.x, EAST.z - 40.0]})
	assert_eq(_task_formation(f, 2), UnitCommand.AUTO, "squad 2's next order carries ITS formation (AUTO)")
	f.controls.set_formation("column")
	assert_eq(_task_formation(f, 2), "column", "a pick for squad 2 re-plans squad 2's task")
	f.controls.recall_group(1)
	assert_eq(f.controls.formation, "line", "squad 1 still reads Line")
	f.controls.order_selection("move", {"to": [WEST.x, WEST.z - 40.0]})
	assert_eq(_task_formation(f, 1), "line", "and its next order goes in Line")


func test_g_cycles_only_the_selected_squad() -> void:
	var f: Fixture = await _setup()
	f.controls.recall_group(1)
	f.controls.set_formation("line")
	f.controls.recall_group(2)
	await f.key(KEY_G)
	assert_eq(f.controls.formation, FormationCatalog.next_in_cycle(UnitCommand.AUTO), "G steps squad 2 on from its own AUTO")
	assert_eq(_task_formation(f, 2), FormationCatalog.next_in_cycle(UnitCommand.AUTO), "and squad 2 takes it")
	assert_eq(_task_formation(f, 1), "line", "squad 1 is untouched")


func test_auto_is_a_choice_per_squad() -> void:
	var f: Fixture = await _setup()
	f.controls.recall_group(1)
	f.controls.set_formation("wedge")
	f.controls.recall_group(2)
	f.controls.set_formation("line")
	f.controls.recall_group(1)
	f.controls.set_formation(UnitCommand.AUTO)
	assert_eq(_task_formation(f, 1), UnitCommand.AUTO, "squad 1 back to its leader's choice")
	assert_true(not _element(f, 1).task.has("formation"), "AUTO is not sent: the leader decides by doctrine")
	f.controls.recall_group(2)
	assert_eq(f.controls.formation, "line", "squad 2 keeps Line")


func test_a_tasked_squad_replans_its_task_in_the_new_shape() -> void:
	var f: Fixture = await _setup()
	f.controls.recall_group(1)
	var to := [WEST.x, WEST.z - 50.0]
	f.controls.order_selection("move", {"to": to})
	var element := _element(f, 1)
	var seq := element.task_seq
	f.controls.set_formation("vee")
	assert_true(_element(f, 1) == element, "the same element")
	assert_eq(element.task.get("to"), to, "the same destination")
	assert_eq(String(element.task.get("formation", "")), "vee", "in the new shape")
	assert_true(element.task_seq > seq, "as a new task (it re-plans from where it is)")


func test_several_squads_selected_take_one_pick_each_and_show_mixed() -> void:
	var f: Fixture = await _setup()
	f.controls.recall_group(1)
	f.controls.set_formation("line")
	f.controls.selection.set_units(f.controls.groups.members(1) + f.controls.groups.members(2))
	assert_eq(f.controls.formation, RtsControls.MIXED_FORMATION, "Line and AUTO selected together read as mixed")
	assert_eq(CommandIcons.formation_readout(f.controls.formation, {})["label"], "—", "the button says —")
	f.controls.set_formation("wedge")
	assert_eq(_task_formation(f, 1), "wedge", "the pick reaches squad 1")
	assert_eq(_task_formation(f, 2), "wedge", "and squad 2")
	assert_eq(f.controls.formation, "wedge", "and the button reads their common one")


func test_a_pick_survives_a_direct_order_through_the_group() -> void:
	var f: Fixture = await _setup()
	f.controls.recall_group(1)
	f.controls.set_formation("line")
	f.controls.order_selection("move", {"to": [WEST.x, WEST.z - 30.0], "queue": true})  # a hand-drawn route: direct
	assert_true(_element(f, 1) == null, "setup: the queued route dissolved the squad's element")
	assert_eq(String(f.orders.current(f.controls.groups.members(1)[0]).get("formation", "")), "line",
			"the route goes in the squad's Line")
	assert_eq(f.controls.formation, "line", "the button still reads Line (the group remembers)")
	f.controls.order_selection("move", {"to": [WEST.x, WEST.z - 60.0]})
	assert_eq(_task_formation(f, 1), "line", "and the next task carries it again")


func test_part_of_a_squad_cannot_take_a_formation_and_says_why() -> void:
	var f: Fixture = await _setup()
	var one := f.controls.groups.members(1)
	f.controls.selection.set_units([one[0], one[1]])
	var said := f.controls.set_formation("line")
	assert_true(said != "", "refused, with a reason (%s)" % said)
	assert_true(_element(f, 1) == null, "nothing formed")
	f.controls.recall_group(1)
	assert_eq(f.controls.formation, UnitCommand.AUTO, "squad 1 unchanged")


## Stretch (b): Shift+G steps the selected squad's shape back through G's cycle.
func test_shift_g_steps_back() -> void:
	var f: Fixture = await _setup()
	f.controls.recall_group(1)
	await f.key(KEY_G)
	await f.key(KEY_G)
	var two_on := f.controls.formation
	await f.key(KEY_G, true)
	assert_eq(f.controls.formation, FormationCatalog.CYCLE[1], "Shift+G goes back one (from %s)" % two_on)
	await f.key(KEY_G, true)
	await f.key(KEY_G, true)
	assert_eq(f.controls.formation, FormationCatalog.CYCLE[FormationCatalog.CYCLE.size() - 1], "and wraps round to the last")
