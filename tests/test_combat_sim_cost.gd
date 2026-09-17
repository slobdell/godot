extends TestCase
## Round 5 (CP1): the simulation's cost cuts must not change what a vehicle does. A parked hull skips its motion step
## and move_and_slide; it must still sit exactly still, drive off the moment it's told to, and block what drives into it. Hulls
## also move in floating mode (flat arenas: no floor queries) and must stay on the ground.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _pair(units: Array) -> Array:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	var entries := []
	for unit: String in units:
		entries.append({"unit": unit})
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "T", "squads": [{"name": "A", "units": entries}]}), "",
			"army loads")
	for brain in game_match.brains.get_children():
		brain.queue_free()
	var tanks := game_match.sorted_team_tanks(Match.Team.GREEN)
	for tank in tanks:
		tank.set_meta("keep", true)
	return [game_match, tanks]


func _drive_all(tanks: Array, throttle: float, ticks: int) -> void:
	for tick in ticks:
		for tank: Tank in tanks:
			tank.command = TankCommand.new(throttle, 0.0, tank.global_position - tank.global_basis.z * 20.0, false)
		await wait_physics_frames(1)


func test_a_parked_hull_stays_exactly_still_and_drives_off_when_told() -> void:
	for unit in ["tank", "gang_scout", "syn_tank"]:  # tracks, wheels, hover
		var setup := _pair([unit])
		var tank: Tank = setup[1][0]
		await wait_physics_frames(1)
		tank.global_position = Vector3(-60.0, 0.0, 10.0)
		await _drive_all([tank], 0.0, 60)
		assert_true(tank.is_parked(tank.command.sanitized()), "%s settles into parked" % unit)
		var parked_at := tank.global_position
		await _drive_all([tank], 0.0, 30)
		assert_eq(tank.global_position, parked_at, "%s does not creep while parked" % unit)
		await _drive_all([tank], 1.0, 45)
		assert_true(tank.global_position.distance_to(parked_at) > 2.0, "%s drives off at once (%.2f m)"
				% [unit, tank.global_position.distance_to(parked_at)])
		# CP1: hulls move in floating mode (no floor queries); they must still sit on the ground, not creep off it.
		assert_near(tank.global_position.y, 0.0, 0.05, "%s stays on the ground while driving" % unit)
		teardown()


func test_a_parked_hull_still_blocks_a_hull_driving_into_it() -> void:
	var setup := _pair(["tank", "tank"])
	var tanks: Array = setup[1]
	var parked: Tank = tanks[0]
	var rammer: Tank = tanks[1]
	await wait_physics_frames(1)
	parked.global_position = Vector3(-60.0, 0.0, 0.0)
	parked.rotation.y = 0.0
	rammer.global_position = Vector3(-60.0, 0.0, 14.0)
	rammer.rotation.y = 0.0  # facing -z, straight at the parked hull
	for tick in 240:
		parked.command = TankCommand.new(0.0, 0.0, parked.global_position + Vector3(0, 0, -20), false)
		rammer.command = TankCommand.new(1.0, 0.0, rammer.global_position + Vector3(0, 0, -20), false)
		await wait_physics_frames(1)
	assert_true(rammer.global_position.z > parked.global_position.z + 3.0,
			"the rammer is stopped by the parked hull, not driven through it (rammer z %.2f, parked z %.2f)"
			% [rammer.global_position.z, parked.global_position.z])

