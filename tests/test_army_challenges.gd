extends TestCase
## Army stretch: challenge missions (fixed armies vs scripted opponents, each teaching one counter).


func test_every_challenge_loads_into_a_real_match() -> void:
	var catalog := ArmyCatalog.from_game()
	for challenge_id in Challenges.ids():
		assert_true(Challenges.playable(challenge_id, catalog), "%s can be played with today's roster" % challenge_id)
		var info := Challenges.info(challenge_id)
		for key in ["title", "counter", "brief", "lesson"]:
			assert_true(String(info.get(key, "")) != "", "%s has a %s" % [challenge_id, key])
		var player := Challenges.army(challenge_id, "player", catalog)
		var enemy := Challenges.army(challenge_id, "enemy", catalog)
		for squad: Dictionary in player["squads"]:
			assert_eq(squad.get("verb"), "hold", "%s: your squads wait for orders" % challenge_id)
		for squad: Dictionary in enemy["squads"]:
			assert_true(not squad.has("formation") and not squad.has("verb"), "%s: the opponent moves (a formation would hold it at base)" % challenge_id)
		var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
		for side in [[Match.Team.GREEN, player], [Match.Team.RUST, enemy]]:
			var parsed := Doctrine.parse(ArmyFormat.to_game_doctrine(side[1]))
			assert_true(parsed.has("doctrine"), "%s's %s army parses: %s" % [challenge_id, side[1]["name"], parsed.get("error", "")])
			if parsed.has("doctrine"):
				assert_eq(game_match.load_doctrine(side[0], parsed["doctrine"]), "", "%s: the match fields it" % challenge_id)
		await wait_physics_frames(1)
		game_match.queue_free()


func test_a_challenge_reward_pays_once_and_only_for_a_win() -> void:
	var profile := Progression.new("")
	var lost := ArmyLoop.challenge_pay({"winner": "Rust"}, "scout_hunt", profile)
	assert_eq([lost["outcome"], lost["credits"]], ["loss", 0], "a loss pays nothing")
	assert_true(not profile.completed_challenges.has("scout_hunt"), "and doesn't clear it")
	var won := ArmyLoop.challenge_pay({"winner": "Green"}, "scout_hunt", profile)
	assert_eq(won["credits"], Challenges.REWARD, "the first win pays the reward")
	assert_eq(profile.credits, Challenges.REWARD, "into the profile")
	var again := ArmyLoop.challenge_pay({"winner": "Green"}, "scout_hunt", profile)
	assert_eq(again["credits"], 0, "a replay pays nothing")
	assert_true(String(again["lines"][0][0]).contains("pay once"), "and says why")
	assert_eq(Progression.migrate(profile.to_dict())["completed_challenges"], ["scout_hunt"], "cleared challenges are saved")


func test_the_challenges_panel_starts_a_challenge() -> void:
	tree.root.size = Vector2i(1280, 720)
	var screen := GarageScreen.new()
	screen.settings = GarageSettings.new("")
	screen.progression = Progression.new("")
	screen.store_dir = "user://test_army_challenges/"
	add_to_tree(screen)
	await wait_physics_frames(3)
	var requested: Array = []
	screen.challenge_requested.connect(func(id: String) -> void: requested.append(id))
	screen.toggle_challenges(true)
	var play := screen.find_child("Challenge_turret_lag", true, false).find_child("Play", true, false) as Button
	assert_true(play.text.contains(str(Challenges.REWARD)), "an uncleared challenge shows its reward")
	play.pressed.emit()
	assert_eq(requested, ["turret_lag"], "PLAY asks to start that challenge")
	assert_true(not (screen.find_child("ChallengePanel", true, false) as Control).visible, "and closes the panel")
