extends TestCase
## Round 14 (G3; round 13's tour: "Nobody fired and it says DEFEAT"): an elimination match that times out with nothing
## lost on either side is a DRAW, whatever the army sizes; a real win on time (the other side lost units) still wins.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


## Green fields one tank, Rust two: under the old rule the bigger army "won" a time-out nobody fought.
func _match() -> Match:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	game_match.elimination = true
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	game_match.seed_spawns(3, 0.0)
	var one := {"name": "One", "squads": [{"name": "A", "verb": "hold", "units": [{"unit": "tank"}]}]}
	var two := {"name": "Two", "squads": [{"name": "A", "verb": "hold", "units": [{"unit": "tank"}, {"unit": "tank"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, one), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, two), "", "rust loads")
	return game_match


func test_a_five_second_time_out_with_no_contact_is_a_draw() -> void:
	var game_match := _match()
	var results := []
	game_match.finished.connect(func(result: Dictionary) -> void: results.append(result))
	game_match.start_limits(0, 5.0)
	for _i in 40:
		await wait_physics_frames(15)
		if not results.is_empty():
			break
	assert_eq(results.size(), 1, "the match finished on its 5 s limit")
	if results.is_empty():
		return
	var result: Dictionary = results[0]
	assert_eq(result["reason"], "time_limit", "on time")
	assert_eq(result["units_lost"], {"green": 0, "rust": 0}, "the premise: nobody lost anything")
	assert_eq(result["winner"], "draw", "1 tank against 2, no contact: a draw, not a DEFEAT")


## One tank each left at full health: the old standing rule (tanks alive, then health) called this a draw although
## Green destroyed a tank and lost nothing. Judged on what each side destroyed, it is Green's.
func test_a_real_win_on_time_still_wins() -> void:
	var game_match := _match()
	await wait_physics_frames(2)
	var rust := game_match.team_tanks(Match.Team.RUST)
	rust[0].apply_damage(1 << 20)
	await wait_physics_frames(2)
	var result := game_match.result("time_limit")
	assert_eq(result["units_lost"], {"green": 0, "rust": 1}, "the premise: Rust lost a tank, Green nothing")
	assert_eq(result["winner"], Match.TEAM_NAMES[Match.Team.GREEN], "the side that destroyed more wins on time")


func test_equal_losses_on_time_are_a_draw() -> void:
	var game_match := _match()
	game_match.losses_by_unit[Match.Team.GREEN] = {"tank": 1}
	game_match.losses_by_unit[Match.Team.RUST] = {"tank": 1}
	assert_eq(game_match.result("time_limit")["winner"], "draw", "a tank each: nobody is ahead")
	game_match.losses_by_unit[Match.Team.GREEN] = {"scout": 1}
	assert_eq(game_match.result("time_limit")["winner"], Match.TEAM_NAMES[Match.Team.GREEN],
			"a scout against a tank: judged on the points destroyed, not the count")


## The results screen says what a time-out was judged on (round 14's tour: DEFEAT with nothing lost was the CPU holding
## the centre 7 to 0, and the screen said only "Time ran out").
func test_the_results_line_says_how_a_time_out_was_judged() -> void:
	var on_time := {"reason": "time_limit"}
	assert_eq(ResultsScreen.reason_text(on_time, "draw"), "Time ran out — draw", "a draw")
	assert_eq(ResultsScreen.reason_text(on_time, "win"), "Time ran out — you destroyed more", "won on points")
	var held := {"reason": "time_limit", "control": {"green": 0, "rust": 7}}
	assert_eq(ResultsScreen.reason_text(held, "loss"), "Time ran out — they held the centre longer (7 to 0)", "lost on the point")
	assert_eq(ResultsScreen.reason_text({"reason": "elimination"}, "win"), "Last army standing", "other reasons unchanged")
