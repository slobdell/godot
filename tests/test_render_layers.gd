extends TestCase
## Render (round 16, R2): the switch table RenderSplit measures with. A layer must put back exactly what it took, or a
## measurement run leaves the picture changed for every later phase (and the cost of the next layer is read against a
## wrong `all`).


func test_every_layer_name_is_handled() -> void:
	# On an empty tree every layer finds nothing and says nothing: an unknown name is the only warning.
	for layer: String in RenderLayers.NAMES:
		var undo := RenderLayers.apply(tree, layer)
		assert_true(undo is Array, "%s returns its undo list" % layer)
		RenderLayers.restore(undo)


func test_glow_and_shadows_are_put_back() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.glow_enabled = true
	world.environment.fog_enabled = true
	add_to_tree(world)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_to_tree(sun)
	var undo := RenderLayers.apply(tree, "no_glow")
	assert_true(not world.environment.glow_enabled, "no_glow switches glow off")
	RenderLayers.restore(undo)
	assert_true(world.environment.glow_enabled, "and back on")
	undo = RenderLayers.apply(tree, "no_shadows")
	assert_true(not sun.shadow_enabled, "no_shadows switches the sun's shadow off")
	RenderLayers.restore(undo)
	assert_true(sun.shadow_enabled, "and back on")
	undo = RenderLayers.apply(tree, "no_env_fog")
	assert_true(not world.environment.fog_enabled, "no_env_fog switches fog off")
	RenderLayers.restore(undo)
	assert_true(world.environment.fog_enabled, "and back on")


func test_a_hidden_thing_comes_back_in_its_own_state() -> void:
	# Something already hidden stays hidden after the restore: the undo records the old value, not "visible".
	var sky := NightSky.new()
	var skyline := NightSky.new()
	skyline.visible = false
	add_to_tree(sky)
	add_to_tree(skyline)
	var undo := RenderLayers.apply(tree, "no_sky")
	assert_true(not sky.visible, "the sky is hidden")
	RenderLayers.restore(undo)
	assert_true(sky.visible, "the sky is back")
	assert_true(not skyline.visible, "the one that was hidden before is still hidden")


func test_the_sky_draws_after_the_arena() -> void:
	# Round 16 (R3): the dome writes no depth, so drawn first it shaded the whole screen for nothing.
	var sky := NightSky.new()
	assert_eq((sky.material_override as Material).render_priority, Material.RENDER_PRIORITY_MAX, "the dome draws last")
	var undo := RenderLayers.apply(tree, "sky_r15")
	RenderLayers.restore(undo)
	sky.free()


func test_every_lever_is_off_unless_named() -> void:
	# Round 16 (R8, contract C16.1): a lever changes the picture, so nothing but the lead's tap turns one on.
	RenderLevers.set_for_test([])
	for lever: String in RenderLevers.NAMES:
		assert_true(not RenderLevers.on(lever), "%s is off by default" % lever)
	assert_eq(RenderLevers.adjust("lights", 4), 4, "four pooled lights untouched")
	assert_eq(RenderLevers.adjust("render_scale", 1.0), 1.0, "full resolution untouched")
	RenderLevers.set_for_test(["lights_2", "scale_085"])
	assert_eq(RenderLevers.adjust("lights", 4), 2, "lights_2 halves the pool")
	assert_near(float(RenderLevers.adjust("render_scale", 1.0)), 0.85, 0.001, "scale_085 renders 85 % of the lines")
	RenderLevers.set_for_test([])


func test_the_presets_are_the_leads_taps() -> void:
	# Round 16 (R9): his taps on the levers page, 2026-10-03. laptop = the five he turned on; desktop = none.
	assert_eq(RenderLevers.PRESETS["laptop"], ["scale_075", "lights_2", "no_env_fog", "no_haze", "crowd_medium"], "laptop is his five taps")
	assert_eq(RenderLevers.PRESETS["desktop"], [], "desktop is the full picture")
	for preset: String in RenderLevers.PRESETS:
		assert_true(not RenderLevers.PRESETS[preset].has("unlit_stands"), "%s keeps the stands lit (he tapped it OFF)" % preset)
		assert_true(not RenderLevers.PRESETS[preset].has("scale_085"), "%s does not use the untapped 85 %%" % preset)
	RenderLevers.apply_preset("laptop", "test")
	for lever: String in RenderLevers.NAMES:
		assert_eq(RenderLevers.on(lever), lever in RenderLevers.PRESETS["laptop"], "laptop: %s" % lever)
	assert_near(float(RenderLevers.adjust("render_scale", 1.0)), 0.75, 0.001, "laptop renders 75 % of the lines")
	RenderLevers.apply_preset("desktop", "test")
	for lever: String in RenderLevers.NAMES:
		assert_true(not RenderLevers.on(lever), "desktop: %s off" % lever)
	assert_eq(RenderLevers.adjust("render_scale", 1.0), 1.0, "desktop renders every line")
	RenderLevers.set_for_test([])


func test_the_adapter_picks_the_preset() -> void:
	var other := RenderingDevice.DEVICE_TYPE_OTHER
	for laptop_gpu in ["Mesa Intel(R) UHD Graphics 620 (WHL GT2)", "Mesa Intel(R) Iris(R) Xe Graphics (TGL GT2)",
			"Intel(R) HD Graphics 520"]:
		assert_eq(RenderLevers.preset_for_adapter(other, laptop_gpu), "laptop", "%s is a laptop" % laptop_gpu)
	for desktop_gpu in ["NVIDIA GeForce RTX 3070/PCIe/SSE2", "AMD Radeon RX 6800 XT (radeonsi, navi21, LLVM 15.0.7, DRM 3.49)",
			"Unknown Adapter", ""]:
		assert_eq(RenderLevers.preset_for_adapter(other, desktop_gpu), "desktop", "%s is a desktop" % desktop_gpu)
	assert_eq(RenderLevers.preset_for_adapter(RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU, "Some GPU"), "laptop", "an integrated type is a laptop")
	assert_eq(RenderLevers.preset_for_adapter(RenderingDevice.DEVICE_TYPE_DISCRETE_GPU, "Intel Arc A770"), "desktop", "a discrete type is a desktop")
	assert_eq(RenderLevers.preset_for_adapter(RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU, "Dummy"), "desktop", "the headless dummy is a desktop")


func test_a_headless_run_resolves_to_desktop() -> void:
	# Round 16 (R9): the headless renderer is a dummy, and baselines, tests and parity must never move with a preset.
	RenderLevers._read = false
	RenderLevers._resolve()
	if RenderLevers.source == "headless" or RenderLevers.source == "adapter":
		assert_eq(RenderLevers.preset(), "desktop", "a headless run (dummy adapter) gets the full picture")
	else:
		assert_true(RenderLevers.source in ["flag", "levers", "saved"], "only an explicit choice overrides it (%s)" % RenderLevers.source)
	RenderLevers.set_for_test([])
