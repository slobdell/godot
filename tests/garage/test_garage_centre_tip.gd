extends TestCase
## Round 15 (H1; round 14's tour: "I didn't do anything and lost" on the control point, 7–0, every tour): the first
## fight from the garage says the centre scores, once per fresh profile, dismissable, and the card goes by itself after
## a few seconds of play (the planning pause does not count).

const PATH := "user://test_garage_centre_tip.cfg"


func test_the_tip_is_taken_once_per_profile_and_remembered() -> void:
	DirAccess.remove_absolute(PATH)
	var settings := GarageSettings.new(PATH)
	assert_true(settings.take_centre_tip(), "a fresh profile: shown")
	assert_true(not settings.take_centre_tip(), "the second fight: not again")
	assert_true(not GarageSettings.new(PATH).take_centre_tip(), "nor after a restart (REMATCH reloads the game)")
	DirAccess.remove_absolute(PATH)


func test_hiding_the_tips_in_the_garage_hides_this_one_too() -> void:
	var settings := GarageSettings.new("")
	settings.skip_tips()
	assert_true(not settings.take_centre_tip(), "X on the tip bar means no tips")


func test_the_card_says_the_line_on_one_line_below_the_planning_banner_at_both_aspects() -> void:
	for screen: Vector2i in [Vector2i(1920, 1080), Vector2i(1800, 810)]:
		root_size(screen)
		var tip := CentreTip.new()
		add_to_tree(tip)
		await tip.get_tree().process_frame
		await tip.get_tree().process_frame
		var label := tip.find_child("Line", true, false) as Label
		assert_eq(label.text, CentreTip.LINE, "the words")
		assert_true(label.get_line_count() == 1, "%s: one line" % screen)
		assert_true(tip.position.y >= screen.y * 0.16, "%s: under the planning banner (top %d)" % [screen, tip.position.y])
		assert_true(tip.position.x >= 0.0 and tip.position.x + tip.size.x <= screen.x, "%s: on screen" % screen)
		var px := label.get_theme_font_size("font_size")
		assert_true(px >= 20, "%s: readable (%d px)" % [screen, px])
		tip.queue_free()
	root_size(Vector2i(64, 64))


func test_the_card_waits_out_the_planning_pause_then_goes_after_some_play() -> void:
	var tip := CentreTip.new()
	add_to_tree(tip)
	tip.set_process(false)
	tip.advance(60.0, true)
	assert_true(not tip.is_queued_for_deletion(), "a long planning pause: still up")
	tip.advance(CentreTip.SHOW_SECONDS - 1.0, false)
	assert_true(not tip.is_queued_for_deletion(), "most of the play window: still up")
	tip.advance(1.5, false)
	assert_true(tip.is_queued_for_deletion(), "then it goes")


func test_a_tap_dismisses_it() -> void:
	var tip := CentreTip.new()
	add_to_tree(tip)
	tip.set_process(false)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tip._gui_input(tap)
	assert_true(tip.is_queued_for_deletion(), "tapped away")


func root_size(screen: Vector2i) -> void:
	(Engine.get_main_loop() as SceneTree).root.size = screen
