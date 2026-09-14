extends TestCase
## Look & feel FX systems (game/theme/fx/): the pooling and budget logic that must hold on every
## platform. Rendering itself is checked by the FX lab screenshots (make fx-bench).


func test_light_pool_gives_explosions_priority_over_nearer_tracers() -> void:
	var positions := PackedVector3Array([Vector3(1, 0, 0), Vector3(50, 0, 0), Vector3(2, 0, 0)])
	var priorities := PackedFloat32Array([LightPool.PRIORITY_TRACER, LightPool.PRIORITY_EXPLOSION, LightPool.PRIORITY_TRACER])
	var chosen := LightPool.choose(positions, priorities, 3, Vector3.ZERO, 2)
	assert_eq(chosen.size(), 2, "two lights for two slots")
	assert_eq(chosen[0], 1, "the far explosion wins a light before any tracer")
	assert_eq(chosen[1], 0, "then the tracer nearest the camera")


func test_light_pool_never_lights_more_than_its_size() -> void:
	var pool: LightPool = add_to_tree(LightPool.new(4))
	for i in 20:
		pool.request(Vector3(i, 0, 0), Color.WHITE, 1.0, 5.0, LightPool.PRIORITY_TRACER)
	pool.commit(Vector3.ZERO, 0.0)
	assert_eq(pool.lit_count, 4, "20 requests light only the 4 pooled lights")
	var visible := pool.lights.filter(func(light: OmniLight3D) -> bool: return light.visible).size()
	assert_eq(visible, 4, "exactly the pool's lights are shown")
	pool.commit(Vector3.ZERO, 0.1)
	assert_eq(pool.lit_count, 0, "requests last one frame: with none, every light turns off")


func test_light_pool_flash_fades_and_expires() -> void:
	var pool: LightPool = add_to_tree(LightPool.new(2))
	pool.flash(Vector3.ZERO, Color.ORANGE, 8.0, 10.0, 0.5, LightPool.PRIORITY_EXPLOSION, 0.0)
	pool.commit(Vector3.ZERO, 0.25)
	assert_eq(pool.lit_count, 1, "a flash holds a light while it lasts")
	assert_true(pool.lights[0].light_energy < 8.0 and pool.lights[0].light_energy > 0.0, "halfway through, the flash has dimmed")
	pool.commit(Vector3.ZERO, 0.6)
	assert_eq(pool.lit_count, 0, "after its duration the flash releases the light")


func test_light_pool_resize_is_the_only_allocation() -> void:
	var pool: LightPool = add_to_tree(LightPool.new(8))
	assert_eq(pool.get_child_count(), 8, "the pool preallocates its lights")
	for frame in 30:
		pool.flash(Vector3(frame, 0, 0), Color.WHITE, 2.0, 4.0, 0.2, LightPool.PRIORITY_MUZZLE, frame * 0.016)
		pool.commit(Vector3.ZERO, frame * 0.016)
	assert_eq(pool.get_child_count(), 8, "combat frames add no light nodes")


func test_burst_system_recycles_a_ring_buffer() -> void:
	var bursts: BurstSystem = add_to_tree(BurstSystem.new(4))
	for i in 10:
		bursts.spawn(BurstSystem.Kind.FIREBALL, Vector3(i, 0, 0), 2.0, 0.5, Color.WHITE, 0.0)
	assert_eq(bursts.capacity(), 4, "spawning past capacity reuses slots instead of growing")
	assert_eq(bursts.started, 10, "every effect started")
	assert_eq(bursts.get_child_count(), 1, "all bursts share one MultiMesh node")


func test_tracer_system_draws_registered_projectiles_only() -> void:
	var tracers: TracerSystem = add_to_tree(TracerSystem.new())
	var pool: LightPool = add_to_tree(LightPool.new(2))
	var shells: Array[Node3D] = []
	for i in 40:
		var shell: Node3D = add_to_tree(Node3D.new())
		shell.position = Vector3(i, 1.2, 0)
		tracers.add(shell, Color.CYAN)
		shells.append(shell)
	tracers.update(pool)
	assert_eq(tracers.active_count(), 40, "40 shells in flight draw 40 tracers (the buffer grew)")
	shells[0].visible = false
	tracers.remove(shells[1])
	tracers.update(pool)
	assert_eq(tracers.active_count(), 38, "hidden and removed shells stop drawing")
	pool.commit(Vector3.ZERO, 0.0)
	assert_eq(pool.lit_count, 2, "tracers compete for the pool instead of each carrying a light")


