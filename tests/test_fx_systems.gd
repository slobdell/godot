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


func test_light_pool_flash_scheduled_for_later_waits_its_turn() -> void:
	var pool: LightPool = add_to_tree(LightPool.new(2))
	pool.flash(Vector3.ZERO, Color.ORANGE, 8.0, 10.0, 0.5, LightPool.PRIORITY_EXPLOSION, 1.0)
	pool.commit(Vector3.ZERO, 0.5)
	assert_eq(pool.lit_count, 0, "a cook-off light due in half a second isn't lit yet")
	pool.commit(Vector3.ZERO, 1.0)
	assert_eq(pool.lit_count, 1, "it lights when its time comes")
	assert_true(pool.lights[0].light_energy <= 8.0, "and never brighter than its peak (%.1f)" % pool.lights[0].light_energy)


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


func test_a_slot_missing_from_a_theme_falls_back_to_the_default_scene() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	for slot in GameTheme.DEFAULT_SLOTS:
		assert_true(GameTheme.slots.has(slot), "cyberpunk resolves %s (its own scene or the default)" % slot)
	assert_eq(GameTheme.slots["prop.crate"], GameTheme.CYBERPUNK_SLOTS["prop.crate"], "a theme's own scene wins")
	GameTheme.use(previous)


func test_cyberpunk_fog_of_war_takes_the_visibility_texture() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var slot := VisualSlot.new()
	slot.slot = "fx.fog_of_war"
	add_to_tree(slot)
	GameTheme.use(previous)
	var image := Image.create_empty(64, 64, false, Image.FORMAT_L8)
	slot.invoke("setup", [{"texture": ImageTexture.create_from_image(image), "origin": Vector2(-160, -160), "size": 320.0}])
	var fog := slot.visual as MeshInstance3D
	assert_true(fog.mesh is PlaneMesh and is_equal_approx((fog.mesh as PlaneMesh).size.x, 320.0), "the sheet spans the arena")
	assert_near(fog.position.x, 0.0, 0.001, "centered on the texture's area")


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
	assert_eq(glow.shadow_count(), 5, "every visible vehicle sits on a blob shadow (render X3: no dynamic shadows)")
	pool.request(Vector3.ZERO, Color.WHITE, 1.0, 5.0, LightPool.PRIORITY_EXPLOSION)
	pool.commit(Vector3.ZERO, 0.0)
	assert_eq(pool.lit_count, 1, "vehicles carry no real lights (render X3, M1): only the explosion is lit")


func test_light_pool_ignores_requests_below_its_floor() -> void:
	var pool: LightPool = add_to_tree(LightPool.new(4))
	pool.min_priority = LightPool.PRIORITY_MUZZLE
	for i in 6:
		pool.request(Vector3(i, 0, 0), Color.WHITE, 1.0, 5.0, LightPool.PRIORITY_TRACER)
	pool.flash(Vector3.ZERO, Color.WHITE, 1.0, 5.0, 1.0, LightPool.PRIORITY_VEHICLE, 0.0)
	pool.commit(Vector3.ZERO, 0.1)
	assert_eq(pool.lit_count, 0, "tracers and vehicle lights never take a real light")
	pool.flash(Vector3.ZERO, Color.WHITE, 1.0, 5.0, 1.0, LightPool.PRIORITY_EXPLOSION, 0.0)
	pool.request(Vector3.ZERO, Color.WHITE, 1.0, 5.0, LightPool.PRIORITY_SHELL)
	pool.commit(Vector3.ZERO, 0.1)
	assert_eq(pool.lit_count, 2, "explosions and tank shells still do")


func test_every_tier_keeps_the_m1_light_budget() -> void:
	for tier in FxQuality.SETTINGS:
		var settings: Dictionary = FxQuality.SETTINGS[tier]
		assert_true(int(settings["lights"]) <= 4, "%s: at most 4 pooled lights (M1: <= 6 real lights with the moon)" % FxQuality.NAMES[tier])
		assert_true(not settings["shadows"], "%s: no dynamic shadows (M1; +4.6 ms GPU in perf-scene)" % FxQuality.NAMES[tier])
		assert_eq(settings["msaa"], Viewport.MSAA_DISABLED, "%s: no MSAA (+2.5 ms GPU in perf-scene)" % FxQuality.NAMES[tier])
		assert_true(float(settings["light_floor"]) >= LightPool.PRIORITY_MUZZLE, "%s: tracers and vehicles never take a light" % FxQuality.NAMES[tier])


