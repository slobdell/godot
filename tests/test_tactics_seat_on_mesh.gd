extends TestCase
## Round 29 (brains B5a): NO SEAT OFF THE MESH. Traffic's T3 lead, traced (the Sumps arrive cell, seed 1, builder0): a
## herringbone slot at (11.1, -73.4), pushed clear of a container by SlotGround, stood 3.6 m off the navmesh. Movement
## reads a goal more than NO_PATH_MARGIN off the mesh as `no_path`, so every crew sent there stuck beside it (crew 4 for
## 13 s), and make-room then traded the slot to the parked squadmate beside it, which read `no_path` there too.
##   - Element.on_mesh moves a point more than NO_PATH_MARGIN off the mesh to its nearest mesh point;
##   - a point on the mesh, or within the margin, is left exactly where it is (no other seat moves);
##   - `--seat-on-mesh=off` (SEAT_ON_MESH_ENABLED false) is the old grounding.

func teardown() -> void:
	Element.SEAT_ON_MESH_ENABLED = true
	super.teardown()


func test_a_seat_off_the_mesh_moves_onto_it() -> void:
	var lab := TacticsLab.create(self, 1, "sumps")
	var tank := lab.unit(Match.Team.GREEN, "Green_M_1", Vector3(0.0, 0.0, -50.0), 0.0, "law_tank")
	await lab.start()
	for frame in 300:
		if Pathing.is_ready(tank):
			break
		await tree.physics_frame
	assert_true(Pathing.is_ready(tank), "the navmesh is ready")
	var map := tank.get_world_3d().navigation_map
	# A point more than the margin off the mesh, found on the arena as loaded here (the traced slot is one in the arrive
	# cell's match; the test's own Sumps may differ in its props, so the stage searches rather than trusting a coordinate).
	var off_mesh := Vector3.INF
	for x in range(-90, 91, 3):
		for z in range(-90, 91, 3):
			var probe := Vector3(x, 0.0, z)
			var near := Pathing.closest_point(map, probe, "test")
			var gap := Vector2(near.x - probe.x, near.z - probe.z).length()
			if gap > Movement.NO_PATH_MARGIN + 0.5 and gap < 8.0:
				off_mesh = probe
				break
		if off_mesh != Vector3.INF:
			break
	assert_true(off_mesh != Vector3.INF, "the stage: a point more than the margin off the mesh")
	if off_mesh == Vector3.INF:
		lab.dispose()
		return
	var moved := Element.on_mesh(tank, off_mesh)
	var after := Pathing.closest_point(map, moved, "test")
	assert_true(Vector2(after.x - moved.x, after.z - moved.z).length() <= 0.1, "moved onto the mesh")
	assert_true(Pathing.query(tank, tank.global_position, moved)["goal_gap_m"] <= Movement.NO_PATH_MARGIN,
			"a crew sent there no longer reads no_path for it")
	# A seat on the mesh is left exactly where it is.
	var on := Pathing.closest_point(map, Vector3(0.0, 0.0, -60.0), "test")
	assert_eq(Element.on_mesh(tank, on), on, "a seat on the mesh does not move")
	Element.SEAT_ON_MESH_ENABLED = false
	assert_eq(Element.on_mesh(tank, off_mesh), off_mesh, "--seat-on-mesh=off: the old grounding")
	lab.dispose()