func test_fx_quality_parses_tiers_and_orders_budgets() -> void:
	assert_eq(FxQuality.parse("LOW"), FxQuality.Tier.LOW, "tier names are case-insensitive")
	assert_eq(FxQuality.parse("ultra"), -1, "unknown tiers are rejected")
	var low: Dictionary = FxQuality.SETTINGS[FxQuality.Tier.LOW]
	var high: Dictionary = FxQuality.SETTINGS[FxQuality.Tier.HIGH]
	assert_true(low["lights"] < high["lights"], "phones get fewer real lights than desktops")
	assert_true(low["render_scale"] <= high["render_scale"], "phones never render above desktop scale")


func test_static_batcher_merges_boxes_by_material() -> void:
	var prop: Node3D = add_to_tree(Node3D.new())
	var a := CyberMaterials.surface(Color.RED)
	var b := CyberMaterials.neon(Color.CYAN)
	for i in 5:
		CyberMaterials.box(prop, Vector3.ONE, Vector3(i * 2, 0, 0), a)
	for i in 3:
		CyberMaterials.box(prop, Vector3.ONE, Vector3(i * 2, 2, 0), b, false)
	var removed := StaticBatcher.merge(prop)
	await tree.process_frame
	assert_eq(removed, 8, "all eight boxes are folded in")
	var merged := prop.find_children("*", "MeshInstance3D", true, false)
	assert_eq(merged.size(), 2, "one mesh per shadow setting (lit boxes cast shadows, neon doesn't)")
	var surfaces := 0
	for instance in merged:
		surfaces += (instance as MeshInstance3D).mesh.get_surface_count()
	assert_eq(surfaces, 2, "one surface (draw) per material")
	var bounds := (merged[0] as MeshInstance3D).get_aabb().merge((merged[1] as MeshInstance3D).get_aabb())
	assert_near(bounds.size.x, 9.0, 0.01, "merged geometry keeps each box where it was")


func test_themes_switch_slots_and_keep_every_slot_id() -> void:
	var previous := GameTheme.theme_name
	for theme_name in GameTheme.THEMES:
		assert_true(GameTheme.use(theme_name), "theme %s can be selected" % theme_name)
		for slot in GameTheme.DEFAULT_SLOTS:
			assert_true(GameTheme.slots.has(slot), "theme %s fills slot %s" % [theme_name, slot])
			assert_true(ResourceLoader.exists(GameTheme.slots[slot]), "theme %s's %s scene exists" % [theme_name, slot])
	GameTheme.use(previous)


func test_every_theme_scene_loads_headless_without_errors() -> void:
	var previous := GameTheme.theme_name
	for theme_name in GameTheme.THEMES:
		GameTheme.use(theme_name)
		for slot in GameTheme.slots:
			var visual_slot := VisualSlot.new()
			visual_slot.slot = slot
			add_to_tree(visual_slot)
			assert_true(visual_slot.visual != null, "%s/%s instantiates on a headless peer" % [theme_name, slot])
			visual_slot.invoke("set_team_color", [Color.MAGENTA])
	await tree.process_frame
	GameTheme.use(previous)


func test_streaks_add_and_remove_without_leaking_instances() -> void:
	var streaks: StreakSystem = add_to_tree(StreakSystem.new())
	var ids: Array[int] = []
	for i in 12:
		ids.append(streaks.add(Vector3(i * 3.0, 2.0, 0), Color.PURPLE))
	await tree.process_frame
	assert_eq(streaks.count(), 12, "every light gets a streak")
	for id in ids.slice(0, 5):
		streaks.remove(id)
	await tree.process_frame
	assert_eq(streaks.count(), 7, "props leaving the tree take their streaks with them")


func test_underglow_follows_visible_vehicles_only() -> void:
	var glow: UnderglowSystem = add_to_tree(UnderglowSystem.new())
	var pool: LightPool = add_to_tree(LightPool.new(4))
	var tanks: Array[Node3D] = []
	for i in 6:
		var tank: Node3D = add_to_tree(Node3D.new())
		tank.position = Vector3(i * 5.0, 0, 0)
		glow.add(tank, Color.CYAN)
		tanks.append(tank)
	tanks[0].visible = false  # destroyed or hidden by fog of war
	glow.update(pool)
	assert_eq(glow.active_count(), 5, "hidden vehicles don't glow (no fog-of-war leaks)")
	pool.request(Vector3.ZERO, Color.WHITE, 1.0, 5.0, LightPool.PRIORITY_EXPLOSION)
	pool.commit(Vector3.ZERO, 0.0)
	assert_eq(pool.lit_count, 4, "vehicles only take pooled lights nobody more important needs")
