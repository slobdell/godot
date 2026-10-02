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


## Round 15 (H3; round 14's tour: "I can't read the loader's small print on my phone"): the hint is >= 14 px at 810 tall,
## the card grows with the touch boost and stays on screen, and two hint lines fit inside it.
func test_the_hint_is_readable_on_a_phone_and_the_card_fits() -> void:
	for case: Array in [[Vector2(1920, 1080), 1.0], [Vector2(1800, 810), 1.0], [Vector2(1800, 810), 1.5], [Vector2(1280, 720), 1.5]]:
		var size: Vector2 = case[0]
		var m := LoadingScreen.garage_card_metrics(size, size.y * 0.3, float(case[1]))
		var card: Rect2 = m["card"]
		assert_true(int(m["hint_px"]) >= 14, "%s boost %s: hint %d px" % [size, case[1], m["hint_px"]])
		assert_true(card.position.x >= 0.0 and card.end.x <= size.x, "%s boost %s: card inside the width (%s)" % [size, case[1], card])
		assert_true(card.end.y < size.y * 0.78, "%s boost %s: card above the progress bar (%s)" % [size, case[1], card])
		var s: float = m["scale"]
		assert_true(134.0 * s + int(m["hint_px"]) * 1.35 <= card.size.y, "%s boost %s: two hint lines inside" % [size, case[1]])
	var phone := LoadingScreen.garage_card_metrics(Vector2(1800, 810), 243.0, 1.5)
	assert_true(int(phone["hint_px"]) >= 18, "on a phone the card grows like the HUD: hint %d px" % phone["hint_px"])
