extends SceneTree
## Round 42 (engage): the far_ambush drill (tests/tactics/tactics_scenarios.gd), stood up exactly as `make tactics-drills`
## does, with one FAR_TRACE line per crew per sample tick (and on every change): what the element issued it, what its brain
## chose, where its mover is going, what its gun is on, and its line to each gun. Written to see why the maneuver half
## stopped going round under --attack-shot=on (the suite-ON check at 57e2e7eb5: widest_lateral 17.0 v 73.3 OFF).
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/engage/far_ambush_trace.gd -- --seconds=26 --every=30
##         [--attack-shot=on]

const LANE_X := -98.0

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _r(x: float) -> float:
	return snappedf(x, 0.1)


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var seconds := float(_flag("seconds", "26"))
	var every := int(_flag("every", "30"))
	var lab := TacticsLab.create(case, 13)
	var game_match := lab.game_match
	var names: Array = []
	for i in 4:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				Vector3(LANE_X, 0.0, 40.0) + Vector3(0.0, 0.0, i * 10.0), 0.0, "tank").name))
	var enemy: Array = []
	for i in 2:
		enemy.append(String(lab.gun(Match.Team.RUST, "Rust_Gun_%d" % (i + 1),
				Vector3(LANE_X - 6.0 + i * 12.0, 0.0, -45.0), PI).name))
	var alpha := lab.element(names, "Alpha")
	await lab.start()
	alpha.assign({"verb": "move", "to": [LANE_X, -60.0]})
	var orders := lab.orders
	var cover := CoverMap.of(game_match)
	var last := {}
	var hp := {}
	print("FAR_TRACE_FLAG attack_shot=%s" % ElementPlan.ATTACK_SHOT)
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		for unit_name: String in names + enemy:
			var t := lab.tank_of(unit_name)
			var h := t.health if t != null and t.is_alive() else 0
			if hp.has(unit_name) and int(hp[unit_name]) != h and (h == 0 or tick % every == 0):
				print("FAR_HP tick %d %s hp %d -> %d" % [game_match.tick, unit_name, int(hp[unit_name]), h])
			hp[unit_name] = h
		for unit_name: String in names:
			var crew := lab.tank_of(unit_name)
			if crew == null or not crew.is_alive():
				continue
			var brain := game_match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
			var pos := Vector3(crew.global_position.x, 0.0, crew.global_position.z)
			var order: Dictionary = orders.call("current", unit_name)
			var mover := Movement.of(crew)
			var lines := {}
			var dists := {}
			for gun_name: String in enemy:
				var gun := lab.tank_of(gun_name)
				if gun != null and gun.is_alive():
					var gp := Vector3(gun.global_position.x, 0.0, gun.global_position.z)
					lines[gun_name] = cover.clear_line(pos, gp) if cover != null else null
					dists[gun_name] = _r(pos.distance_to(gp))
			var row := {
				"tick": game_match.tick, "unit": unit_name, "pos": [_r(pos.x), _r(pos.z)],
				"speed": _r(Vector2(crew.estimated_velocity.x, crew.estimated_velocity.z).length()),
				"order": String(order.get("verb", "")), "order_target": String(order.get("target", "")),
				"order_to": order.get("goal", null), "order_src": String(order.get("source", "")),
				"issued": String(alpha.issued_to(unit_name).get("verb", "")),
				"issued_to": alpha.issued_to(unit_name).get("to", null),
				"drill": alpha.drill, "why_el": alpha.reason,
				"choice": String(brain.choice.get("option", "")) if brain else "-",
				"choice_target": String(brain.choice.get("target", "")) if brain else "-",
				"why": brain.why if brain else "-",
				"move": String(brain.move_order.get("type", "")) if brain else "-",
				"move_to": [_r(float(brain.move_order.get("x", 0.0))), _r(float(brain.move_order.get("z", 0.0)))]
						if brain and brain.move_order.has("x") else null,
				"phase": mover.phase if mover != null else "-",
				"goal": [_r(mover._goal.x), _r(mover._goal.z)] if mover != null and mover._goal != Vector3.INF else null,
				"engaged": brain.engaged_target if brain else "-", "lines": lines, "dists": dists,
				"role": brain.element.get("role", "") if brain else "-",
			}
			var key := "%s|%s|%s|%s|%s|%s|%s|%s" % [row["order"], row["order_target"], row["issued"], row["drill"], row["choice"],
					row["move"], row["phase"], row["engaged"]]
			if String(last.get(unit_name, "")) != key or tick % every == 0:
				print("FAR_TRACE %s" % JSON.stringify(row))
			last[unit_name] = key
	print("FAR_TRACE_DONE")
	lab.dispose()
	quit(0)
