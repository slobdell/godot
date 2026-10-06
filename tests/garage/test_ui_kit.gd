extends TestCase
## Round 19 (garage, G2): the UI kit's elements (`_agents/ui_kit.md`), their states and the rules the doc states.


func test_every_box_is_chamfered_not_rounded() -> void:
	for box: StyleBoxFlat in [CyberKit.box(Color.BLACK, Color.WHITE), CyberKit.panel_box(1.5)]:
		assert_eq(box.corner_detail, 1, "corner_detail 1 makes a 45-degree cut, not a curve")
		assert_true(box.corner_radius_top_left > 0, "the corner is cut")


func test_buttons_are_at_least_one_tap_target_tall() -> void:
	for scale in [1.0, 0.75, 1.5]:
		var button := CyberKit.button("FIGHT", scale, CyberStyle.GREEN)
		assert_true(button.custom_minimum_size.y >= CyberKit.TAP * scale, "a kit button at scale %s is a finger tall" % scale)
		var chip := CyberKit.chip("TANK", scale)
		assert_true(chip.custom_minimum_size.y >= CyberKit.TAP * scale, "a chip at scale %s is a finger tall" % scale)
		button.free()
		chip.free()


func test_every_faction_has_a_colour_and_a_crest_mark() -> void:
	for faction: String in Units.FACTIONS:
		assert_true(CyberKit.FACTION_COLORS.has(faction), "%s has a kit colour" % faction)
		assert_true(CyberKit.FACTION_MARKS.has(faction), "%s has crest letters" % faction)
	assert_eq(CyberKit.faction_color("wardens"), CyberStyle.CYAN, "an unknown faction falls back to cyan, not an error")


func test_the_meter_says_what_is_left_and_when_it_is_over() -> void:
	var meter := CyberMeter.new()
	meter.total = 1000
	meter.unit = "CR"
	meter.shows_left = true
	meter.value = 620
	assert_eq(meter.readout(), "620 CR LEFT", "what is left")
	assert_near(meter.fraction(), 0.62, 0.0001, "the fill is what is left")
	assert_true(not meter.over(), "not over")
	meter.value = -40
	assert_true(meter.over(), "a negative amount left is an overdraft")
	assert_eq(meter.readout(), "OVER BY 40 CR", "and says by how much")
	meter.shows_left = false
	meter.value = 1040
	assert_eq(meter.readout(), "OVER BY 40 CR", "a spent meter past its total is over too")
	meter.value = 300
	assert_eq(meter.readout(), "300 / 1000 CR", "a spent meter reads value / total")
	meter.free()


func test_a_selected_card_lights_up_and_a_disabled_one_refuses() -> void:
	var card := CyberCard.new()
	add_to_tree(card)
	var plain := card.get_theme_stylebox("normal") as StyleBoxFlat
	card.selected = true
	var lit := card.get_theme_stylebox("normal") as StyleBoxFlat
	assert_true(lit.border_width_top > plain.border_width_top, "a selected card's border is heavier")
	assert_true(lit.bg_color.a > 0.0 and lit.bg_color != plain.bg_color, "and its fill takes the accent")
	assert_true(card.custom_minimum_size.y >= CyberKit.TAP, "a card is a finger tall")
	assert_eq(card.content.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the content never steals the card's tap")


func test_the_gallery_knows_every_element_the_doc_names() -> void:
	var doc := FileAccess.get_file_as_string("res://_agents/ui_kit.md")
	var gallery := load("res://game/ui/widgets/kit/ui_kit_gallery.gd") as GDScript
	for element: String in gallery.get_script_constant_map()["ELEMENTS"]:
		assert_true(doc.contains("`%s.png`" % element), "ui_kit.md points at the %s frame" % element)
