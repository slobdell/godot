extends TestCase
## Control X3: orders from the mouse and keyboard, through the real input pipeline, into K1 Orders. Right-click
## ground = move, an enemy = attack, a friend = follow; A + click = attack-move; S stop; H hold; F + click = follow;
## shift queues (with waypoints); every order is acknowledged; and the response guarantee holds end to end.

const Fixture := preload("res://tests/support/control_fixture.gd")


func _setup(with_executor := false) -> Fixture:
	var f := Fixture.new(self)
	await f.build(with_executor)
	return f


func test_right_click_ground_moves_the_selection() -> void:
	var f := await _setup()
	var issued: Array = []
	f.controls.command_issued.connect(func(command: Dictionary, error: String) -> void: issued.append([command, error]))
	await f.select(["Green_Alpha_1", "Green_Alpha_2"])
	await f.right_click(f.ground(Vector3(-15, 0, 15)))
	var order := f.orders.current("Green_Alpha_1")
	assert_eq(order.get("verb", ""), "move", "right-clicking the ground issues a move")
	assert_eq(order.get("units", []), ["Green_Alpha_1", "Green_Alpha_2"], "to the whole selection")
	assert_true(Vector2(order["to"][0], order["to"][1]).distance_to(Vector2(-15, 15)) < 1.0, "to the clicked spot (%s)" % [order.get("to")])
	assert_eq(f.orders.current("Green_Alpha_3"), {}, "unselected units aren't ordered")
	assert_eq(issued.size(), 1, "command_issued fires once")
	assert_eq(issued[0][1], "", "without an error")
	var ack := f.controls.last_ack()
	assert_eq(ack.get("kind", ""), "move", "the order is acknowledged with a move marker")
	assert_true((ack["position"] as Vector3).distance_to(Vector3(-15, 0, 15)) < 1.0, "at the clicked spot")


## Round 5 reopened: right-clicking a friend is a MOVE to that spot, not a follow (game_design.md: "right-click ground
## = move ... F + click a friendly = follow/escort"). With an army packed together, follow-on-right-click meant half the
## player's "go there" clicks made a squad chase one of its own.
func test_right_click_an_enemy_attacks_it_and_a_friend_is_just_ground() -> void:
	var f := await _setup()
	await f.select(["Green_Alpha_1"])
	await f.right_click(f.screen("Rust_Alpha_1"))
	var order := f.orders.current("Green_Alpha_1")
	assert_eq(order.get("verb", ""), "attack", "right-clicking an enemy attacks")
	assert_eq(order.get("target", ""), "Rust_Alpha_1", "that enemy")
	assert_eq(f.controls.last_ack().get("kind", ""), "attack", "an attack marker acknowledges it")
	await f.right_click(f.screen("Green_Bravo_2"))
	order = f.orders.current("Green_Alpha_1")
	assert_eq(order.get("verb", ""), "move", "right-clicking a friend moves to that spot")
	assert_eq(order.get("target", ""), "", "and takes nobody as a target")
	await f.key(KEY_F)
	await f.click(f.screen("Green_Bravo_2"))
	order = f.orders.current("Green_Alpha_1")
	assert_eq(order.get("verb", ""), "follow", "F then a click is how you follow a friend")
	assert_eq(order.get("target", ""), "Green_Bravo_2", "that friend")


func test_a_then_click_attack_moves_and_right_click_cancels_it() -> void:
	var f := await _setup()
	await f.select(["Green_Alpha_1", "Green_Alpha_2"])
	await f.key(KEY_A)
	assert_eq(f.controls.mode, "attack_move", "A arms attack-move")
	await f.click(f.ground(Vector3(10, 0, 10)))
	assert_eq(f.orders.current("Green_Alpha_2").get("verb", ""), "attack_move", "the click attack-moves")
	assert_eq(f.controls.mode, "", "and disarms")
	assert_eq(f.controls.selection.units, ["Green_Alpha_1", "Green_Alpha_2"], "the click didn't change the selection")
	await f.key(KEY_A)
	await f.click(f.screen("Rust_Alpha_1"))
	assert_eq(f.orders.current("Green_Alpha_1").get("verb", ""), "attack", "A + click on an enemy attacks it")
	await f.key(KEY_A)
	await f.right_click(f.ground(Vector3(10, 0, 10)))
	assert_eq(f.controls.mode, "", "right-click cancels an armed order")
	assert_eq(f.orders.current("Green_Alpha_1").get("verb", ""), "attack", "without ordering anything")
	await f.key(KEY_A)
	await f.key(KEY_ESCAPE)
	assert_eq(f.controls.mode, "", "Escape cancels an armed order")
	assert_eq(f.controls.selection.units.size(), 2, "and keeps the selection")


func test_s_stops_h_holds_and_f_follows() -> void:
	var f := await _setup()
	await f.select(["Green_Alpha_1", "Green_Alpha_2"])
	await f.right_click(f.ground(Vector3(-15, 0, 15)))
	await f.key(KEY_S)
	assert_eq(f.orders.current("Green_Alpha_1").get("verb", ""), "stop", "S stops")
	await f.key(KEY_H)
	assert_eq(f.orders.current("Green_Alpha_2").get("verb", ""), "hold", "H holds")
	await f.key(KEY_F)
	assert_eq(f.controls.mode, "follow", "F arms follow")
	await f.click(f.screen("Green_Bravo_1"))
	assert_eq(f.orders.current("Green_Alpha_1").get("verb", ""), "follow", "F + click a friend follows it")
	assert_eq(f.orders.current("Green_Alpha_1").get("target", ""), "Green_Bravo_1", "that friend")


