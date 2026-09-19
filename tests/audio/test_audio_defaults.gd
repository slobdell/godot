extends TestCase
## Feel (round 6): the lead found "the audio is defaulted to off". Only two make targets passed the flags; every other
## way into the game (the title's SKIRMISH, the garage's FIGHT, a bare launch) got no announcer and no music.


func test_a_game_with_a_window_sounds_unless_told_not_to() -> void:
	var bare := LaunchFlags.parse(PackedStringArray(["--skirmish"]))
	assert_eq(AudioDefaults.value(bare, "music", false), "on", "music on by default in a real game")
	assert_eq(AudioDefaults.value(bare, "announcer", false), "voice", "the booth speaks by default")
	var told := LaunchFlags.parse(PackedStringArray(["--skirmish", "--music=off", "--announcer=text"]))
	assert_eq(AudioDefaults.value(told, "music", false), "off", "an explicit flag wins")
	assert_eq(AudioDefaults.value(told, "announcer", false), "text", "for either system")
	var muted := LaunchFlags.parse(PackedStringArray(["--skirmish", "--mute"]))
	assert_eq(AudioDefaults.value(muted, "music", false), "off", "--mute still means silence")


func test_headless_runs_stay_silent_by_default() -> void:
	var bare := LaunchFlags.parse(PackedStringArray(["--match"]))
	assert_eq(AudioDefaults.value(bare, "music", true), "off", "tests, servers and the match runner stay quiet")
	assert_eq(AudioDefaults.value(bare, "announcer", true), "off", "and attach no booth of their own")


func test_the_title_backdrop_is_not_announced() -> void:
	var title := LaunchFlags.parse(PackedStringArray(["--title"]))
	assert_eq(AudioDefaults.value(title, "announcer", false), "off", "no booth calling the fight behind the menu")
	assert_eq(AudioDefaults.value(title, "music", false), "off", "and no match music under it")
