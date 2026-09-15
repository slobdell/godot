extends TestCase
## Round-3 stretch: the CPU difficulty knob (Difficulty). Levels, and a deterministic aim wander.


func test_levels_exist_and_normal_changes_nothing() -> void:
	for level: String in ["easy", "normal", "hard"]:
		assert_true(Difficulty.LEVELS.has(level), "%s exists" % level)
	assert_eq(Difficulty.LEVELS["normal"]["think_ticks"], 0, "normal keeps the brain's own think interval")
	assert_eq(Difficulty.aim_offset(0.0, 123, 4), Vector3.ZERO, "no wander, no offset")
	assert_true(int(Difficulty.LEVELS["easy"]["think_ticks"]) > TankBrain.THINK_EVERY_TICKS, "easy reacts slower")
	assert_true(int(Difficulty.LEVELS["hard"]["think_ticks"]) < TankBrain.THINK_EVERY_TICKS, "hard reacts faster")


func test_the_aim_wander_is_deterministic_bounded_and_moves() -> void:
	var seen := {}
	for tick in range(0, 400, 20):
		var offset := Difficulty.aim_offset(2.0, tick, 3)
		assert_eq(offset, Difficulty.aim_offset(2.0, tick, 3), "same inputs, same offset")
		assert_true(absf(offset.x) <= 2.0 and absf(offset.z) <= 2.0 and offset.y == 0.0, "within the wander, flat (%s)" % offset)
		seen[offset] = true
	assert_true(seen.size() >= 4, "it wanders around (%d distinct offsets)" % seen.size())


func test_use_sets_a_team_and_reset_restores_the_default() -> void:
	Difficulty.use(Match.Team.RUST, "easy")
	assert_eq(Difficulty.name_for_team(Match.Team.RUST), "easy", "rust is easy")
	assert_eq(Difficulty.name_for_team(Match.Team.GREEN), Difficulty.DEFAULT, "green unchanged")
	Difficulty.reset()
	assert_eq(Difficulty.name_for_team(Match.Team.RUST), Difficulty.DEFAULT, "reset")
