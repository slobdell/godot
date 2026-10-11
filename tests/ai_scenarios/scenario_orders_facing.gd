extends TestCase
## Round 26 (orders; found by test_control_order_marks flaking on main d28bf8c5): a squad whose task is re-given WITHOUT
## a heading, after its crews already carry the old one, must shed it. They did not: `Element._should_issue` compares
## the intention (verb, place, target) without the heading, so a crew already on the leader's move is never re-issued
## and keeps driving to the old heading (builder0 at ba541b96: unchanged after 360 physics frames, issued_tick 5).
## Brains' fix; PENDING until it lands, then promoted (the runner fails an UNEXPECTED PASS, which is the reminder).
## Orders' half (an element order that drops a heading is not a repeat, `Orders._same_order`) is unit-tested in
## test_control_armed_facing.

const PENDING := ["test_a_squad_re_given_its_task_without_a_heading_sheds_the_old_one"]

const Fixture := preload("res://tests/support/control_fixture.gd")
const CREWS := ["Green_Bravo_1", "Green_Bravo_2"]


func test_a_squad_re_given_its_task_without_a_heading_sheds_the_old_one() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.elements = Elements.install(f.game_match, f.orders)
	var element := f.controls.elements.form(CREWS, "Bravo")
	element.assign({"verb": "move", "to": [30.0, 10.0], "facing": [0.0, -1.0], "drills": false})
	await wait_physics_frames(30)
	for unit_name: String in CREWS:
		assert_true(f.orders.current(unit_name).has("facing"), "setup: %s carries the task's heading" % unit_name)
	element.assign({"verb": "move", "to": [30.0, 10.0], "drills": false})
	var waited := 0
	while waited < 360 and CREWS.any(func(n: String) -> bool: return f.orders.current(n).has("facing")):
		await wait_physics_frames(10)
		waited += 10
	print("MEASURE stale_heading_shed_frames ", waited)
	for unit_name: String in CREWS:
		assert_true(not f.orders.current(unit_name).has("facing"),
				"%s dropped the old heading within 6 s (%s)" % [unit_name, f.orders.current(unit_name)])
