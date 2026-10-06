extends TestCase
## Round 20 (garage, R2; contract C20.4): every vehicle he can buy has its picture, for its card and its squad chip,
## rendered from the real mesh by `make unit-thumbs` and committed. A unit added to `Units.PROFILES` without one fails
## here, in words, before it reaches the garage as a blank card.


func test_every_unit_has_a_card_and_a_chip_picture() -> void:
	for unit_id: String in Units.ids():
		var card := UnitThumbs.card(unit_id)
		var chip := UnitThumbs.chip(unit_id)
		assert_true(card != null, "%s has a card picture at %s (make remote T=unit-thumbs, then make unit-thumbs-adopt)" % [
				unit_id, UnitThumbs.card_path(unit_id)])
		assert_true(chip != null, "%s has a chip picture at %s" % [unit_id, UnitThumbs.chip_path(unit_id)])
		if card == null or chip == null:
			continue
		assert_eq(card.get_size(), Vector2(320, 200), "%s's card picture is 320 x 200" % unit_id)
		assert_eq(chip.get_size(), Vector2(128, 80), "%s's chip picture is 128 x 80" % unit_id)


func test_a_picture_is_the_vehicle_on_nothing() -> void:
	# Transparent around the vehicle (the card behind is the backdrop), and the vehicle fills the frame (cropped to it).
	for unit_id: String in Units.ids():
		var card := UnitThumbs.card(unit_id)
		if card == null:
			continue
		var image := card.get_image()
		if image.is_compressed():
			image.decompress()
		assert_true(image.detect_alpha() != Image.ALPHA_NONE, "%s's picture has a transparent background" % unit_id)
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(319, 0), Vector2i(0, 199), Vector2i(319, 199)]:
			assert_true(image.get_pixelv(corner).a < 0.05, "%s: the corner %s is empty" % [unit_id, corner])
		var used := image.get_used_rect()
		assert_true(used.size.x >= 240 or used.size.y >= 150, "%s fills its frame (drawn %s of 320 x 200)" % [unit_id,
				used.size])


func test_crop_to_vehicle_centres_the_drawn_pixels_at_the_aspect() -> void:
	var image := Image.create_empty(400, 400, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(300, 100, 80, 40), Color.WHITE)  # a long thing near the right edge
	var cropped := UnitThumbs.crop_to_vehicle(image, 1.6, 0.1)
	assert_near(float(cropped.get_width()) / float(cropped.get_height()), 1.6, 0.02, "the crop is at the card's aspect")
	var used := cropped.get_used_rect()
	assert_eq(used.size, Vector2i(80, 40), "the whole drawn thing is kept")
	assert_near(used.get_center().x, cropped.get_width() / 2.0, 1.0, "centred across")
	assert_near(used.get_center().y, cropped.get_height() / 2.0, 1.0, "and down, even where the crop leaves the render")
	var empty := Image.create_empty(10, 10, false, Image.FORMAT_RGBA8)
	empty.fill(Color(0, 0, 0, 0))
	assert_eq(UnitThumbs.crop_to_vehicle(empty, 1.6, 0.1).get_size(), Vector2i(10, 10), "nothing drawn: left as it was")
