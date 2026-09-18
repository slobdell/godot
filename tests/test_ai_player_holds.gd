extends TestCase
## Round 5, the lead's playtest: *"they all also just rush forward right away at the start of the game"*. A unit the
## PLAYER commands waits where it spawned until it is ordered; a CPU unit still advances on its own. The mode says whose
## team is the player's (`game_match.set_meta("player_team", team)`), and the brains read it through OrderFeed.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const SECONDS := 12


func _run(player_team: int) -> Dictionary:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	game_match.seed_spawns(3, 0.0)
	if player_team >= 0:
		game_match.set_meta("player_team", player_team)
	var mine := game_match.add_brain_tank(Match.Team.GREEN, "Alpha", "tank", [{}], "Green_A_1")
	var theirs := game_match.add_brain_tank(Match.Team.RUST, "Bravo", "tank", [{}], "Rust_A_1")
	mine.global_position = Vector3(-60, 0, 90)
	theirs.global_position = Vector3(60, 0, -90)
	var started_mine := mine.global_position
	var started_theirs := theirs.global_position
	# Seconds, not frames (lesson 30): `SECONDS * 60` ran 24 s at the 30 Hz tick, twice the intended window, against a
	# drift bar measured over 12 (control, round 6).
	await wait_physics_frames(SECONDS * Engine.physics_ticks_per_second)
	return {"mine": started_mine.distance_to(mine.global_position),
			"theirs": started_theirs.distance_to(theirs.global_position)}


func test_the_players_units_wait_for_orders_and_the_cpu_does_not() -> void:
	var commanded := await _run(Match.Team.GREEN)
	print("MEASURE ai_start_of_match player's unit moved %.1f m in %d s, the CPU's %.1f m" % [
			commanded["mine"], SECONDS, commanded["theirs"]])
	assert_true(float(commanded["mine"]) < 5.0,
			"the player's unit is still where it spawned (%.1f m)" % commanded["mine"])
	assert_true(float(commanded["theirs"]) > 20.0,
			"while the CPU's advances on its own (%.1f m)" % commanded["theirs"])


func test_with_nobody_commanding_both_sides_advance_as_before() -> void:
	var cpu_only := await _run(-1)
	print("MEASURE ai_start_of_match_cpu_only green moved %.1f m, rust %.1f m" % [cpu_only["mine"], cpu_only["theirs"]])
	assert_true(float(cpu_only["mine"]) > 20.0 and float(cpu_only["theirs"]) > 20.0,
			"a CPU-vs-CPU match is unchanged (%.1f m / %.1f m)" % [cpu_only["mine"], cpu_only["theirs"]])
