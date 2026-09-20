extends TestCase
## Feel X1/X2, contract S2 (round 9, the lead twice: "the semi trucks for the road gangs are still one long box
## itself of a truck / trailer combination"). The War Rig's trailer is cut out of the approved hull mesh at the fifth
## wheel and yawed by tractor-trailer kinematics. The cut must lose nothing and double nothing, the gun must ride the
## trailer, the hinge must obey the law it claims, and the jackknife limit must be MEASURED against the mesh rather
## than chosen -- the cab must never be inside the tanker.

const RIG := "gang_tank"
const VOXEL := 0.03  # model space; the rig is 0.85 x 1.35 x 3.60 m, so ~28 x 45 x 120 cells


## The cut only happens under a Tank (the part reads the unit id from it), so a VisualSlot on its own is not the
## thing under test -- build a real, non-simulating tank the way facing_audit.gd does.
func _hull_part(unit_id: String) -> Node3D:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var tank: Node3D = (load("res://game/tank/tank.tscn") as PackedScene).instantiate()
	tank.set("unit_id", unit_id)
	tank.set("simulate", false)
	add_to_tree(tank)
	GameTheme.use(previous)
	for node in tank.find_children("*", "VisualSlot", true, false):
		var visual := (node as Node).get("visual") as Node3D
		if visual != null and visual.get("part") == "hull":
			return visual
	return null


func test_the_rig_has_a_trailer_cut_and_other_units_do_not() -> void:
	var cut := FactionArt.trailer_cut(RIG)
	assert_true(not cut.is_empty(), "the War Rig is cut at the fifth wheel")
	assert_true((cut["boxes"] as Array).size() >= 2,
			"the cut is not a plane: the tanker overhangs the tractor's drive tandem")
	for unit_id in ["tank", "gang_scout", "gang_support", "law_tank", "syn_tank"]:
		assert_true(FactionArt.trailer_cut(unit_id).is_empty(), "%s is one rigid body" % unit_id)


func test_the_cut_loses_nothing_and_doubles_nothing() -> void:
	## The approved model is not regenerated: every triangle ends up on exactly one of the two pieces.
	var model := AssetIO.load_glb("game/theme/factions/gangs/generated/unit_gangs_tank_hull.glb")
	assert_true(model != null, "the War Rig's hull model loads")
	add_to_tree(model)
	var whole := _triangles(model)
	var boxes: Array = FactionArt.trailer_cut(RIG)["boxes"]
	var tractor := 0
	var trailer := 0
	var union := AABB()
	var first := true
	for instance in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (instance as MeshInstance3D).mesh
		if mesh == null:
			continue
		var pieces := FactionArt.split_mesh_boxes(mesh, _to_model(instance as MeshInstance3D, model), boxes)
		for i in 2:
			if pieces[i] == null:
				continue
			var count := _mesh_triangles(pieces[i])
			if i == 0:
				tractor += count
			else:
				trailer += count
			union = (pieces[i] as Mesh).get_aabb() if first else union.merge((pieces[i] as Mesh).get_aabb())
			first = false
	assert_eq(tractor + trailer, whole, "every triangle is on exactly one piece")
	assert_true(tractor > 1000 and trailer > 1000,
			"both pieces are real geometry (tractor %d, trailer %d triangles)" % [tractor, trailer])
	var uncut := FactionArt.natural_bounds(model)
	assert_near(union.position.z, uncut.position.z, 0.01, "the merged pieces start where the uncut model starts")
	assert_near(union.end.z, uncut.end.z, 0.01, "and end where it ends: a hinge at zero angle IS the original mesh")
	assert_near(union.size.y, uncut.size.y, 0.01, "nothing lost off the top or the bottom")


