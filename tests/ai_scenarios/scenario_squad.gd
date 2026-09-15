extends TestCase
## Squad tactics (A6 in _agents/streams/ai.md): three brains in one squad against three targets spread in front
## of them. Each brain alone shoots whatever is nearest; a squad with a plan piles onto one target.

const PENDING := []


func _damage(tank: Tank) -> float:
	return float(1_000_000 - tank.health) + (tank.max_shield - tank.shield)


func _focus_share(variant: String) -> Array:
	BrainVariants.use(Match.Team.GREEN, variant)
	var s := AiScenario.create(self, 3)
	var targets: Array[Tank] = []
	for spot in [Vector3(-116, 0, 0), Vector3(-100, 0, -4), Vector3(-84, 0, 0)]:
		var target := s.dummy(Match.Team.RUST, "Rust_Target_%d" % (targets.size() + 1), spot, PI)
		AiScenario.make_durable(target)
		targets.append(target)
	var members: Array[Tank] = []
	for x in [-114.0, -100.0, -86.0]:
		members.append(s.brain_tank(Match.Team.GREEN, "Green_Alpha_%d" % (members.size() + 1), Vector3(x, 0, 42), 0.0, {}, "tank", "", "Alpha"))
	s.form_squad(Match.Team.GREEN, "Alpha", members)
	await s.start()
	for tick in 60 * 15:
		await s.step()
	var damage: Array = targets.map(func(t: Tank) -> float: return _damage(t))
	var total: float = damage.reduce(func(a: float, b: float) -> float: return a + b, 0.0)
	var share: float = damage.max() / maxf(total, 1.0)
	s.dispose()
	BrainVariants.reset()
	return [share, damage]


func test_a_squad_focuses_its_fire() -> void:
	var alone: Array = await _focus_share("a4")
	var squad: Array = await _focus_share("a6")
	print("MEASURE ai_focus_fire most-damaged target's share: without squad tactics %.0f%% %s, with %.0f%% %s" % [
			alone[0] * 100.0, alone[1], squad[0] * 100.0, squad[1]])
	assert_true(squad[0] >= 0.6, "with a plan, the squad puts most of its damage on one target (%.0f%%)" % (squad[0] * 100.0))
	assert_true(squad[0] > alone[0] + 0.15, "clearly more focused than brains fighting alone (%.0f%% vs %.0f%%)" % [squad[0] * 100.0, alone[0] * 100.0])
