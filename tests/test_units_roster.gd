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
		# LOCAL, not global. This asserted `turret.global_position.y`, which is the muzzle's height IN THE WORLD --
		# so it passed only while the hull happened to be resting exactly on y = 0, one physics frame after spawn.
		# It failed on builder0 at 0.26 against 1.12, i.e. the scout sitting 0.86 m LOW, and passed alone on the same
		# tree: an order-dependent failure, and the suspicion fell on `Units.tuning` leaking between tests. It is not
		# that -- the tuning keys in play are max_shield, damage and armor, none of which is a muzzle height.
		#
		# The defect is that ONE assertion was making TWO claims: "the catalog sets the muzzle above the hull"
		# (deterministic, and the only thing a test named *the catalog is where stats come from* should check) and
		# "the hull has settled on the ground" (physics, timing, and whatever the previous test left the world in).
		# When a conflated assertion fails you cannot tell which claim broke, so it gets blamed on whatever changed
		# most recently. Whether hulls settle is worth testing; it belongs in a spawn test, with enough frames to
		# actually settle, and not here.
		assert_near(unit.turret.position.y + Tank.MUZZLE_ABOVE_PIVOT, float(Units.PROFILES[unit_id]["muzzle_height"]), 0.01,
				"its muzzle sits at the catalog's height above its own hull")
		assert_near(unit.heat_capacity, float(Units.PROFILES[unit_id].get("heat_capacity", 0.0)), 0.01, "heat only if its weapon heats")


func test_v1_armies_are_rejected_with_reasons() -> void:
	for pair in [[{"unit": "hovercraft"}, "hovercraft"], [{"unit": "tank", "weapon": "laser"}, "fixed weapons"],
			[{"unit": "tank", "components": ["heat_sink"]}, "'components'"], [{"unit": "scout", "weapons": {"main": "laser"}}, "'weapons'"],
			[{"paint": "#ffffff"}, "needs a 'unit'"], [{"unit": "tank", "paint": "greenish"}, "paint"]]:
		var error: String = Doctrine.parse(_army([pair[0]])).get("error", "")
		assert_true(error.contains(pair[1]), "%s is rejected mentioning '%s' (got '%s')" % [pair[0], pair[1], error])
	var v1 := {"name": "Old", "squads": [{"name": "A", "tanks": [{"unit": "tank"}]}]}
	assert_true(String(Doctrine.parse(v1).get("error", "")).contains("'units'"), "a v1 'tanks' list says to use 'units'")
	# A faction army is bigger than the five squads a player builds in the garage (round 4): the caps are
	# Doctrine.MAX_SQUADS squads, MAX_SQUAD_UNITS each, and MAX_UNITS vehicles in total (one per spawn point).
	var full := {"name": "Big", "squads": []}
	var placed := 0
	while placed < Doctrine.MAX_UNITS:
		var units: Array = []
		for u in mini(Doctrine.MAX_SQUAD_UNITS, Doctrine.MAX_UNITS - placed):
			units.append({"unit": "scout"})
		placed += units.size()
		full["squads"].append({"name": "S%d" % full["squads"].size(), "units": units})
	assert_true(full["squads"].size() > Doctrine.PLAYER_MAX_SQUADS,
			"a full army needs more squads than the garage offers a player")
	assert_true(Doctrine.parse(full).has("doctrine"), "armies grow to %d units" % Doctrine.MAX_UNITS)
	full["squads"].append({"name": "S_extra", "units": [{"unit": "scout"}]})
	assert_true(String(Doctrine.parse(full).get("error", "")).contains("spawn points"),
			"but not past what the arena can spawn")
	assert_eq(Units.cost_of({"unit": "ifv"}), int(Units.PROFILES["ifv"]["cost"]), "a unit costs its type's points")


func test_the_burner_is_the_flamethrowers_unit() -> void:
	var game_match := _setup()
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _army([{"unit": "burner"}])), "", "a Burner loads")
	var burner := game_match.tanks.get_node("Green_A_1") as Tank
	var target := game_match.spawn_tank("Rust_Target_1", 0, Match.Team.RUST, "tank")
	await wait_physics_frames(1)
	assert_eq(burner.weapon_id, "flamethrower", "it carries the flamethrower (stretch: the future Burner)")
	assert_true(int(Units.profile("burner")["unlock_tier"]) > 0, "it is an unlock, not a starter")
	burner.global_position = Vector3(-100, 0, 20)
	target.global_position = Vector3(-100, 0, 8)
	target.rotation.y = PI / 2.0
	var full: float = target.health + target.shield
	for tick in SimClock.TICK_RATE * 2:
		burner.command = TankCommand.new(0.0, 0.0, target.global_position, true)
		target.command = TankCommand.new()
		await tree.physics_frame
	assert_true(target.health + target.shield < full - 30.0, "and burns what it reaches (%.0f of %.0f left)" % [target.health + target.shield, full])


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
	for tick in SimClock.TICK_RATE * 10:
		enemy.command = TankCommand.new(0.0, 0.0, scout.global_position, false)  # holds still, gun silent
		await tree.physics_frame
		if tick > SimClock.TICK_RATE * 4:
			closest = minf(closest, scout.global_position.distance_to(enemy.global_position))
			if game_match.is_visible_to(Match.Team.GREEN, enemy):
				seen_ticks += 1
	assert_true(closest > 70.0, "after backing off, the scout stays outside cannon range (closest %.0f m)" % closest)
	assert_true(seen_ticks > SimClock.TICK_RATE * 5 * 0.9, "while keeping the enemy spotted for the team (%d of %d ticks)" % [seen_ticks, SimClock.TICK_RATE * 6])


