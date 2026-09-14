extends TestCase
## Directive set 2 part 2: artillery lobs rounds over cover at what the TEAM can see.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const CRATE := preload("res://game/arena/crate.tscn")


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


## An artillery tank driven by a plain OrderController that spots through team intel, like a brain.
func _battery(game_match: Match, at: Vector3) -> Array:
	var gun := game_match.spawn_tank("Green_Gun_1", 0, Match.Team.GREEN, Weapons.DEFAULT, {"unit": "artillery"})
	gun.global_position = at
	var orders := OrderController.new()
	orders.tank = gun
	orders.tanks_root = game_match.tanks
	orders.spotter = func(other: Tank) -> bool: return game_match.is_visible_to(Match.Team.GREEN, other)
	add_to_tree(orders)
	orders.set_orders({"type": "stop"}, {"type": "fire_at_will"})
	return [gun, orders]


func _toughness(tank: Tank) -> float:
	return tank.health + tank.shield


func test_a_spotted_target_behind_cover_gets_shelled() -> void:
	var game_match := _setup()
	game_match.seed_spawns(3, 0.0)  # scatter uses the match RNG: seed it, or the test is a dice roll
	var setup: Array = _battery(game_match, Vector3(-100, 0, 80))
	var gun: Tank = setup[0]
	var target := game_match.spawn_tank("Rust_Target_1", 0, Match.Team.RUST)
	target.global_position = Vector3(-100, 0, -20)  # 100 m north
	for i in 3:  # a wall of crates between them: no direct line of sight
		var crate: Node3D = CRATE.instantiate()
		crate.position = Vector3(-104 + i * 4.0, 0, 60)
		add_to_tree(crate)
	await wait_physics_frames(3)
	assert_true(not Perception.has_line_of_sight(gun, target), "setup: the battery can't see its target")
	await wait_physics_frames(60 * 3)
	assert_eq(game_match.stats["shots"][Match.Team.GREEN], 0, "with nobody spotting, it doesn't fire")
	var spotter := game_match.spawn_tank("Green_Eyes_1", 0, Match.Team.GREEN, Weapons.DEFAULT, {"unit": "scout"})
	spotter.global_position = Vector3(-80, 0, 40)  # 63 m from the target, clear view
	var before := _toughness(target)
	var lowest := before
	for i in 60 * 20:
		target.command = TankCommand.new()
		await tree.physics_frame
		lowest = minf(lowest, _toughness(target))  # the shield recharges between rounds: track the lowest
	var shots: int = game_match.stats["shots"][Match.Team.GREEN]
	assert_true(shots >= 3, "once a scout spots it, the battery fires (%d)" % shots)
	var hits: int = game_match.stats["hits"][Match.Team.GREEN]
	assert_true(hits >= 2, "rounds land on it over the cover (%d of %d rounds hit)" % [hits, shots])
	assert_true(lowest < before - 40.0, "and hurt it (lowest %.0f of %.0f)" % [lowest, before])


func test_no_firing_inside_the_minimum_range() -> void:
	var game_match := _setup()
	var setup: Array = _battery(game_match, Vector3(-100, 0, 40))
	var target := game_match.spawn_tank("Rust_Close_1", 0, Match.Team.RUST)
	target.global_position = Vector3(-100, 0, 20)  # 20 m: inside the 35 m minimum
	await wait_physics_frames(60 * 6)
	assert_true(game_match.is_visible_to(Match.Team.GREEN, target), "setup: it's visible")
	assert_eq(game_match.stats["shots"][Match.Team.GREEN], 0, "a mortar can't hit something that close")


func test_a_burst_hurts_everything_nearby_with_falloff() -> void:
	var game_match := _setup()
	var near := game_match.spawn_tank("Rust_Near_1", 0, Match.Team.RUST)
	var edge := game_match.spawn_tank("Rust_Edge_1", 0, Match.Team.RUST)
	var far := game_match.spawn_tank("Rust_Far_1", 0, Match.Team.RUST)
	var friend := game_match.spawn_tank("Green_Friend_1", 0, Match.Team.GREEN)
	near.global_position = Vector3(-100, 0, 0)
	edge.global_position = Vector3(-94, 0, 0)
	far.global_position = Vector3(-80, 0, 0)
	friend.global_position = Vector3(-104, 0, 0)  # inside the burst, not touching (overlapping hulls get pushed apart)
	await wait_physics_frames(2)
	var weapon := Weapons.profile("mortar")
	game_match._rounds.append({"from": Vector3(-100, 1, 100), "to": Vector3(-100, 0, 0), "land_tick": game_match.tick + 1,
			"team": Match.Team.GREEN, "shooter": "Green_Gun_1", "weapon": weapon})
	await wait_physics_frames(3)
	var full := _toughness(far)
	assert_near(full - _toughness(near), float(weapon["damage"]), 1.5, "a direct hit deals full damage")
	assert_true(full - _toughness(edge) > 0.0 and full - _toughness(edge) < float(weapon["damage"]) * 0.6, "the edge of the burst deals less (%.0f)" % (full - _toughness(edge)))
	assert_eq(_toughness(far), full, "20 m away is untouched")
	assert_eq(_toughness(friend), full, "no friendly fire")


func _situation(contacts: Array, allies: Array = []) -> Dictionary:
	return {
		"tick": 1000,
		"self": {"name": "Green_Gun_1", "team": 0, "position": Vector3.ZERO, "forward": Vector3.FORWARD,
				"health": 200, "max_health": 200, "shield": 80.0, "max_shield": 80.0, "class": "artillery",
				"weapon": Weapons.profile("mortar"), "ammo": 24, "max_ammo": 24},
		"directives": Directives.resolve([]), "contacts": contacts, "allies": allies,
		"objective": null, "objective_radius": 0.0, "squad_center": null, "cover": [],
		"rally": Vector3(0, 0, 90), "enemy_base": Vector3(0, 0, -90), "memory_ticks": Match.CONTACT_MEMORY_TICKS,
	}


func _enemy(position: Vector3, visible := true) -> Dictionary:
	return {"name": "Rust_A_1", "position": position, "velocity": Vector3.ZERO, "forward": Vector3.BACK, "health": 300,
			"shield": 150, "weapon": "cannon", "visible": visible, "age": 0 if visible else 300, "exposed_face": "front",
			"facing_ally": false, "aiming_at_me": false}


func test_artillery_shells_from_afar_and_trails_its_team() -> void:
	var decide := func(s: Dictionary) -> String: return TankBrain.label(TankBrain.decide(s, {})["choice"])
	assert_eq(decide.call(_situation([_enemy(Vector3(0, 0, -120))])), "BOMBARD Rust_A_1", "a spotted enemy 120 m out: shell it")
	assert_eq(decide.call(_situation([_enemy(Vector3(0, 0, -40))])), "BOMBARD Rust_A_1",
			"an enemy close by: still BOMBARD (which backs off to a safe distance), never a brawl")
	var ally := [{"name": "Green_Tank_1", "position": Vector3(0, 0, -30)}]
	assert_eq(decide.call(_situation([], ally)), "SHADOW", "nothing spotted: stay behind the team")
	assert_eq(decide.call(_situation([_enemy(Vector3(0, 0, -80), false)], ally)), "SHADOW", "a stale memory isn't worth walking into")
