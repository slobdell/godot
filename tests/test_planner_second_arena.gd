extends TestCase
## Round 32 (the orchestrator's priority question): **does a planner static survive a match?** A War Rig's face-behind
## (manoeuvre's stage: yard_open, gang_tank "Rig" at START heading 0, face START + (0, 0, 100)) played three times in
## ONE process, the match, its controller and the arena freed between plays (native's scratch did not free them, so its
## later Rigs spawned on a still-parked Rig). Every play must read the same: if a later play differs, something
## outlived its match (the seam's crew / retry tables keyed by hull name, the C++ navmesh cell cache, a cached bake
## radius) and the player's SECOND skirmish would plan against the FIRST.

const MATCH := preload("res://game/match/match.tscn")
const START := Vector3(0.0, 0.0, 15.0)
const SECONDS := 40.0


func _play(label: String) -> Dictionary:
	var arena := await ArenaFixture.build(self, "yard_open")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(1, 0.0)
	var tank := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	tank.place(START, 0.0)
	var controller := OrderController.new()
	controller.tank = tank
	controller.tanks_root = game_match.tanks
	add_to_tree(controller)
	await wait_physics_frames(2)
	var requests_before := PlannerSeam.requests
	controller.set_orders({"type": "face", "x": START.x, "z": START.z + 100.0}, {"type": "hold_fire"})
	var legs := 0
	var gear := 0
	var aligned := -1
	for frame in int(SimClock.TICK_RATE * SECONDS):
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
	var out := {"legs": legs, "aligned_s": snappedf(float(aligned) / SimClock.TICK_RATE, 0.01) if aligned >= 0 else -1.0,
			"drift_m": snappedf(Vector2(tank.global_position.x - START.x, tank.global_position.z - START.z).length(), 0.01),
			"seam_requests": PlannerSeam.requests - requests_before}
	print("SECOND_ARENA %s: %s | crews held after %s | cache %s" % [label, JSON.stringify(out), str(PlannerSeam._crews.keys()),
			JSON.stringify(Planner.native_cache_stats())])
	controller.free()
	game_match.free()
	# Match._exit_tree -> PlannerSeam.end_match: nothing of this match is held for the next, not even for a frame.
	assert_true(not PlannerSeam._crews.has("Rig"), "%s: no crew of the freed match" % label)
	assert_true(not PlannerSeam._retry_until.has("Rig"), "%s: no decline window of the freed match's hull" % label)
	arena.free()
	await drain_navigation()
	return out


func test_a_war_rig_faces_behind_the_same_in_every_match_of_a_session() -> void:
	PlannerSeam.reset()
	var first := await _play("play 1")
	var second := await _play("play 2")
	var third := await _play("play 3")
	assert_true(int(first["legs"]) > 0 and float(first["aligned_s"]) > 0.0, "play 1 turns round (%s)" % first)
	assert_eq(second, first, "play 2, a fresh match on a fresh arena, plays as play 1")
	assert_eq(third, first, "play 3 as play 1")
	PlannerSeam.reset()
