extends TestCase
## Round-3 X2 (_agents/streams/ai.md): movement while fighting. The lead: *"Tanks will just sit there stationary and
## shoot each other … no intent of trying to circle your opponent."* Brain variant x2 (CombatMotion) against a6 (round
## 2's champion) as the control. Open ground west of the walls.

const PENDING := []


## A duel between two brain tanks of `variant`: moving share per side, seconds each spent seeing the other's side or
## rear, shots per side, and the share of hits that landed on a front.
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
			if tanks[i].estimated_velocity.length() > 1.5:
				moving[i] += 1
			if _sees_side_or_rear(tanks[i], tanks[1 - i]):
				flanked[i] += 1
	var faces: Dictionary = s.game_match.stats["hits_by_face"]
	var hits := maxi(int(faces["front"]) + int(faces["side"]) + int(faces["rear"]), 1)
	var result := {"moving": [float(moving[0]) / maxf(counted, 1), float(moving[1]) / maxf(counted, 1)],
			"flank_seconds": [flanked[0] / 60.0, flanked[1] / 60.0], "shots": [s.shots_by(green), s.shots_by(rust)],
			"front_share": float(faces["front"]) / hits, "seconds": counted / 60.0}
	s.dispose()
	BrainVariants.reset()
	return result


## `me` looks at `other`'s side or rear: more than 45° off its front (cos 0.707).
static func _sees_side_or_rear(me: Tank, other: Tank) -> bool:
	var from_other := Vector3(me.global_position.x - other.global_position.x, 0.0, me.global_position.z - other.global_position.z).normalized()
	return (-other.global_basis.z).dot(from_other) < 0.707


func test_two_tanks_duel_on_the_move_front_armor_first() -> void:
	var control := await _duel("a6", 1)
	var moving := await _duel("x3", 1)
	for entry: Array in [["a6 (round 2)", control], ["x3 (moving)", moving]]:
		var r: Dictionary = entry[1]
		print("MEASURE ai_duel %s: moving %s, flank seconds %s, shots %s, front hits %.0f%% over %.1f s" % [entry[0],
				r["moving"], r["flank_seconds"], r["shots"], float(r["front_share"]) * 100.0, r["seconds"]])
	for i in 2:
		assert_true(float(moving["moving"][i]) >= 0.5, "side %d keeps moving while it fights (%.0f%% of the time)" % [i, float(moving["moving"][i]) * 100.0])
	assert_true(float(moving["front_share"]) >= 0.5, "weaving keeps the front armor on the gun (%.0f%% of hits on fronts)" % (float(moving["front_share"]) * 100.0))
	assert_true(int(moving["shots"][0]) + int(moving["shots"][1]) >= 6, "and they still fight (%s shots)" % [moving["shots"]])


func test_two_tanks_on_one_work_round_to_its_side() -> void:
	# Both sides pinned: this measures the pair's flanking, not whatever the champion does to the lone defender (with
	# x4's reload windows it peeks and hides, and the angle the pair gets drops from 4.2 s to 2.6 s of 20).
	BrainVariants.use(Match.Team.GREEN, "x3")
	BrainVariants.use(Match.Team.RUST, "x3")
	var s := AiScenario.create(self, 2)
	var enemy := s.brain_tank(Match.Team.RUST, "Rust_A_1", Vector3(-98, 0, -20), PI)
	AiScenario.make_durable(enemy)
	var pair: Array[Tank] = []
	for i in 2:
		var tank := s.brain_tank(Match.Team.GREEN, "Green_Alpha_%d" % (i + 1), Vector3(-104 + i * 12, 0, 28), 0.0, {}, "tank", "", "Alpha")
		AiScenario.make_durable(tank)
		pair.append(tank)
	s.form_squad(Match.Team.GREEN, "Alpha", pair)
	var flank_ticks := 0
	var first := -1
	await s.start()
	for tick in 60 * 20:
		await s.step()
		if pair.any(func(t: Tank) -> bool: return _sees_side_or_rear(t, enemy)):
			flank_ticks += 1
			first = tick if first < 0 else first
	print("MEASURE ai_pair_flank a tank sees the enemy's side or rear %.1f s of 20 (first after %.1f s)" % [flank_ticks / 60.0, first / 60.0])
	assert_true(flank_ticks >= 60 * 3 and first >= 0 and first <= 60 * 10,
			"one of the pair gets an angle on it within 10 s, for 3 s+ (%.1f s, first after %.1f s)" % [flank_ticks / 60.0, first / 60.0])
	BrainVariants.reset()


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


## Round-3 X4: no dithering. A 3 v 3 mixed brawl; how often each brain changes what it's doing (option switches per unit
## per minute of fighting). Printed for a6 and x3; x3 must stay readable.
func _switches_per_minute(variant: String) -> float:
	BrainVariants.use(Match.Team.GREEN, variant)
	BrainVariants.use(Match.Team.RUST, variant)
	var s := AiScenario.create(self, 6)
	var units := ["tank", "ifv", "scout"]
	var brains: Array[TankBrain] = []
	for i in 3:
		brains.append(s.brain_of(s.brain_tank(Match.Team.GREEN, "Green_A_%d" % (i + 1), Vector3(-108 + i * 9, 0, 40), 0.0, {}, units[i], "", "Alpha")))
		brains.append(s.brain_of(s.brain_tank(Match.Team.RUST, "Rust_A_%d" % (i + 1), Vector3(-104 + i * 9, 0, -20), PI, {}, units[i], "", "Alpha")))
	var last := {}
	var switches := 0
	var unit_ticks := 0
	await s.start()
	for tick in 60 * 30:
		await s.step()
		for brain in brains:
			if not brain.tank.is_alive() or brain.choice.is_empty():
				continue
			unit_ticks += 1
			var option := TankBrain.label(brain.choice)
			if last.has(brain.name) and last[brain.name] != option:
				switches += 1
			last[brain.name] = option
	s.dispose()
	BrainVariants.reset()
	return switches / maxf(unit_ticks / 3600.0, 0.01)


func test_brains_dont_dither() -> void:
	var round2 := await _switches_per_minute("a6")
	var moving := await _switches_per_minute("x3")
	print("MEASURE ai_dither option switches per unit per minute: a6 %.1f, x3 %.1f" % [round2, moving])
	assert_true(moving <= 12.0, "x3 changes its mind at most every 5 s on average (%.1f per minute)" % moving)
