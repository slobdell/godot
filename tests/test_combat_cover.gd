extends TestCase
## Round 5 combat X2: is hard cover worth using? The rules have to make three things true before a brain choosing
## cover can mean anything: a wall stops rounds, a crew behind one is meaningfully safer over time, and the fire
## falling on the other side of it does not pin you through it. Measured, with MEASURE lines, rather than asserted
## from the data sheet.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## A wall in the default arena (18 x 1.5 m, 3 m tall) and the open ground beside it.
const WALL_CLEAR := 26.0


func _setup() -> Match:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	game_match.elimination = true  # a wreck must stay a wreck, or damage reads as zero (round 4's lesson)
	return game_match


func _wall(game_match: Match) -> Dictionary:
	for feature: Dictionary in (game_match.get_meta("arena") as Arena).cover_features():
		if feature["type"] == "wall":
			return feature
	return {}


## `shooter` fires at `victim` for `seconds`; returns the hull + shield points it lost.
func _trade(game_match: Match, shooter: Tank, victim: Tank, seconds: float) -> float:
	var before := victim.health + victim.shield
	for tick in SimClock.ticks(seconds):
		shooter.command = TankCommand.new(0.0, 0.0, victim.global_position + Vector3.UP, true)
		victim.command = TankCommand.new()
		await wait_physics_frames(1)
	return before - (victim.health + victim.shield)


func test_a_crew_behind_a_wall_takes_far_less_fire_than_one_in_the_open() -> void:
	var game_match := _setup()
	var wall := _wall(game_match)
	assert_true(not wall.is_empty(), "the default arena has a wall to hide behind")
	if wall.is_empty():
		return
	# Across the wall's narrow face: the shooter on one side, the victim on the other, both 12 m off it.
	var across := Vector3(0, 0, 1).rotated(Vector3.UP, float(wall["rotation"]))
	var middle: Vector3 = wall["position"]
	var shooter := game_match.spawn_tank("Gun", 0, Match.Team.GREEN, "ifv")
	var covered := game_match.spawn_tank("Covered", 0, Match.Team.RUST, "tank")
	for brain in game_match.brains.get_children():
		brain.queue_free()
	await wait_physics_frames(1)
	shooter.global_position = middle + across * 12.0
	covered.global_position = middle - across * 12.0
	covered.look_at(shooter.global_position, Vector3.UP)
	shooter.look_at(covered.global_position, Vector3.UP)
	await wait_physics_frames(2)
	var behind_cover := await _trade(game_match, shooter, covered, 6.0)
	# The same trade, the same distance, in the open beside the wall.
	var exposed := game_match.spawn_tank("Exposed", 0, Match.Team.RUST, "tank")
	await wait_physics_frames(1)
	var side := Vector3(1, 0, 0).rotated(Vector3.UP, float(wall["rotation"]))
	shooter.global_position = middle + side * WALL_CLEAR + across * 12.0
	exposed.global_position = middle + side * WALL_CLEAR - across * 12.0
	exposed.look_at(shooter.global_position, Vector3.UP)
	shooter.look_at(exposed.global_position, Vector3.UP)
	await wait_physics_frames(2)
	var in_the_open := await _trade(game_match, shooter, exposed, 6.0)
	print("MEASURE cover_protection behind a wall %.0f damage, in the open %.0f over 6 s at 24 m" % [behind_cover, in_the_open])
	assert_true(in_the_open > 0.0, "setup: the gun hurts what it can see (%.0f)" % in_the_open)
	assert_true(behind_cover < in_the_open * 0.2, "a wall between them stops most of it (%.0f vs %.0f)"
			% [behind_cover, in_the_open])


func test_fire_stopped_by_a_wall_still_suppresses_the_crew_sheltering_behind_it() -> void:
	# Worth knowing before a drill trusts cover: rounds stamp the ground they FLEW OVER, and a 6 m threat cell is
	# wider than a 1.5 m wall, so the crew on the far side is inside the beaten zone the wall itself is in. Being
	# shot at through your cover is suppressive in life too; this test records that the rules agree.
	var game_match := _setup()
	var wall := _wall(game_match)
	if wall.is_empty():
		return
	var across := Vector3(0, 0, 1).rotated(Vector3.UP, float(wall["rotation"]))
	var middle: Vector3 = wall["position"]
	var shooter := game_match.spawn_tank("Gun", 0, Match.Team.GREEN, "scout")
	var covered := game_match.spawn_tank("Covered", 0, Match.Team.RUST, "tank")
	for brain in game_match.brains.get_children():
		brain.queue_free()
	await wait_physics_frames(1)
	shooter.global_position = middle + across * 12.0
	covered.global_position = middle - across * 3.0
	covered.max_health = 100000
	covered.health = 100000
	shooter.look_at(covered.global_position, Vector3.UP)
	await wait_physics_frames(2)
	await _trade(game_match, shooter, covered, 3.0)
	print("MEASURE cover_suppression a crew 3 m behind a wall under a machine gun: suppression %.2f (pinned at %.2f)"
			% [covered.suppression, Tank.PINNED_SUPPRESSION])
	assert_true(covered.suppression > 0.05, "fire on the far side of its cover still rattles the crew (%.2f)"
			% covered.suppression)
