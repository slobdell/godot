extends TestCase
## Control X6: readability at the close zoom X1 brought in. X4 collapsed the panel's portraits to one per type,
## so "which of mine is nearly dead" has to live in the world now: a hull bar over vehicles that are hurt or
## selected, sized from the hull's own width on screen, and over nothing else.

const Fixture := preload("res://tests/support/control_fixture.gd")


func _frames(count := 2) -> void:
	for i in count:
		await tree.process_frame


func _bar(bars: Array, unit_name: String) -> Dictionary:
	for bar: Dictionary in bars:
		if String(bar["unit"]) == unit_name:
			return bar
	return {}


func test_only_hurt_or_selected_vehicles_carry_a_bar() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.selection.clear()
	await _frames(2)
	assert_eq(f.controls.health_bars(), [], "a healthy force nobody has selected draws nothing")
	f.tank("Green_Alpha_2").health = f.tank("Green_Alpha_2").max_health / 2
	await _frames(2)
	var bars := f.controls.health_bars()
	assert_eq(bars.size(), 1, "one hurt vehicle, one bar")
	assert_eq(bars[0]["unit"], "Green_Alpha_2", "over the one that is hurt")
	assert_near(float(bars[0]["health"]), 0.5, 0.02, "showing how much is left")
	f.controls.selection.set_units(["Green_Alpha_1"])
	await _frames(2)
	var names := f.controls.health_bars().map(func(b: Dictionary) -> String: return String(b["unit"]))
	assert_true(names.has("Green_Alpha_1"), "a selected vehicle carries one even at full health")
	assert_true(names.has("Green_Alpha_2"), "and the hurt one still does")
	assert_eq(names.size(), 2, "and nobody else does")


func test_enemies_never_carry_our_bars() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.tank("Rust_Alpha_1").health = 1
	f.controls.selection.inspect("Rust_Alpha_1")
	await _frames(2)
	for bar: Dictionary in f.controls.health_bars():
		assert_true(not String(bar["unit"]).begins_with("Rust"), "%s is theirs, not ours" % bar["unit"])


func test_a_bar_shrinks_with_the_vehicle_it_belongs_to() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.selection.set_units(["Green_Alpha_3"])
	f.rig.zoom = 0.15
	f.rig.focus = Vector3(0, 0, 40)
	f.rig.snap()
	await _frames(2)
	var close := float(_bar(f.controls.health_bars(), "Green_Alpha_3")["width"])
	f.rig.zoom = 0.85
	f.rig.snap()
	await _frames(2)
	var far := float(_bar(f.controls.health_bars(), "Green_Alpha_3")["width"])
	print("MEASURE control_bar_width close=%.1f far=%.1f px" % [close, far])
	assert_true(close > far, "a bar is wider up close than from high up (%.1f vs %.1f)" % [close, far])
	assert_true(far >= RtsControls.BAR_MIN_PX - 0.01, "and never disappears (%.1f)" % far)
	assert_true(close <= RtsControls.BAR_MAX_PX + 0.01, "nor swallows the model up close (%.1f)" % close)


func test_a_bar_sits_above_the_hull_not_across_it() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.selection.set_units(["Green_Alpha_1"])
	await _frames(2)
	var bar := _bar(f.controls.health_bars(), "Green_Alpha_1")
	var hull_top := f.camera.unproject_position(f.tank("Green_Alpha_1").global_position + Vector3.UP * 1.6)
	assert_true((bar["at"] as Vector2).y < hull_top.y, "the bar is drawn above the vehicle (%s vs %s)" % [bar["at"], hull_top])


func test_a_full_army_of_wrecks_still_draws_one_bar_each() -> void:
	var f := Fixture.new(self)
	await f.build_scale(30)
	for tank in f.game_match.sorted_team_tanks(Match.Team.GREEN):
		tank.health = maxi(1, tank.max_health / 3)
	await _frames(2)
	var bars := f.controls.health_bars()
	var on_screen := 0
	for tank in f.game_match.sorted_team_tanks(Match.Team.GREEN):
		if tank.is_alive() and not f.camera.is_position_behind(tank.global_position) \
				and f.controls.get_viewport_rect().has_point(f.camera.unproject_position(tank.global_position)):
			on_screen += 1
	assert_true(bars.size() <= on_screen, "no bar for a vehicle that isn't on screen (%d bars, %d visible)" % [bars.size(), on_screen])
	assert_true(bars.size() > 10, "but the ones you can see all have one (%d)" % bars.size())
	# Against the reference workload (Fixture.fastest_ms), not the wall clock: builder0 is shared.
	var timed := Fixture.fastest_ms(func() -> void: f.controls.health_bars(), 30)
	var ratio := timed[0] / timed[1]
	print("MEASURE control_bars_ms=%.3f reference_ms=%.3f ratio=%.2f bars=%d" % [timed[0], timed[1], ratio, bars.size()])
	# The old 0.6 ms in reference workloads (0.077 ms idle, laptop): 7.8. Measured 1.73-1.84.
	Fixture.judge_timing(self, ratio < 7.8, "working them out costs %.2f reference workloads a frame (%.3f ms)" % [ratio, timed[0]])


## X4 (CP1): HUD unit icons are drawn once into textures and shown as batched rects.
func test_unit_icons_are_cached_textures_with_a_tintable_body_and_dark_ink() -> void:
	for role in ["tank", "ifv", "scout", "artillery", "lancer", "burner"]:
		var texture := CommandIcons.unit_texture(role)
		assert_true(texture != null and texture.get_width() == CommandIcons.UNIT_TEXTURE_PX, "%s has a texture" % role)
		assert_true(is_same(texture, CommandIcons.unit_texture(role)), "%s's texture is built once" % role)
		var image := texture.get_image()
		assert_eq(image.get_pixel(0, 0).a, 0.0, "%s: the corner is transparent" % role)
	var tank := CommandIcons.unit_texture("tank").get_image()
	var half := CommandIcons.UNIT_TEXTURE_PX / 2
	var body := tank.get_pixel(half - 11, half + 14)
	assert_true(body.a > 0.9 and body.r > 0.9, "the tank's hull is white, so a tint colours it (%s)" % body)
	var gun := tank.get_pixel(half, half - 20)
	assert_true(gun.a > 0.5, "its gun reaches up the icon (%s)" % gun)
