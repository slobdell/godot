extends TestCase
## Cyberpunk vehicle visuals: they must stay cheap (two draws per part, shared materials) and honor
## the slot contract's optional methods, on a headless peer too.

const PARTS := ["tank.hull", "tank.turret", "weapon.cannon", "weapon.flamethrower"]


func _part(slot_name: String) -> Node3D:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var slot := VisualSlot.new()
	slot.slot = slot_name
	add_to_tree(slot)
	GameTheme.use(previous)
	return slot.visual as Node3D


func test_every_part_is_one_mesh_with_at_most_two_surfaces() -> void:
	for slot_name in PARTS:
		var part := _part(slot_name)
		var mesh := (part.get_node("Mesh") as MeshInstance3D).mesh
		assert_true(mesh != null and mesh.get_surface_count() <= 2, "%s draws in at most two calls (lit + neon)" % slot_name)


func test_team_color_rebuilds_vertex_colors_not_materials() -> void:
	var cyan := _part("tank.hull")
	var magenta := _part("tank.hull")
	cyan.call("set_team_color", Color("#00F3FF"))
	magenta.call("set_team_color", Color("#FF0099"))
	var a := (cyan.get_node("Mesh") as MeshInstance3D).mesh
	var b := (magenta.get_node("Mesh") as MeshInstance3D).mesh
	# The neon surface is the last one (a generated part's accent mesh has no lit surface of its own).
	var neon_a := a.get_surface_count() - 1
	var neon_b := b.get_surface_count() - 1
	assert_eq(a.surface_get_material(neon_a), b.surface_get_material(neon_b), "both teams share one neon material")
	var colors_a: PackedColorArray = a.surface_get_arrays(neon_a)[Mesh.ARRAY_COLOR]
	var colors_b: PackedColorArray = b.surface_get_arrays(neon_b)[Mesh.ARRAY_COLOR]
	assert_true(colors_a != colors_b, "team colors live in the vertex colors")


func test_cannon_heat_is_a_per_instance_parameter() -> void:
	var cannon := _part("weapon.cannon")
	var other := _part("weapon.cannon")
	cannon.call("set_heat", 0.8)
	var mesh_instance := cannon.get_node("Mesh") as MeshInstance3D
	assert_near(float(mesh_instance.get_instance_shader_parameter("heat")), 0.8, 0.001, "set_heat writes the instance uniform")
	assert_near(float((other.get_node("Mesh") as MeshInstance3D).get_instance_shader_parameter("heat")), 0.0, 0.001, "other cannons stay cold")


func test_flamethrower_shows_its_flame_only_while_firing() -> void:
	var flamer := _part("weapon.flamethrower")
	flamer.call("setup", Weapons.profile("flamethrower"))
	var flame := flamer.get_node("Flame") as MeshInstance3D
	assert_true(not flame.visible, "no flame at rest")
	flamer.call("set_firing", true)
	assert_true(flame.visible, "the flame shows while firing")
	var cone := flame.mesh as CylinderMesh
	assert_near(cone.height, float(Weapons.profile("flamethrower").get("range", 20.0)), 0.01, "the flame is as long as the weapon's range")


func test_shield_events_show_then_hide_the_shell() -> void:
	var hull := _part("tank.hull")
	var shield := hull.get_node("Shield") as ShieldEffect
	for frame in 5:
		hull.call("set_shield", 1.0)  # gameplay calls this every frame
	assert_true(not shield.visible, "a full, untouched shield draws nothing")
	hull.call("set_shield", 0.6)
	assert_true(shield.visible and shield.state()["hit"] > 0.0, "a hit shows the shimmer")
	hull.call("set_shield", 0.0)
	assert_true(shield.state()["down"] > 0.0, "reaching zero plays the shield-down crackle")
	for i in 90:
		shield._process(1.0 / 60.0)
	assert_true(not shield.visible, "the shell hides once the events finish")
	hull.call("set_shield", 0.1)
	assert_true(shield.visible and shield.state()["recharge"] > 0.0, "a rising shield shows the recharge sweep")


func test_laser_parts_and_beams_follow_the_gameplay_contract() -> void:
	var laser := _part("weapon.laser")
	for method in ["set_team_color", "setup", "set_firing", "set_heat"]:
		assert_true(laser.has_method(method), "weapon.laser implements %s" % method)
	laser.call("set_heat", 0.7)
	assert_near(float((laser.get_node("Mesh") as MeshInstance3D).get_instance_shader_parameter("heat")), 0.7, 0.001, "laser coils take heat")
	var beam := _part("fx.laser_beam")
	assert_true(beam.has_method("setup"), "fx.laser_beam implements setup(from, to)")
	beam.call("setup", Vector3.ZERO, Vector3(0, 1, -20))  # headless: no FxWorld, must not error


