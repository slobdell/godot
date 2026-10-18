extends TestCase
## C33.5 (round 33, brains): a respawn never lands inside a standing hull. The slot is not kept free while its owner is
## dead, so a squadmate (or an enemy) can be parked on it; `Match.respawn_spot` keeps the slot when its hull box is
## clear and otherwise takes the nearest clear spot (trip-up 82: physics separates an overlap differently by a match's
## place in the process).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.respawn_seconds = 0.1
	return game_match


## Interpenetration of two hull boxes that share the team's facing (every respawn faces the enemy, and the parked hulls
## here are placed facing it too): > 0 on both axes is an overlap.
func _overlap(at_a: Vector3, unit_a: String, at_b: Vector3, unit_b: String) -> Vector2:
	var a := ArmyLayout._hull(unit_a)
	var b := ArmyLayout._hull(unit_b)
	return Vector2((a.x + b.x) * 0.5 - absf(at_a.x - at_b.x), (a.y + b.y) * 0.5 - absf(at_a.z - at_b.z))


func _parked(game_match: Match, tank_name: String, unit: String, team: int, at: Vector3) -> Tank:
	var tank := game_match.spawn_tank(tank_name, 0, team, unit)
	tank.place(at, Match.spawn_yaw(team))
	return tank


func test_a_war_rig_respawning_beside_a_parked_hull_lands_clear_of_it() -> void:
	var game_match := _setup()
	var rig := game_match.spawn_tank("Rust_Rig", 0, Match.Team.RUST, "gang_tank")
	var slot := Match.spawn_position(Match.Team.RUST, rig.slot)
	# A bus parked 1.5 m across and 5 m along from the rig's slot: inside the 14 m rig's box, as a jostling base leaves one.
	var bus := _parked(game_match, "Rust_Bus", Units.DEFAULT, Match.Team.RUST, slot + Vector3(1.5, 0.0, 5.0))
	await wait_physics_frames(2)
	var spot := game_match.respawn_spot(rig, slot)
	var depth := _overlap(spot, rig.unit_id, bus.global_position, bus.unit_id)
	assert_true(not (depth.x > 0.0 and depth.y > 0.0),
			"the rig's respawn %s clears the parked bus at %s (interpenetration %s)" % [spot, bus.global_position, depth])
	assert_true(Vector2(spot.x - slot.x, spot.z - slot.z).length() <= 2.0 * ArmyLayout.SEARCH_STEP_M * ArmyLayout.SEARCH_RINGS,
			"and stays near its slot (%s from %s)" % [spot, slot])
	assert_near(spot.y, slot.y, 0.001, "at the slot's lift")


func test_a_clear_slot_is_kept_exactly() -> void:
	var game_match := _setup()
	var rig := game_match.spawn_tank("Rust_Rig", 0, Match.Team.RUST, "gang_tank")
	var slot := Match.spawn_position(Match.Team.RUST, rig.slot)
	_parked(game_match, "Rust_Bus", Units.DEFAULT, Match.Team.RUST, slot + Vector3(40.0, 0.0, 0.0))
	await wait_physics_frames(2)
	var spot := game_match.respawn_spot(rig, slot + Vector3(0.7, 0.0, 0.1))
	assert_true(spot.is_equal_approx(slot + Vector3(0.7, 0.0, 0.1)), "nothing near: the (jittered) slot itself, %s" % spot)


func test_an_enemy_standing_on_the_slot_counts_and_the_dead_do_not() -> void:
	var game_match := _setup()
	var rig := game_match.spawn_tank("Rust_Rig", 0, Match.Team.RUST, "gang_tank")
	var slot := Match.spawn_position(Match.Team.RUST, rig.slot)
	var enemy := _parked(game_match, "Green_Bus", Units.DEFAULT, Match.Team.GREEN, slot)
	await wait_physics_frames(2)
	var spot := game_match.respawn_spot(rig, slot)
	var depth := _overlap(spot, rig.unit_id, enemy.global_position, enemy.unit_id)
	assert_true(not (depth.x > 0.0 and depth.y > 0.0), "an enemy on the slot is avoided too (%s)" % depth)
	enemy.apply_damage(enemy.health + int(enemy.shield) + 1000)
	assert_true(not enemy.is_alive(), "the enemy is dead")
	assert_true(game_match.respawn_spot(rig, slot).is_equal_approx(slot), "a wreck does not hold the slot")


## The whole path: the rig dies, a squadmate parks on its slot, and the respawn after `respawn_seconds` stands clear.
func test_the_respawn_itself_lands_clear() -> void:
	var game_match := _setup()
	var rig := game_match.spawn_tank("Rust_Rig", 0, Match.Team.RUST, "gang_tank")
	var slot := Match.spawn_position(Match.Team.RUST, rig.slot)
	await wait_physics_frames(2)
	var respawned := [0]
	rig.died.connect(func() -> void:
		_parked(game_match, "Rust_Bus", Units.DEFAULT, Match.Team.RUST, slot + Vector3(-1.5, 0.0, -4.0)))
	rig.apply_damage(rig.health + int(rig.shield) + 1000)
	assert_true(not rig.is_alive(), "the rig is destroyed")
	for frame in SimClock.TICK_RATE * 3:
		await tree.physics_frame
		if rig.is_alive():
			respawned[0] = 1
			break
	assert_eq(respawned[0], 1, "the rig respawns")
	var bus := game_match.tanks.get_node("Rust_Bus") as Tank
	var depth := _overlap(rig.global_position, rig.unit_id, bus.global_position, bus.unit_id)
	assert_true(not (depth.x > 0.0 and depth.y > 0.0),
			"respawned at %s, clear of the bus at %s (interpenetration %s)" % [rig.global_position, bus.global_position, depth])
