extends TestCase
## Feel (round 6; the lead: "Our semi truck for the gang that was supposed to be a huge tank is tiny compared to the
## other vehicles ... Scouts are small, the IFVs are bigger, the tanks bigger than that (everything drawn to scale)").
## hull_size (C1) is the size of a unit; the art must draw it.


func _spawn(unit_id: String) -> Tank:
	var tank: Tank = (load("res://game/tank/tank.tscn") as PackedScene).instantiate()
	tank.unit_id = unit_id
	tank.simulate = false
	add_to_tree(tank)
	return tank


## The drawn hull's length (m) along the tank's -Z, from the visual's meshes in tank space.
func _drawn_length(tank: Tank) -> float:
	return _drawn_size(tank).z


func _under_gun_pivot(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current.name == "GunPivot":
			return true
		current = current.get_parent()
	return false


## The drawn hull's extent (m) in tank space: width, height, length.
func _drawn_size(tank: Tank) -> Vector3:
	var hull: Node = tank.get_node("HullVisual")
	var models := hull.find_children("Model", "Node3D", true, false)
	if not models.is_empty():
		hull = models[0]  # the model only: a shielded unit's shield shell is bigger than its hull
	var result := AABB()
	var first := true
	for child in hull.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null or not instance.is_visible_in_tree() or instance.mesh.get_surface_count() == 0:
			continue
		if _under_gun_pivot(instance):
			continue  # a gun cut out of the hull turns with the turret and may overhang the box; the hull is what fits it
		var box := (tank.global_transform.affine_inverse() * instance.global_transform) * instance.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result.size


## Round 8 (the lead, the third time: "the gang tanks are still tiny"): the War Rig's box was raised to 4.4 m tall and
## the art, fitted by length, still drew it 2.09 m tall: shorter on screen than the Condemned tank. A box in the model's
## own proportions (SizeLook.box_at_length, the numbers agreed with combat) is filled on every axis, not just length.
func test_a_box_in_the_models_proportions_is_filled_on_every_axis() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var box: Array = SizeLook.box_at_length("gang_tank", 12.0)
	Units.tuning["gang_tank.hull_size"] = box
	var drawn := _drawn_size(_spawn("gang_tank"))
	Units.tuning.erase("gang_tank.hull_size")
	GameTheme.use(previous)
	for axis in 3:
		assert_near(drawn[axis], float(box[axis]), float(box[axis]) * 0.05, "axis %d: drawn %s, box %s" % [axis, drawn, box])


func test_every_faction_draws_its_units_at_their_hull_size() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	for faction in ["gangs", "law", "syndicate"]:
		var lengths := {}
		for unit_id in Units.roster(faction):
			if not GameTheme.slots.has("unit.%s.hull" % unit_id):
				continue
			var tank := _spawn(unit_id)
			await wait_physics_frames(1)
			var drawn := _drawn_length(tank)
			var wanted := float(Units.stat(unit_id, "hull_size")[2])
			assert_near(drawn, wanted, wanted * 0.05, "%s draws its %.1f m hull (drew %.2f m)" % [unit_id, wanted, drawn])
			lengths[Units.role_of(unit_id)] = drawn
			tank.queue_free()
		if lengths.has("scout") and lengths.has("tank"):
			assert_true(lengths["scout"] < lengths["tank"], "%s: the scout is smaller than the tank %s" % [faction, lengths])
	GameTheme.use(previous)


func test_a_turret_scales_with_its_hull() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var tank := _spawn("gang_tank")  # the semi: its model was 3.6 m of a 5.6 m hull
	await wait_physics_frames(2)
	GameTheme.use(previous)
	var fit := float(Units.stat("gang_tank", "hull_size")[2]) / FactionArt.hull_length("gang_tank")
	for part in tank.get_node("Turret").find_children("Model", "Node3D", true, false):
		var total := (tank.global_transform.affine_inverse() * (part as Node3D).global_transform).basis.get_scale().x
		assert_near(total, fit, 0.01, "the turret part takes the hull's scale (%.2f)" % total)


func test_the_gang_ifv_and_the_syndicate_lancer_face_forward() -> void:
	## Round 7 (the lead, three times: "the gang's IFV drives backwards"); make facing-audit then found the Syndicate
	## lancer the same way round (its approved concept has the nose and the emitter's lens leading).
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	for unit_id in ["gang_ifv", "syn_lancer"]:
		var tank := _spawn(unit_id)
		await wait_physics_frames(1)
		var model := tank.get_node("HullVisual").find_children("Model", "Node3D", true, false)[0] as Node3D
		assert_near(absf(wrapf(model.rotation.y, -PI, PI)), PI, 0.01, "%s's hull model is turned round to face -Z" % unit_id)
		tank.queue_free()
	GameTheme.use(previous)


func test_a_gun_baked_into_its_hull_turns_with_the_turret() -> void:
	## Round 7 (the lead: "the turrets on the gang tanks didn't rotate"): the gang tank's gun was generated as part of its
	## hull, with a nub for a turret part. The gun is cut out of the hull and yaws with the tank's turret.
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var tank := _spawn("gang_tank")
	await wait_physics_frames(2)
	GameTheme.use(previous)
	var pivots := tank.get_node("HullVisual").find_children("GunPivot", "Node3D", true, false)
	assert_eq(pivots.size(), 1, "the hull gave its gun a pivot of its own")
	var gun_meshes := (pivots[0] as Node3D).find_children("Gun", "MeshInstance3D", true, false)
	assert_true(gun_meshes.size() >= 1, "with the gun's triangles in it")
	var turret_models := tank.get_node("Turret").find_children("Model", "Node3D", true, false)
	for model in turret_models:
		assert_true(not (model as Node3D).is_visible_in_tree(), "the stand-in nub is hidden")
	tank.turret.rotation.y = 1.0
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	assert_true(absf(tank.turret.rotation.y) > 0.1, "the turret is turned")
	assert_near((pivots[0] as Node3D).rotation.y, tank.turret.rotation.y, 0.05, "the gun follows the turret's yaw")


## X4 (round 9, after CP2's resize): the round-8 generalisation of `test_the_semis_fill_their_boxes` from two semis
## to the WHOLE ROSTER, and from length to EVERY AXIS.
##
## Why it is not a duplicate of scale's `test_every_box_is_its_meshs_proportions_at_that_length`, which asserts the
## same-sounding thing: scale's test asks whether the CATALOG's box matches the mesh's proportions. This one spawns
## the unit and measures what is actually DRAWN. They fail on different things — scale's catches a bad box; this one
## catches a bad FIT, and the fit now has more moving parts than it did (`_fit_to_hull`'s uniform scale, a gun cut
## out of the hull onto its own pivot, and since round 9 a trailer cut onto a second pivot). `hull_size` IS the
## collider, so a unit that draws outside it is a shell passing through empty air.
##
## The division of labour, because a failure here is routed rather than fixed in place: **scale derives the numbers,
## feel checks the art is not distorted by them.** `_fit_to_hull` scales uniformly by length, so width and height
## come out as the mesh's own proportions — a unit whose mesh cannot fill its new box is a finding handed BACK to
## scale, never something to stretch away.
func test_every_unit_with_art_is_drawn_inside_its_own_box_on_every_axis() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var checked := 0
	var worst := {"unit": "", "axis": -1, "off": 0.0}
	for faction in Units.FACTIONS:
		for unit_id in Units.roster(faction):
			# Round 11 (fleet T3): units WITHOUT hull art of their own are covered too. This test skipped them, and they
			# were exactly the two drawn with a 1.63:1 distortion; their shape is held by test_units_bus_eye.gd.
			var tank := _spawn(unit_id)
			await wait_physics_frames(1)
			# Round 11 (fleet): and one PROCESS frame. The crane carrier's outriggers start down (artillery_part
			# `deployed = 1.0`) and are stowed by the tank's first _process (tank.gd `_shown_deploy` starts NAN); a physics
			# frame alone can finish before any process frame, and then this test read the braced 4.74 m, intermittently.
			await tree.process_frame
			var drawn := _drawn_size(tank)
			var box: Array = Units.stat(unit_id, "hull_size")
			checked += 1
			for axis in 3:
				var wanted := float(box[axis])
				var off := absf(drawn[axis] - wanted) / maxf(wanted, 0.001)
				if off > worst["off"]:
					worst = {"unit": unit_id, "axis": axis, "off": off}
				assert_true(off <= 0.05,
						"%s axis %d: drawn %.2f m against a %.2f m box (%.0f%% out). scale derives the box; if the mesh cannot fill it, that is scale's finding, not a reason to stretch the art"
								% [unit_id, axis, drawn[axis], wanted, off * 100.0])
			tank.queue_free()
	GameTheme.use(previous)
	assert_true(checked >= 21, "the whole roster was checked, not a handful (%d units)" % checked)
	print("UNIT_BOX_FILL %d units, worst %s axis %d at %.1f%%" % [checked, worst["unit"], worst["axis"], worst["off"] * 100.0])


func test_the_box_fill_check_can_actually_fail() -> void:
	## Prove the guard goes red (Invariant 0). A box nobody's mesh has the proportions of must be caught — otherwise
	## the test above passes for the same reason a switched-off test passes.
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	Units.tuning["gang_tank.hull_size"] = [3.32, 5.24, 28.0]  # twice the rig's length, same width and height
	var drawn := _drawn_size(_spawn("gang_tank"))
	Units.tuning.erase("gang_tank.hull_size")
	GameTheme.use(previous)
	# Fitted by LENGTH, the rig now draws 28 m long and twice as wide and tall as its box says — so width and height
	# must both be well outside the 5% the test above allows.
	var wide := absf(drawn.x - 3.32) / 3.32
	var tall := absf(drawn.y - 5.24) / 5.24
	assert_true(wide > 0.05 or tall > 0.05,
			"a deliberately wrong box is caught (drew %.2f x %.2f, box says 3.32 x 5.24)" % [drawn.x, drawn.y])


## Round 11 (fleet T1; the lead: "The turret on the Law's IFV is not spinning"). It was spinning, inside its hull: the
## Law IFV's turret part was drawn below its own roof, and so were others. The check is DERIVED from the meshes for the
## whole roster, no list (lesson 3): whatever turns with the turret -- the turret part, the weapon part, a gun cut out
## of the hull -- must be drawn mostly ABOVE the hull under it (TurretFit: a height field of the hull, 0.2 m cells),
## at rest and turned a quarter round, because a turret that only clears the roof pointing ahead still vanishes as it
## traverses. 80%: every unit whose turret reads as a turret on `make facing-audit TINT=1` scored 86-100% when this was
## written, and every buried one 31-69%, so the line has room on both sides.
const TURRET_ABOVE_HULL := 0.8
## And not floating: at rest, the lowest thing that turns is within this of the hull under it. Round 11's T3 lowered
## the bus's roof 0.68 m and left its turret hanging +0.71 m in the air; the Syndicate's hover guns, floating by
## design, measured +0.13 (IFV pod) and +0.24 m (railgun), the War Rig's cut gun +0.19.
const TURRET_FLOATS_M := 0.4


func _turret_above(unit_id: String, yaw_deg: float, sink_m := 0.0) -> Dictionary:
	var tank := _spawn(unit_id)
	await wait_physics_frames(2)  # a turret part is fitted to the hull deferred (dozer_part _fit_to_hull)
	for part in ["Turret/TurretVisual", "Turret/WeaponVisual"]:
		(tank.get_node(part) as Node3D).position.y -= sink_m / maxf(tank.turret.scale.y, 0.001)
	tank.set("sync_turret_yaw", deg_to_rad(yaw_deg))  # a tank that isn't simulating eases toward the synced yaw
	tank.turret.rotation.y = deg_to_rad(yaw_deg)
	await tree.process_frame
	tank.turret.rotation.y = deg_to_rad(yaw_deg)
	var fit := TurretFit.measure(tank)
	tank.queue_free()
	return fit


func test_what_turns_with_every_turret_is_drawn_above_its_hull() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var checked := 0
	var failures: Array = []
	for faction in Units.FACTIONS:
		for unit_id in Units.roster(faction):
			for yaw in [0.0, 90.0]:
				var fit: Dictionary = await _turret_above(unit_id, yaw)
				if int(fit["points"]) == 0:
					continue  # nothing turns: a fixed mount, or a gun drawn into a hull nobody cut
				checked += 1
				if float(fit["above"]) < TURRET_ABOVE_HULL:
					failures.append("%s at %d deg: %.0f%% above the hull, lowest point %+.2f m" % [unit_id, yaw,
							float(fit["above"]) * 100.0, fit["lowest"]])
				elif yaw == 0.0 and float(fit["lowest"]) > TURRET_FLOATS_M:
					failures.append("%s: floating %.2f m over its roof" % [unit_id, fit["lowest"]])
	GameTheme.use(previous)
	assert_true(checked >= 24, "the turret units were measured, both ways round (%d)" % checked)
	assert_true(failures.is_empty(), "turrets buried in their own hulls: %s" % "; ".join(failures))


func test_the_turret_check_sees_a_buried_turret() -> void:
	## Invariant 0: bury a turret that passes (the Condemned tank's, seated on the roof by round 10's mount) and the
	## measure must drop under the line.
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var seated: Dictionary = await _turret_above("tank", 0.0)
	var buried: Dictionary = await _turret_above("tank", 0.0, 1.0)
	GameTheme.use(previous)
	assert_true(float(seated["above"]) >= TURRET_ABOVE_HULL, "seated on the roof it passes (%.0f%%)" % (float(seated["above"]) * 100.0))
	assert_true(float(buried["above"]) < TURRET_ABOVE_HULL, "a metre down it fails (%.0f%%)" % (float(buried["above"]) * 100.0))


## Round 11 (fleet T2; the lead: "the barrel of the tank is detached at the tip, there's a floating piece of the barrel
## that stays fixed in front of the tank"). Two causes, both checked from what is DRAWN, for the whole roster:
## a generated weapon part that is a sliver (FactionArt.is_stray_stick), and a barrel fragment left in a hull mesh
## (FactionArt.HULL_TRIMS).
func test_no_unit_draws_a_weapon_part_that_is_a_stick() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var drawn := 0
	var sticks: Array = []
	for faction in Units.FACTIONS:
		for unit_id in Units.roster(faction):
			var tank := _spawn(unit_id)
			await wait_physics_frames(2)
			var points := TurretFit.points(tank, tank.get_node("Turret/WeaponVisual"), true)
			tank.queue_free()
			if points.is_empty():
				continue
			drawn += 1
			var box := AABB(points[0], Vector3.ZERO)
			for p in points:
				box = box.expand(p)
			var sides := [box.size.x, box.size.y, box.size.z]
			sides.sort()
			if float(sides[0]) / float(sides[2]) < FactionArt.STICK_ASPECT:
				sticks.append("%s (%.3f x %.3f x %.2f m)" % [unit_id, sides[0], sides[1], sides[2]])
	GameTheme.use(previous)
	assert_true(drawn >= 3, "the units whose weapon IS a part still draw it (%d)" % drawn)
	assert_true(sticks.is_empty(), "weapon parts drawn as slivers: %s" % ", ".join(sticks))


func test_the_stick_rule_refuses_the_law_tanks_stick_and_keeps_real_guns() -> void:
	## Invariant 0: the rule must see the stick that started this (and not a real barrel with a breech).
	var bounds := func(path: String) -> AABB:
		var model := (load(path) as PackedScene).instantiate() as Node3D
		var box := FactionArt.natural_bounds(model)
		model.free()
		return box
	assert_true(FactionArt.is_stray_stick(bounds.call("res://game/theme/factions/law/generated/unit_law_tank_weapon.tscn")),
			"the Law tank's 14-triangle stick is refused")
	for kept in ["unit_ifv_weapon", "unit_scout_weapon", "unit_lancer_weapon"]:
		assert_true(not FactionArt.is_stray_stick(bounds.call("res://game/theme/roster/generated/%s.tscn" % kept)),
				"%s is a gun, not a stick" % kept)


func test_every_hull_trim_removes_only_a_barrel() -> void:
	## A trim box is authored by hand in model space, so check what it takes: triangles (not a stale box), and only
	## something barrel-shaped -- its thicker cross-section side under 15% of its length (the Law tank's tip, muzzle
	## brake and all, is 0.06 x 0.10 x 0.85 m: 12%) -- never a slab of hull.
	for key: String in FactionArt.HULL_TRIMS:
		var parts := key.split("/")
		var model := (load(FactionArt.generated_scene(parts[0], parts[1], "hull")) as PackedScene).instantiate() as Node3D
		var removed := AABB()
		var any := false
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var instance := node as MeshInstance3D
			var to_model := Transform3D.IDENTITY
			var up: Node = instance
			while up != null and up != model:
				to_model = (up as Node3D).transform * to_model
				up = up.get_parent()
			var cut: Variant = FactionArt.split_mesh_boxes(instance.mesh, to_model, FactionArt.HULL_TRIMS[key])[1]
			if cut == null:
				continue
			# Only the vertices its triangles use: the cut keeps the source's whole vertex array (FactionArt.split_mesh).
			for surface in (cut as ArrayMesh).get_surface_count():
				var arrays := (cut as ArrayMesh).surface_get_arrays(surface)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for i: int in arrays[Mesh.ARRAY_INDEX]:
					var p := to_model * verts[i]
					removed = AABB(p, Vector3.ZERO) if not any else removed.expand(p)
					any = true
		model.free()
		assert_true(any, "%s: the trim still takes triangles" % key)
		var sides := [removed.size.x, removed.size.y, removed.size.z]
		sides.sort()
		assert_true(float(sides[1]) <= 0.15 * float(sides[2]),
				"%s: what it takes is barrel-shaped, not a slab of hull (%s)" % [key, removed.size])


## Round 11 (fleet T5; the lead: "Syndicate has some backwards vehicles"). The first test that a nose points at -Z --
## judged by FacingCheck from the drawn geometry, not from the tables that set the orientation. Where the geometry
## cannot decide, a person must have looked: FACING_EYE_CHECKED is that record (unit -> who, when, what they saw).
## A new model the proxy cannot judge fails here until someone looks at `make facing-audit UNITS=<id>` and adds it.
const FACING_EYE_CHECKED := {
	"scout": "fleet, round 11, facing-audit side: the twin guns lead, the roll cage and engine aft",
	"ifv": "fleet, round 11, facing-audit side: the cab leads, the compactor body aft",
	"artillery": "fleet, round 11, facing-audit side + quarter: the cab leads, the rocket rack and outriggers aft",
	"gang_scout": "fleet, round 11, facing-audit side: the exposed engine and front wheels lead, the cab aft",
	"law_scout": "fleet, round 11, facing-audit quarter against law_scout_a.jpg: the push bar and hood lead",
	"law_artillery": "fleet, round 11, facing-audit side: the cab leads, the rocket pod on the bed aft",
}


func _facing(unit_id: String, turned_round := false) -> Dictionary:
	var tank := _spawn(unit_id)
	await wait_physics_frames(2)
	await tree.process_frame
	if turned_round:  # Invariant 0: the same model, drawn tail-first
		(tank.get_node("HullVisual") as Node3D).rotation.y += PI
		tank.set("sync_turret_yaw", PI)
		tank.turret.rotation.y = PI
	var result := FacingCheck.measure(tank, unit_id)
	tank.queue_free()
	return result


func test_every_nose_points_at_minus_z() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var backwards: Array = []
	var unlooked: Array = []
	var forward := 0
	for faction in Units.FACTIONS:
		for unit_id in Units.roster(faction):
			var facing: Dictionary = await _facing(unit_id)
			print("FACING %s %s taper=%+.2f mass=%+.3f" % [unit_id, facing["verdict"], facing["taper"], facing["mass"]])
			match facing["verdict"]:
				"forward":
					forward += 1
				"backwards":
					backwards.append("%s (taper %+.2f, mass %+.3f)" % [unit_id, facing["taper"], facing["mass"]])
				_:
					if not FACING_EYE_CHECKED.has(unit_id):
						unlooked.append(unit_id)
	GameTheme.use(previous)
	assert_true(backwards.is_empty(), "drawn tail-first: %s" % ", ".join(backwards))
	assert_true(unlooked.is_empty(), "the geometry cannot tell which end leads, and nobody has looked: %s" % ", ".join(unlooked))
	assert_true(forward >= 12, "most of the roster is judged by geometry, not by the eye list (%d)" % forward)


func test_the_nose_check_catches_a_model_turned_round() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var caught: Array = []
	for unit_id in ["gang_tank", "law_tank", "syn_lancer", "syn_ifv"]:
		var facing: Dictionary = await _facing(unit_id, true)
		if facing["verdict"] == "backwards":
			caught.append(unit_id)
	GameTheme.use(previous)
	assert_eq(caught.size(), 4, "each of them, drawn tail-first, is called backwards (caught: %s)" % str(caught))
