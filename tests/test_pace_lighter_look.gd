extends TestCase
## Round 26 (perf P5, stretch): the LIGHTER look he can switch on. It is opt-in: no machine's default changes (the adapter
## never picks it, a headless run is desktop), the LOOK toggle cycles full -> light -> lighter -> full, and it keeps his
## round-16 taps (laptop's five levers ON, the stands lit) and only adds the four round-26 levers.


func teardown() -> void:
	RenderLevers.set_for_test([])
	super.teardown()


func test_lighter_is_laptop_plus_four_levers() -> void:
	var lighter: Array = RenderLevers.PRESETS["lighter"]
	for lever: String in RenderLevers.PRESETS["laptop"]:
		assert_true(lighter.has(lever), "lighter keeps laptop's %s" % lever)
	for lever in ["scale_065", "no_glow", "fx_lean", "crowd_low"]:
		assert_true(lighter.has(lever), "lighter adds %s" % lever)
		assert_true(RenderLevers.NAMES.has(lever), "%s is a named lever (--render-levers reaches it)" % lever)
	assert_true(not lighter.has("unlit_stands"), "the stands stay lit (he tapped unlit_stands OFF)")
	assert_eq(lighter.size(), RenderLevers.PRESETS["laptop"].size() + 4, "nothing else")


func test_no_machine_is_given_lighter_by_default() -> void:
	var types := [RenderingDevice.DEVICE_TYPE_OTHER, RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU,
			RenderingDevice.DEVICE_TYPE_DISCRETE_GPU]
	for type: int in types:
		for name in ["Mesa Intel(R) UHD Graphics 620 (WHL GT2)", "NVIDIA GeForce RTX 3070", "", "Unknown Adapter"]:
			assert_true(RenderLevers.preset_for_adapter(type, name) != "lighter", "%s / %d is not lighter" % [name, type])


func test_the_look_toggle_cycles_three_states() -> void:
	RenderLevers.apply_preset("desktop", "test")
	assert_eq(RenderLevers.label(), "LOOK FULL", "full")
	assert_eq(RenderLevers.next_preset(), "laptop", "full -> light")
	RenderLevers.apply_preset("laptop", "test")
	assert_eq(RenderLevers.label(), "LOOK LIGHT", "light")
	assert_eq(RenderLevers.next_preset(), "lighter", "light -> lighter")
	RenderLevers.apply_preset("lighter", "test")
	assert_eq(RenderLevers.label(), "LOOK LIGHTER", "lighter")
	assert_eq(RenderLevers.next_preset(), "desktop", "lighter -> full")
	RenderLevers.set_for_test(["no_glow"])
	assert_eq(RenderLevers.next_preset(), "desktop", "a custom lever list goes back to full")


func test_each_lever_changes_only_its_budget() -> void:
	RenderLevers.set_for_test(["scale_065"])
	assert_near(float(RenderLevers.adjust("render_scale", 1.0)), 0.65, 0.001, "scale_065: 65 % of the lines")
	assert_eq(RenderLevers.adjust("glow", true), true, "scale_065 leaves glow")
	RenderLevers.set_for_test(["no_glow"])
	assert_eq(RenderLevers.adjust("glow", true), false, "no_glow: no glow")
	assert_eq(RenderLevers.adjust("render_scale", 1.0), 1.0, "no_glow leaves the scale")
	RenderLevers.set_for_test(["fx_lean"])
	assert_eq(RenderLevers.adjust("effects", 128), 96, "fx_lean: effects capped")
	assert_eq(RenderLevers.adjust("effects", 64), 64, "a cap, never a raise")
	assert_eq(RenderLevers.adjust("decals", 12), 8, "fx_lean: scorch marks capped")
	assert_eq(RenderLevers.adjust("sprays", 4), 3, "fx_lean: sprays capped")
	assert_near(float(RenderLevers.adjust("overdraw", 3000.0)), 2000.0, 0.001, "fx_lean: overdraw capped")
	assert_eq(RenderLevers.adjust("splats", true), false, "fx_lean: no ground splats")
	assert_eq(RenderLevers.adjust("lights", 4), 4, "fx_lean leaves the lights to lights_2")
	RenderLevers.set_for_test([])
	for key in ["effects", "decals", "sprays"]:
		assert_eq(RenderLevers.adjust(key, 128), 128, "no lever: %s untouched" % key)
	assert_eq(RenderLevers.adjust("glow", true), true, "no lever: glow untouched")
	assert_eq(RenderLevers.adjust("splats", true), true, "no lever: splats untouched")


func test_lighter_through_the_quality_path() -> void:
	RenderLevers.apply_preset("lighter", "test")
	assert_near(float(RenderLevers.adjust("render_scale", 1.0)), 0.65, 0.001, "lighter renders 65 % of the lines")
	assert_eq(RenderLevers.adjust("lights", 4), 2, "two lights (laptop's lights_2)")
	assert_eq(RenderLevers.adjust("haze", true), false, "no haze (laptop's)")
	assert_eq(RenderLevers.adjust("glow", true), false, "no glow")
