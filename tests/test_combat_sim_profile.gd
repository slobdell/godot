extends TestCase
## Round 5 (CP1): SimProfile splits a physics tick by process-priority band and by the simulation's own sections.
## The numbers are wall-clock and machine-dependent, so these tests check the bookkeeping, not the timings.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func test_a_profiled_match_reports_the_tick_its_bands_and_its_sections() -> void:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	game_match.seed_spawns(5, 0.0)
	var army := {"name": "T", "squads": [{"name": "A", "units": [{"unit": "tank"}, {"unit": "scout"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, army), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, army), "", "rust loads")
	SimProfile.install(game_match)
	await wait_physics_frames(30)
	var report := SimProfile.report()
	SimProfile.uninstall()
	assert_true(int(report["ticks"]) >= 25, "counted the ticks (%s)" % report["ticks"])
	assert_true(float(report["tick_ms"]) > 0.0, "a tick costs something")
	var sections: Dictionary = report["sections"]
	for name in ["match", "tank", "tank/drive", "segment:controllers", "segment:elements"]:
		assert_true(sections.has(name), "reports %s (got %s)" % [name, sections.keys()])
	assert_near(float(sections["tank"]["calls_per_tick"]), 4.0, 0.2, "one tank section per vehicle per tick")
	assert_near(float(sections["match"]["calls_per_tick"]), 1.0, 0.1, "one match section per tick")
	var attributed := 0.0
	for name: String in sections:
		if not name.contains("/"):
			attributed += float(sections[name]["ms_per_tick"])
	assert_near(attributed + float(report["unattributed_ms"]), float(report["tick_ms"]), 0.01,
			"top-level sections plus the remainder add up to the tick")


func test_profiling_is_off_unless_installed() -> void:
	assert_true(not SimProfile.enabled, "no test or mode leaves the profiler on")
