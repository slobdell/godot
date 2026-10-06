extends TestCase
## Round 19 (brains, stretch (c)): orders' first suspicion for his "a bunch of vehicles just basically ran off to the
## middle of the map" was the brain's idle fallback that drives a unit with nowhere to be at the objective or the enemy
## base (TankBrain's SPOT and ADVANCE: `s["objective"] if s["objective"] != null else s["enemy_base"]`). Pinned here:
## his units can never reach it. Two locks, each tested: (1) no order verb but "idle" leaves the brain SPOT or ADVANCE;
## (2) a unit on his side always has a post (its spawn until his first order, then where his last order left it), and an
## idle unit's objective IS that post, so even SPOT and ADVANCE drive it home, never to the zone.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const SECONDS := 12
## The options whose goal falls back to the objective or the enemy's base when the unit has no objective of its own.
const ROAMING := ["SPOT", "ADVANCE"]


func test_no_order_but_idle_leaves_the_brain_an_option_that_roams_to_the_objective() -> void:
	for verb: String in TankBrain.ORDER_OPTIONS:
		if verb == "idle":
			continue
		for option: String in ROAMING:
			assert_true(not (TankBrain.ORDER_OPTIONS[verb] as Array).has(option),
					"an ordered unit (%s) cannot pick %s, which drives to the objective" % [verb, option])


func _run(unit_id: String) -> Dictionary:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	game_match.control_point = true
	add_to_tree(game_match)
	game_match.seed_spawns(3, 0.0)
	game_match.set_meta("player_team", Match.Team.GREEN)
	game_match.objectives = [{"name": "middle", "position": Vector3.ZERO, "radius": 16.0, "owner": -1, "progress": 0.0}]
	var mine := game_match.add_brain_tank(Match.Team.GREEN, "Alpha", unit_id, [{}], "Green_A_1")
	mine.global_position = Vector3(-60, 0, 90)
	var started := mine.global_position
	await wait_physics_frames(SECONDS * Engine.physics_ticks_per_second)
	return {"moved": started.distance_to(mine.global_position),
			"to_middle": Vector2(mine.global_position.x, mine.global_position.z).length()}


func _assert_stays(unit_id: String) -> void:
	var ran := await _run(unit_id)
	print("MEASURE ai_idle_fallback %s moved %.1f m in %d s (%.1f m from the zone)" % [unit_id, ran["moved"], SECONDS,
			ran["to_middle"]])
	assert_true(float(ran["moved"]) < 5.0, "his %s stays at its post with an objective on the map (%s)" % [unit_id, ran])


## The scout is the unit whose own choice is SPOT; the tank's is ADVANCE. Neither leaves its post with the zone open.
func test_his_idle_scout_never_drives_to_the_objective() -> void:
	await _assert_stays("scout")


func test_his_idle_tank_never_drives_to_the_objective() -> void:
	await _assert_stays("tank")
