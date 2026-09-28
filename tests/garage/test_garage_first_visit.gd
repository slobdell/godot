extends TestCase
## Round 13 (G1, the garage smoke-tested like a player): what a first visit runs into.
## Round 14 (G1, room to build): the starter army leaves room for the cheapest unit, so a first + ADD works.


func _open() -> GarageScreen:
	tree.root.size = Vector2i(1280, 720)
	var screen := GarageScreen.new()
	screen.settings = GarageSettings.new("")
	screen.progression = Progression.new("")
	screen.store_dir = "user://test_garage_first_visit/"
	add_to_tree(screen)
	await wait_physics_frames(2)
	return screen


func _cheapest(catalog: ArmyCatalog) -> int:
	var cheapest := 1 << 30
	for unit_id in catalog.unit_ids():
		if catalog.is_unlocked(unit_id):
			cheapest = mini(cheapest, catalog.unit_cost(unit_id))
	return cheapest


func _cheapest_id(catalog: ArmyCatalog) -> String:
	for unit_id in catalog.unit_ids():
		if catalog.is_unlocked(unit_id) and catalog.unit_cost(unit_id) == _cheapest(catalog):
			return unit_id
	return ""


## The round-14 rule: a new player's first + ADD of the cheapest unit lands, at every budget tier.
func test_the_starter_army_leaves_room_for_the_cheapest_unit_at_every_tier() -> void:
	var base := ArmyCatalog.from_game()
	var progression := Progression.new("")
	for tier in Progression.BUDGET_TIERS.size():
		progression.budget_tier = tier
		var catalog := progression.catalog_for(base, tier)
		var starter := GarageScreen.starter_army(catalog)
		assert_true(starter.is_ready(), "tier %d: the starter can FIGHT: %s" % [tier, starter.problems()])
		assert_true(starter.remaining_budget() >= _cheapest(catalog), "tier %d: %d left of %d, the cheapest unit is %d"
				% [tier, starter.remaining_budget(), catalog.budget, _cheapest(catalog)])
		assert_eq(starter.catalog.budget, catalog.budget, "tier %d: the army is priced against the tier's full budget" % tier)


func test_a_first_add_of_the_cheapest_unit_works() -> void:
	var screen := await _open()
	var unit_id := _cheapest_id(screen.draft.catalog)
	var before := screen.draft.unit_count()
	var error := screen.add_unit(unit_id)
	assert_eq(error, "", "the first + ADD (%s) is not refused" % unit_id)
	assert_eq(screen.draft.unit_count(), before + 1, "and the army has one more unit")


## Past the room the starter leaves, a refusal still says how to get unstuck.
func test_an_add_that_does_not_fit_says_how_to_make_room() -> void:
	var screen := await _open()
	var unit_id := _cheapest_id(screen.draft.catalog)
	var error := ""
	for _i in 20:
		error = screen.add_unit(unit_id)
		if error != "":
			break
	assert_true(error.contains("Not enough budget") or error.contains("full"), "eventually refused: %s" % error)
	if error.contains("Not enough budget"):
		assert_true(error.contains("REMOVE"), "and it says how to make room: %s" % error)
