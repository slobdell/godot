extends TestCase
## HUD widgets (game/ui/widgets/): the mavlink-hud banner lifecycle, frame geometry, conductors,
## and the Hud.post_message → banner wiring. Banners animate on a manual clock (advance), so these
## tests step time exactly instead of waiting on frames.

const HUD_SCENE := preload("res://game/ui/hud.tscn")


func _banner(kind: int) -> CyberBanner:
	tree.root.size = Vector2i(1920, 1080)  # headless root is 64×64 (trip-up #31)
	var banner := CyberBanner.new()
	banner.kind = kind
	banner.clock = func() -> String: return "12:00:00"
	add_to_tree(banner)
	banner.set_process(false)
	return banner


func _step(banner: CyberBanner, seconds: float, dt := 1.0 / 60.0) -> void:
	var elapsed := 0.0
	while elapsed < seconds - 0.00001:
		banner.advance(dt)
		elapsed += dt


func test_status_banner_beams_then_opens_then_types() -> void:
	var banner := _banner(CyberBanner.Kind.STATUS)
	assert_eq(banner.state, CyberBanner.State.HIDDEN, "starts hidden")
	banner.post("Squad Alpha: move", CyberBanner.Severity.INFO)
	assert_eq(banner.state, CyberBanner.State.ENTERING, "a message starts the entrance")
	_step(banner, 0.2)
	assert_near(banner.frame.anim_width, 1.0, 0.01, "after 200 ms the beam spans the full width")
	assert_near(banner.frame.anim_height, CyberBanner.BEAM_HEIGHT, 0.01, "...while still a thin beam")
	_step(banner, 0.15)
	assert_eq(banner.state, CyberBanner.State.SHOWN, "after 350 ms the shutter is open")
	assert_near(banner.frame.anim_height, 1.0, 0.01, "full height once open")
	_step(banner, 0.1)
	assert_true(banner.displayed_text().ends_with(CyberBanner.CURSOR), "typing shows the block cursor")
	assert_true(banner.displayed_text().length() < "12:00:00: Squad Alpha: move".length() + 1, "partway through, only a prefix is typed")
	_step(banner, 0.6)
	assert_true(banner.displayed_text().begins_with("12:00:00: Squad Alpha: move"), "typing finishes within 600 ms with a timestamp")


func test_warning_banner_glitches_and_bounces_for_1_6_seconds() -> void:
	var banner := _banner(CyberBanner.Kind.WARNING)
	banner.post("Commander down", CyberBanner.Severity.ERROR)
	assert_eq(banner.frame.border_color, CyberStyle.ERROR_BORDER, "an error restyles the top banner red")
	_step(banner, 0.9)
	assert_eq(banner.state, CyberBanner.State.ENTERING, "still entering after beam + open (900 ms)")
	var lowest := 1.0
	for i in 24:
		banner.advance(1.0 / 60.0)
		lowest = minf(lowest, banner.frame.anim_alpha)
	assert_true(lowest < 0.4, "the glitch strobes the whole panel (alpha dipped to %.2f)" % lowest)
	_step(banner, 0.12)
	var peak := 0.0
	for i in 6:
		banner.advance(1.0 / 60.0)
		peak = maxf(peak, banner.frame.anim_width)
	assert_true(peak > 1.02, "the snap overshoots the box before settling (width peaked at %.3f)" % peak)
	_step(banner, 0.3)
	assert_eq(banner.state, CyberBanner.State.SHOWN, "open after ~1.6 s")
	assert_near(banner.frame.anim_width, 1.0, 0.001, "settles at exactly full size")


func test_new_message_while_open_snaps_and_pushes_history() -> void:
	var banner := _banner(CyberBanner.Kind.STATUS)
	banner.post("first", CyberBanner.Severity.INFO)
	_step(banner, 1.0)
	banner.post("second", CyberBanner.Severity.INFO)
	assert_eq(banner.state, CyberBanner.State.SHOWN, "no entrance replay while open (spec 6.5)")
	assert_eq(banner.current_text(), "12:00:00: second", "the new message types in the current slot")
	assert_eq(banner.history, "12:00:00: first", "the old one moves to history")
	banner.post("third", CyberBanner.Severity.INFO)
	assert_eq(banner.history.split("\n")[0], "12:00:00: second", "history is newest first")


