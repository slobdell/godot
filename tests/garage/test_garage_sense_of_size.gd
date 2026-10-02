extends TestCase
## Round 15 (H2; round 14's tour: "is the scout as big as the bus?" -- the turntable frames every unit to its panel, so a
## 3 m buggy and a 10 m bus look the same size): the card says how long the unit is, the match's own hull_size.


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


func test_every_catalogue_card_and_the_inspector_say_it() -> void:
	var screen: GarageScreen = await _open()
	var catalog := screen.draft.catalog
	for unit_id in catalog.unit_ids():
		var card := screen.find_child("Card_" + unit_id, true, false)
		assert_true(card != null, "a card for %s" % unit_id)
		var kit := card.find_child("Kit", true, false) as Label if card != null else null
		assert_true(kit != null and kit.text.ends_with(catalog.length_text(unit_id)),
				"%s's card: '%s'" % [unit_id, kit.text if kit != null else "?"])
	screen.select_unit(0, 0)
	await wait_physics_frames(1)
	var length := screen.find_child("UnitLength", true, false) as Label
	var shown := String(screen.draft.unit_at(0, 0).get("unit", ""))
	assert_true(length != null and length.text == catalog.length_text(shown),
			"the inspected %s: '%s'" % [shown, length.text if length != null else "?"])


static func longest_unit(catalog: ArmyCatalog) -> String:
	var longest := ""
	for unit_id in catalog.unit_ids():
		if longest == "" or catalog.length_m(unit_id) > catalog.length_m(longest):
			longest = unit_id
	return longest


static func shortest_unit(catalog: ArmyCatalog) -> String:
	var shortest := ""
	for unit_id in catalog.unit_ids():
		if shortest == "" or catalog.length_m(unit_id) < catalog.length_m(shortest):
			shortest = unit_id
	return shortest


## The measurement H2 decides on: with the longest unit setting the frame, how many pixels long is the shortest unit
## on the garage's own turntable at desktop and phone size (the brief's bar: >= 60 px at 1800 x 810).
func test_measure_the_fixed_scale_at_both_aspects() -> void:
	for screen_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1800, 810)]:
		tree.root.size = screen_size
		var screen := GarageScreen.new()
		screen.settings = GarageSettings.new("")
		screen.progression = Progression.new("")
		screen.store_dir = "user://test_garage_sense_of_size/"
		add_to_tree(screen)
		await wait_physics_frames(3)
		var catalog := screen.draft.catalog
		screen.select_unit(0, 0)
		await wait_physics_frames(3)
		var turntable := screen.find_child("Turntable", true, false) as GarageTurntable
		var lengths := {}
		for unit_id: String in [shortest_unit(catalog), longest_unit(catalog)]:
			turntable.show_unit({"unit": unit_id}, Color.CYAN)
			turntable.scale_unit = longest_unit(catalog)
			lengths[unit_id] = turntable.drawn_length_px()
		print("H2_MEASURE screen=%s turntable=%s fixed: %s %.0f px, %s %.0f px" % [screen_size, turntable.size,
				shortest_unit(catalog), lengths[shortest_unit(catalog)], longest_unit(catalog), lengths[longest_unit(catalog)]])
		var ratio := float(lengths[shortest_unit(catalog)]) / float(lengths[longest_unit(catalog)])
		var truth := catalog.length_m(shortest_unit(catalog)) / catalog.length_m(longest_unit(catalog))
		assert_true(absf(ratio - truth) <= 0.1 * truth, "%s: drawn ratio %.3f, catalogue %.3f" % [screen_size, ratio, truth])
		screen.queue_free()
		await wait_physics_frames(1)