func test_auto_quality_only_steps_down_when_slow_and_nobody_chose() -> void:
	assert_true(FxAutoQuality.should_step_down(30.0, FxQuality.Tier.HIGH, true, 0.0), "slow frames at high step down")
	assert_true(not FxAutoQuality.should_step_down(30.0, FxQuality.Tier.LOW, true, 0.0), "never below low")
	assert_true(not FxAutoQuality.should_step_down(30.0, FxQuality.Tier.HIGH, false, 0.0), "a player's (or flag's) choice is respected")
	assert_true(not FxAutoQuality.should_step_down(30.0, FxQuality.Tier.HIGH, true, 3.0), "cooldown between steps")
	assert_true(not FxAutoQuality.should_step_down(17.0, FxQuality.Tier.HIGH, true, 0.0), "a 60 Hz frame is fine")


func test_every_tier_budget_is_complete_and_ordered() -> void:
	var keys := ["lights", "light_floor", "splats", "glow", "render_scale", "msaa", "shadows", "effects"]
	for tier in FxQuality.SETTINGS:
		for key in keys:
			assert_true(FxQuality.SETTINGS[tier].has(key), "tier %s sets %s" % [FxQuality.NAMES[tier], key])
	assert_true(FxQuality.SETTINGS[FxQuality.Tier.LOW]["effects"] <= FxQuality.SETTINGS[FxQuality.Tier.HIGH]["effects"], "fewer pooled effects on low")
	assert_true(not FxQuality.SETTINGS[FxQuality.Tier.LOW]["shadows"], "no dynamic shadows on phones (+4.9 ms in the lab)")


func test_sfx_pool_never_grows_and_loads_every_sound() -> void:
	var sfx: SfxSystem = add_to_tree(SfxSystem.new())
	sfx.muted = false
	for sound in SfxSystem.SOUNDS:
		assert_true(sfx.streams.has(sound), "sound %s loads" % sound)
	var voices := sfx.voice_count()
	for i in 40:
		sfx.play_at("cannon_shot", Vector3(i, 0, 0))
	sfx.play_ui("ui_blip")
	assert_eq(sfx.voice_count(), voices, "a 40-shot burst reuses the pooled voices")
	assert_eq(sfx.played, 41, "every request played (oldest voices stolen when busy)")
	var flame := sfx.streams["flame_loop"] as AudioStreamWAV
	assert_eq(flame.loop_mode, AudioStreamWAV.LOOP_FORWARD, "the flame roar loops")


func test_sounds_before_the_tree_are_dropped_not_errors() -> void:
	# Integration 2026-09-15: gameplay's announcer posts a banner at spawn, before FxWorld's deferred add,
	# and every skirmish start logged "Playback can only happen when a node is inside the scene tree".
	var sfx := SfxSystem.new()
	sfx.muted = false
	sfx.play_ui("ui_blip")
	sfx.play_at("cannon_shot", Vector3.ZERO)
	assert_eq(sfx.played, 0, "nothing plays outside the tree")
	sfx.free()


func test_decorative_bursts_thin_out_when_the_overdraw_budget_is_spent() -> void:
	assert_eq(BurstSystem.budget_scale(BurstSystem.Kind.GROUND_GLOW, 10.0, 0.0, 500.0), 1.0, "room left: full size")
	assert_near(BurstSystem.budget_scale(BurstSystem.Kind.GROUND_GLOW, 10.0, 436.0, 500.0), 0.8, 0.001, "a little room: smaller")
	assert_eq(BurstSystem.budget_scale(BurstSystem.Kind.GROUND_GLOW, 10.0, 490.0, 500.0), 0.0, "no room: skipped")
	assert_eq(BurstSystem.budget_scale(BurstSystem.Kind.FIREBALL, 10.0, 5000.0, 500.0), 1.0, "a hit's fireball is information, never thinned")
	var bursts: BurstSystem = add_to_tree(BurstSystem.new(64))
	bursts.overdraw_budget = 300.0
	for i in 10:
		bursts.spawn(BurstSystem.Kind.GROUND_GLOW, Vector3(i, 0, 0), 10.0, 1.0, Color.ORANGE, 0.0)
	assert_true(bursts.alive_area <= 300.0 + 0.01, "alive area stays inside the budget (%.0f)" % bursts.alive_area)
	assert_true(bursts.thinned >= 7, "most of a pile-up of glows is thinned (%d)" % bursts.thinned)
	bursts.update(2.0)
	assert_eq(bursts.alive_area, 0.0, "expired effects free the budget")


