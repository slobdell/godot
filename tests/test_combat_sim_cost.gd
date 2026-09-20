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
	# (A `keep` meta was set on each tank here and nothing in the repo ever read it -- removed rather than left as
	# a thing the next reader has to go and check. `teardown()` frees the match, which owns them.)
	return [game_match, game_match.sorted_team_tanks(Match.Team.GREEN)]


func _drive_all(tanks: Array, throttle: float, ticks: int) -> void:
	for tick in ticks:
		for tank: Tank in tanks:
			tank.command = TankCommand.new(throttle, 0.0, tank.global_position - tank.global_basis.z * 20.0, false)
		await wait_physics_frames(1)


func test_a_parked_hull_stays_exactly_still_and_drives_off_when_told() -> void:
	for unit in ["tank", "gang_scout", "syn_tank"]:  # tracks, wheels, hover
		# ⚠ A BASELINE, NOT AN ABSOLUTE, and this is the correction to the first version of these assertions. They
		# asserted `bodies == 0` at the boundary, which passed here and FAILED on builder0 with `expected 0, got 1`
		# -- because `_count_bodies` walks the WHOLE tree, so a body some EARLIER test in the shard left behind is
		# counted against this one. That is precisely the charge-the-observer defect these assertions exist to stop,
		# reproduced inside the fix for it. What this test can honestly assert is that IT added nothing.
		var bodies_before := int(_world_left_behind()["bodies"])
		var regions_before := NavigationServer3D.map_get_regions(tree.root.world_3d.navigation_map).size()
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
		# ⚠ `await`, AND THE REASON IS WORTH THE THREE LINES, because this read as a physics leak for two rounds.
		# `teardown()` ends in `await drain_navigation()`. Called WITHOUT `await` -- which is how this loop was
		# written -- it frees the nodes, clears `_owned_nodes`, and then DETACHES a coroutine that sits in a
		# 120-frame wait while this loop builds the NEXT unit's arena. That stale drain then counts the regions of
		# an arena that is alive and in use, gives up, and appends "left 2 navigation region(s) on the map" against
		# THIS test. Two detached drains plus the runner's own is why the failure arrived twice.
		#
		# There was never a holder. `free()` released everything at every boundary; the guard was reporting the
		# test's own next fixture. Measured after the `await`, all three units: arena invalid, match invalid,
		# **regions 0, bodies 0** -- asserted below rather than printed, so a real holder would fail here in future
		# instead of landing on whatever test runs next.
		var game_match: Match = setup[0]
		var arena: Node = game_match.get_meta("arena")
		await teardown()
		assert_true(not is_instance_valid(arena) and not is_instance_valid(game_match),
				"%s: the fixture is gone at the boundary" % unit)
		var regions_after := NavigationServer3D.map_get_regions(tree.root.world_3d.navigation_map).size()
		var bodies_after := int(_world_left_behind()["bodies"])
		print("MEASURE sim_cost_boundary %-10s bodies %d -> %d, navigation regions %d -> %d" % [
				unit, bodies_before, bodies_after, regions_before, regions_after])
		assert_true(regions_after <= regions_before,
				"%s: it added no navigation regions (%d -> %d), so the next unit bakes on the map it found"
				% [unit, regions_before, regions_after])
		assert_true(bodies_after <= bodies_before,
				"%s: and no physics bodies (%d -> %d)" % [unit, bodies_before, bodies_after])


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

