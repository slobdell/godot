extends TestCase
## Burning kill sites (art stretch): a kill leaves a fire that feeds the pooled bursts and light pool, burns down and
## goes out; the tier caps how many burn at once.


func test_a_kill_site_burns_then_goes_out() -> void:
	var bursts := BurstSystem.new(64)
	add_to_tree(bursts)
	var lights := LightPool.new(4)
	add_to_tree(lights)
	var fires := FireSites.new()
	fires.ignite(Vector3(10, 0, 5), 0.0, bursts)
	assert_eq(fires.burning_count(), 1, "the kill site is burning")
	var before := bursts.started
	for step in 40:
		fires.update(step * 0.1, bursts, lights)
	assert_true(bursts.started - before >= 6, "it keeps feeding flames into the pooled bursts (%d in 4 s)" % (bursts.started - before))
	fires.update(FireSites.BURN_SECONDS + 1.0, bursts, lights)
	assert_eq(fires.burning_count(), 0, "after %d s the fire is out" % FireSites.BURN_SECONDS)


func test_the_tier_caps_how_many_sites_burn() -> void:
	var bursts := BurstSystem.new(64)
	add_to_tree(bursts)
	var previous := FxQuality.tier()
	FxQuality.set_tier(FxQuality.Tier.LOW, "test")
	var fires := FireSites.new()
	for i in 8:
		fires.ignite(Vector3(i * 10.0, 0, 0), float(i), bursts)
	assert_eq(fires.burning_count(), FireSites.PER_TIER[FxQuality.Tier.LOW], "phones keep only the newest few fires")
	assert_near((fires.sites[0]["position"] as Vector3).x, 50.0, 0.001, "the oldest went out first")
	FxQuality.set_tier(previous, "test")


func test_heat_haze_rises_over_the_nearest_fires_on_the_high_tier_only() -> void:
	var previous := FxQuality.tier()
	var haze: HeatHaze = add_to_tree(HeatHaze.new())
	var sites: Array = []
	for i in 12:
		sites.append({"position": Vector3(i * 10.0, 0, 0), "start": 0.0})
	FxQuality.set_tier(FxQuality.Tier.HIGH, "test")
	var nodes := haze.get_child_count()
	haze.update(sites, Vector3.ZERO, 5.0)
	assert_eq(haze.active_count(), HeatHaze.MAX_QUADS, "twelve fires, the %d nearest shimmer" % HeatHaze.MAX_QUADS)
	assert_eq(haze.get_child_count(), nodes, "one MultiMesh however many fires")
	FxQuality.set_tier(FxQuality.Tier.LOW, "test")
	haze.update(sites, Vector3.ZERO, 5.0)
	assert_eq(haze.active_count(), 0, "phones skip the screen-copy haze")
	FxQuality.set_tier(previous, "test")


func test_heat_haze_box_is_its_quads_not_the_world() -> void:
	# Round 16 (R3): the haze reads the screen texture, so the renderer copies the whole screen whenever its MultiMesh
	# passes the frustum test. A world-sized box passed it every frame a wreck burned anywhere; the box must be the
	# quads' own, and still hold every quad from any view (they turn to face the camera).
	var previous := FxQuality.tier()
	FxQuality.set_tier(FxQuality.Tier.HIGH, "test")
	var haze: HeatHaze = add_to_tree(HeatHaze.new())
	var sites: Array = [{"position": Vector3(100.0, 0, 80.0), "start": 0.0}, {"position": Vector3(110.0, 0, 90.0), "start": 0.0}]
	haze.update(sites, Vector3.ZERO, 5.0)
	var mesh := haze.get_node("HazeMesh") as MultiMeshInstance3D
	var box := mesh.custom_aabb
	assert_true(box.size.x < 40.0 and box.size.z < 40.0, "the box is two fires wide, not the arena (%s)" % box)
	# A headless renderer keeps no MultiMesh instance data, so the quads' centres come from the fires themselves.
	for site: Dictionary in sites:
		var at: Vector3 = site["position"] + Vector3.UP * (HeatHaze.HEIGHT * 0.5 + 0.8)
		var corner := Vector3(HeatHaze.WIDTH, HeatHaze.HEIGHT, 0.0) * 0.5
		for turned in [corner, Vector3(corner.z, corner.y, corner.x), -corner, Vector3(-corner.z, -corner.y, corner.x)]:
			assert_true(box.grow(0.001).has_point(at + turned), "the quad at %s keeps its corner %s inside the box" % [at, turned])
	FxQuality.set_tier(previous, "test")


func test_the_transparent_effects_have_one_defined_order() -> void:
	# Round 16 (R1, the orchestrator's decision): six FX systems used to share one world-sized box and so one sort
	# depth, and an unstable sort chose their order. FxWorld.TRANSPARENT_ORDER pins it; read it back from the live
	# systems so no stream's change can flip it silently. A higher priority renders EARLIER: back to front, ground
	# decals, order marks, heat haze, beams and tracers, then the fire -- nothing is drawn over a fireball.
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var order := ["decals", "order_feedback", "haze", "beams", "tracers", "bursts"]
	var last := Material.RENDER_PRIORITY_MAX + 1
	for system_name: String in order:
		var materials := FxWorld.materials_of(fx.get(system_name))
		assert_true(not materials.is_empty(), "%s draws with a material" % system_name)
		for material in materials:
			assert_eq(material.render_priority, int(FxWorld.TRANSPARENT_ORDER[system_name]), "%s's priority is the table's" % system_name)
		assert_true(materials[0].render_priority <= last, "%s is not drawn before the system listed before it" % system_name)
		last = materials[0].render_priority
	for material in FxWorld.materials_of(fx.bursts):
		assert_true(material.render_priority < 0, "the fire is drawn after everything left at the default (0)")