func test_beam_system_batches_and_expires_pulses() -> void:
	var beams: BeamSystem = add_to_tree(BeamSystem.new())
	var pool: LightPool = add_to_tree(LightPool.new(4))
	var sources: Array[Node] = []
	for i in 20:
		var source: Node = add_to_tree(Node.new())
		beams.add(source, Vector3(i, 1.2, 0), Vector3(i, 1.0, -30), Color.VIOLET, 0.0)
		sources.append(source)
	beams.update(pool, 0.05)
	assert_eq(beams.active_count(), 20, "twenty live pulses draw in one batch")
	pool.commit(Vector3.ZERO, 0.05)
	assert_eq(pool.lit_count, 4, "beams borrow pooled lights instead of carrying their own")
	beams.update(pool, BeamSystem.FADE_SECONDS + 0.01)
	assert_eq(beams.active_count(), 0, "faded pulses stop drawing even before Match frees them")


func test_paint_is_full_body_and_never_changes_the_team_accents() -> void:
	# The procedural hull (vehicle gallery, fallback art); the default tank.hull is the dozer, tested below.
	var hull: Node3D = preload("res://game/theme/cyberpunk/tank_hull.tscn").instantiate()
	add_to_tree(hull)
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	hull.call("set_team_color", GameTheme.team_color(1))
	var accents_before: PackedColorArray = (hull.get_node("Mesh") as MeshInstance3D).mesh.surface_get_arrays(1)[Mesh.ARRAY_COLOR]
	var body_before: PackedColorArray = (hull.get_node("Mesh") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	hull.call("set_team_color", Color.HOT_PINK)  # how the garage paints today (Tank.set_paint)
	var accents_after: PackedColorArray = (hull.get_node("Mesh") as MeshInstance3D).mesh.surface_get_arrays(1)[Mesh.ARRAY_COLOR]
	var body_after: PackedColorArray = (hull.get_node("Mesh") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	GameTheme.use(previous)
	assert_eq(accents_after, accents_before, "a paint color leaves the team accent lights alone")
	assert_true(body_after != body_before, "and repaints the body")
	assert_true(body_after.has(Color(Color.HOT_PINK, 1.0)), "with the chosen color")


func test_camera_shake_falls_off_with_distance_and_scales_with_trauma() -> void:
	assert_near(CameraShake.falloff(10.0, 25.0), 1.0, 0.001, "full strength near the camera's focus")
	assert_near(CameraShake.falloff(100.0, 25.0), 0.0, 0.001, "nothing at 4x the radius")
	var shake := CameraShake.new()
	add_to_tree(shake)
	var big := shake.offset_at(1.0, 0.37).length()
	var small := shake.offset_at(0.3, 0.37).length()
	assert_true(small < big * 0.2, "trauma squared: small hits barely move the view (%.3f vs %.3f)" % [small, big])


func test_the_generated_dozer_wears_team_accents_paint_and_a_shield() -> void:
	# Integration 2026-09-15: the assets stream's Meshy prison dozer fills the cyberpunk tank slots.
	var hull := _part("tank.hull")
	assert_true(hull.get_node_or_null("Model") != null, "tank.hull is the generated model")
	assert_true(hull.get_node_or_null("Shield") is ShieldEffect, "with the theme's shield shell")
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	hull.call("set_team_color", GameTheme.team_color(1))
	var accent_mesh := (hull.get_node("Mesh") as MeshInstance3D).mesh
	var accents_before: PackedColorArray = accent_mesh.surface_get_arrays(accent_mesh.get_surface_count() - 1)[Mesh.ARRAY_COLOR]
	assert_true(accents_before.has(Color(GameTheme.team_color(1), 1.0)) or accents_before.size() > 0, "team accent strips are drawn")
	hull.call("set_paint", Color.HOT_PINK)
	GameTheme.use(previous)
	accent_mesh = (hull.get_node("Mesh") as MeshInstance3D).mesh
	var accents_after: PackedColorArray = accent_mesh.surface_get_arrays(accent_mesh.get_surface_count() - 1)[Mesh.ARRAY_COLOR]
	assert_eq(accents_after, accents_before, "paint leaves the team accents alone")
	var model := hull.get_node("Model")
	var painted := model.find_children("*", "MeshInstance3D", true, false).any(func(m: MeshInstance3D) -> bool:
		for surface in m.mesh.get_surface_count():
			var material := m.get_surface_override_material(surface) as BaseMaterial3D
			if material != null and material.albedo_color.r > material.albedo_color.g + 0.1:
				return true
		return false)
	assert_true(painted, "and tints the generated body")

