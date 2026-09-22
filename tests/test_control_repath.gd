extends TestCase
## Round 10, R2: a player's order pre-empts everything, within one input frame. The lead, on Terminus: *"I had a
## selection and the yellow X's on the map were in the center, that's where they were driving to, and I was trying to
## right click to move them in a different direction and they didnt respond."*
##
## K1's repeat rule (Orders._same_order) compared each unit's SLOT goal within SAME_ORDER_M = 3 m, so two clicks a few
## metres apart on a group compared equal and the second was dropped without a word. The player's order now compares
## the CLICK, and only the same click again is a repeat.

const Fixture := preload("res://tests/support/control_fixture.gd")
const ALPHA := ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]


func _orders() -> Orders:
	var f := Fixture.new(self)
	await f.build(false)
	return f.orders


func test_a_players_second_click_a_few_metres_away_is_a_new_order() -> void:
	var orders := await _orders()
	var move := {"units": ALPHA, "verb": "move", "to": [-10.0, 0.0], "source": "player"}
	assert_eq(orders.issue(move), "", "the first click lands")
	var first := orders.current("Green_Alpha_2")
	move["to"] = [-8.0, 1.0]  # 2.2 m away: every slot moves by the same 2.2 m, inside the old 3 m repeat radius
	assert_eq(orders.issue(move), "", "the second click is accepted")
	assert_true(orders.current("Green_Alpha_2")["id"] != first["id"], "and REPLACES the order: it is where he clicked")
	assert_eq(orders.last_dropped, 0, "nobody was left on the old one")


func test_the_same_click_again_is_still_not_a_restart() -> void:
	var orders := await _orders()
	var move := {"units": ALPHA, "verb": "move", "to": [-10.0, 0.0], "source": "player"}
	orders.issue(move)
	var first := orders.current("Green_Alpha_1")
	move["to"] = [-10.4, 0.3]
	orders.issue(move)
	assert_eq(orders.current("Green_Alpha_1")["id"], first["id"], "a double-click on one spot is one order (round 5's rule)")
	assert_eq(orders.last_dropped, ALPHA.size(), "and Orders says every unit kept its order")
	move["units"] = ["Green_Alpha_1", "Green_Alpha_2"]
	orders.issue(move)
	assert_true(orders.current("Green_Alpha_1")["id"] != first["id"], "the same spot for a different group is a new formation")


func test_a_players_order_always_takes_a_unit_off_its_leaders() -> void:
	var orders := await _orders()
	orders.issue({"units": ["Green_Alpha_1"], "verb": "move", "to": [-10.0, 0.0], "source": "element"})
	var leader := orders.current("Green_Alpha_1")
	orders.issue({"units": ["Green_Alpha_1"], "verb": "move", "to": [-10.0, 0.0], "source": "player"})
	assert_true(orders.current("Green_Alpha_1")["id"] != leader["id"], "the same spot, but now it is HIS order")
	assert_eq(orders.current("Green_Alpha_1")["source"], "player", "which no leader re-slots")


func test_an_order_under_a_new_task_is_never_a_repeat() -> void:
	var orders := await _orders()
	assert_eq(UnitCommand.validate({"units": ["Green_Alpha_1"], "verb": "move", "to": [0, 0], "task": 1.5}),
			"'task' must be a whole number (the element's task sequence)", "task is a sequence number")
	orders.issue({"units": ["Green_Alpha_1"], "verb": "move", "to": [-10.0, 0.0], "source": "element", "task": 3})
	var first := orders.current("Green_Alpha_1")
	orders.issue({"units": ["Green_Alpha_1"], "verb": "move", "to": [-10.5, 0.0], "source": "element", "task": 3})
	assert_eq(orders.current("Green_Alpha_1")["id"], first["id"], "the same task's drift is still a repeat (no churn)")
	orders.issue({"units": ["Green_Alpha_1"], "verb": "move", "to": [-10.5, 0.0], "source": "element", "task": 4})
	assert_true(orders.current("Green_Alpha_1")["id"] != first["id"], "a new task at the same place is a new order")
	assert_eq(int(orders.current("Green_Alpha_1")["task"]), 4, "carrying its task number")
