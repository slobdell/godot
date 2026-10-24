extends TestCase
## Round 39 (feedback F1, C39.5): candidate looks for R1-R3 are built for his directions page, and nothing new shows
## until he picks one (FeedbackLook.RULE_LOOKS, `--rules-look=`).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func teardown() -> void:
	FeedbackLook.reset()
	RuleSwitches.pin_slow_on = RuleSwitches._on("pin_slow")
	super.teardown()


func _tank() -> Tank:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match.spawn_tank("Crew", 0, Match.Team.RUST, "gang_ifv")


func test_nothing_new_shows_until_he_picks() -> void:
	FeedbackLook.reset()
	for slot: String in FeedbackLook.RULE_LOOKS:
		assert_eq(FeedbackLook.rule(slot), "none", "%s draws nothing by default" % slot)
		assert_eq(FeedbackLook.RULE_LOOKS[slot][0], "none", "%s offers none first" % slot)
	var material := ShaderMaterial.new()
	FogViewers.apply(material, null)
	assert_eq(float(material.get_shader_parameter("settled_glow")), 0.0, "the fog's settled glow is off by default")


func test_a_pick_is_parsed() -> void:
	var picked := FeedbackLook.parse_rules("sight:edge,slowed:brake")
	assert_eq(picked["sight"], "edge", "a named look")
	assert_eq(picked["fire"], "none", "a slot it does not name draws nothing")
	assert_eq(picked["slowed"], "brake", "another")
	FeedbackLook.use_rules("sight:edge")
	var material := ShaderMaterial.new()
	FogViewers.apply(material, null)
	assert_eq(float(material.get_shader_parameter("settled_glow")), FogViewers.SETTLED_GLOW, "edge turns the glow on")


func test_amber_shows_a_chevron_from_the_first_slow() -> void:
	RuleSwitches.pin_slow_on = true
	var tank := _tank()
	await wait_physics_frames(1)
	var bars := UnitBars.new()
	bars.feedback = FeedbackFx.new()
	add_to_tree(bars)
	tank.suppression = 0.2  # below the pinned look's 0.3: R3 takes 8 % of its speed
	assert_eq(bars.chevrons_for(tank), 0, "today: a crew slowed 8 % shows no chevron")
	FeedbackLook.use_rules("slowed:amber")
	assert_eq(bars.chevrons_for(tank), 1, "amber: one chevron from the first slow")
	tank.suppression = 0.1  # 4 %
	assert_eq(bars.chevrons_for(tank), 0, "but not for a slow too small to notice")
	RuleSwitches.pin_slow_on = false
	tank.suppression = 0.2
	assert_eq(bars.chevrons_for(tank), 0, "and nothing when R3 is off (nothing slows it)")
	bars.feedback.free()
