extends TestCase
## Round 8 (the lead): *"I'm also testing just telling a group of units to attack a single unit, but they don't obey and
## instead they shoot at whatever they were already shooting at."* test_ai_orders proves the BRAIN picks the ordered
## target from a hand-built situation; this plays the lead's sequence through the game's own paths — a whole group gets
## an attack task (a right-click on an enemy, RtsControls.assign_task), or a handful gets direct player orders — while it
## is already fighting a nearer enemy, and counts what the guns are actually on.

const X := TacticsScenarios.LANE_X


## Four player units already fighting A (nearer); B is also in sight. `how`: "task" (the element path) or "direct".
func _run(how: String) -> Dictionary:
	var lab := TacticsLab.create(self, 41)
	lab.game_match.set_meta("player_team", Match.Team.GREEN)
	var names: Array = []
	for i in 4:
		var tank := lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1), Vector3(X - 12.0 + i * 8.0, 0, 45), 0.0)
		AiScenario.make_durable(tank)
		names.append(String(tank.name))
	for spec: Array in [["Rust_A", Vector3(X - 6.0, 0, 15)], ["Rust_B", Vector3(X + 22.0, 0, 5)]]:
		var enemy := lab.gun(Match.Team.RUST, spec[0], spec[1], 0.0)
		AiScenario.make_durable(enemy)
		(lab.game_match.brains.get_node("Orders_" + spec[0]) as OrderController).set_orders({"type": "stop"}, {"type": "hold_fire"})
	var alpha := lab.element(names, "Alpha")
	await lab.start()
	assert_eq(alpha.assign({"verb": "attack", "target": "Rust_A"}), "", "setup: fighting A")
	for tick in SimClock.TICK_RATE * 6:
		await lab.step()
	var on_a_before := _on(lab, names, "Rust_A")
	# The lead's order: attack B.
	if how == "task":
		assert_eq(alpha.assign({"verb": "attack", "target": "Rust_B"}), "", "the attack task on B is accepted")
	else:
		lab.elements.disband(alpha)
		assert_eq((lab.orders as Orders).issue(UnitCommand.make(names, "attack", {"target": "Rust_B", "source": "player"})), "",
				"the direct attack order on B is accepted")
	var ticks := {"Rust_A": 0, "Rust_B": 0, "": 0}
	for tick in SimClock.TICK_RATE * 10:
		await lab.step()
		if tick >= SimClock.TICK_RATE * 2:  # two seconds to turn the guns
			for unit_name: String in names:
				var engaged := _engaged(lab, unit_name)
				ticks[engaged if ticks.has(engaged) else ""] = int(ticks.get(engaged if ticks.has(engaged) else "", 0)) + 1
	lab.dispose()
	return {"on_a_before": on_a_before, "unit_ticks": ticks}


func _engaged(lab: TacticsLab, unit_name: String) -> String:
	var brain := lab.game_match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
	return brain.engaged_target if brain != null else ""


func _on(lab: TacticsLab, names: Array, target: String) -> int:
	var count := 0
	for unit_name: String in names:
		if _engaged(lab, unit_name) == target:
			count += 1
	return count


func test_an_attack_task_on_a_new_target_moves_the_guns_onto_it() -> void:
	var result := await _run("task")
	print("MEASURE attack_order task %s" % result)
	assert_true(int(result["on_a_before"]) >= 2, "setup: the group really was fighting A (%d of 4 on it)" % result["on_a_before"])
	var ticks: Dictionary = result["unit_ticks"]
	assert_true(int(ticks["Rust_B"]) > 4 * int(ticks["Rust_A"]), "the guns go onto B, the ordered target (B %d vs A %d unit-ticks)"
			% [ticks["Rust_B"], ticks["Rust_A"]])


func test_a_direct_attack_order_on_a_new_target_moves_the_guns_onto_it() -> void:
	var result := await _run("direct")
	print("MEASURE attack_order direct %s" % result)
	assert_true(int(result["on_a_before"]) >= 2, "setup: the group really was fighting A (%d of 4 on it)" % result["on_a_before"])
	var ticks: Dictionary = result["unit_ticks"]
	assert_true(int(ticks["Rust_B"]) > 4 * int(ticks["Rust_A"]), "the guns go onto B, the ordered target (B %d vs A %d unit-ticks)"
			% [ticks["Rust_B"], ticks["Rust_A"]])
