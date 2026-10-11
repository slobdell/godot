extends TestCase
## O5 (`make showmatch`, the lead: *"pit 2 computer players against each other so I can easily record the game to share
## with people"*): a CPU-vs-CPU match whose factions roll from the seed (never a mirror) unless pinned, an end banner
## that names the winner rather than reading from a side nobody plays, and a clean feed with no HUD chrome.


func _flags(raw: Array) -> LaunchFlags:
	return LaunchFlags.parse(PackedStringArray(raw))


func test_a_showmatch_is_two_computer_players_filmed_by_the_cinematic_camera() -> void:
	var flags := SkirmishMode.demo_flags(_flags(["--skirmish", "--demo-match", "--seed=41"]))
	assert_eq(flags.text("player"), "cpu", "the first side is the computer")
	assert_eq(flags.text("enemy"), "cpu", "and so is the second")
	assert_true(flags.has("cinematic"), "filmed by the self-directing camera")
	assert_true(flags.has("no-pick-faction") and not SkirmishMode.wants_faction_menu(flags), "no faction menu in a recording")
	assert_eq(SkirmishMode.commanded_team(flags), -1, "nobody commands either side, so both play themselves")


func test_the_factions_roll_from_the_seed_and_are_never_a_mirror() -> void:
	var seen := {}
	for seed_value in 200:
		var flags := SkirmishMode.demo_flags(_flags(["--demo-match", "--seed=%d" % seed_value]))
		var player := flags.text("player-faction")
		var enemy := flags.text("enemy-faction")
		assert_true(Units.FACTIONS.has(player) and Units.FACTIONS.has(enemy), "real factions (%s, %s)" % [player, enemy])
		assert_true(player != enemy, "seed %d is not a mirror (%s)" % [seed_value, player])
		seen[player] = true
		var again := SkirmishMode.demo_flags(_flags(["--demo-match", "--seed=%d" % seed_value]))
		assert_eq([again.text("player-faction"), again.text("enemy-faction")], [player, enemy], "the seed replays it")
	assert_eq(seen.size(), Units.FACTIONS.size(), "every faction gets the first side across 200 seeds (%s)" % [seen.keys()])


func test_pinned_factions_and_seed_are_kept() -> void:
	var flags := SkirmishMode.demo_flags(_flags(["--demo-match", "--seed=7", "--player-faction=law", "--enemy-faction=gangs"]))
	assert_eq(flags.text("player-faction"), "law", "FACTION= pins the first side")
	assert_eq(flags.text("enemy-faction"), "gangs", "ENEMY_FACTION= pins the second")
	assert_eq(flags.integer("seed", -1), 7, "SEED= is the match's seed")
	var one_pinned := SkirmishMode.demo_flags(_flags(["--demo-match", "--seed=7", "--player-faction=law"]))
	assert_true(one_pinned.text("enemy-faction") not in ["", "law"], "the open side rolls, never his mirror (%s)" % one_pinned.text("enemy-faction"))


func test_a_showmatch_without_a_seed_still_has_one_to_print() -> void:
	var flags := SkirmishMode.demo_flags(_flags(["--demo-match"]))
	assert_true(flags.text("seed").is_valid_int(), "a seed is chosen so DEMO_SEED can name it (%s)" % flags.text("seed"))


func test_the_end_banner_names_the_winner_when_nobody_plays_a_side() -> void:
	var factions := {Match.Team.GREEN: "gangs", Match.Team.RUST: "law"}
	assert_eq(SkirmishMode.end_banner("Green", true, factions), "WINNER: ROAD GANGS", "a spectator is told who won")
	assert_eq(SkirmishMode.end_banner("Rust", true, factions), "WINNER: THE LAW", "either side")
	assert_eq(SkirmishMode.end_banner("draw", true, factions), "DRAW", "a time-out nobody won")
	assert_eq(SkirmishMode.end_banner("Green", false, factions), "VICTORY", "a player still reads it from his side")
	assert_eq(SkirmishMode.end_banner("Rust", false, factions), "DEFEAT", "both ways")
	assert_eq(SkirmishMode.end_banner("Rust", true, {}), "WINNER: RUST", "a side with no faction is named by its team")


func _layer() -> CanvasLayer:
	var layer := CanvasLayer.new()
	for node_name in ["Status", "Scoreboard", "Banner", "CyberMessages", "TacticalMap", "UnitBars", "ScoreBug"]:
		var node := Control.new()
		node.name = node_name
		layer.add_child(node)
	var skin := Control.new()
	skin.name = "HudSkin"
	for part_name in ["StatusFrame", "BannerFrame", "FxButton"]:
		var part := Control.new()
		part.name = part_name
		skin.add_child(part)
	layer.add_child(skin)
	layer.add_child(Node.new())  # a plain node (the HUD's bug mount) is left alone
	add_to_tree(layer)
	return layer


func test_the_clean_feed_hides_every_piece_of_hud_but_the_banner() -> void:
	var layer := _layer()
	var banner := layer.get_node("Banner") as Control
	banner.visible = false
	CleanFeed.apply(layer, false)
	for node_name in ["Status", "Scoreboard", "CyberMessages", "TacticalMap", "UnitBars", "ScoreBug", "HudSkin/StatusFrame", "HudSkin/FxButton"]:
		assert_true(not (layer.get_node(node_name) as Control).visible, "%s is off the feed" % node_name)
	assert_true((layer.get_node("HudSkin") as Control).visible, "the skin stays, for the banner's frame")
	assert_true(not banner.visible, "the banner keeps its own visibility (hidden until the match ends)")
	banner.visible = true
	CleanFeed.apply(layer, false)
	assert_true(banner.visible, "and shows when the match ends")


func test_hud_1_keeps_the_score_bug() -> void:
	var layer := _layer()
	CleanFeed.apply(layer, true)
	assert_true((layer.get_node("ScoreBug") as Control).visible, "HUD=1: the score bug stays")
	assert_true(not (layer.get_node("TacticalMap") as Control).visible, "but the command chrome does not")


func test_the_clean_feed_leaves_the_real_banner_frame_alone() -> void:
	var layer := CanvasLayer.new()
	var skin := HudSkin.new()
	skin.name = "HudSkin"
	skin.persist_frame_target = false  # tests never write the player's profile (trip-up 54)
	layer.add_child(skin)
	add_to_tree(layer)  # _ready parents the frames and buttons (and its _exit_tree restores the window theme)
	skin.banner_frame.visible = true
	CleanFeed.apply(layer, false)
	assert_true(skin.banner_frame.visible, "the end banner's frame stays up")
	assert_true(not skin.status_frame.visible and not skin.fx_button.visible, "the status frame and buttons go")
