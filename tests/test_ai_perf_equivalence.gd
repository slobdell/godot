extends TestCase
## Round-5 X1 (ai): the cheap versions of per-tick AI queries must answer exactly what the originals answered, so a cost
## cut changes no decision. Each test drives a real match and compares the two on every tick.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## Open ground on the west side of the arena.
const LANE_X := -100.0


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(11, 0.0)
	return game_match


func test_counting_incoming_rounds_matches_the_full_incoming_list() -> void:
	var game_match := _setup()
	var shooters: Array[Tank] = []
	var targets: Array[Tank] = []
	# Two fast-firing guns and a cannon on one side; targets spread across and along the lanes, some dead ahead, some
	# near misses, some just outside the danger radius.
	for i in 3:
		var shooter := game_match.spawn_tank("Gun%d" % i, 0, Match.Team.GREEN, "scout" if i < 2 else "tank")
		shooter.global_position = Vector3(LANE_X + i * 6.0, 0.0, 40.0)
		shooters.append(shooter)
	var offsets := [-9.0, -5.0, -2.5, 0.0, 1.5, 4.0, 7.0, 11.0]
	for i in offsets.size():
		var target := game_match.spawn_tank("Target%d" % i, 0, Match.Team.RUST, "tank")
		target.global_position = Vector3(LANE_X + 6.0 + float(offsets[i]), 0.0, -10.0 - 4.0 * i)
		targets.append(target)
	await wait_physics_frames(2)
	var everyone: Array[Tank] = []
	everyone.append_array(shooters)
	everyone.append_array(targets)
	var compared := 0
	var nonzero := 0
	for tick in 240:
		for shooter in shooters:
			# Sweep the aim across the targets so rounds pass at many distances.
			var sweep := targets[(tick / 20 + shooter.get_index()) % targets.size()].global_position
			shooter.command = TankCommand.new(0.0, 0.0, sweep, true)
		for target in targets:
			target.command = TankCommand.new(0.3 if tick % 60 < 30 else -0.3, 0.0, target.global_position + Vector3.FORWARD)
		await tree.physics_frame
		for unit in everyone:
			var full := IncomingFire.for_unit(game_match, unit).size()
			var counted := IncomingFire.count_for(game_match, unit)
			if full != counted:
				assert_eq(counted, full, "tick %d, %s: the quick count agrees with the full list" % [tick, unit.name])
				return
			compared += 1
			nonzero += 1 if full > 0 else 0
	assert_true(nonzero >= 20, "the comparison saw rounds actually inbound (%d of %d samples)" % [nonzero, compared])
