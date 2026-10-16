extends TestCase
## Round 26 (manoeuvre M1b, C26.9): a War Rig at rest told to face behind it comes round in planned legs, not the creep's
## 0.5 s shuffle. Split from test_manoeuvre_behind.gd (round 32, C32.8: that file ran 69 s); bodies byte-identical.

const MATCH := preload("res://game/match/match.tscn")
const START := Vector3(0.0, 0.0, 15.0)


## M1b alone: a War Rig at rest told to face behind it comes round in planned legs (control: the creep's 0.5 s legs).
func _face_behind(off: PackedStringArray) -> Dictionary:
	await ArenaFixture.build(self, "yard_open")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(1, 0.0)
	var tank := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	tank.place(START, 0.0)
	var controller := OrderController.new()
	controller.tank = tank
	controller.tanks_root = game_match.tanks
	add_to_tree(controller)
	var saved := Movement._off
	Movement._off = off
	await wait_physics_frames(2)
	controller.set_orders({"type": "face", "x": START.x, "z": START.z + 100.0}, {"type": "hold_fire"})
	var legs := 0
	var gear := 0
	var aligned := -1
	for frame in SimClock.TICK_RATE * 60:
		await tree.physics_frame
		var speed := tank.speed()
		var g := 1 if speed > 0.3 else (-1 if speed < -0.3 else 0)
		if g != 0 and g != gear:
			legs += 1
			gear = g
		var nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z)
		if absf(rad_to_deg(nose.angle_to(Vector2(0.0, 1.0)))) <= 10.0 and absf(speed) < 0.2:
			aligned = frame
			break
	Movement._off = saved
	return {"legs": legs, "aligned_s": float(aligned) / SimClock.TICK_RATE if aligned >= 0 else -1.0,
			"drift_m": Vector2(tank.global_position.x - START.x, tank.global_position.z - START.z).length()}


func test_control_the_war_rig_creeps_round_to_face_behind() -> void:
	var r := await _face_behind(PackedStringArray(["faceturn"]))
	assert_true(int(r["legs"]) > 8, "control: the creep's short legs (%s)" % r)


func test_the_war_rig_faces_behind_in_a_planned_turn() -> void:
	var r := await _face_behind(PackedStringArray())
	assert_true(int(r["legs"]) <= 3, "a three-point turn: three legs for a half turn (%s)" % r)
	assert_true(float(r["drift_m"]) <= 8.0, "turned at its spot (the plan ends within its 6 m settle radius; momentum adds a little), not looped away from it (%s)" % r)
	assert_true(float(r["aligned_s"]) >= 0.0 and float(r["aligned_s"]) <= 25.0, "and it comes round (%s)" % r)
