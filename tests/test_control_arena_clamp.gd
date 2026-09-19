extends TestCase
## Contract M4 (round 7): control's clamps ask the arena, not a square constant. An order - or the cursor's ground point -
## past the wall lands at the nearest point a hull can be: arena's nearest-boundary clamp, WALL_CLEARANCE_M inside the
## wall's inner face, and out of water and pits. On today's square that is exactly the old ±DRIVABLE_LIMIT.


func _with(layout: Dictionary, body: Callable) -> void:
	var saved := Arena.active
	Arena.active = layout
	body.call()
	Arena.active = saved


func test_on_the_square_the_clamp_is_the_old_one() -> void:
	_with({"half_size": 120.0}, func() -> void:
		for point: Vector3 in [Vector3(0, 0, 200), Vector3(-300, 0, 10), Vector3(130, 0, 130), Vector3(-500, 0, -140)]:
			var old := Vector3(clampf(point.x, -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT), 0.0,
					clampf(point.z, -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT))
			assert_true(Orders.clamp_to_arena(point).distance_to(old) < 0.01,
					"%s clamps to %s as before (got %s)" % [point, old, Orders.clamp_to_arena(point)])
		assert_eq(Orders.clamp_to_arena(Vector3(10, 0, -20)), Vector3(10, 0, -20), "a point inside is left alone"))


func test_on_a_hexagon_nothing_lands_outside_the_wall() -> void:
	# half_size is the shape's bound: for a hexagon its circumradius, so its flats are 121 x cos 30° = 104.8 m out.
	_with({"half_size": 121.0, "shape": {"kind": "hexagon"}}, func() -> void:
		var clearance := Orders.WALL_CLEARANCE_M
		for angle in range(0, 360, 15):
			var far := Vector3(sin(deg_to_rad(angle)), 0.0, cos(deg_to_rad(angle))) * 300.0
			var at := Orders.clamp_to_arena(far)
			var flat := Vector2(at.x, at.z)
			assert_true(ArenaShape.contains("hexagon", 121.0, flat, clearance - 0.01),
					"an order toward %d° stays a hull's clearance inside the wall (%s)" % [angle, at])
			# Nearest boundary: against the wall (within half a metre of the clearance line), not pulled short of it.
			assert_true(not ArenaShape.contains("hexagon", 121.0, flat, clearance + 0.5),
					"and against the wall, not short of it (%s toward %d°)" % [at, angle])
		# The diagonal a square clamp gets wrong: the old ±116 box allows (116, 116), 164 m out, past this wall.
		var corner := Orders.clamp_to_arena(Vector3(116, 0, 116))
		assert_true(ArenaShape.contains("hexagon", 121.0, Vector2(corner.x, corner.z), clearance - 0.01),
				"a point the old box allowed is brought inside the hexagon (%s)" % corner))


func test_a_click_past_the_wall_orders_inside_it() -> void:
	var f := preload("res://tests/support/control_fixture.gd").new(self)
	await f.build(false)
	_with({"half_size": 121.0, "shape": {"kind": "hexagon"}}, func() -> void:
		f.controls.selection.set_units(["Green_Alpha_1"])
		assert_eq(f.controls.order_selection("move", {"to": [150.0, 150.0]}), "", "the order is taken")
		var to: Array = f.orders.current("Green_Alpha_1")["to"]
		assert_true(ArenaShape.contains("hexagon", 121.0, Vector2(float(to[0]), float(to[1]))),
				"and it is inside the hexagon (%s)" % [to]))
