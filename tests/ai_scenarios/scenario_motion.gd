extends TestCase
## Round-3 X2 (_agents/streams/ai.md): movement while fighting. The lead: *"Tanks will just sit there stationary and
## shoot each other … no intent of trying to circle your opponent."* Brain variant x2 (CombatMotion) against a6 (round
## 2's champion) as the control. Open ground west of the walls.

const PENDING := []


## A duel between two brain tanks of `variant`: [moving share per side, seconds each spent seeing its enemy's side or
## rear, shots per side, hull + shield lost per side].
func _duel(variant: String, seed_value: int) -> Dictionary:
	BrainVariants.use(Match.Team.GREEN, variant)
	BrainVariants.use(Match.Team.RUST, variant)
	var s := AiScenario.create(self, seed_value)
	var green := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 25), 0.0)
	var rust := s.brain_tank(Match.Team.RUST, "Rust_A_1", Vector3(-96, 0, -20), PI)
	var tanks: Array[Tank] = [green, rust]
	var moving := [0, 0]
	var flanked := [0, 0]
	var counted := 0
	await s.start()
	for tick in 60 * 20:
		await s.step()
		if not green.is_alive() or not rust.is_alive():
			break
		counted += 1
		for i in 2:
			var me := tanks[i]
			var other := tanks[1 - i]
			if me.estimated_velocity.length() > 1.5:
				moving[i] += 1
			# I see its side or rear: more than 45° off its front (cos 0.707).
			var from_other := Vector3(me.global_position.x - other.global_position.x, 0.0, me.global_position.z - other.global_position.z).normalized()
			if (-other.global_basis.z).dot(from_other) < 0.707:
				flanked[i] += 1
	var result := {"moving": [float(moving[0]) / maxf(counted, 1), float(moving[1]) / maxf(counted, 1)],
			"flank_seconds": [flanked[0] / 60.0, flanked[1] / 60.0], "shots": [s.shots_by(green), s.shots_by(rust)],
			"lost": [green.max_health + green.max_shield - green.health - green.shield, rust.max_health + rust.max_shield - rust.health - rust.shield],
			"seconds": counted / 60.0}
	s.dispose()
	BrainVariants.reset()
	return result


func test_two_tanks_duel_on_the_move_and_one_gets_an_angle() -> void:
	var control := await _duel("a6", 1)
	var moving := await _duel("x2", 1)
	print("MEASURE ai_duel a6 (round 2): moving %s, flank seconds %s, shots %s, lost %s over %.1f s" % [control["moving"],
			control["flank_seconds"], control["shots"], control["lost"], control["seconds"]])
	print("MEASURE ai_duel x2 (moving): moving %s, flank seconds %s, shots %s, lost %s over %.1f s" % [moving["moving"],
			moving["flank_seconds"], moving["shots"], moving["lost"], moving["seconds"]])
	for i in 2:
		assert_true(float(moving["moving"][i]) >= 0.6, "side %d keeps moving while it fights (%.0f%% of the time)" % [i, float(moving["moving"][i]) * 100.0])
	assert_true(maxf(moving["flank_seconds"][0], moving["flank_seconds"][1]) >= 2.0,
			"at least one works round to the other's side or rear for 2 s+ (%s)" % [moving["flank_seconds"]])
	assert_true(int(moving["shots"][0]) + int(moving["shots"][1]) >= 6, "and they still fight (%s shots)" % [moving["shots"]])


func test_a_scout_makes_attack_runs_on_a_tank() -> void:
	BrainVariants.use(Match.Team.GREEN, "x2")
	var s := AiScenario.create(self)
	var tank := s.shooter(Match.Team.RUST, "Rust_Tank_1", Vector3(-100, 0, -10), 0.0)
	AiScenario.make_durable(tank)
	var scout := s.brain_tank(Match.Team.GREEN, "Green_Scout_1", Vector3(-100, 0, 45), 0.0, {}, "scout")
	AiScenario.make_durable(scout)
	var orders := s.orders()
	await s.start()
	orders.call("issue", {"units": [String(scout.name)], "verb": "attack", "target": String(tank.name), "queue": false})
	var brain := s.brain_of(scout)
	var runs := 0
	var last_phase := "run"
	var behind_shots := 0
	var last_shots := 0
	for tick in 60 * 25:
		await s.step()
		if brain._run_phase != last_phase:
			if brain._run_phase == "extend":
				runs += 1
			last_phase = brain._run_phase
		if s.shots_by(scout) > last_shots:
			last_shots = s.shots_by(scout)
			var from_tank := Vector3(scout.global_position.x - tank.global_position.x, 0.0, scout.global_position.z - tank.global_position.z).normalized()
			if (-tank.global_basis.z).dot(from_tank) < 0.707:
				behind_shots += 1
	print("MEASURE ai_scout_runs %d runs in 25 s, %d shots, %d from the tank's side or rear, tank took %d" % [runs,
			s.shots_by(scout), behind_shots, 1_000_000 - tank.health + int(tank.max_shield - tank.shield)])
	assert_true(runs >= 3, "repeated attack runs (%d)" % runs)
	assert_true(behind_shots >= 10, "firing into its side and rear (%d shots)" % behind_shots)
	BrainVariants.reset()
