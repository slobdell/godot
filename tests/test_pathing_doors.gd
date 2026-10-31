extends TestCase
## Round 47 (route R5, C47.8 / R47.12): a route through a blast door is taken only while the door is open now AND at the
## crew's estimated arrival. Stand-in door: one NavigationLink3D across the Locks canal at x = -45 (between the lock and
## the west swing bridge), on the door's own navigation layer bit, as mapkit's doors will be. Until mapkit's BlastDoors
## lands, open/shut is RouteDoors.is_open_fn.

const DOOR := Vector3(-45.0, 0.0, 0.0)
const FROM := Vector3(-50.0, 0.0, 40.0)
const TO := Vector3(-45.0, 0.0, -40.0)


func _arena_with_link() -> Node3D:
	RouteDoors.clear()
	await ArenaFixture.build(self, "locks")
	var probe := Node3D.new()
	add_to_tree(probe)
	var link := NavigationLink3D.new()
	link.start_position = DOOR + Vector3(0.0, 0.0, 12.0)
	link.end_position = DOOR - Vector3(0.0, 0.0, 12.0)
	link.bidirectional = true
	link.navigation_layers = RouteDoors.layer_of(0)
	add_to_tree(link)
	await wait_physics_frames(3)
	return probe


func teardown() -> void:
	RouteDoors.clear()
	RouteDoors.off = false


static func _length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length()
	return total


static func _through_door(points: PackedVector3Array) -> bool:
	for i in range(1, points.size()):
		var on := Geometry3D.get_closest_point_to_segment(DOOR, points[i - 1], points[i])
		if Vector2(on.x - DOOR.x, on.z - DOOR.z).length() <= 3.0:
			return true
	return false


func test_an_unregistered_door_link_is_never_used() -> void:
	var probe := await _arena_with_link()
	var path := Pathing.find_path(probe, FROM, TO)
	assert_true(path.size() >= 2, "a route")
	assert_true(not _through_door(path), "no door registered: layer 1 only, the link is not on it (today's routes)")


func test_an_open_door_is_the_short_way() -> void:
	var probe := await _arena_with_link()
	var shut := _length(Pathing.find_path(probe, FROM, TO))
	assert_eq(RouteDoors.register(&"door_a", DOOR), RouteDoors.layer_of(0), "slot 0's layer")
	var path := Pathing.find_path(probe, FROM, TO)
	assert_true(_through_door(path), "open: the route goes through the door")
	assert_true(_length(path) < shut - 20.0, "and it is the short way (%.1f v %.1f m round)" % [_length(path), shut])
	var reading := Pathing.query(probe, FROM, TO)
	assert_true(bool(reading["reachable"]) and _through_door(reading["points"]), "query reads the same route")


func test_a_shut_door_is_not_taken() -> void:
	var probe := await _arena_with_link()
	RouteDoors.register(&"door_a", DOOR)
	RouteDoors.is_open_fn = func(_id: StringName, _tick: int) -> bool: return false
	var path := Pathing.find_path(probe, FROM, TO)
	assert_true(path.size() >= 2 and not _through_door(path), "shut: round by a crossing")
	assert_true(int(RouteDoors.shut_out.get(&"door_a", 0)) >= 1, "counted")


func test_a_door_that_shuts_before_the_crew_arrives_is_not_taken() -> void:
	var probe := await _arena_with_link()
	RouteDoors.register(&"door_a", DOOR)
	RouteDoors.now_tick = 100
	# Open until tick 110 (a third of a second): a crew 40 m away at 8 m/s arrives at ~ tick 250.
	RouteDoors.is_open_fn = func(_id: StringName, tick: int) -> bool: return tick < 110
	assert_true(not _through_door(Pathing.find_path(probe, FROM, TO)), "it would shut in front of the crew")
	# Open until tick 2000: well after it gets there.
	RouteDoors.is_open_fn = func(_id: StringName, tick: int) -> bool: return tick < 2000
	assert_true(_through_door(Pathing.find_path(probe, FROM, TO)), "open the whole way: taken")


func test_route_off_doors_reads_every_door_open() -> void:
	var probe := await _arena_with_link()
	RouteDoors.register(&"door_a", DOOR)
	RouteDoors.is_open_fn = func(_id: StringName, _tick: int) -> bool: return false
	RouteDoors.off = true
	assert_true(_through_door(Pathing.find_path(probe, FROM, TO)), "--route-off=doors: the clock is ignored")
