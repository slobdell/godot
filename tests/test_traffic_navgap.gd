extends TestCase
## Round 32 (traffic, C32.6): the default arena's "navmesh gap". Round 31's reach probe read the default arena's
## (-25.7, 7.3), where test_control_queued_task's Green_Alpha_3 stood held, as 8.2 m off the navmesh (snapping to
## (-17.5, 7.3)). That reading was TERMINUS's navmesh: the probe built its default-arena lab after a Terminus lab in the
## same process and asked before the map held the new arena's own regions (ArenaFixture's round-6 trap: `Pathing.is_ready`
## answers from the previous arena's map). With the default arena's own navigation synced, the spot is ON the mesh,
## 0.45 m north of Crate_7's carved edge (the 4.5 m crate at (-24, 12) plus the bake's 2 m agent radius). No bake hole.
## The pictures and the bake's inputs: references/round32/traffic/navgap_*.png, tests/traffic/navgap_probe.gd.

const SPOT := Vector3(-25.7, 0.0, 7.3)


func test_the_default_arenas_alpha_3_spot_is_on_its_own_navmesh() -> void:
	var arena := await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var map := arena.get_world_3d().navigation_map
	var closest := NavigationServer3D.map_get_closest_point(map, SPOT)
	var gap := Vector2(closest.x - SPOT.x, closest.z - SPOT.z).length()
	print("MEASURE navgap default spot gap_m %.2f closest (%.2f, %.2f)" % [gap, closest.x, closest.z])
	assert_true(gap <= 1.0, "the default arena's (-25.7, 7.3) is within 1 m of its navmesh (%.2f m to %s)" % [gap, closest])
	# And the spot reaches both of the test's shift-waypoints.
	for goal: Vector3 in [Vector3(-35.0, 0.0, 10.0), Vector3(-20.0, 0.0, 25.0)]:
		assert_true(ArenaFixture.route_arrives(arena, SPOT, goal), "a route from the spot reaches %s" % goal)


func test_terminus_at_the_same_spot_is_the_8_m_reading() -> void:
	# The round-31 number belongs to this map: a Terminus block stands there.
	var arena := await ArenaFixture.build(self, "terminus")
	var closest := NavigationServer3D.map_get_closest_point(arena.get_world_3d().navigation_map, SPOT)
	var gap := Vector2(closest.x - SPOT.x, closest.z - SPOT.z).length()
	assert_near(gap, 8.2, 0.3, "Terminus's navmesh at (-25.7, 7.3) is the probe's 8.2 m (%.2f to %s)" % [gap, closest])
