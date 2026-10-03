extends TestCase
## Round 16 (play P3, the lead: *"when I run make skirmish can we make the opponent actually randomized so I can get
## more varied gameplay?"*). The faction menu opens with the enemy on RANDOM; FIGHT rolls it from the launch seed, so a
## replay of the seed is the same match, and a tap (or ENEMY_FACTION) still pins it.


func _picker_for(raw: PackedStringArray) -> FactionPicker:
	return SkirmishMode.faction_picker_for(LaunchFlags.parse(raw))


func test_the_menu_opens_with_the_enemy_on_random() -> void:
	var picker := _picker_for(["--skirmish", "--seed=92721"])
	assert_eq(picker.enemy_faction, FactionPicker.RANDOM, "the enemy row starts on RANDOM")
	assert_eq(picker.player_faction, Units.DEFAULT_FACTION, "his own pick is his: unchanged")
	picker.free()


func test_ten_seeds_give_more_than_one_enemy_and_one_seed_twice_gives_the_same() -> void:
	var seen := {}
	for seed_value in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		var rolled := FactionPicker.roll_enemy(seed_value, "law")
		assert_true(Units.FACTIONS.has(rolled), "seed %d rolls a real faction (%s)" % [seed_value, rolled])
		assert_true(rolled != "law", "the roll is one of the other three: more variety than a mirror")
		seen[rolled] = true
		assert_eq(FactionPicker.roll_enemy(seed_value, "law"), rolled, "seed %d twice is the same enemy" % seed_value)
	assert_true(seen.size() > 1, "ten launches meet more than one enemy faction: %s" % [seen.keys()])


func test_fight_on_random_sends_the_rolled_faction_into_the_restart() -> void:
	var picker := _picker_for(["--skirmish", "--seed=92721"])
	picker.player_faction = "law"
	var got: Array = []
	picker.chosen.connect(func(mine: String, theirs: String) -> void: got.append([mine, theirs]))
	picker.confirm()
	assert_eq(got, [["law", FactionPicker.roll_enemy(92721, "law")]], "FIGHT resolves RANDOM before the restart")
	var next := SkirmishMode.faction_flags(LaunchFlags.parse(["--skirmish", "--seed=92721"]), got[0][0], got[0][1])
	assert_true(Units.FACTIONS.has(next.text("enemy-faction")), "the restart carries a real faction, never 'random'")
	assert_eq(next.text("seed"), "92721", "and the same seed: the replay is the same match")
	picker.free()


func test_a_pinned_enemy_stays_pinned() -> void:
	var picker := _picker_for(["--skirmish", "--seed=5", "--pick-faction", "--enemy-faction=gangs"])
	assert_eq(picker.enemy_faction, "gangs", "ENEMY_FACTION=gangs (make skirmish) opens the menu pinned")
	var got: Array = []
	picker.chosen.connect(func(_mine: String, theirs: String) -> void: got.append(theirs))
	picker.confirm()
	assert_eq(got, ["gangs"], "and fights gangs")
	picker.free()


func test_a_tap_pins_it_and_random_can_be_picked_again() -> void:
	var picker := _picker_for(["--skirmish", "--seed=5"])
	picker.set_side("syndicate", true)
	assert_eq(picker.enemy_faction, "syndicate", "right-clicking a faction pins the enemy")
	picker.set_side(FactionPicker.RANDOM, true)
	assert_eq(picker.enemy_faction, FactionPicker.RANDOM, "right-clicking RANDOM puts it back")
	picker.set_side(FactionPicker.RANDOM, false)
	assert_eq(picker.player_faction, Units.DEFAULT_FACTION, "RANDOM is the enemy's only: his side is his pick")
	picker.free()


func test_the_menu_still_opens_when_only_the_enemy_is_pinned_by_make() -> void:
	assert_true(SkirmishMode.wants_faction_menu(LaunchFlags.parse(["--skirmish", "--pick-faction", "--enemy-faction=law"])),
			"--pick-faction keeps the menu up with the enemy pinned")
