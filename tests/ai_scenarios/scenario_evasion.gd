extends TestCase
## Round-3 X3 (_agents/streams/archive/round3/ai.md): evasion. A unit fights a cannon tank 50 m away that leads its shots; how many of
## the cannon's shells land, per brain variant: a6 (round 2, parks and trades), x2 (fights on the move), x3 (on the move
## and dodging). Physics decide who can dodge: a tank shell crosses 50 m in ~0.7 s, so a unit must already be moving
## across the line of fire to get out of the way; light units strafe (and dodge), heavy hulls weave with their front on
## the gun (and mostly take the hit on the front armor).

## Waits for combat X2's slower, visible tank shells (see the note above the IFV test).
const PENDING := ["test_a_light_unit_dodges_most_tank_shells"]


## [shells fired at the brain unit, shells that hit it] over `seconds`.
## (60 s: this loop counted `60 * seconds` ticks until round 6, which at the 30 Hz tick meant 60 s while saying 30 — the
## units are fixed and the default doubled, so the sample is the same length it always was. Lesson 30.)
func _duel(variant: String, unit: String, seed_value: int, seconds := 60) -> Array:
	BrainVariants.use(Match.Team.GREEN, variant)
	var s := AiScenario.create(self, seed_value)
	var gun := s.shooter(Match.Team.RUST, "Rust_Gun_1", Vector3(-100, 0, -15), 0.0)
	AiScenario.make_durable(gun)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-104 + seed_value * 3, 0, 35), PI, {}, unit)
	AiScenario.make_durable(me)
	var hits := 0
	var last := me.health + me.shield
	await s.start()
	for tick in SimClock.TICK_RATE * seconds:
		await s.step()
		var now := me.health + me.shield
		if now < last - 5.0:
			hits += 1
		last = now
	var fired := s.shots_by(gun)
	s.dispose()
	BrainVariants.reset()
	return [fired, hits]


func _dodge_rates(unit: String, variants: Array) -> Dictionary:
	var rates := {}
	for variant: String in variants:
		var fired := 0
		var hits := 0
		for seed_value in [1, 2, 3]:
			var result: Array = await _duel(variant, unit, seed_value)
			fired += int(result[0])
			hits += int(result[1])
		rates[variant] = 1.0 - float(hits) / maxf(fired, 1)
		print("MEASURE ai_dodge %s %s: %d of %d shells hit (dodge rate %.0f%%)" % [unit, variant, hits, fired, rates[variant] * 100.0])
	return rates


## With round-2 shells (70 m/s) at the ranges fights happen (25-45 m) a shell arrives in ~0.5 s and a 14 m/s² hull can
## move ~2 m off the shooter's lead: less than half a hull. Measured 2026-09-15: IFV a6 0%, x2 9-15%, x3 6-15% (noise over
## 33 shells). Dodging proper waits for slower, visible tank shells (combat X2; request in the brief's Status): pending.
func test_a_light_unit_dodges_most_tank_shells() -> void:
	var rates: Dictionary = await _dodge_rates("ifv", ["a6", "x3"])
	assert_true(float(rates["x3"]) >= 0.35, "the dodging IFV makes at least 35%% of tank shells miss (%.0f%%)" % (float(rates["x3"]) * 100.0))


func test_tanks_for_reference() -> void:
	await _dodge_rates("tank", ["a6", "x3"])
