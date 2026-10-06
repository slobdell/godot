extends TestCase
## Round 15 (H2; round 14's tour: "is the scout as big as the bus?"): the card says how long the unit is, the match's own
## hull_size. Round 19 (G3): the turntable is gone with the inspector; the length stays on every vehicle card.


func _open() -> GarageScreen:
	tree.root.size = Vector2i(1280, 720)
	var screen := GarageScreen.new()
	screen.settings = GarageSettings.new("")
	screen.progression = Progression.new("")
	screen.store_dir = "user://test_garage_sense_of_size/"
	add_to_tree(screen)
	await wait_physics_frames(2)
	return screen


func test_the_length_is_the_hull_size_to_one_decimal() -> void:
	var catalog := ArmyCatalog.from_game()
	for unit_id in catalog.unit_ids():
		var box: Array = Units.stat(unit_id, "hull_size")
		assert_eq(catalog.length_text(unit_id), "%.1f m long" % float(box[2]), unit_id)


func test_every_vehicle_card_says_it() -> void:
	var screen: GarageScreen = await _open()
	var catalog := screen.draft.catalog
	for unit_id in catalog.unit_ids():
		var card := screen.find_child("Card_" + unit_id, true, false)
		assert_true(card != null, "a card for %s" % unit_id)
		var detail := card.find_child("Detail", true, false) as Label if card != null else null
		assert_true(detail != null and detail.text.contains(catalog.length_text(unit_id)),
				"%s's card: '%s'" % [unit_id, detail.text if detail != null else "?"])
