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
