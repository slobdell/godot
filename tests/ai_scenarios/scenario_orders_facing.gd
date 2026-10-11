extends TestCase
## Round 26 (orders; found by test_control_order_marks flaking on main d28bf8c5): a squad of HIS whose task is re-given
## WITHOUT a heading, after its crews already carry the old one, sheds it within a second. On the player's team the
## task's first update re-issues every crew under the new task id (Element.preempting), so it sheds in ~5 frames
## (brains measured, builder0 lab 8fd6209a). Without the "player_team" meta (the control fixture's default) the element
## only re-issues on its own cadence and kept the old heading 360+ frames: that path is brains' (`_should_issue`,
## brains 3214dddf), measured in their test_tactics_reorder_heading. Orders' half (an element order that drops a
## heading is not a repeat, `Orders._same_order`) is unit-tested in test_control_armed_facing.

const Fixture := preload("res://tests/support/control_fixture.gd")
const CREWS := ["Green_Bravo_1", "Green_Bravo_2"]


func test_a_squad_re_given_its_task_without_a_heading_sheds_the_old_one() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.elements = Elements.install(f.game_match, f.orders)
	f.game_match.set_meta("player_team", Match.Team.GREEN)
	var element := f.controls.elements.form(CREWS, "Bravo")
	element.assign({"verb": "move", "to": [30.0, 10.0], "facing": [0.0, -1.0], "drills": false})
	await wait_physics_frames(30)
	for unit_name: String in CREWS:
		assert_true(f.orders.current(unit_name).has("facing"), "setup: %s carries the task's heading" % unit_name)
	element.assign({"verb": "move", "to": [30.0, 10.0], "drills": false})
	var waited := 0
	while waited < 60 and CREWS.any(func(n: String) -> bool: return f.orders.current(n).has("facing")):
		await wait_physics_frames(1)
		waited += 1
	print("MEASURE stale_heading_shed_frames ", waited)
	for unit_name: String in CREWS:
		assert_true(not f.orders.current(unit_name).has("facing"),
				"%s dropped the old heading within 1 s (%s)" % [unit_name, f.orders.current(unit_name)])