func test_the_trailer_is_the_tanker_and_the_tractor_keeps_its_cab_and_drive_axles() -> void:
	## The cut box is read off the mesh (make assets-profile): cab rear wall at model z -0.19, tanker front cap at
	## -0.01, drive tandem axles at +0.19 and +0.39, trailer bogie at +1.55. Assert the split lands on those features
	## rather than merely producing two pieces.
	var boxes: Array = FactionArt.trailer_cut(RIG)["boxes"]
	var cab := Vector3(0.0, 0.9, -0.60)  # inside the cab
	var drive_wheel := Vector3(0.28, 0.24, 0.29)  # the tandem, under the fifth wheel
	var barrel_front := Vector3(0.0, 0.75, 0.10)  # the tanker's front section, over those wheels
	var bogie := Vector3(0.25, 0.24, 1.55)  # the trailer's own axle
	assert_true(not FactionArt._in_any(boxes, cab), "the cab stays on the tractor")
	assert_true(not FactionArt._in_any(boxes, drive_wheel), "the drive tandem stays on the tractor")
	assert_true(FactionArt._in_any(boxes, barrel_front), "the tanker's front section is trailer, wheels or no wheels")
	assert_true(FactionArt._in_any(boxes, bogie), "the trailer's own bogie is trailer")


func test_the_jackknife_limit_clears_the_cab_on_the_real_mesh() -> void:
	## MEASURED, not chosen. Voxelise everything FORWARD of the tanker's front cap -- the cab, the stacks, the hood,
	## the plow, the fuel tank -- swing the trailer about the fifth wheel a degree at a time, and find the last angle
	## at which no trailer voxel is inside it. The shipped constant must be below that, with a margin; if the model
	## or the cut boxes change, this fails instead of the cab ending up inside the tanker.
	##
	## What it deliberately does NOT guard: the cut faces at the fifth wheel are coincident, because the rig is one
	## mesh and the chassis rails run through the cut. Any articulation at all makes those few centimetres of rail
	## overlap. That is invisible -- it is under the barrel and between the drive wheels -- and it is the same
	## accepted cost as the collider: contract S2 says the trailer is art.
	var model := AssetIO.load_glb("game/theme/factions/gangs/generated/unit_gangs_tank_hull.glb")
	add_to_tree(model)
	var cut := FactionArt.trailer_cut(RIG)
	var boxes: Array = cut["boxes"]
	var pivot: Vector3 = cut["pivot"]
	var cap: float = (boxes[1] as AABB).position.z - 0.01  # the tanker's front cap: the cut's forward edge
	var tractor := {}
	var trailer: Array[Vector3] = []
	for centroid in _centroids(model):
		if FactionArt._in_any(boxes, centroid):
			trailer.append(centroid - pivot)
		elif centroid.z < cap:
			tractor[_cell(centroid)] = true
	assert_true(trailer.size() > 500 and tractor.size() > 500, "both pieces voxelise")
	var clear := 0
	for degrees in range(1, 91):
		var basis := Basis(Vector3.UP, deg_to_rad(float(degrees)))
		var hit := false
		for point in trailer:
			if tractor.has(_cell(basis * point + pivot)):
				hit = true
				break
		if hit:
			break
		clear = degrees
	print("TRAILER_JACKKNIFE measured clear to %d deg (shipped %.0f)" % [clear, float(cut["jackknife_deg"])])
	assert_true(float(cut["jackknife_deg"]) <= float(clear) - 2.0,
			"the shipped jackknife limit (%.0f deg) leaves the cab clear, measured to %d deg on the mesh"
					% [float(cut["jackknife_deg"]), clear])
	assert_true(float(cut["jackknife_deg"]) >= 25.0,
			"a hinge that bends less than 25 deg is not worth drawing (%.0f)" % float(cut["jackknife_deg"]))


func test_the_trailer_follows_the_tractor_and_settles_on_a_straight() -> void:
	var limit := deg_to_rad(60.0)
	var yaw := deg_to_rad(40.0)  # starting well out of line
	for step in 400:
		yaw = FactionArt.trailer_follow(yaw, 0.0, 10.0, 5.0, 1.0 / 60.0, limit)
	assert_near(yaw, 0.0, deg_to_rad(0.5), "driving straight pulls the trailer into line")


