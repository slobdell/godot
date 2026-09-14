extends TestCase
## Directive set 2 part 1: the unit catalog drives the simulation, doctrines carry loadouts, and scouts
## behave like scouts.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


func _army(entries: Array) -> Dictionary:
	return {"name": "Test", "squads": [{"name": "A", "tanks": entries}]}


func test_the_catalog_is_where_stats_come_from() -> void:
	var game_match := _setup()
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _army([{"unit": "tank"}, {"unit": "scout"}])), "", "a mixed army loads")
	var tank := game_match.tanks.get_node("Green_A_1") as Tank
	var scout := game_match.tanks.get_node("Green_A_2") as Tank
	await wait_physics_frames(1)
	assert_eq(tank.max_health, int(Units.PROFILES["tank"]["max_health"]), "a tank's hull is the catalog's")
	assert_eq(scout.max_health, int(Units.PROFILES["scout"]["max_health"]), "a scout's too")
	assert_near(scout.sight_radius, 110.0, 0.01, "scouts see farther")
	assert_true(scout.max_forward_speed > tank.max_forward_speed + 3.0, "and drive faster")
	assert_eq(scout.weapon_id, "machine_gun", "a scout's default weapon is its hardpoint's first choice")
	assert_true((scout.get_node("Collision") as CollisionShape3D).shape != (tank.get_node("Collision") as CollisionShape3D).shape,
			"a scout gets its own, smaller hitbox (not the shared scene shape)")


func test_loadout_weapons_and_components_apply() -> void:
	var game_match := _setup()
	var army := _army([{"unit": "tank", "weapons": {"main": "laser"}, "components": ["heat_sink", "shield_booster"]},
			{"unit": "tank", "weapon": "cannon", "components": ["ammo_rack"], "paint": "#8a3ab9"}])
	assert_true(Doctrine.parse(army).has("doctrine"), "a loadout doctrine validates: %s" % Doctrine.parse(army).get("error", ""))
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, army), "", "and loads")
	var laser := game_match.tanks.get_node("Green_A_1") as Tank
	var cannon := game_match.tanks.get_node("Green_A_2") as Tank
	assert_eq(laser.weapon_id, "laser", "weapons by hardpoint")
	assert_near(laser.heat_capacity, 100.0 + 40.0, 0.01, "a heat sink raises heat capacity")
	assert_near(laser.max_shield, 150.0 + 60.0, 0.01, "a shield booster raises the shield")
	assert_eq(cannon.max_ammo, roundi(45 * 1.5), "an ammo rack carries half a load more")
	assert_eq(Units.cost_of({"unit": "tank", "weapons": {"main": "laser"}, "components": ["heat_sink", "shield_booster"]}),
			200 + 20 + 30 + 40, "cost = chassis + weapon + components")


func test_invalid_loadouts_are_rejected_with_reasons() -> void:
	for pair in [[{"unit": "hovercraft"}, "hovercraft"], [{"unit": "scout", "weapon": "cannon"}, "doesn't take"],
			[{"unit": "scout", "components": ["heat_sink", "ammo_rack"]}, "component slots"],
			[{"components": ["flux_capacitor"]}, "flux_capacitor"], [{"weapons": {"turret2": "laser"}}, "no hardpoint"],
			[{"paint": "greenish"}, "paint"]]:
		var error: String = Doctrine.parse(_army([pair[0]])).get("error", "")
		assert_true(error.contains(pair[1]), "%s is rejected mentioning '%s' (got '%s')" % [pair[0], pair[1], error])
	var twenty := {"name": "Big", "squads": []}
	for i in 4:
		twenty["squads"].append({"name": "S%d" % i, "tanks": [{"unit": "scout"}, {"unit": "scout"}, {"unit": "scout"}, {"unit": "scout"}, {"unit": "scout"}]})
	assert_true(Doctrine.parse(twenty).has("doctrine"), "armies grow to 20 units in 4 squads")


func _scout_situation(contacts: Array) -> Dictionary:
	return {
		"tick": 1000,
		"self": {"name": "Green_A_1", "team": 0, "position": Vector3.ZERO, "forward": Vector3.FORWARD,
				"health": 140, "max_health": 140, "shield": 80.0, "max_shield": 80.0, "class": "scout",
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
