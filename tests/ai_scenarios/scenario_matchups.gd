extends TestCase
## Matchup-aware fighting (A5 in _agents/streams/archive/round2/ai.md). Needs rules' catalog v2 (fixed-mount scouts, IFVs);
## until checkpoint 1 these are pending and say what they wait for.

const PENDING := []


func test_a_scout_circles_a_tank_instead_of_trading_frontally() -> void:
	BrainVariants.use(Match.Team.GREEN, "a5")
	var s := AiScenario.create(self)
	# A normal tank (an invulnerable one would make any duel hopeless, and the brain would rightly refuse it).
	var tank := s.shooter(Match.Team.RUST, "Rust_Tank_1", Vector3(-100, 0, 0), PI)
	var scout := s.brain_tank(Match.Team.GREEN, "Green_Scout_1", Vector3(-100, 0, 40), 0.0, {}, "scout")
	# Durable: this measures the orbit, and one of round 3's tank shells kills a scout outright.
	AiScenario.make_durable(scout)
	var close_ticks := 0
	var swept := 0.0
	var last_bearing := NAN
	await s.start()
	for tick in SimClock.TICK_RATE * 20:
		await s.step()
		if not scout.is_alive():
			continue
		var offset := scout.global_position - tank.global_position
		if Vector2(offset.x, offset.z).length() > 50.0:
			last_bearing = NAN
			continue
		close_ticks += 1
		var bearing := atan2(offset.x, offset.z)
		if not is_nan(last_bearing):
			swept += absf(angle_difference(last_bearing, bearing))
		last_bearing = bearing
	var degrees_per_second := rad_to_deg(swept) / maxf(close_ticks / float(SimClock.TICK_RATE), 0.01)
	var turret := rad_to_deg(tank.turret_turn_rate)
	print("MEASURE ai_scout_orbit %.0f deg/s around the tank over %.1f s close (turret %.0f deg/s), scout alive %s, tank hull %d shield %d, scout shots %d" % [
			degrees_per_second, close_ticks / float(SimClock.TICK_RATE), turret, scout.is_alive(), tank.health, int(tank.shield), s.shots_by(scout)])
	assert_true(String(Units.profile("scout").get("mount", "")) == "fixed", "needs rules' catalog v2: a fixed-mount scout")
	assert_true(close_ticks >= SimClock.TICK_RATE * 5, "the scout closes in to fight (%.1f s within 50 m)" % (close_ticks / float(SimClock.TICK_RATE)))
	assert_true(degrees_per_second >= 0.6 * turret, "it circles faster than the turret can comfortably track (%.0f vs %.0f deg/s)" % [degrees_per_second, turret])
	BrainVariants.reset()


func test_an_ifv_prioritizes_scouts() -> void:
	assert_true(Units.exists("ifv"), "needs rules' catalog v2: an 'ifv' unit")
	if not Units.exists("ifv"):
		return
	BrainVariants.use(Match.Team.GREEN, "a5")
	var s := AiScenario.create(self)
	var enemy_tank := s.dummy(Match.Team.RUST, "Rust_Tank_1", Vector3(-106, 0, 5), PI)
	var enemy_scout := s.dummy(Match.Team.RUST, "Rust_Scout_1", Vector3(-94, 0, 0), PI, "scout")
	AiScenario.make_durable(enemy_tank)
	AiScenario.make_durable(enemy_scout)
	var ifv := s.brain_tank(Match.Team.GREEN, "Green_IFV_1", Vector3(-100, 0, 40), 0.0, {}, "ifv")
	var on_scout := 0
	var on_tank := 0
	var orders := s.controller_of(ifv)
	await s.start()
	for tick in SimClock.TICK_RATE * 6:
		await s.step()
		if orders.engaged_target == enemy_scout.name:
			on_scout += 1
		elif orders.engaged_target == enemy_tank.name:
			on_tank += 1
	print("MEASURE ai_ifv_priority engaged scout %d ticks, tank %d ticks" % [on_scout, on_tank])
	assert_true(on_scout > 3 * on_tank, "the IFV spends its fire on the scout, not the nearer tank (%d vs %d ticks)" % [on_scout, on_tank])
	BrainVariants.reset()