func test_a_constant_radius_turn_settles_at_the_off_tracking_angle() -> void:
	## Steady state on a circle of radius R is asin(L / R) of lag. This is the law's own closed form and the reason
	## a semi cuts the corner: assert the integrator reproduces it rather than merely "lagging".
	var wheelbase := 5.0
	var radius := 20.0
	var speed := 8.0
	var delta := 1.0 / 60.0
	var tractor := 0.0
	var trailer := 0.0
	for step in 3000:
		tractor += (speed / radius) * delta  # a left turn: yaw increases (orientation.md trip-up 2)
		trailer = FactionArt.trailer_follow(trailer, tractor, speed, wheelbase, delta, deg_to_rad(80.0))
	var lag := wrapf(tractor - trailer, -PI, PI)
	assert_near(lag, asin(wheelbase / radius), deg_to_rad(0.5),
			"steady-state off-tracking is asin(L/R) = %.1f deg" % rad_to_deg(asin(wheelbase / radius)))


func test_reversing_diverges_and_is_caught_by_the_jackknife_limit() -> void:
	var limit := deg_to_rad(38.0)
	var yaw := deg_to_rad(3.0)  # the tiniest kink, as a real reversing trailer has
	for step in 600:
		yaw = FactionArt.trailer_follow(yaw, 0.0, -6.0, 5.0, 1.0 / 60.0, limit)
	assert_near(yaw, limit, 0.001, "in reverse the trailer diverges -- that is jackknifing -- and the limit holds it")


func test_the_hinge_is_clamped_however_hard_it_is_driven() -> void:
	## A pathological delta (a frame spike) must not throw the trailer round the back of the cab.
	var limit := deg_to_rad(38.0)
	var tractor := deg_to_rad(170.0)
	var yaw := FactionArt.trailer_follow(0.0, tractor, 60.0, 0.5, 1.0, limit)
	assert_true(absf(wrapf(yaw - tractor, -PI, PI)) <= limit + 0.001, "clamped to the limit, not wrapped past the cab")


func test_the_drawn_rig_carries_a_trailer_pivot_and_the_gun_rides_it() -> void:
	var hull := _hull_part(RIG)
	assert_true(hull != null, "the War Rig's hull part builds")
	var pivot := hull.get("trailer_pivot") as Node3D
	assert_true(pivot != null, "the hull part has a TrailerPivot")
	assert_true(pivot.get_node_or_null("Trailer") != null, "with the tanker under it")
	var gun := hull.get("gun_pivot") as Node3D
	assert_true(gun != null, "the naval gun is still cut out of the hull")
	assert_true(pivot.is_ancestor_of(gun),
			"the gun is mounted on the tanker, so its pivot hangs under the trailer's, not the hull's")
	assert_near(hull.call("articulation"), 0.0, 0.001, "at rest the hinge is straight: the approved model, unmoved")


func test_a_unit_without_a_trailer_is_untouched() -> void:
	var hull := _hull_part("law_tank")
	assert_true(hull != null, "the Law tank's hull part builds")
	assert_true(hull.get("trailer_pivot") == null, "no trailer pivot on a unit with no trailer cut")
	assert_eq(hull.get_node("Model").get_node_or_null("TrailerPivot"), null, "and nothing named like one")
	assert_true((hull.get("gun_pivot") as Node3D) == null, "and its gun is a real turret part, uncut")


# ---- helpers ------------------------------------------------------------------------------

func _cell(point: Vector3) -> Vector3i:
	return Vector3i(floori(point.x / VOXEL), floori(point.y / VOXEL), floori(point.z / VOXEL))


func _to_model(instance: MeshInstance3D, model: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var node: Node = instance
	while node != null and node != model:
		if node is Node3D:
			result = (node as Node3D).transform * result
		node = node.get_parent()
	return result


func _mesh_triangles(mesh: Mesh) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		total += (indices.size() if indices != null and not indices.is_empty()
				else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total


func _triangles(model: Node3D) -> int:
	var total := 0
	for instance in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (instance as MeshInstance3D).mesh
		if mesh != null:
			total += _mesh_triangles(mesh)
	return total


func _centroids(model: Node3D) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		var to_model := _to_model(instance, model)
		for s in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices == null or indices.is_empty():
				indices = PackedInt32Array()
				indices.resize(verts.size())
				for i in verts.size():
					indices[i] = i
			for t in range(0, indices.size() - 2, 3):
				result.append(to_model * ((verts[indices[t]] + verts[indices[t + 1]] + verts[indices[t + 2]]) / 3.0))
	return result
