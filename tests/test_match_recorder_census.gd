extends TestCase
## S7 (round 16): the census row is built without Movement.state()'s full reading, and must be the row the reading
## gave, in every movement phase -- the recording stays byte-identical.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


## The pre-S7 row, verbatim.
static func _reference_row(tank: Tank) -> Dictionary:
	var order: Dictionary = {}
	var mover: Dictionary = Movement.state(tank)
	return {"n": String(tank.name), "team": tank.team,
			"pos": [snappedf(tank.global_position.x, 0.1), snappedf(tank.global_position.z, 0.1)],
			"hp": snappedf(tank.health, 0.1), "shield": snappedf(tank.shield if "shield" in tank else 0.0, 0.1),
			"order": String(order.get("verb", "")), "src": String(order.get("source", "")),
			"phase": String(mover.get("phase", "")), "blocked": String(mover.get("blocked_by", ""))}


func test_the_census_row_is_the_row_the_reading_gave() -> void:
	add_to_tree(ARENA.instantiate())
	var m: Match = MATCH.instantiate()
	add_to_tree(m)
	m.load_doctrine(Match.Team.GREEN, {"squads": [{"name": "A", "units": [{"unit": "tank"}, {"unit": "scout"}]}]})
	m.load_doctrine(Match.Team.RUST, {"squads": [{"name": "B", "units": [{"unit": "ifv"}]}]})
	var lone := m.spawn_tank("NoMover", 0, Match.Team.GREEN)
	await wait_physics_frames(3)
	var movers := 0
	for tank: Tank in m.sorted_team_tanks(0) + m.sorted_team_tanks(1):
		var mover := Movement.of(tank)
		if mover == null:
			assert_eq(MatchRecorder.census_row(tank, null), _reference_row(tank), "%s without a mover" % tank.name)
			continue
		movers += 1
		var original: String = mover.phase
		var original_by: String = mover.blocked_by
		for phase in ["arrived", "moving", "blocked", "yielding", "unsticking"]:
			mover.phase = phase
			mover.blocked_by = "Someone"
			var row := MatchRecorder.census_row(tank, null)
			assert_eq(row, _reference_row(tank), "%s in phase %s" % [tank.name, phase])
			assert_eq(JSON.stringify(row), JSON.stringify(_reference_row(tank)), "and the same bytes")
		mover.phase = original
		mover.blocked_by = original_by
	assert_true(movers >= 3, "the brain tanks have movers (%d)" % movers)
	assert_true(Movement.of(lone) == null, "setup: a plain spawn has no mover")
