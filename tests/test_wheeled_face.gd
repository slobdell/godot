extends TestCase
## Round 8 (the lead): *"the semi trucks are yawing in place (should be impossible, they're not a tracker vehicle)."* A
## wheeled hull turns on the spot only by creeping forward and back, and the brain kept asking it to: a held unit's refused
## advance became a turn toward the threat. Asserted as a MECHANISM: a held, turreted wheeled truck with an enemy in sight
## is never ordered to face (its turret aims), while a tracked tank in the same spot still is — the control that makes
## this the rule, not the situation.


func _run(unit_id: String) -> Dictionary:
	var s := AiScenario.create(self, 4)
	s.game_match.set_meta("player_team", Match.Team.GREEN)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 40), PI + 0.7, {}, unit_id)
	AiScenario.make_durable(me)
	# 30 m off, inside every gun's band; the hull starts ~40 degrees off it, so facing it means turning the hull.
	var target := s.dummy(Match.Team.RUST, "Rust_A_1", Vector3(-100, 0, 10), 0.0)
	AiScenario.make_durable(target)
	var brain := s.brain_of(me)
	var faces := 0
	await s.start()
	for tick in SimClock.TICK_RATE * 12:
		await s.step()
		if String(brain.move_order.get("type", "")) == "face":
			faces += 1
	var result := {"faces": faces, "declined": brain.faces_declined, "shots": s.shots_by(me)}
	s.dispose()
	return result


func test_a_held_turreted_truck_lets_its_turret_aim() -> void:
	assert_true(TankBrain.turret_carries_aim("gang_tank"), "setup: the War Rig is wheeled with a turret")
	assert_true(not TankBrain.turret_carries_aim("tank"), "setup: the control tank is not")
	assert_true(not TankBrain.turret_carries_aim("gang_scout"), "and a fixed-gun buggy is not: its hull is its aim")
	var truck := await _run("gang_tank")
	var tank := await _run("tank")
	print("MEASURE wheeled_face truck %s; tracked control %s" % [truck, tank])
	assert_eq(int(truck["faces"]), 0, "the truck is never ordered to turn in place (%d ticks)" % truck["faces"])
	assert_true(int(truck["declined"]) > 0, "because it declined the brain's face orders (%d), not because none came" % truck["declined"])
	assert_true(int(tank["faces"]) > 0, "control: a tracked tank in the same spot is ordered to face (%d ticks)" % tank["faces"])
	assert_true(int(truck["shots"]) > 0, "and the truck still fights, its turret on the target (%d shots)" % truck["shots"])
