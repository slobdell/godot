extends TestCase
## Round 8 (nav): FlowField — one cost-to-goal field per shared goal, read as a gradient, instead of every unit owning
## its own A* route to the same place. Pre-registered in _agents/streams/nav.md; OFF by default (`--nav-off=flow`
## turns it ON) until it clears the bar written there.


func test_the_gradient_walks_to_the_goal_around_cover() -> void:
	var arena := await ArenaFixture.build(self, "yard")
	var goal := Vector3(40, 0, -40)
	var field := FlowField.for_goal(arena, goal)
	assert_true(field.ready, "a field is built once the navmesh is up")
	var here := Vector3(-40, 0, 40)
	assert_true(field.reachable(here), "the far corner reaches the goal")
	var steps := 0
	while here.distance_to(goal) > FlowField.CELL_M * 2.0 and steps < 400:
		var next := field.next_point(here)
		assert_true(next.distance_to(here) > 0.01, "the gradient always points somewhere (step %d at %s)" % [steps, here])
		here = next
		steps += 1
	assert_true(here.distance_to(goal) <= FlowField.CELL_M * 2.0,
			"walking the gradient arrives (%.1f m away after %d steps)" % [here.distance_to(goal), steps])


func test_the_walk_is_no_longer_than_the_a_star_route_by_much() -> void:
	var arena := await ArenaFixture.build(self, "yard")
	var from := Vector3(-40, 0, 40)
	var goal := Vector3(40, 0, -40)
	var route := Pathing.find_path(arena, from, goal)
	var direct := 0.0
	for i in range(1, route.size()):
		direct += Vector2(route[i].x - route[i - 1].x, route[i].z - route[i - 1].z).length()
	var field := FlowField.for_goal(arena, goal)
	var here := from
	var walked := 0.0
	for step in 400:
		if here.distance_to(goal) <= FlowField.CELL_M * 2.0:
			break
		var next := field.next_point(here)
		walked += here.distance_to(next)
		here = next
	assert_true(walked <= direct * 1.35 + FlowField.CELL_M * 2.0,
			"the gradient's route is within a third of A* (%.1f m vs %.1f m)" % [walked, direct])


func test_a_goal_behind_a_wall_of_cover_is_unreachable_from_inside_it() -> void:
	var arena := await ArenaFixture.build(self, "yard")
	var inside: Variant = ArenaFixture.inside_cover(arena.layout)
	assert_true(inside != null, "the yard has cover to stand inside")
	var field := FlowField.for_goal(arena, Vector3(40, 0, -40))
	assert_true(not field.reachable(inside), "a cell inside cover has no way to the goal")


func test_two_units_sharing_a_goal_share_one_field() -> void:
	var arena := await ArenaFixture.build(self, "yard")
	var goal := Vector3(40, 0, -40)
	var first := FlowField.for_goal(arena, goal)
	var again := FlowField.for_goal(arena, goal + Vector3(0.4, 0, 0.4))
	var other := FlowField.for_goal(arena, Vector3(-40, 0, 40))
	assert_true(first == again, "goals within a cell share the field (that is the point of a flow field)")
	assert_true(first != other, "a different goal gets its own")


## The same two guarantees test_movement makes of the A* route, with the field driving instead: a unit gets there, and
## an unreachable goal still says so (it falls back to A*, because a goal off the mesh has no cell to sweep from).
func _flow_on() -> PackedStringArray:
	var saved := Movement._off
	Movement._off = PackedStringArray(["flow"])
	FlowField.clear()
	return saved


func test_a_unit_drives_to_its_goal_on_the_field() -> void:
	var saved := _flow_on()
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = preload("res://game/match/match.tscn").instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Mover", 0, Match.Team.GREEN)
	tank.global_position = Vector3(-100, 0, 20)
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	orders.set_orders({"type": "move_to", "x": -100.0, "z": -10.0}, {"type": "hold_fire"})
	for frame in SimClock.TICK_RATE * 12:
		await tree.physics_frame
		if Movement.state(tank)["phase"] == "arrived":
			break
	assert_eq(Movement.state(tank)["phase"], "arrived", "30 m of open lane, driven on the gradient")
	Movement._off = saved
	FlowField.clear()


func test_an_unreachable_goal_still_says_so_on_the_field() -> void:
	var saved := _flow_on()
	var arena := await ArenaFixture.build(self, "yard")
	var game_match: Match = preload("res://game/match/match.tscn").instantiate()
	add_to_tree(game_match)
	var inside: Variant = ArenaFixture.inside_cover(arena.layout)
	var target: Vector3 = inside
	var tank := game_match.spawn_tank("Mover", 0, Match.Team.GREEN)
	var start := NavigationServer3D.map_get_closest_point(arena.get_world_3d().navigation_map, target + Vector3(0, 0, 25))
	tank.global_position = Vector3(start.x, 0.0, start.z)
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	orders.set_orders({"type": "move_to", "x": target.x, "z": target.z}, {"type": "hold_fire"})
	var reading := {}
	for frame in SimClock.TICK_RATE * 12:
		await tree.physics_frame
		reading = Movement.state(tank)
		if reading["phase"] == "blocked":
			break
	assert_eq(reading.get("phase"), "blocked", "a goal inside cover reads blocked, not arrived (got %s)" % reading)
	Movement._off = saved
	FlowField.clear()
