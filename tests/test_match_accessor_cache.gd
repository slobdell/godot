extends TestCase
## S3 (round 16): the accessors the HUD calls every frame return cached values. Each must return exactly what the
## pre-S3 walk returned (copied here as the reference) after a spawn, a death, a tick, a removal mid-tick, a squad
## added, and on a second call in the same tick; and a caller that tries to mutate a cached value fails loudly.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


# ---- The pre-S3 walks, verbatim ----

static func _ref_tanks_by_name(m: Match) -> Dictionary:
	var result := {}
	for tank in m._sorted_tanks():
		result[String(tank.name)] = tank
	return result


static func _ref_team_squads(m: Match, team: int) -> Array[Squad]:
	var result: Array[Squad] = []
	var keys := m.squads.keys()
	keys.sort()
	for key in keys:
		if (m.squads[key] as Squad).team == team:
			result.append(m.squads[key])
	return result


static func _ref_sorted_team_tanks(m: Match, team: int) -> Array[Tank]:
	var result: Array[Tank] = []
	for tank in m._sorted_tanks():
		if tank.team == team:
			result.append(tank)
	return result


static func _ref_team_tanks(m: Match, team: int) -> Array[Tank]:
	var result: Array[Tank] = []
	for node in m.tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.team == team and not tank.is_queued_for_deletion():
			result.append(tank)
	return result


static func _ref_alive_count(m: Match, team: int) -> int:
	var count := 0
	for tank in _ref_team_tanks(m, team):
		if tank.is_alive():
			count += 1
	return count


static func _ref_is_visible_to(m: Match, team: int, tank: Tank) -> bool:
	if tank.team == team:
		return tank.is_alive()
	return tank.is_alive() and bool(m.intel[team].get(String(tank.name), {}).get("visible", false))


## Independent of _sorted_tanks (S3b keeps its sorted list across ticks): the children, filtered and sorted now.
static func _ref_sorted(m: Match) -> Array[Tank]:
	var result: Array[Tank] = []
	for node in m.tanks.get_children():
		if node is Tank and not node.is_queued_for_deletion():
			result.append(node)
	result.sort_custom(func(a: Tank, b: Tank) -> bool: return String(a.name) < String(b.name))
	return result


func _same(m: Match, when: String) -> int:
	var bad := 0
	if m._sorted_tanks() != _ref_sorted(m):
		bad += 1
		assert_true(false, "%s: _sorted_tanks" % when)
	if m.tanks_by_name() != _ref_tanks_by_name(m):
		bad += 1
		assert_true(false, "%s: tanks_by_name" % when)
	for team in 2:
		for pair in [[m.team_squads(team), _ref_team_squads(m, team), "team_squads"],
				[m.sorted_team_tanks(team), _ref_sorted_team_tanks(m, team), "sorted_team_tanks"],
				[m.team_tanks(team), _ref_team_tanks(m, team), "team_tanks"]]:
			if pair[0] != pair[1]:
				bad += 1
				assert_true(false, "%s: %s(%d) %s vs %s" % [when, pair[2], team, pair[0], pair[1]])
		if m.alive_count(team) != _ref_alive_count(m, team):
			bad += 1
			assert_true(false, "%s: alive_count(%d)" % [when, team])
		for tank: Tank in _ref_sorted_team_tanks(m, 0) + _ref_sorted_team_tanks(m, 1):
			if m.is_visible_to(team, tank) != _ref_is_visible_to(m, team, tank):
				bad += 1
				assert_true(false, "%s: is_visible_to(%d, %s)" % [when, team, tank.name])
	return bad