func test_repeated_static_models_draw_as_one_multimesh() -> void:
	var root: Node3D = add_to_tree(Node3D.new())
	var shared := BoxMesh.new()
	for i in 5:
		var holder := Node3D.new()
		holder.position = Vector3(i * 10.0, 0, 0)
		var model := MeshInstance3D.new()
		model.mesh = shared
		model.position = Vector3(0, 1, 0)
		holder.add_child(model)
		root.add_child(holder)
	var lone := MeshInstance3D.new()
	lone.mesh = SphereMesh.new()
	root.add_child(lone)
	var removed := StaticInstancer.instance_repeats(root)
	assert_eq(removed, 4, "five copies become one draw")
	var draws := root.find_children("*", "MultiMeshInstance3D", false, false)
	assert_eq(draws.size(), 1, "one MultiMesh for the repeated mesh; the lone sphere is left alone")
	var multimesh := (draws[0] as MultiMeshInstance3D).multimesh
	assert_eq(multimesh.instance_count, 5, "every copy is an instance")
	# Headless renderers don't keep MultiMesh instance data: the instancer records the transforms for tests.
	var placed: Array = (draws[0] as MultiMeshInstance3D).get_meta("transforms")
	assert_eq((placed[3] as Transform3D).origin, Vector3(30, 1, 0), "placed where the copy was")
	assert_true(lone.visible, "a single model keeps its own node")


func test_the_unlit_floor_is_one_plane_and_lit_floors_stay_tiled() -> void:
	var ground: ChunkedGround = add_to_tree(ChunkedGround.new())
	assert_eq(ground.tile_count(), 64, "lit floors: 8 x 8 tiles so a light re-draws only what it reaches")
	ground.chunked = false
	ground.build()
	assert_eq(ground.tile_count(), 1, "unlit floor: one draw")
	var plane := (ground.get_child(0) as MeshInstance3D).mesh as PlaneMesh
	assert_true(plane.subdivide_width >= 40, "still ~5 m between vertices for per-vertex fog (%d)" % plane.subdivide_width)


func test_jolts_skip_vehicles_too_far_from_the_camera_to_see_them() -> void:
	var jolts := VehicleJolt.new()
	var near: Node3D = add_to_tree(Node3D.new())
	var far: Node3D = add_to_tree(Node3D.new())
	far.position = Vector3(0, 0, -200)
	for unit in [near, far]:
		var slot := VisualSlot.new()
		unit.add_child(slot)
	jolts.camera_position = Vector3(0, 40, 30)
	jolts.kick(near, Vector3.FORWARD, 2.0, 0.1, 0.0)
	jolts.kick(far, Vector3.FORWARD, 2.0, 0.1, 0.0)
	assert_eq(jolts.active_count(), 1, "only the vehicle within %d m of the camera rocks" % VehicleJolt.VISIBLE_RANGE)


func test_dead_vehicles_leave_capped_wrecks_that_a_new_match_clears() -> void:
	var yard: KitYard = add_to_tree(KitYard.new())
	var field := WreckField.new(yard)
	var owner: Node3D = add_to_tree(Node3D.new())
	var cap: int = WreckField.PER_TIER[FxQuality.tier()]
	for i in cap + 5:
		field.add(owner, Vector3(i, 0, 0), Vector3.FORWARD, [2.4, 1.6, 3.6], "Unit_%d" % i, float(i))
	assert_eq(field.count(), cap, "the oldest wrecks go past the tier's cap")
	assert_eq(yard.count("wreck"), cap, "one yard instance per wreck")
	field.add(owner, Vector3(0, 0, 0), Vector3.FORWARD, [2.4, 1.6, 3.6], "Unit_%d" % (cap + 4), float(cap + 4) + 0.5)
	assert_eq(field.count(), cap, "a death reported twice leaves one wreck")
	field.clear()
	assert_eq(yard.count("wreck"), 0, "a new match starts clean")
	var fit := WreckField.scale_for([2.4, 1.6, 3.6])
	assert_true(fit.x / fit.z <= 1.4 + 0.001 and fit.z / fit.x <= 1.4 + 0.001, "a husk is never stretched past 40%% between axes (%s)" % fit)


func test_effects_place_themselves_where_a_body_is_drawn() -> void:
	# Ahead of the 30 Hz simulation: with interpolation off (today) the drawn transform is the physics one.
	var body: Node3D = add_to_tree(Node3D.new())
	body.position = Vector3(3, 0, -7)
	body.rotation.y = 0.4
	assert_eq(FxWorld.visual_transform(body), body.global_transform, "no interpolation: exactly the global transform")
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	assert_eq(FxWorld.visual_transform(body).origin, body.global_position, "still where it is before any tick has moved it")


func test_muzzle_effects_follow_the_drawn_hull_not_the_tick() -> void:
	var body: Node3D = add_to_tree(Node3D.new())
	body.position = Vector3(4, 0, 2)
	assert_eq(WeaponFx.drawn_offset(body), Vector3.ZERO, "no interpolation: effects spawn exactly at the event's muzzle")
	assert_eq(WeaponFx.drawn_offset(null), Vector3.ZERO, "an unknown shooter changes nothing")
