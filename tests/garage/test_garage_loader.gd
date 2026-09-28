extends TestCase
## Round 14 (G5; round 13's tour: a garage load showed the match loader's "STOP [S]" task card for ~5 s): the loader
## shows the army the garage opens with; a launch that goes straight to a match keeps the task card.


func test_a_garage_load_shows_the_army_it_opens_with() -> void:
	var card := GarageMode.loader_card(LaunchFlags.parse(["--garage", "--garage-scratch"]))
	assert_true(not card.is_empty(), "a garage load has an army card")
	var starter := GarageScreen.starter_army(Progression.new("").catalog_for(ArmyCatalog.from_game(), 0))
	assert_eq(card["name"], "My Army", "a first visit's army")
	assert_true(String(card["line"]).contains("%d / %d" % [starter.total_cost(), starter.catalog.budget]),
			"with what it costs of the budget: %s" % card["line"])
	for unit_id: String in starter.counts_by_unit():
		assert_true(String(card["line"]).contains(starter.catalog.display_name(unit_id)), "names the %s: %s" % [unit_id, card["line"]])


func test_a_launch_straight_into_a_match_keeps_the_task_card() -> void:
	assert_true(GarageMode.loader_card(LaunchFlags.parse(["--garage", "--garage-rematch"])).is_empty(), "REMATCH")
	assert_true(GarageMode.loader_card(LaunchFlags.parse(["--garage", "--challenge=scout_hunt"])).is_empty(), "a challenge")
	assert_true(GarageMode.loader_card(LaunchFlags.parse(["--garage", "--garage-autofight"])).is_empty(), "an immediate FIGHT")
	assert_true(GarageMode.loader_card(LaunchFlags.parse(["--skirmish"])).is_empty(), "a skirmish")
