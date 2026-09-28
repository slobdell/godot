extends TestCase
## Round 13 (G1, the garage smoke-tested like a player): what a first visit runs into.


## The starter army leaves 100 of the 800 budget and the cheapest unit costs 110, so a new player's first + ADD is
## refused. The refusal has to say how to get unstuck.
func test_a_first_add_that_does_not_fit_says_how_to_make_room() -> void:
	tree.root.size = Vector2i(1280, 720)
	var screen := GarageScreen.new()
	screen.settings = GarageSettings.new("")
	screen.progression = Progression.new("")
	screen.store_dir = "user://test_garage_first_visit/"
	add_to_tree(screen)
	await wait_physics_frames(2)
	var cheapest := 1 << 30
	for unit_id in screen.draft.catalog.unit_ids():
		if screen.draft.catalog.is_unlocked(unit_id):
			cheapest = mini(cheapest, screen.draft.catalog.unit_cost(unit_id))
	assert_true(screen.draft.remaining_budget() < cheapest, "the premise: the starter leaves %d, the cheapest unit is %d"
			% [screen.draft.remaining_budget(), cheapest])
	var error := screen.add_unit("scout")
	assert_true(error.contains("Not enough budget"), "refused: %s" % error)
	assert_true(error.contains("REMOVE"), "and it says how to make room: %s" % error)
