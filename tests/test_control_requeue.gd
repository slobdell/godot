extends TestCase
## Round 35 (orders D6, R35.28): A SHIFT-CLICK NEVER REPLACES A SQUAD'S ROUTE. Round 22's untangle (O1b) re-deals VEHICLES
## between two squads whose drives would cross at a click (his interleaved threes), so the elements it forms are no longer
## exactly the control groups; a later shift-click found no element "exactly" the group, queued nothing and REPLACED the
## task (planner's probe, Crossing 5 route s3614: three squads got one leg each). Now a shifted move queues on the elements
## the squad's units belong to.

const Fixture := preload("res://tests/support/control_fixture.gd")

var _was := RtsControls.REQUEUE


func teardown() -> void:
	RtsControls.REQUEUE = _was
	SelectionSquads.reset_g1()
	super.teardown()


## Two squads of five standing interleaved across the way to the click (each squad's crews on both sides), so the row's
## two places make their drives cross and untangle re-deals vehicles between them.
func _interleaved(f: Fixture) -> Array[String]:
	var all: Array[String] = []
	for number in [1, 2]:
		var names := f.controls.groups.members(number)
		for i in names.size():
			f.place(names[i], Vector3(-45.0 + i * 20.0 + (number - 1) * 10.0, 0, 90.0 + (number - 1) * 6.0))
		all.append_array(names)
	return all


func test_a_shift_click_after_an_untangled_click_queues_on_every_squad() -> void:
	RtsControls.REQUEUE = true  # D6 is off by default until its A/B
	SelectionSquads.set_g1(false)  # the untangle's re-deal is the group click before G1
	var f := Fixture.new(self)
	await f.build_scale(10)
	var all := _interleaved(f)
	await wait_physics_frames(2)
	f.controls.selection.set_units(all)
	assert_eq(f.controls.order_selection("move", {"to": [0.0, 0.0]}), "", "the first click is taken")
	var first := {}
	var mixed := false
	for name in all:
		var element: Element = f.controls.elements.of(name)
		assert_true(element != null, "%s has an element after the click" % name)
		first[name] = element.task.get("to")
		var group_one := f.controls.groups.members(1).has(name)
		for other: String in element.members():
			if f.controls.groups.members(1).has(other) != group_one:
				mixed = true
	print("MEASURE requeue: untangle mixed the squads' vehicles: %s" % mixed)
	assert_true(mixed, "setup: untangle re-dealt vehicles across the two squads (else this test reproduces nothing)")
	f.controls.selection.set_units(all)
	assert_eq(f.controls.order_selection("move", {"to": [0.0, -40.0], "queue": true}), "", "the shift-click is taken")
	for name in all:
		var element: Element = f.controls.elements.of(name)
		assert_eq(element.task.get("to"), first[name], "%s still drives its first leg (not replaced)" % name)
		assert_eq(element.queued_tasks.size(), 1, "%s has the shifted leg queued behind it" % name)


func test_switched_off_the_shift_click_replaces_as_round_34_did() -> void:
	RtsControls.REQUEUE = false
	SelectionSquads.set_g1(false)
	var f := Fixture.new(self)
	await f.build_scale(10)
	var all := _interleaved(f)
	await wait_physics_frames(2)
	f.controls.selection.set_units(all)
	f.controls.order_selection("move", {"to": [0.0, 0.0]})
	f.controls.selection.set_units(all)
	f.controls.order_selection("move", {"to": [0.0, -40.0], "queue": true})
	var replaced := 0
	for name in all:
		if f.controls.elements.of(name).queued_tasks.is_empty():
			replaced += 1
	assert_true(replaced > 0, "off: the old replace (%d crews lost their first leg)" % replaced)
