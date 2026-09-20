extends TestCase
## Round 7, from nav's and squad's measurements: most of a unit's churn under an order is the evasion the lead asked for,
## and it may read to him as a unit that forgot its order. So the order stays on screen until it is done: a marker at
## the ordered point with the task's own symbol, a lead line from the group, and how many have got there.

const Fixture := preload("res://tests/support/control_fixture.gd")


func test_an_order_stays_on_screen_until_the_squad_gets_there() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	await f.select(["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	assert_eq(f.controls.order_selection("attack_move", {"to": [0.0, -40.0]}), "", "the selection is sent somewhere")
	var marks := f.controls.order_marks()
	assert_eq(marks.size(), 1, "one marker for the one order")
	var mark: Dictionary = marks[0]
	assert_eq(mark["verb"], "attack_move", "it names the order")
	assert_true((mark["point"] as Vector3).distance_to(Vector3(0, 0, -40)) < 1.0, "at the ordered point")
	assert_eq(int(mark["units"]), 3, "for the three units carrying it")
	assert_eq(int(mark["arrived"]), 0, "none there yet")
	assert_true(String(f.controls.order_mark_label(mark)).begins_with("ATTACK-MOVE"), "labelled in the player's words (%s)" % f.controls.order_mark_label(mark))
	# Two of them get there: the mark counts them, and the order is still shown for the third.
	for unit_name in ["Green_Alpha_1", "Green_Alpha_2"]:
		var goal: Vector3 = Orders.goal_of(f.orders.current(unit_name), f.game_match)
		f.place(unit_name, goal)
	assert_eq(int(f.controls.order_marks()[0]["arrived"]), 2, "two of three there")
	assert_true(f.controls.order_mark_label(f.controls.order_marks()[0]).contains("2/3"), "and it says so")


func test_nothing_selected_or_nothing_ordered_draws_nothing() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	assert_true(f.controls.order_marks().is_empty(), "no selection, no marks")
	await f.select(["Green_Alpha_1"])
	assert_true(f.controls.order_marks().is_empty(), "no order, no marks")


## The case the lead plays: a squad on a task. The pin names the TASK he gave (Screen), not the leader's own moves.
func test_a_squad_on_a_task_shows_the_task() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.elements = Elements.install(f.game_match, f.orders)
	f.controls.groups.save(2, ["Green_Bravo_1", "Green_Bravo_2"])
	await f.select(["Green_Bravo_1", "Green_Bravo_2"])
	await f.key(KEY_E)
	await f.click(f.ground(Vector3(30, 0, 10)))
	assert_eq(f.controls.elements.of("Green_Bravo_1").task.get("verb", ""), "screen", "the squad is screening")
	var marks := f.controls.order_marks()
	assert_eq(marks.size(), 1, "one pin for the squad's task (%s)" % [marks])
	assert_eq(marks[0]["verb"], "screen", "naming the task, not the leader's moves")
	assert_true(bool(marks[0]["task"]), "drawn as a task, with a lead line from the squad")
	assert_true((marks[0]["point"] as Vector3).distance_to(Vector3(30, 0, 10)) < 1.0, "at the point he clicked")
	assert_true(f.controls.order_mark_label(marks[0]).begins_with("SCREEN"), "labelled SCREEN")


## Round 9: the pin for a move the player DREW a heading on carries that heading, so he can see which way his units
## will be pointing when they get there - before they get there. A pin for a plain click carries none.
func test_a_dragged_order_puts_its_heading_on_the_pin() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	await f.select(["Green_Alpha_1", "Green_Alpha_2"])
	await f.right_click(f.ground(Vector3(-30, 0, 10)))
	assert_true(not (f.controls.order_marks()[0] as Dictionary).has("facing"),
			"a plain right click leaves the pin with no heading on it")
	await f.right_drag(f.ground(Vector3(-30, 0, 10)), f.ground(Vector3(-30, 0, -10)))
	var mark: Dictionary = f.controls.order_marks()[0]
	assert_true(mark.has("facing"), "the dragged order's pin carries the heading (%s)" % [mark])
	assert_true((mark["facing"] as Vector3).distance_to(Vector3(0, 0, -1)) < 0.08,
			"pointing the way he dragged, got %s" % [mark["facing"]])
	assert_true(f.controls.describe({"units": ["Green_Alpha_1"], "verb": "move", "facing": [0.0, -1.0]}).ends_with("facing N"),
			"and the HUD says which way in plain compass: %s" % f.controls.describe({"units": ["Green_Alpha_1"], "verb": "move", "facing": [0.0, -1.0]}))


## The pin draws what the CREWS WERE TOLD, not what the task holds. squad's 23b1d1a7 gives a dragged heading to the
## element's LEADER and leaves followers on a plain follow, so a pin mirroring the task would show an arrow for a
## turn the squad is not going to make -- which the lead would read as his units ignoring him, the exact complaint
## the facing drag exists to answer.
func test_the_squad_pin_only_claims_a_heading_every_crew_was_given() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.elements = Elements.install(f.game_match, f.orders)
	var element := f.controls.elements.form(["Green_Bravo_1", "Green_Bravo_2"], "Bravo")
	element.assign({"verb": "move", "to": [30.0, 10.0], "facing": [0.0, -1.0], "drills": false})
	f.controls.groups.save(2, ["Green_Bravo_1", "Green_Bravo_2"])
	await f.select(["Green_Bravo_1", "Green_Bravo_2"])
	assert_true(not f.controls.order_marks().is_empty(), "setup: the squad's task has a pin")
	# The task holds a heading, but no crew has been told one: the pin must NOT claim it.
	assert_true(not (f.controls.order_marks()[0] as Dictionary).has("facing"),
			"a heading on the task that no crew was given is not drawn (%s)" % [f.controls.order_marks()[0]])
	# squad's 23b1d1a7 shape: the LEADER has it, the follower does not. Still not a squad heading.
	assert_eq(f.orders.issue({"units": ["Green_Bravo_1"], "verb": "move", "to": [30.0, 10.0],
			"facing": [0.0, -1.0], "source": "player"}), "", "the leader is given the heading")
	assert_true(not (f.controls.order_marks()[0] as Dictionary).has("facing"),
			"one crew out of two is not the squad arriving on a heading")
	# Every crew told the same heading: now the pin may claim it, and does so with no further change here.
	assert_eq(f.orders.issue({"units": ["Green_Bravo_1", "Green_Bravo_2"], "verb": "move", "to": [30.0, 10.0],
			"facing": [0.0, -1.0], "source": "player"}), "", "both crews are given it")
	var mark: Dictionary = f.controls.order_marks()[0]
	assert_true(mark.has("facing"), "with every crew told, the pin draws the heading (%s)" % [mark])
	assert_true((mark["facing"] as Vector3).distance_to(Vector3(0, 0, -1)) < 0.08, "and it is the one they were given")
