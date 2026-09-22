extends TestCase
## After CP2 (combat's round-3 weapons, wheels, artillery deploy): combat's requests to ai (_agents/streams/archive/round3/combat.md
## "Requests to other streams", balance.md matrix #6). Wheeled units can't turn in place, artillery must stand still to
## fire, and scouts should use their machine gun when it pays.

## Round 7 triage: the scout's claim on Lancers was withdrawn by combat in round 4 (game/units/units.gd, the scout's
## `good_vs`: "lancer" removed until the matchup matrix shows it; suppression is the mechanic that could earn it back),
## so the brain rightly no longer hunts one. Pending until that claim is restored.
const PENDING := ["test_a_scout_guns_down_a_lancer"]


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
##
## ROUND 10 (combat, backlog item 5): the target now stops at (-45, -40), not (-30, -40), and the artillery is
## unchanged. The old goal made the result depend on the target's ROUTE. When this scenario runs after another in the
## same process, the target's first route request lands on the frame where the previous arena's navigation regions
## are gone and the new ones are not yet synced (`regions=[]`). It gets no route, drives a straight line for the 4 s
## until `Movement` replans, and parks at (-33, -40), out of the spotter's line of sight. The battery then correctly
## packs up to SHADOW (1 round, FAIL). Run first in its process, the tick-2 route is the 7-point path, the target parks
## at (-32, -41) in sight, and the battery keeps shelling (5 rounds, PASS). Measured with probes, laptop, `2434f50d`.
## (-45, -40) is in the spotter's sight on both routes, so the scenario tests what it claims (the battery on a moving,
## spotted target) and not which frame navigation synced on. The route retry is nav's (`Movement`).
func test_artillery_stays_dug_in_on_a_moving_target() -> void:
	var s := AiScenario.create(self)
	var target := s.shooter(Match.Team.RUST, "Rust_Tank_1", Vector3(-110, 0, -40), PI, {"type": "move_to", "x": -45.0, "z": -40.0},
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
func _deck_run(variant: String) -> Dictionary:
	var s := AiScenario.create(self)
	BrainVariants.use(Match.Team.GREEN, variant)
	# Granted to combat 2026-09-20 (orchestrator): with DECK_PROBE=1 in the environment, print the three columns that
	# decide who owns a missing engine-deck hit -- travel angle against Armor's 25 deg cone, the shooter's bearing
	# from the victim's nose, and the range -- for every enemy hit here. DEFAULT OFF so `ai-scenarios` stays quiet in
	# metrics' gate; `Armor.deck_probe` is never set in play. 2026-09-20 reading: 16 hits, NONE within 66.7 deg of the
	# cone, bearing topping out at 109.7 deg -- the scout never gets behind, so the flag has nothing to miss.
	Armor.deck_probe = OS.get_environment("DECK_PROBE") == "1"
	var tank := s.shooter(Match.Team.RUST, "Rust_Tank_1", Vector3(-100, 0, -20), PI, {"type": "stop"}, {"type": "fire_at_will"})
	AiScenario.make_durable(tank)
	var scout := s.brain_tank(Match.Team.GREEN, "Green_Scout_1", Vector3(-70, 0, 20), 0.0, {}, "scout")
	AiScenario.make_durable(scout)
	await s.start()
	# ORBIT_PROBE=1 (squad, round 10 item 6b): per 0.5 s, the scout's option, its attack-run flag, its range and
	# angular rate around the tank's centre, its speed, and how far the tank's turret is off it. Default off.
	var orbit_probe := OS.get_environment("ORBIT_PROBE") == "1"
	var last_bearing := 0.0
	for tick in SimClock.TICK_RATE * 25:
		await s.step()
		if not orbit_probe:
			continue
		var rel := scout.global_position - tank.global_position
		var bearing := atan2(rel.x, rel.z)
		var rate := rad_to_deg(absf(angle_difference(bearing, last_bearing))) * SimClock.TICK_RATE
		last_bearing = bearing
		if tick % 15 == 0:
			var brain := s.brain_of(scout)
			var gun := tank.turret_forward()
			var off := rad_to_deg(Vector2(gun.x, gun.z).angle_to(Vector2(rel.x, rel.z)))
			print("ORBIT_PROBE t=%.1f %s burst=%s r=%.1f w=%.0f v=%.1f gun_off=%.0f hp=%.0f ranked=%s" % [tick / 30.0,
					String((brain.get("choice") as Dictionary).get("option", "?")) if brain.get("choice") is Dictionary else "?", str(brain.get("_bursting")),
					Vector2(rel.x, rel.z).length(), rate, scout.estimated_velocity.length(), absf(off), float(scout.health), str(brain.ranked)])
	var result := {"deck": int(s.game_match.stats["weak_spot_hits"][Match.Team.GREEN]),
			"hits": int(s.game_match.stats["hits"][Match.Team.GREEN]), "shots": s.shots_by(scout)}
	Armor.deck_probe = false
	BrainVariants.reset()
	s.dispose()
	return result


## Round 7: asked as a share. The absolute bar (40 deck hits) was set under the fire model before CP4's band and
## combat's X6 acquisition; what the behaviour claims is that most of the scout's hits land on the deck.
## The same round fixed the reason it had stopped working: circling a target is crossing its line of sight fast, the
## scout lost sight mid-orbit, and ORBIT required a visible target even to keep going (0 shots, 0 on the deck).
func test_a_scout_works_onto_a_tanks_engine_deck() -> void:
	var seeking := await _deck_run("x4mw")
	var blind := await _deck_run("x3m")  # the same fight without weak_spots, for the record
	print("MEASURE ai_cp2_scout_engine_deck x4mw %s; x3m (no weak spots) %s" % [seeking, blind])
	assert_true(int(seeking["hits"]) >= 20, "the scout fights the tank at all (%d hits)" % seeking["hits"])
	var share := float(seeking["deck"]) / maxf(float(seeking["hits"]), 1.0)
	# The deck is a narrow arc astern: hits that were not sought land there a minority of the time (x3m, round 4: 19 of
	# 46). Today's x3m scout does not take this fight at all (0 shots on the laptop, 2026-09-19), so it is printed, not
	# asserted against: a control that never fires proves nothing.
	assert_true(share >= 0.5, "the scout works onto the engine deck (%d deck hits of %d)" % [seeking["deck"], seeking["hits"]])


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