func test_the_cached_accessors_return_what_the_walk_returns() -> void:
	add_to_tree(ARENA.instantiate())
	var m: Match = MATCH.instantiate()
	add_to_tree(m)
	var doctrine := {"squads": [{"name": "Alpha", "units": [{"unit": "tank"}, {"unit": "scout"}]},
			{"name": "Bravo", "units": [{"unit": "ifv"}]}]}
	m.load_doctrine(Match.Team.GREEN, doctrine)
	m.load_doctrine(Match.Team.RUST, doctrine)
	assert_eq(_same(m, "after the armies load (tick %d)" % m.tick), 0, "cached = walked after load")
	assert_eq(_same(m, "second call, same tick"), 0, "and on a second call in the same tick")
	await wait_physics_frames(4)
	assert_eq(_same(m, "four ticks on"), 0, "cached = walked after ticks")
	var late := m.add_player(77)
	assert_eq(_same(m, "a spawn inside the tick"), 0, "a spawn is seen in the same tick")
	m.load_doctrine(Match.Team.RUST, {"squads": [{"name": "Charlie", "units": [{"unit": "tank"}]}]})
	assert_eq(_same(m, "a squad added"), 0, "a squad added is seen at once")
	var victim: Tank = _ref_sorted_team_tanks(m, Match.Team.GREEN)[0]
	victim.apply_damage(100000)
	assert_true(not victim.is_alive(), "setup: the victim is dead")
	assert_eq(_same(m, "a death inside the tick"), 0, "a death is seen in the same tick (alive_count, is_visible_to)")
	await wait_physics_frames(6)
	assert_eq(_same(m, "after intel ran"), 0, "cached = walked once intel has contacts")
	m.remove_player(77)
	assert_true(late.is_queued_for_deletion(), "setup: the player's tank is leaving")
	assert_eq(_same(m, "a removal inside the tick"), 0, "a tank leaving mid-tick is gone from every list at once")
	await wait_physics_frames(2)
	assert_eq(_same(m, "after the removal frees"), 0, "and after it is freed")
	# S3b: one leaves and one joins in the same tick -- the same count, a different set (the sort must be redone).
	m.add_player(88)
	await wait_physics_frames(2)
	assert_eq(_same(m, "before the swap"), 0, "setup")
	m.remove_player(88)
	# The joiner is added straight under `tanks`, with no accessor call between the leave and the next tick: the
	# leaver is freed at the frame's end, so the next tick sees the same child count and the same size, another set.
	m.tanks.add_child(m._build_tank({"name": "Tank_89", "owner": 89, "team": Match.Team.GREEN, "slot": 40,
			"position": Match.spawn_position(Match.Team.GREEN, 40), "yaw": Match.spawn_yaw(Match.Team.GREEN),
			"unit": Units.DEFAULT, "paint": ""}))
	await wait_physics_frames(1)
	assert_eq(_same(m, "a leave and a join in one frame"), 0, "a same-size swap is a new set")
	await wait_physics_frames(2)
	assert_eq(_same(m, "after the swap settles"), 0, "and after the leaver is freed")


func test_a_caller_cannot_mutate_a_cached_value() -> void:
	add_to_tree(ARENA.instantiate())
	var m: Match = MATCH.instantiate()
	add_to_tree(m)
	m.load_doctrine(Match.Team.GREEN, {"squads": [{"name": "Alpha", "units": [{"unit": "tank"}]}]})
	assert_true(m.tanks_by_name().is_read_only(), "tanks_by_name is read-only")
	assert_true(m.team_tanks(0).is_read_only(), "team_tanks is read-only")
	assert_true(m.sorted_team_tanks(0).is_read_only(), "sorted_team_tanks is read-only")
	assert_true(m.team_squads(0).is_read_only(), "team_squads is read-only")


func test_team_frame_is_the_same_answer_and_read_only() -> void:
	for swapped in [false, true]:
		Match.swap_bases = swapped
		for team in 2:
			var south: bool = (team == Match.Team.GREEN) != swapped
			var frame := Match.team_frame(team)
			assert_eq(frame, {"right": Vector3.RIGHT if south else Vector3.LEFT,
					"forward": Vector3.FORWARD if south else Vector3.BACK}, "team %d, swapped %s" % [team, swapped])
			assert_true(frame.is_read_only(), "and shared read-only")
	Match.swap_bases = false