func test_duplicates_are_dropped_and_history_is_capped() -> void:
	var banner := _banner(CyberBanner.Kind.WARNING)
	banner.post("same", CyberBanner.Severity.WARNING)
	_step(banner, 2.0)
	banner.post("same", CyberBanner.Severity.WARNING)
	assert_eq(banner.history, "", "a consecutive duplicate is ignored")
	for i in 60:
		banner.post("message number %d with some length" % i, CyberBanner.Severity.WARNING)
	assert_true(banner.history.length() <= 500, "warning history is capped at 500 chars")


func test_dismisses_five_seconds_after_the_last_message_and_keeps_history() -> void:
	var banner := _banner(CyberBanner.Kind.STATUS)
	banner.post("one", CyberBanner.Severity.INFO)
	_step(banner, 4.0)
	banner.post("two", CyberBanner.Severity.INFO)
	_step(banner, 4.0)
	assert_eq(banner.state, CyberBanner.State.SHOWN, "each message resets the 5 s clock")
	_step(banner, 1.2)
	assert_eq(banner.state, CyberBanner.State.EXITING, "5 s after the last message it closes")
	_step(banner, 1.0)
	assert_near(banner.frame.anim_height, CyberBanner.BEAM_HEIGHT, 0.01, "shut to a beam before retracting")
	_step(banner, 0.7)
	assert_eq(banner.state, CyberBanner.State.HIDDEN, "retracted after 1.6 s")
	assert_true(banner.history.begins_with("12:00:00: two"), "history survives the banner closing")
	banner.post("two", CyberBanner.Severity.INFO)
	assert_eq(banner.state, CyberBanner.State.ENTERING, "after closing, the same text may be posted again")


func test_hud_post_message_routes_by_severity() -> void:
	tree.root.size = Vector2i(1280, 720)
	var hud: Hud = add_to_tree(HUD_SCENE.instantiate())
	var messages := hud.get_node("CyberMessages") as CyberMessages
	hud.post_message("Squad Bravo lost", Hud.ERROR)
	assert_eq(messages.warning.state, CyberBanner.State.ENTERING, "an error opens the top banner")
	assert_eq(messages.warning.frame.border_color, CyberStyle.ERROR_BORDER, "in the red theme")
	assert_eq(messages.status.state, CyberBanner.State.HIDDEN, "the bottom banner stays closed")
	hud.post_message("Orders sent", Hud.INFO)
	assert_eq(messages.status.state, CyberBanner.State.ENTERING, "info opens the bottom banner")
	hud.post_message("Low ammo", Hud.WARNING)
	assert_eq(messages.warning.frame.border_color, CyberStyle.YELLOW, "a warning restyles the top banner yellow")
	assert_true(messages.warning.position.y < messages.status.position.y, "warnings on top, info at the bottom")


func test_frame_geometry_follows_the_spec_clamps() -> void:
	var rect := Rect2(0, 0, 1152, 97)
	var chamfer := CyberFrame.clamp_chamfer(20.0, rect.size)
	assert_near(chamfer, 20.0, 0.001, "a full banner keeps its 20 px chamfer")
	var arm := CyberFrame.clamp_arm(30.0, chamfer, rect.size)
	assert_near(arm, 97.0 / 2.0 - 20.0, 0.001, "vertical arms clamp to half the height minus the chamfer")
	var beam := CyberFrame.animated_rect(rect, 0.5, 0.05)
	assert_eq(beam.get_center(), rect.get_center(), "the animated box scales about its fixed center")
	assert_near(CyberFrame.clamp_chamfer(20.0, beam.size), beam.size.y / 2.5, 0.001, "a collapsed beam clamps the chamfer to h/2.5")
	assert_eq(CyberFrame.chamfer_polygon(rect, chamfer).size(), 8, "the fill is an octagon")
	var paths := CyberFrame.bracket_paths(rect, chamfer, arm)
	assert_eq(paths.size(), 4, "four separate corner brackets, not an outline")
	assert_true(paths[0][0].x < rect.size.x / 2.0, "the top edge stays open in the middle")