func test_keys_do_nothing_without_a_selection() -> void:
	var f := await _setup()
	await f.key(KEY_S)
	await f.key(KEY_A)
	assert_eq(f.controls.mode, "", "nothing to arm without a selection")
	await f.right_click(f.ground(Vector3(0, 0, 10)))
	assert_eq(f.orders.ordered_units(), [], "no orders without a selection")


func test_shift_queues_orders_and_shows_waypoints() -> void:
	var f := await _setup()
	await f.select(["Green_Bravo_2"])
	var points := [Vector3(20, 0, 25), Vector3(30, 0, 15), Vector3(20, 0, 5)]
	for point in points:
		await f.right_click(f.ground(point), true)
	assert_eq(f.orders.current("Green_Bravo_2").get("verb", ""), "move", "the first shift-click starts at once")
	assert_eq(f.orders.queue("Green_Bravo_2").size(), 2, "the others wait in the queue")
	var route := f.controls.waypoints("Green_Bravo_2")
	assert_eq(route.size(), 3, "the waypoint route shows all three stops")
	for i in points.size():
		assert_true((route[i]["position"] as Vector3).distance_to(points[i]) < 1.0, "stop %d is where it was clicked" % i)
	await f.key(KEY_A, true)
	await f.click(f.ground(Vector3(0, 0, 10)), true)
	assert_eq(f.controls.mode, "attack_move", "shift keeps attack-move armed for the next click")
	await f.click(f.ground(Vector3(-10, 0, 10)), true)
	assert_eq(f.orders.queue("Green_Bravo_2").size(), 4, "shift + A + clicks queue attack-moves")
	assert_eq(f.controls.waypoints("Green_Bravo_2")[4]["kind"], "attack_move", "queued attack-moves show as such")


func test_a_right_click_order_reaches_the_tracks_within_three_ticks() -> void:
	var f := await _setup(true)
	await f.select(["Green_Alpha_1", "Green_Bravo_2"])
	var goal := Vector3(0, 0, 5)
	var start_positions := {}
	for unit_name in ["Green_Alpha_1", "Green_Bravo_2"]:
		start_positions[unit_name] = f.tank(unit_name).global_position
	f.button(f.ground(goal), true, MOUSE_BUTTON_RIGHT)
	f.button(f.ground(goal), false, MOUSE_BUTTON_RIGHT)
	var first := {}
	for tick in SimClock.TICK_RATE:
		await tree.physics_frame
		for unit_name in start_positions:
			var tank := f.tank(unit_name)
			var aim: Variant = f.orders.goal_position(unit_name)
			if not first.has(unit_name) and aim != null and (absf(tank.command.turn) > 0.05 or tank.command.throttle > 0.05):
				first[unit_name] = tick + 1
	print("MEASURE control_click_to_command_ticks %s" % [first])
	for unit_name in start_positions:
		assert_true(first.has(unit_name) and first[unit_name] <= 3, "%s drives within 3 ticks of the click (%s)" % [unit_name, first.get(unit_name)])
		var closer: float = (start_positions[unit_name] as Vector3).distance_to(goal) - f.tank(unit_name).global_position.distance_to(goal)
		assert_true(closer > 1.0, "%s is on its way a second later (%.1f m closer)" % [unit_name, closer])


## Round 5 reopened (the lead: "I select squad 1, having them go somewhere ... the units do not re-arrange as intended",
## and later "it's as though their behavior is overridden by a higher priority"). A plain move is a DIRECT order now:
## the player said where, and that is where they go. The leader's own judgement stays on the verbs that ask for it -
## attack-move (fight what you meet), screen, base of fire - and on attacks.
func test_a_right_click_move_is_a_direct_order_and_the_other_verbs_stay_tasks() -> void:
	var f := await _setup()
	f.controls.elements = Elements.install(f.game_match, f.orders)  # the skirmish installs these; the plain fixture doesn't
	f.controls.groups.save(1, ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	f.controls.recall_group(1)
	await f.right_click(f.ground(Vector3(-30, 0, -20)))
	for unit_name in ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]:
		var order := f.orders.current(unit_name)
		assert_eq(String(order.get("verb", "")), "move", "%s has the player's own move order" % unit_name)
		assert_eq(String(order.get("source", "")), "player", "%s knows the player asked for it" % unit_name)
	assert_eq(f.controls.selected_element(), null, "a direct order stands the element down, so no leader re-issues")
	await f.key(KEY_E)
	await f.click(f.ground(Vector3(30, 0, -20)))
	assert_true(f.controls.selected_element() != null, "E still gives the element a screening task")


## Round 6: a direct order to PART of an element releases those units from it, so its leader stops re-slotting them;
## the rest stay the element, and re-selecting the whole group re-forms it with the next task.
func test_a_direct_order_to_part_of_an_element_releases_only_those_units() -> void:
	var f := await _setup()
	f.controls.elements = Elements.install(f.game_match, f.orders)
	f.controls.groups.save(1, ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	f.controls.recall_group(1)
	await f.key(KEY_H)
	var element := f.controls.selected_element()
	assert_true(element != null, "setup: a hold task forms the element")
	await f.select(["Green_Alpha_1"])
	await f.right_click(f.ground(Vector3(-10, 0, -20)))
	assert_eq(f.controls.elements.of("Green_Alpha_1"), null, "the unit given its own order leaves the element")
	assert_true(f.controls.elements.of("Green_Alpha_2") == element and f.controls.elements.of("Green_Alpha_3") == element,
			"the rest stay the element")
	f.controls.recall_group(1)
	await f.key(KEY_H)
	var again := f.controls.selected_element()
	assert_true(again != null and again.members().size() == 3, "re-selecting the group and tasking it re-forms all three")
