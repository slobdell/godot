extends TestCase
## Round 39 (feedback F3, his picks 2026-10-24): of the looks filmed for R1-R3 he picked only "slowed: amber", ON by
## default (FeedbackLook slot "slowed"); the fog itself shows R1 (FogViewers), and nothing shows R2 but the tracers.

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


func test_amber_is_on_by_default() -> void:
	FeedbackLook.reset()
	assert_true(FeedbackLook.on("slowed"), "his pick shows without a flag")
	assert_true(FeedbackLook.SLOTS.has("slowed"), "and --feedback-look=slowed:off turns it off")
	assert_true(not FeedbackLook.parse("slowed:off")["slowed"], "parsed")


func test_amber_shows_a_chevron_from_the_first_slow() -> void:
	RuleSwitches.pin_slow_on = true
	var tank := _tank()
	await wait_physics_frames(1)
	var bars := UnitBars.new()
	bars.feedback = FeedbackFx.new()
	add_to_tree(bars)
	tank.suppression = 0.2  # below the pinned look's 0.3: R3 takes 8 % of its speed
	FeedbackLook.use("slowed:off")
	assert_eq(bars.chevrons_for(tank), 0, "before his pick: a crew slowed 8 % showed no chevron")
	FeedbackLook.use("")
	assert_eq(bars.chevrons_for(tank), 1, "amber: one chevron from the first slow")
	tank.suppression = 0.1  # 4 %
	assert_eq(bars.chevrons_for(tank), 0, "but not for a slow too small to notice")
	tank.suppression = 0.2
	FeedbackLook.use("pinned:off")
	assert_eq(bars.chevrons_for(tank), 0, "it draws the pinned chevrons, so it goes when they do")
	FeedbackLook.use("")
	RuleSwitches.pin_slow_on = false
	assert_eq(bars.chevrons_for(tank), 0, "and nothing when R3 is off (nothing slows it)")
	bars.feedback.free()
