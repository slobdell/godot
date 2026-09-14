extends TestCase
## Stretch (anti-snowball): the center control point.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	game_match.control_point = true
	add_to_tree(game_match)
	return game_match


func test_one_tank_captures_the_center_and_scores() -> void:
	var game_match := _setup()
	var green := game_match.spawn_tank("Green_1", 0, Match.Team.GREEN)
	green.global_position = Vector3(5, 0, 5)
	await wait_physics_frames(roundi(Match.CONTROL_CAPTURE_SECONDS * 60.0) - 30)
	assert_eq(game_match.control_owner, -1, "not captured before %.0f s" % Match.CONTROL_CAPTURE_SECONDS)
	await wait_physics_frames(60)
	assert_eq(game_match.control_owner, Match.Team.GREEN, "captured after %.0f s" % Match.CONTROL_CAPTURE_SECONDS)
	await wait_physics_frames(60 * 3)
	assert_true(game_match.control_score[Match.Team.GREEN] >= 2, "the holder scores a point a second (%d)" % game_match.control_score[0])


func test_a_bigger_army_does_not_capture_faster_and_contesting_freezes_it() -> void:
	var game_match := _setup()
	for i in 4:
		var tank := game_match.spawn_tank("Green_%d" % i, 0, Match.Team.GREEN)
		tank.global_position = Vector3(-8 + i * 5, 0, 6)
	await wait_physics_frames(roundi(Match.CONTROL_CAPTURE_SECONDS * 60.0) / 2)
	assert_true(game_match.control_owner == -1, "four tanks still take the full capture time (flat rate: anti-snowball)")
	var rust := game_match.spawn_tank("Rust_1", 0, Match.Team.RUST)
	rust.global_position = Vector3(0, 0, -8)
	await wait_physics_frames(Match.INTEL_EVERY_TICKS)
	var frozen := game_match.control_progress
	await wait_physics_frames(60 * 4)
	assert_near(game_match.control_progress, frozen, 0.001, "with both teams inside, capture stops")


func test_holding_to_the_limit_wins_the_match() -> void:
	var game_match := _setup()
	var results: Array = []
	game_match.finished.connect(func(result: Dictionary) -> void: results.append(result))
	game_match.spawn_tank("Rust_1", 0, Match.Team.RUST).global_position = Vector3(0, 0, 0)
	game_match.spawn_tank("Green_1", 0, Match.Team.GREEN)
	game_match.control_owner = Match.Team.RUST
	game_match.control_progress = -1.0
	game_match._control_ticks = [0, (Match.CONTROL_POINTS_TO_WIN - 1) * 60]
	await wait_physics_frames(90)
	assert_eq(results.size(), 1, "the match ends")
	assert_eq(results[0]["winner"], "Rust", "the holder wins")
	assert_eq(results[0]["reason"], "control", "by control")


func test_brains_go_take_a_center_they_dont_hold() -> void:
	var s := {
		"tick": 1000, "self": {"name": "Green_A_1", "team": 0, "position": Vector3(0, 0, 60), "forward": Vector3.FORWARD,
				"health": 300, "max_health": 300, "shield": 150.0, "max_shield": 150.0, "weapon": Weapons.profile("cannon")},
		"directives": Directives.resolve([]), "contacts": [], "allies": [], "objective": null, "objective_radius": 0.0,
		"squad_center": null, "cover": [], "rally": Vector3(0, 0, 90), "enemy_base": Vector3(0, 0, -90),
		"memory_ticks": Match.CONTACT_MEMORY_TICKS,
		"control": {"center": Vector3.ZERO, "radius": Match.CONTROL_RADIUS, "owner": -1},
	}
	assert_eq(TankBrain.label(TankBrain.decide(s, {})["choice"]), "CONTEST", "a neutral center is worth taking")
	s["control"]["owner"] = 0
	assert_eq(TankBrain.label(TankBrain.decide(s, {})["choice"]), "CONTEST", "ours but I'm outside: come hold it")
	s["control"] = null
	assert_eq(TankBrain.label(TankBrain.decide(s, {})["choice"]), "ADVANCE", "without a control point, nothing changes")
