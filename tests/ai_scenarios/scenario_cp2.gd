extends TestCase
## After CP2 (combat's round-3 weapons, wheels, artillery deploy): combat's requests to ai (_agents/streams/archive/round3/combat.md
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
	for tick in SimClock.TICK_RATE * 15:
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
	for tick in SimClock.TICK_RATE * 25:
		await s.step()
		if battery.deploy_ratio >= 1.0:
			deployed += 1
	print("MEASURE ai_cp2_artillery deployed %.1f s of 25, %d rounds" % [deployed / float(SimClock.TICK_RATE), s.shots_by(battery)])
	assert_true(s.shots_by(battery) >= 3, "the battery digs in and fires (%d rounds)" % s.shots_by(battery))


## Combat's request (d): a battery stays dug in while its target drives across its range (the turret follows it);
## re-facing the hull every think packed it up again.
func test_artillery_stays_dug_in_on_a_moving_target() -> void:
	var s := AiScenario.create(self)
	var target := s.shooter(Match.Team.RUST, "Rust_Tank_1", Vector3(-110, 0, -40), PI, {"type": "move_to", "x": -30.0, "z": -40.0},
			{"type": "hold_fire"})
	AiScenario.make_durable(target)
	var spotter := s.dummy(Match.Team.GREEN, "Green_Scout_1", Vector3(-80, 0, 0), 0.0, "scout")
	AiScenario.make_durable(spotter)
	var battery := s.brain_tank(Match.Team.GREEN, "Green_Battery_1", Vector3(-100, 0, 60), 0.0, {}, "artillery")
	AiScenario.make_durable(battery)
	var packs := 0
	var was_deployed := false
	await s.start()
	for tick in SimClock.TICK_RATE * 25:
		await s.step()
		if was_deployed and battery.deploy_ratio < 1.0:
			packs += 1
		was_deployed = battery.deploy_ratio >= 1.0
	print("MEASURE ai_cp2_artillery_moving_target packed up %d times, %d rounds, battery moved to %s" % [packs,
			s.shots_by(battery), battery.global_position.snapped(Vector3.ONE)])
	assert_true(packs <= 1, "it stays dug in while the target crosses its range (packed up %d times)" % packs)
	assert_true(s.shots_by(battery) >= 3, "and keeps shelling it (%d rounds)" % s.shots_by(battery))

func test_a_scout_guns_down_a_lancer() -> void:
	var s := AiScenario.create(self)
	var lancer := s.shooter(Match.Team.RUST, "Rust_Lancer_1", Vector3(-100, 0, -20), PI, {"type": "stop"},
			{"type": "fire_at_will"}, "lancer")
	AiScenario.make_durable(lancer)
	var scout := s.brain_tank(Match.Team.GREEN, "Green_Scout_1", Vector3(-100, 0, 50), 0.0, {}, "scout")
	AiScenario.make_durable(scout)
	await s.start()
	for tick in SimClock.TICK_RATE * 20:
		await s.step()
	print("MEASURE ai_cp2_scout_vs_lancer scout shots %d (%d hits, %d on the deck), lancer lost %d" % [s.shots_by(scout),
			s.game_match.stats["hits"][Match.Team.GREEN], s.game_match.stats["weak_spot_hits"][Match.Team.GREEN],
			1_000_000 - lancer.health + int(lancer.max_shield - lancer.shield)])
	assert_true(s.shots_by(scout) >= 30, "a scout closes on a Lancer (its counter) and fires (%d rounds)" % s.shots_by(scout))


## Combat's request (b): a scout's machine gun barely scratches a tank's plates (×0.05 on the front) but gets through
## its engine deck (×1.13), so a scout hunting a tank works its way dead astern and bursts in while the cannon reloads.
## Orbiting is the matchup-aware brains' move (x4mw); without weak_spots (x3m), 19 of 46 hits landed on the deck.
func test_a_scout_works_onto_a_tanks_engine_deck() -> void:
	var s := AiScenario.create(self)
	BrainVariants.use(Match.Team.GREEN, "x4mw")
	var tank := s.shooter(Match.Team.RUST, "Rust_Tank_1", Vector3(-100, 0, -20), PI, {"type": "stop"}, {"type": "fire_at_will"})
	AiScenario.make_durable(tank)
	var scout := s.brain_tank(Match.Team.GREEN, "Green_Scout_1", Vector3(-70, 0, 20), 0.0, {}, "scout")
	AiScenario.make_durable(scout)
	await s.start()
	for tick in SimClock.TICK_RATE * 25:
		await s.step()
	var deck: int = s.game_match.stats["weak_spot_hits"][Match.Team.GREEN]
	var hits: int = s.game_match.stats["hits"][Match.Team.GREEN]
	print("MEASURE ai_cp2_scout_engine_deck %d of %d hits on the deck, %d shots, tank lost %d" % [deck, hits, s.shots_by(scout),
			1_000_000 - tank.health + int(tank.max_shield - tank.shield)])
	assert_true(deck >= 40 and deck * 2 >= hits, "the scout works onto the engine deck (%d deck hits of %d)" % [deck, hits])
	BrainVariants.reset()


## Combat's request (f): two lone tanks with no objective, from mirror spawns on the point-symmetric arena. Both used to
## drive the straight base-to-base line, so each hid behind the center crate from the other and they passed at 9 m unseen
## (mirror-image side lanes didn't help: the line between mirror positions always crosses the center: 48 m, never seen).
func test_lone_tanks_without_objectives_find_each_other() -> void:
	var s := AiScenario.create(self)
	var green := s.brain_tank(Match.Team.GREEN, "Green_Tank_1", Match.spawn_position(Match.Team.GREEN, 0),
			Match.spawn_yaw(Match.Team.GREEN))
	var rust := s.brain_tank(Match.Team.RUST, "Rust_Tank_1", Match.spawn_position(Match.Team.RUST, 0),
			Match.spawn_yaw(Match.Team.RUST))
	AiScenario.make_durable(green)
	AiScenario.make_durable(rust)
	var seen_at := -1
	var closest_unseen := INF
	await s.start()
	for tick in SimClock.TICK_RATE * 40:
		await s.step()
		if seen_at >= 0:
			continue
		if s.game_match.is_visible_to(Match.Team.GREEN, rust) or s.game_match.is_visible_to(Match.Team.RUST, green):
			seen_at = tick
		else:
			closest_unseen = minf(closest_unseen, green.global_position.distance_to(rust.global_position))
	print("MEASURE ai_cp2_lone_tanks first sighting after %.1f s, closest unseen %.0f m, shots %d + %d" % [seen_at / float(SimClock.TICK_RATE),
			closest_unseen, s.shots_by(green), s.shots_by(rust)])
	assert_true(seen_at >= 0 and closest_unseen >= 25.0, "they spot each other before passing close (%.1f s, %.0f m)" % [
			seen_at / float(SimClock.TICK_RATE), closest_unseen])
	assert_true(s.shots_by(green) + s.shots_by(rust) >= 2, "and fight")
