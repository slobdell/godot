extends TestCase
## Catalog v2 (rules R1): fixed unit types drive the simulation, army JSON v2 lists them, and scouts behave like scouts.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


func _army(entries: Array) -> Dictionary:
	return {"name": "Test", "squads": [{"name": "A", "units": entries}]}


func test_the_catalog_is_where_stats_come_from() -> void:
	var game_match := _setup()
	var army := _army([{"unit": "tank"}, {"unit": "scout"}, {"unit": "ifv"}, {"unit": "artillery"}, {"unit": "lancer", "paint": "#8a3ab9"}])
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, army), "", "a mixed army loads")
	var tank := game_match.tanks.get_node("Green_A_1") as Tank
	var scout := game_match.tanks.get_node("Green_A_2") as Tank
	await wait_physics_frames(1)
	assert_eq(tank.max_health, int(Units.PROFILES["tank"]["max_health"]), "a tank's hull is the catalog's")
	assert_eq(scout.max_health, int(Units.PROFILES["scout"]["max_health"]), "a scout's too")
	assert_near(scout.sight_radius, 110.0, 0.01, "scouts see farther")
	assert_true(scout.max_forward_speed > tank.max_forward_speed + 3.0, "and drive faster")
	assert_true((scout.get_node("Collision") as CollisionShape3D).shape != (tank.get_node("Collision") as CollisionShape3D).shape,
			"a scout gets its own, smaller hitbox (not the shared scene shape)")
	for index in army["squads"][0]["units"].size():
		var unit_id: String = army["squads"][0]["units"][index]["unit"]
		var unit := game_match.tanks.get_node("Green_A_%d" % (index + 1)) as Tank
		assert_eq(unit.unit_id, unit_id, "spawned as a %s" % unit_id)
		assert_eq(unit.weapon_id, Units.PROFILES[unit_id]["weapon"], "a %s fires its fixed weapon" % unit_id)
		assert_eq(unit.mount, Units.PROFILES[unit_id]["mount"], "and has the catalog's mount (C4)")
		assert_near(unit.turret.global_position.y + Tank.MUZZLE_ABOVE_PIVOT, float(Units.PROFILES[unit_id]["muzzle_height"]), 0.01,
				"its muzzle sits at the catalog's height")
		assert_near(unit.heat_capacity, float(Units.PROFILES[unit_id].get("heat_capacity", 0.0)), 0.01, "heat only if its weapon heats")


func test_v1_armies_are_rejected_with_reasons() -> void:
	for pair in [[{"unit": "hovercraft"}, "hovercraft"], [{"unit": "tank", "weapon": "laser"}, "fixed weapons"],
			[{"unit": "tank", "components": ["heat_sink"]}, "'components'"], [{"unit": "scout", "weapons": {"main": "laser"}}, "'weapons'"],
			[{"paint": "#ffffff"}, "needs a 'unit'"], [{"unit": "tank", "paint": "greenish"}, "paint"]]:
		var error: String = Doctrine.parse(_army([pair[0]])).get("error", "")
		assert_true(error.contains(pair[1]), "%s is rejected mentioning '%s' (got '%s')" % [pair[0], pair[1], error])
	var v1 := {"name": "Old", "squads": [{"name": "A", "tanks": [{"unit": "tank"}]}]}
	assert_true(String(Doctrine.parse(v1).get("error", "")).contains("'units'"), "a v1 'tanks' list says to use 'units'")
	var full := {"name": "Big", "squads": []}
	for i in 5:
		full["squads"].append({"name": "S%d" % i, "units": [{"unit": "scout"}, {"unit": "scout"}, {"unit": "scout"}, {"unit": "scout"}, {"unit": "scout"}]})
	assert_true(Doctrine.parse(full).has("doctrine"), "armies grow to 25 units in 5 squads")
	full["squads"].append({"name": "S6", "units": [{"unit": "scout"}]})
	assert_true(Doctrine.parse(full).has("error"), "but not a sixth squad")
	assert_eq(Units.cost_of({"unit": "ifv"}), int(Units.PROFILES["ifv"]["cost"]), "a unit costs its type's points")


func _scout_situation(contacts: Array) -> Dictionary:
	return {
		"tick": 1000,
		"self": {"name": "Green_A_1", "team": 0, "position": Vector3.ZERO, "forward": Vector3.FORWARD,
				"health": 140, "max_health": 140, "shield": 80.0, "max_shield": 80.0, "class": "scout", "role": "scout",
				"weapon": Weapons.profile("machine_gun"), "ammo": 600, "max_ammo": 600},
		"directives": Directives.resolve([{"role": "scout"}]), "contacts": contacts, "allies": [],
		"objective": null, "objective_radius": 0.0, "squad_center": null, "cover": [],
		"rally": Vector3(0, 0, 90), "enemy_base": Vector3(0, 0, -90), "memory_ticks": Match.CONTACT_MEMORY_TICKS,
	}


func _contact(position: Vector3, visible := true) -> Dictionary:
	return {"name": "Rust_A_1", "position": position, "velocity": Vector3.ZERO, "forward": Vector3.BACK, "health": 300,
			"shield": 150, "weapon": "cannon", "visible": visible, "age": 0 if visible else 200, "exposed_face": "front",
			"facing_ally": false, "aiming_at_me": true}


func test_scouts_spot_from_a_distance_instead_of_brawling() -> void:
	var choose := func(contacts: Array) -> String:
		return TankBrain.label(TankBrain.decide(_scout_situation(contacts), {})["choice"])
	assert_eq(choose.call([]), "SPOT", "nothing known: scout ahead")
	assert_eq(choose.call([_contact(Vector3(0, 0, -50))]), "SPOT", "an enemy tank 50 m away: back off to spotting range, don't fight")
	assert_eq(choose.call([_contact(Vector3(0, 0, -95))]), "SPOT", "at spotting range: keep watching")
	var artillery := _contact(Vector3(0, 0, -60))
	artillery["weapon"] = "mortar"
	artillery["aiming_at_me"] = false
	assert_eq(choose.call([artillery]), "ENGAGE Rust_A_1", "enemy artillery in sight: scouts hunt it")


func test_a_scout_keeps_an_enemy_tank_in_sight_but_out_of_its_range() -> void:
	var game_match := _setup()
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _army([{"unit": "scout", "directive": {"role": "scout"}}])), "", "setup: scout")
	var scout := game_match.tanks.get_node("Green_A_1") as Tank
	var enemy := game_match.spawn_tank("Rust_Target_1", 0, Match.Team.RUST)
	scout.global_position = Vector3(-100, 0, 40)
	enemy.global_position = Vector3(-100, 0, -15)  # 55 m: inside cannon range
	enemy.rotation.y = PI
	var closest := INF
	var seen_ticks := 0
	for tick in 60 * 10:
		enemy.command = TankCommand.new(0.0, 0.0, scout.global_position, false)  # holds still, gun silent
		await tree.physics_frame
		if tick > 60 * 4:
			closest = minf(closest, scout.global_position.distance_to(enemy.global_position))
			if game_match.is_visible_to(Match.Team.GREEN, enemy):
				seen_ticks += 1
	assert_true(closest > 70.0, "after backing off, the scout stays outside cannon range (closest %.0f m)" % closest)
	assert_true(seen_ticks > 60 * 5 * 0.9, "while keeping the enemy spotted for the team (%d of %d ticks)" % [seen_ticks, 60 * 6])
