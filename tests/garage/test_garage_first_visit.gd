extends TestCase
## Round 13 (G1, the garage smoke-tested like a player): what a first visit runs into. Round 19 (G3): a first visit
## opens on the faction's suggested army at 1000 credits; every faction's suggestion is ready, legal and spends the
## money (stretch a: exactly, where the prices allow it).


func _open() -> GarageScreen:
	tree.root.size = Vector2i(1280, 720)
	var screen := GarageScreen.new()
	screen.settings = GarageSettings.new("")
	screen.progression = Progression.new("")
	screen.store_dir = "user://test_garage_first_visit/"
	add_to_tree(screen)
	await wait_physics_frames(2)
	return screen


func test_every_factions_suggested_army_is_ready_and_spends_the_money() -> void:
	var spent := {}
	for faction: String in Units.FACTIONS:
		var catalog := ArmyCatalog.for_game(faction)
		var suggested := GarageSuggest.draft(catalog)
		assert_true(suggested.is_ready(), "%s: the suggestion can FIGHT: %s" % [faction, suggested.problems()])
		assert_true(suggested.total_cost() <= Credits.GAME_CREDITS, "%s: inside 2000 credits (%d)" % [faction, suggested.total_cost()])
		assert_true(suggested.squads().size() <= ArmyCatalog.MAX_SQUADS and suggested.unit_count() <= ArmyCatalog.MAX_UNITS,
				"%s: ten squads of five at most" % faction)
		# Round 20 (R3): never a row of one-vehicle squads (the Syndicate's five of one). Round 22 (A2): squads of three to
		# five at 2000 credits (the brief: "the Syndicate's seven tanks is two squads"), about four each.
		assert_eq(suggested.squads().size(), clampi(ceili(suggested.unit_count() / float(GarageSuggest.SQUAD_TARGET)), 1,
				ArmyCatalog.MAX_SQUADS), "%s: %d vehicles in squads of about four (%d squads)" % [faction,
				suggested.unit_count(), suggested.squads().size()])
		for squad: Dictionary in suggested.squads():
			assert_true((squad["units"] as Array).size() >= 3 and (squad["units"] as Array).size() <= 5,
					"%s: a squad of three to five (%s: %d)" % [faction, squad["name"], (squad["units"] as Array).size()])
		var cheapest := 1 << 30
		for unit_id in catalog.unit_ids():
			cheapest = mini(cheapest, catalog.unit_cost(unit_id))
		assert_true(suggested.unit_count() == ArmyCatalog.MAX_UNITS or suggested.remaining_budget() < cheapest,
				"%s: nothing more fits (%d left, %d vehicles)" % [faction, suggested.remaining_budget(), suggested.unit_count()])
		var counts := suggested.counts_by_unit()
		assert_true(counts.size() >= 3, "%s: a mix, not one vehicle (%s)" % [faction, counts])
		for unit_id: String in counts:
			assert_true(int(counts[unit_id]) * 2 <= suggested.unit_count() + 1, "%s: no vehicle is most of the army (%s)" % [
					faction, counts])
		assert_eq(GarageSuggest.draft(catalog).army, suggested.army, "%s: the same suggestion every time" % faction)
		spent[faction] = "%d CR, %d vehicles, %s" % [suggested.total_cost(), suggested.unit_count(), suggested.counts_by_unit()]
	print("MEASURE suggested_armies %s" % spent)


func test_after_clear_the_first_tap_of_the_cheapest_vehicle_buys() -> void:
	var screen := await _open()
	screen.clear()
	var cheapest := ""
	for unit_id in screen.draft.catalog.unit_ids():
		if cheapest == "" or screen.draft.catalog.unit_cost(unit_id) < screen.draft.catalog.unit_cost(cheapest):
			cheapest = unit_id
	assert_eq(screen.buy(cheapest), "", "the first buy (%s) is not refused" % cheapest)
	assert_eq(screen.draft.unit_count(), 1, "and the army has it")


## A refusal says how to get unstuck.
func test_a_buy_that_does_not_fit_says_how_to_make_room() -> void:
	var screen := await _open()
	var error := ""
	for _i in 40:
		error = screen.buy("artillery")
		if error != "":
			break
	assert_true(error.contains("Not enough credits") or error.contains("full"), "eventually refused: %s" % error)
	if error.contains("Not enough credits"):
		assert_true(error.contains("sell"), "and it says how to make room: %s" % error)
