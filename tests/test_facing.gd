extends TestCase
## Facing is a squad concept (round 6, the lead): *"I couldn't tell what direction they were facing"*, and facing matters
## *"for trying to emplace units in an ambush"*. An order that says which way to face is obeyed end to end: K1's
## `facing` on a move, an element task's `facing`, and an ambush pointing at its kill zone.

const EAST := Vector3(1, 0, 0)


func _forward(tank: Tank) -> Vector3:
	return TacticsFormation.flat(-tank.global_basis.z)


func test_a_unit_ordered_to_face_east_ends_facing_east() -> void:
	var lab := TacticsLab.create(self, 31)
	var tank := lab.unit(Match.Team.GREEN, "Green_A_1", Vector3(TacticsScenarios.LANE_X, 0, 40), 0.0)
	await lab.start()
	# Driving north, told to face east once there.
	assert_eq((lab.orders as Orders).issue(UnitCommand.make(["Green_A_1"], "move",
			{"to": [TacticsScenarios.LANE_X, 0.0], "facing": [1.0, 0.0]})), "", "setup: the order is accepted")
	for tick in SimClock.TICK_RATE * 20:
		await lab.step()
	var forward := _forward(tank)
	print("MEASURE facing K1 move forward %s, %.1f m from the goal" % [forward,
			Vector2(tank.global_position.x - TacticsScenarios.LANE_X, tank.global_position.z).length()])
	assert_true(forward.dot(EAST) > 0.9, "it arrived and turned to the facing it was given (forward %s)" % forward)
	lab.dispose()


func test_an_element_moved_with_a_facing_ends_pointing_that_way() -> void:
	var lab := TacticsLab.create(self, 32)
	var names: Array = []
	for i in 4:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				Vector3(TacticsScenarios.LANE_X + i * 8.0, 0, 50), 0.0).name))
	var alpha := lab.element(names, "Alpha")
	await lab.start()
	assert_eq(alpha.assign({"verb": "move", "to": [TacticsScenarios.LANE_X, 0.0], "drills": false, "facing": [1.0, 0.0]}),
			"", "setup: a plain move with a facing is a valid task")
	for tick in SimClock.TICK_RATE * 25:
		await lab.step()
	assert_true((alpha.heading as Vector3).dot(EAST) > 0.99, "the element's formation is laid facing east (%s)" % alpha.heading)
	var facing := 0
	for unit_name: String in names:
		if _forward(lab.tank_of(unit_name)).dot(EAST) > 0.8:
			facing += 1
	assert_true(facing >= 3, "and its vehicles face east once there (%d of 4)" % facing)
	lab.dispose()
