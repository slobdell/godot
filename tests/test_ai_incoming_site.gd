extends TestCase
## Round 10 (combat's research C6, squad's site): `IncomingFire` reads the hull through `Units.hull_reach_of` with its
## own site name, so `match.hull_disc_squad_incoming` switches the disc or the box HERE alone. The arm proof: a round
## travelling north 5 m off a War Rig's flank is incoming under the disc (half-diagonal 7.19 m) and not under the box
## (half-width 1.66 m, 3.3 m clear against Match.INCOMING_MARGIN 1.0); the knob at this site flips the count, and the
## knob at another site does not.

const RIG := "gang_tank"  # the War Rig, 3.32 x 14.00 m


func _count(scenario: AiScenario, rig: Tank) -> int:
	# One round in AiTickCache's per-tick flight arrays, seeded for this tick, then IncomingFire's own read.
	AiTickCache._flight_match = scenario.game_match.get_instance_id()
	AiTickCache._flight_tick = scenario.game_match.tick
	AiTickCache._flight_x = PackedFloat32Array([5.0])
	AiTickCache._flight_z = PackedFloat32Array([30.0])
	AiTickCache._flight_dir_x = PackedFloat32Array([0.0])
	AiTickCache._flight_dir_z = PackedFloat32Array([-1.0])
	AiTickCache._flight_vx = PackedFloat32Array([0.0])
	AiTickCache._flight_vz = PackedFloat32Array([-70.0])
	AiTickCache._flight_reach = PackedFloat64Array([80.0])
	AiTickCache._flight_shooter = PackedStringArray(["Rust_Gun_1"])
	return IncomingFire._count_in_flight(scenario.game_match, rig)


func test_the_squad_incoming_knob_moves_this_site_and_no_other() -> void:
	var scenario := AiScenario.create(self)
	var rig := scenario.dummy(Match.Team.GREEN, "Green_Rig_1", Vector3.ZERO, 0.0, RIG)
	await scenario.start()
	var hull: Array = Units.stat(rig.unit_id, "hull_size")
	assert_true(maxf(float(hull[0]), float(hull[2])) >= 13.0, "setup: the dummy is a long rig (%s)" % str(hull))
	var disc := _count(scenario, rig)
	assert_eq(Units.apply_tuning("match.hull_disc_squad_incoming=0"), "", "match.hull_disc_squad_incoming is a knob")
	var box := _count(scenario, rig)
	Units.tuning.erase("hull_disc_squad_incoming")
	assert_eq(Units.apply_tuning("match.hull_disc_lof=0"), "", "setup: another site's knob")
	var neighbour := _count(scenario, rig)
	Units.tuning.erase("hull_disc_lof")
	print("MEASURE incoming_site disc %d, squad_incoming=0 %d, lof=0 %d" % [disc, box, neighbour])
	assert_eq(disc, 1, "on the disc (the default) a round 5 m off the rig's flank is incoming")
	assert_eq(box, 0, "with the box at this site it passes 3.3 m clear")
	assert_eq(neighbour, 1, "and another site's knob leaves this reader on the disc")
	AiTickCache._flight_match = 0
	scenario.dispose()
