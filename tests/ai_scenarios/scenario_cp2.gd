extends TestCase
## After CP2 (combat's round-3 weapons, wheels, artillery deploy): combat's requests to ai (_agents/streams/combat.md
## "Requests to other streams", balance.md matrix #6). Wheeled units can't turn in place, artillery must stand still to
## fire, and scouts should use their machine gun when it pays.

const PENDING := []


## Sign changes of a unit's hull speed (ignoring |speed| < 0.5): a hull rocking back and forth flips it constantly.
static func _count_flips(samples: Array) -> int:
	var flips := 0
	var last := 0
	for speed: float in samples:
		if absf(speed) < 0.5:
			continue
		var sign := 1 if speed > 0.0 else -1
		if last != 0 and sign != last:
			flips += 1
		last = sign
	return flips


func test_a_lancer_holds_steady_and_lases_a_tank() -> void:
	var s := AiScenario.create(self)
	var tank := s.shooter(Match.Team.RUST, "Rust_Tank_1", Vector3(-100, 0, -38), PI)
	AiScenario.make_durable(tank)
	var lancer := s.brain_tank(Match.Team.GREEN, "Green_Lancer_1", Vector3(-100, 0, 40), 0.0, {}, "lancer")
	AiScenario.make_durable(lancer)
	var speeds: Array = []
	await s.start()
	for tick in 60 * 15:
		await s.step()
		speeds.append(lancer.speed())
	var flips := _count_flips(speeds)
	print("MEASURE ai_cp2_lancer %d speed reversals in 15 s, %d laser shots, tank lost %d" % [flips, s.shots_by(lancer),
			1_000_000 - tank.health + int(tank.max_shield - tank.shield)])
	assert_true(flips <= 6, "it doesn't rock back and forth (%d reversals)" % flips)
	assert_true(s.shots_by(lancer) >= 10, "and keeps lasing (%d shots)" % s.shots_by(lancer))


func test_artillery_digs_in_and_shells_a_spotted_target() -> void:
	var s := AiScenario.create(self)
	var target := s.dummy(Match.Team.RUST, "Rust_Tank_1", Vector3(-100, 0, -40), PI)
	AiScenario.make_durable(target)
	var spotter := s.dummy(Match.Team.GREEN, "Green_Scout_1", Vector3(-95, 0, 5), 0.0, "scout")
	AiScenario.make_durable(spotter)
	var battery := s.brain_tank(Match.Team.GREEN, "Green_Battery_1", Vector3(-100, 0, 60), 0.0, {}, "artillery")
	AiScenario.make_durable(battery)
	var deployed := 0
	await s.start()
	for tick in 60 * 25:
		await s.step()
		if battery.deploy_ratio >= 1.0:
			deployed += 1
	print("MEASURE ai_cp2_artillery deployed %.1f s of 25, %d rounds" % [deployed / 60.0, s.shots_by(battery)])
	assert_true(s.shots_by(battery) >= 3, "the battery digs in and fires (%d rounds)" % s.shots_by(battery))


func test_a_scout_guns_down_a_lancer() -> void:
	var s := AiScenario.create(self)
	var lancer := s.shooter(Match.Team.RUST, "Rust_Lancer_1", Vector3(-100, 0, -20), PI, {"type": "stop"},
			{"type": "fire_at_will"}, "lancer")
	AiScenario.make_durable(lancer)
	var scout := s.brain_tank(Match.Team.GREEN, "Green_Scout_1", Vector3(-100, 0, 50), 0.0, {}, "scout")
	AiScenario.make_durable(scout)
	await s.start()
	for tick in 60 * 20:
		await s.step()
	print("MEASURE ai_cp2_scout_vs_lancer scout shots %d, lancer lost %d" % [s.shots_by(scout),
			1_000_000 - lancer.health + int(lancer.max_shield - lancer.shield)])
	assert_true(s.shots_by(scout) >= 30, "a scout closes on a Lancer (its counter) and fires (%d rounds)" % s.shots_by(scout))