func test_every_roster_role_can_be_put_in_a_squad() -> void:
	# Army.squads_for() iterates SQUADS, not the units -- so a unit whose role is not a key in that table is
	# SILENTLY DROPPED from every generated army. No error, the army still builds, one unit type just never appears.
	#
	# This is not hypothetical twice over. The table's own comment records the gangs' rat rods getting the Condemned
	# scout's directive and the faction winning 10-30% of everything. And when X5 re-roled the Lance Platform from
	# "lancer" to "designator" this test did not exist, so the Syndicate fought 60 matches without its new special
	# and the result read as "the designator makes them slightly worse".
	var missing: Array[String] = []
	for faction in ["condemned", "gangs", "law", "syndicate"]:
		for unit_id: String in Units.roster(faction):
			var role := Units.role_of(unit_id)
			if not Army.SQUADS.has(role) and not Army.SQUADS.has("%s/%s" % [faction, role]):
				missing.append("%s (%s, role '%s')" % [unit_id, faction, role])
	assert_eq(missing, [] as Array[String],
			"every roster unit's role has a SQUADS entry, or it never reaches a battlefield: %s" % [missing])


func test_faction_directives_can_be_ablated_for_a_measurement() -> void:
	# The gangs went from 23% to 53% across a single commit that carried BOTH CP4 (the engagement envelope) and the
	# `gangs/scout` directive fix, and no matrix ran between them -- so the swing is unattributed and CP4 must be
	# given no credit for it until something separates the two.
	#
	# The separation is an ABLATION, and the reason it is a flag rather than a hand-edit of SQUADS is that a
	# hand-edit leaves a modified tree: the arm is invisible in the output, `run_conditions` reports the run DIRTY,
	# and the number arrives six weeks later with no way to tell which arm produced it. A flag can be printed.
	assert_true(Army.faction_directives, "faction-specific directives are ON by default: the ablation is the exception")
	assert_eq(Army.squad_key("gang_scout"), "gangs/scout", "a gang scout normally takes its faction's own entry")
	assert_eq(String(Army.SQUADS["gangs/scout"]["directive"]["role"]), "assault", "which sends the spear buggies IN")

	Army.faction_directives = false
	assert_eq(Army.squad_key("gang_scout"), "scout", "ablated, it falls back to the plain role...")
	assert_eq(String(Army.SQUADS["scout"]["directive"]["role"]), "scout", "...which is the standoff-spotter directive")
	# The ablation must touch ONLY faction-keyed entries. If it also changed plain-role units the arm would measure
	# "directives off" rather than "the gangs' scout directive off", and the difference would be unattributable in
	# exactly the way this test exists to prevent.
	assert_eq(Army.squad_key("syn_lancer"), "lancer", "a unit with no faction entry is unaffected")
	assert_eq(Army.squad_key("law_tank"), "tank", "and so is every plain-role unit")
	Army.faction_directives = true
	assert_eq(Army.squad_key("gang_scout"), "gangs/scout", "and the switch goes back")


func test_the_spawn_grid_holds_the_unit_a_bare_spawn_drives() -> void:
	# The spawn grid holds only what is placed ON it, and for every shipping path that is `Units.DEFAULT`:
	# `Match.spawn_tank` defaults to it, and network players and legacy bots are the callers. A doctrine army never
	# stays there -- `load_doctrine` ends with `ArmyLayout.deploy()`, which teleports every unit at tick 0 before any
	# physics step -- so the roster is free to carry vehicles far longer than the grid's pitch, and after round 8 it
	# does: the War Rig is 14 m against a grid pitch of 8.0.
	#
	# An earlier version of this test asserted the whole roster against the grid. That was wrong twice over: it
	# guarded a holding position no doctrine army occupies, and it would now fail on a size the lead asked for.
	# The real ceiling on vehicle size is the spacing the army STANDS at -- tests/test_army_footprint.gd.
	var rows := _spawn_rows()
	var length_ceiling := (rows[1] - rows[0]) - 2.0 * Match.SPAWN_JITTER_MAX_Z if rows.size() > 1 \
			else Match.SPAWN_ROW_SPACING - 2.0 * Match.SPAWN_JITTER_MAX_Z
	var width_ceiling := _spawn_column_pitch() - 2.0 * Match.SPAWN_JITTER_MAX_X
	var size: Array = Units.PROFILES[Units.DEFAULT]["hull_size"]
	assert_true(float(size[2]) <= length_ceiling,
			"the bare-spawn unit (%s, %.1f m long) fits between spawn rows (%.1f m of pitch after jitter)"
			% [Units.DEFAULT, size[2], length_ceiling])
	assert_true(float(size[0]) <= width_ceiling,
			"...and between spawn columns (%.1f m after jitter)" % width_ceiling)


func _spawn_rows() -> Array[float]:
	var found := {}
	for spot: Array in Arena.active.get("spawns", {}).get("green", []):
		found[snappedf(float(spot[1]), 0.01)] = true
	var rows: Array[float] = []
	for z: float in found:
		rows.append(z)
	if rows.is_empty():
		for row in Match.SPAWN_ROWS:
			rows.append(Match.BASE_Z + Match.SPAWN_ROW_SPACING * float(row))
	rows.sort()
	return rows


## The smallest gap between adjacent spawn columns in the loaded layout (the tightest packing a hull must fit).
func _spawn_column_pitch() -> float:
	var found := {}
	for spot: Array in Arena.active.get("spawns", {}).get("green", []):
		found[snappedf(float(spot[0]), 0.01)] = true
	var xs: Array[float] = []
	for x: float in found:
		xs.append(x)
	if xs.size() < 2:
		return absf(float(Match.SLOT_X[1]) - float(Match.SLOT_X[0]))
	xs.sort()
	var pitch := INF
	for i in range(1, xs.size()):
		pitch = minf(pitch, xs[i] - xs[i - 1])
	return pitch
