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


func _overwatch_hidden_share(variant: String) -> Array:
	BrainVariants.use(Match.Team.GREEN, variant)
	var s := AiScenario.create(self, 4)
	# A durable gun north-west, beyond WallWestA; the squad starts in the open east of the wall's end, and only
	# Alpha_1 (the commander, on the west end) has a hiding place within reach of its overwatch position.
	var gun := s.dummy(Match.Team.RUST, "Rust_Gun_1", Vector3(-40, 0, -60), PI)
	AiScenario.make_durable(gun)
	var members: Array[Tank] = []
	for x in [-22.0, -16.0, -10.0, -4.0]:
		members.append(s.brain_tank(Match.Team.GREEN, "Green_Alpha_%d" % (members.size() + 1), Vector3(x, 0, -8), 0.0,
				{"role": "anchor"}, "tank", "", "Alpha"))
	var squad := s.form_squad(Match.Team.GREEN, "Alpha", members)
	await s.start()
	for tick in 30:
		await s.step()
	assert_eq(s.game_match.command_squad(Match.Team.GREEN, {"squad": "Alpha", "verb": "bound", "to": [-12, -70]}), "", "setup: bound north")
	var watcher := members[0]
	var samples := 0
	var hidden := 0
	# The first leg: element 1 bounds while element 0 (with Alpha_1) watches.
	for tick in 60 * 6:
		await s.step()
		if squad.bounding_element != 1:
			break
		samples += 1
		hidden += 0 if AiScenario.sees(gun, watcher) else 1
	var share := float(hidden) / maxf(samples, 1)
	for tick in 60 * 20:
		await s.step()
		if squad.arrived:
			break
	var progress := members[0].global_position.z
	s.dispose()
	BrainVariants.reset()
	return [share, progress, samples]


func test_the_overwatch_element_covers_from_cover() -> void:
	var stay: Array = await _overwatch_hidden_share("a4")
	var tactical: Array = await _overwatch_hidden_share("a6")
	print("MEASURE ai_overwatch Alpha_1 hidden during the first overwatch leg: staying put %.0f%% of %d ticks (commander ends at z %.0f), tactical spot %.0f%% of %d ticks (z %.0f)" % [
			stay[0] * 100.0, stay[2], stay[1], tactical[0] * 100.0, tactical[2], tactical[1]])
	assert_true(tactical[0] >= 0.3 and tactical[0] >= stay[0] + 0.25, "with a hiding place in reach, the watcher covers the bound from it (%.0f%% vs %.0f%%)" % [
			tactical[0] * 100.0, stay[0] * 100.0])
	assert_true(tactical[1] <= stay[1] + 10.0, "and the bound still makes progress (commander z %.0f vs %.0f)" % [tactical[1], stay[1]])