func test_glitch_and_bounce_curves() -> void:
	assert_near(CyberBanner.glitch_alpha(0.25), 0.2, 0.001, "glitch keyframe 1/4 = 0.2")
	assert_near(CyberBanner.glitch_alpha(0.75), 0.5, 0.001, "glitch keyframe 3/4 = 0.5")
	assert_near(CyberBanner.glitch_alpha(1.0), 1.0, 0.001, "the glitch ends fully lit")
	assert_near(CyberStyle.bounce(1.0), 1.0, 0.01, "bounce lands on 1")
	assert_near(CyberStyle.decelerate(0.5), 0.75, 0.001, "decelerate(0.5) = 0.75")


func test_conductor_bus_keeps_45_degree_elbows_and_breathes_in_range() -> void:
	var route := Conductors.bus_route(Vector2(0, 0), Vector2.RIGHT, Vector2(300, 400), Vector2.DOWN, 24.0)
	assert_eq(route.size(), 4, "a bus line is run → diagonal → run")
	var diagonal := route[2] - route[1]
	assert_near(absf(diagonal.x), absf(diagonal.y), 0.01, "the bend is exactly 45 degrees")
	assert_near(route[0].y, route[1].y, 0.01, "the first run is horizontal")
	assert_near(route[2].x, route[3].x, 0.01, "the last run is vertical")
	for t in [0.0, 1000.0, 7777.0, 123456.0]:
		var f := Conductors.fraction(t, 0.00045, 0.5)
		assert_true(f >= 0.0 and f <= 1.0, "breathing fraction stays within 0..1")
	var period_ms := TAU / 0.00045
	assert_true(period_ms > 10000.0 and period_ms < 25000.0, "breathing periods are 10–25 s")


func test_hud_font_has_the_block_cursor_glyph() -> void:
	var font := CyberStyle.font()
	assert_true(font.has_char(CyberBanner.CURSOR.unicode_at(0)), "the HUD font (with fallback) can draw the █ cursor")
	assert_true(font.has_char("A".unicode_at(0)), "and ordinary text")


func test_banners_move_beside_the_tactical_map_and_wrap() -> void:
	tree.root.size = Vector2i(1600, 720)
	var hud: Hud = add_to_tree(HUD_SCENE.instantiate())
	var fake_map := Control.new()
	fake_map.name = "TacticalMap"
	fake_map.set_script(load("res://tests/support/fake_tactical_view.gd"))
	hud.add_child(fake_map)
	await tree.process_frame
	await tree.process_frame
	var messages := hud.get_node("CyberMessages") as CyberMessages
	var arena_left := (1600.0 - 720.0) / 2.0
	assert_true(messages.status.column.has_area(), "with the top-down map up, info moves into a side column")
	assert_true(messages.status.column.end.x <= arena_left, "the info column stays left of the arena")
	assert_true(messages.warning.column.position.x >= 1600.0 - arena_left, "warnings stay right of the arena")
	hud.post_message("Commander ALPHA-1 down: ALPHA-2 takes command of the squad", Hud.ERROR)
	messages.warning.advance(2.0)
	var tall := messages.warning.size.y
	hud.post_message("Short", Hud.WARNING)
	messages.warning.advance(0.1)
	assert_true(tall > messages.warning.size.y, "a long message wraps into a taller banner (%.0f vs %.0f px)" % [tall, messages.warning.size.y])
	fake_map.set("tactical_view", false)
	await tree.process_frame
	assert_true(not messages.status.column.has_area(), "in the 3D view the spec's centered strips return")
	assert_true(messages.status.position.y + messages.status.size.y <= 720.0 - HudSkin.COMMAND_BAR_PX, "above the command bar")
