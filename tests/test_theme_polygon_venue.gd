extends TestCase
## Round 7 (arena's contract D, the hexagon): the venue follows the perimeter polygon arena builds its colliders from,
## and the stands' profile is published as data for control's cutaway.


func _dressing(shape: Dictionary) -> Node3D:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var dressing: Node3D = add_to_tree((load(GameTheme.CYBERPUNK_SLOTS["arena.dressing"]) as PackedScene).instantiate())
	GameTheme.use(previous)
	dressing.call("setup", {"name": "hex", "half_size": 120.0, "obstacles": [], "shape": shape})
	return dressing


func test_a_hexagon_gets_stands_on_every_side_facing_in_and_outside_the_wall() -> void:
	var dressing := _dressing({"kind": "hexagon"})
	var structures: Node3D = dressing.get("structures")
	var stands := structures.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Stands"))
	var edge := ArenaShape.edge_length("hexagon", 120.0)
	var per_side := int(edge / 23.07)
	assert_eq(stands.size(), 6 * per_side, "%d modules on each of six sides (a %.1f m side)" % [per_side, edge])
	for node in stands:
		var at := Vector2((node as Node3D).position.x, (node as Node3D).position.z)
		assert_true(not ArenaShape.contains("hexagon", 120.0, at), "every module stands outside the wall (%s)" % at)
		var facing := -(node as Node3D).transform.basis.z
		# Its side's inward normal: toward the centre, though not straight at it from a module along the side.
		assert_true(facing.dot(-Vector3(at.x, 0.0, at.y).normalized()) > 0.8, "and faces into the arena")
		var yaw := snappedf(fposmod(rad_to_deg((node as Node3D).rotation.y), 360.0), 1.0)
		assert_true(int(yaw) % 60 == 0, "square to its own side (one of six facings, %.0f)" % yaw)
	var walls := structures.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Perimeter"))
	assert_eq(walls.size(), 6, "one wall per side")
	var crowd: CrowdSystem = dressing.get("crowd")
	assert_true(crowd != null and crowd.seats.size() > 1000, "and the stands are full")


func test_a_gate_span_gets_its_gate_and_no_stands() -> void:
	var edge := ArenaShape.edge_length("hexagon", 120.0)
	var gate_from := edge / 2.0 - 15.0
	var gate_to := edge / 2.0 + 15.0
	var spans := [{"kind": "stands", "to_m": gate_from}, {"kind": "gate", "to_m": gate_to}, {"kind": "stands", "to_m": edge}]
	var authored := []
	for i in 6:
		authored.append({"spans": spans if i % 3 == 0 else [{"kind": "stands", "to_m": edge}]})
	var dressing := _dressing({"kind": "hexagon", "edges": authored})
	var structures: Node3D = dressing.get("structures")
	var gates := structures.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Gate"))
	assert_eq(gates.size(), 2, "a gate on each of the two sides that asked for one (point-symmetric)")
	var edges := ArenaShape.edges({"kind": "hexagon", "edges": authored}, 120.0)
	var a: Vector2 = edges[0]["from"]
	var along: Vector2 = ((edges[0]["to"] as Vector2) - a).normalized()
	for node in structures.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Stands")):
		var at := Vector2((node as Node3D).position.x, (node as Node3D).position.z)
		var t := (at - a).dot(along)
		var off_edge := absf((at - a).dot(Vector2(-along.y, along.x)))
		if off_edge < 30.0:  # a module behind edge 0
			assert_true(t + 11.5 <= gate_from + 0.01 or t - 11.5 >= gate_to - 0.01, "no module in the gate's span (t %.1f)" % t)


func test_the_stands_profile_is_published_from_the_model_the_dressing_places() -> void:
	var points := StandsProfile.points()
	assert_true(points.size() >= 4, "several points out from the wall")
	assert_eq(points[0], Vector2(2.0, 3.0), "starting with the wall's own top")
	for i in range(1, points.size()):
		assert_true(points[i].x > points[i - 1].x and points[i].y >= points[i - 1].y, "going out, never lower")
	assert_near(points[1].x, 2.0 + StandsProfile.GAP + 2.0, 0.6, "the first slice just past the gap behind the wall")
	assert_near(points[points.size() - 1].x, 22.2, 1.5, "the back as control measured it by hand (22.2 m)")
	assert_near(points[points.size() - 1].y, 15.7, 0.3, "and 15.7 m tall")
