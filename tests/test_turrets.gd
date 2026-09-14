extends TestCase
## G5 (streams/gameplay.md): turrets track threats independently of the hull, so tanks keep
## fighting while they move, retreat, or break contact.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const LANE_X := -100.0
const NORTH := Vector3(0, 0, -1)


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


func _squad(game_match: Match, count: int) -> Squad:
	var tanks := []
	for i in count:
		tanks.append({"weapon": "cannon"})
	var doctrine := {"name": "Test", "squads": [{"name": "Alpha", "formation": "line", "verb": "hold", "tanks": tanks}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, doctrine), "", "setup: doctrine loads")
	return game_match.squads["0/Alpha"]


## Rust pursuers: plain tanks pushed south (toward Green) at a steady crawl, guns silent.
func _pursuers(game_match: Match, count: int, z: float) -> Array[Tank]:
	var result: Array[Tank] = []
	for i in count:
		var tank := game_match.spawn_tank("Rust_P_%d" % (i + 1), 0, Match.Team.RUST)
		tank.global_position = Vector3(LANE_X + i * 8.0, 0.0, z)
		tank.rotation.y = PI  # facing south
		result.append(tank)
	return result


func _push(pursuers: Array[Tank], throttle: float) -> void:
	for tank in pursuers:
		tank.command = TankCommand.new(throttle, 0.0, tank.global_position + Vector3(0, 0, 10), false)


func _turret_yaw(tank: Tank) -> float:
	var forward := tank.turret_forward()
	return atan2(-forward.x, -forward.z)


func test_turret_holds_its_world_heading_while_the_hull_turns() -> void:
	var game_match := _setup()
	var tank := game_match.spawn_tank("Spinner", 0, Match.Team.GREEN)
	tank.global_position = Vector3(LANE_X, 0.0, 30.0)
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	await wait_physics_frames(3)
	var before := _turret_yaw(tank)
	orders.set_orders({"type": "drive", "throttle": 0.6, "turn": 1.0, "seconds": 1.5}, {"type": "hold_fire"})
	await wait_physics_frames(80)
	var hull_turned := absf(angle_difference(tank.rotation.y, 0.0))
	assert_true(hull_turned > deg_to_rad(60.0), "setup: the hull swung around (%.0f deg)" % rad_to_deg(hull_turned))
	var drift := absf(angle_difference(_turret_yaw(tank), before))
	assert_true(drift < deg_to_rad(4.0), "with nothing to shoot, the turret keeps pointing the same way in the world (drift %.1f deg)" % rad_to_deg(drift))


func test_turret_watches_a_known_threat_it_cannot_shoot_yet() -> void:
	var game_match := _setup()
	var squad := _squad(game_match, 1)
	var tank := game_match.tanks.get_node("Green_Alpha_1") as Tank
	tank.global_position = Vector3(LANE_X, 0.0, 40.0)
	tank.rotation.y = 0.0
	# 72 m east: inside team sensor range (75) but beyond the cannon's 70 m reach.
	var enemy := game_match.spawn_tank("Rust_Far_1", 0, Match.Team.RUST)
	enemy.global_position = Vector3(LANE_X + 72.0, 0.0, 40.0)
	await wait_physics_frames(3)
	# Drive south: the hull turns around; the turret should stay on the enemy to the east, not ride along.
	assert_eq(game_match.command_squad(Match.Team.GREEN, {"squad": squad.squad_name, "verb": "move", "to": [LANE_X - 10.0, 100.0]}), "",
			"move order accepted")
	var worst := 0.0
	for frame in 60 * 5:
		await tree.physics_frame
		if frame > 150:  # after the first swing onto the threat (it starts 90 deg away)
			var to_enemy := enemy.global_position - tank.global_position
			var off := tank.turret_forward().angle_to(Vector3(to_enemy.x, 0, to_enemy.z).normalized())
			worst = maxf(worst, off)
	assert_true(game_match.intel[Match.Team.GREEN].has("Rust_Far_1"), "setup: the team knows about the enemy")
	assert_true(worst < deg_to_rad(10.0), "while driving away, the turret stays on the known threat (worst %.0f deg off)" % rad_to_deg(worst))


func _retreat_under_pursuit(verb: String, destination: Vector2) -> Dictionary:
	var game_match := _setup()
	var squad := _squad(game_match, 2)
	var greens: Array[Tank] = [game_match.tanks.get_node("Green_Alpha_1"), game_match.tanks.get_node("Green_Alpha_2")]
	for i in greens.size():
		greens[i].global_position = Vector3(LANE_X + i * 8.0, 0.0, 10.0)
		greens[i].rotation.y = 0.0  # facing north, toward the pursuers
	var pursuers := _pursuers(game_match, 2, -40.0)
	await wait_physics_frames(3)
	assert_eq(game_match.command_squad(Match.Team.GREEN, {"squad": squad.squad_name, "verb": verb, "to": [destination.x, destination.y]}), "",
			"%s order accepted" % verb)
	var shots_before: int = game_match.stats["shots"][Match.Team.GREEN]
	var front_samples := 0
	var samples := 0
	for frame in 60 * 10:
		_push(pursuers, 0.35)
		await tree.physics_frame
		if frame % 30 == 0 and frame > 120:
			for tank in greens:
				var threat := pursuers[0].global_position - tank.global_position
				samples += 1
				if (-tank.global_basis.z).dot(Vector3(threat.x, 0, threat.z).normalized()) > 0.5:
					front_samples += 1
	return {"shots": int(game_match.stats["shots"][Match.Team.GREEN]) - shots_before,
			"front": float(front_samples) / maxf(samples, 1), "lead_z": greens[0].global_position.z}


func test_break_contact_keeps_firing_at_pursuers() -> void:
	var outcome: Dictionary = await _retreat_under_pursuit("break_contact", Vector2(LANE_X, 80.0))
	assert_true(outcome["lead_z"] > 25.0, "the squad actually withdraws south (lead z %.1f)" % outcome["lead_z"])
	assert_true(outcome["shots"] >= 4, "retreating tanks keep shooting at pursuers in range (%d shots in 10 s)" % outcome["shots"])
	assert_true(outcome["front"] >= 0.8, "and keep their front armor toward the threat (%.0f%% of samples)" % (outcome["front"] * 100.0))


func test_a_move_away_from_the_enemy_still_returns_fire() -> void:
	# The lead's playtest: a plain Move order back toward base. The hull turns to drive; the gun must not.
	var outcome: Dictionary = await _retreat_under_pursuit("move", Vector2(LANE_X, 80.0))
	assert_true(outcome["lead_z"] > 30.0, "the squad drives south (lead z %.1f)" % outcome["lead_z"])
	assert_true(outcome["shots"] >= 4, "tanks moving away keep shooting at pursuers in range (%d shots in 10 s)" % outcome["shots"])
