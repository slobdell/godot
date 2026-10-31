extends TestCase
## Mapkit (round 47, R47.45's next item): blast doors in a REAL arena -- terminus_doors, the Terminus with his doors across
## the west and east streets. The route goes through a door only while RouteDoors asks for its bit (open now and at the
## crew's arrival), and round by the ring roads otherwise; both doors share one schedule (both sides).

const NORTH := Vector3(-70.0, 0.0, 15.0)
const SOUTH := Vector3(-70.0, 0.0, -15.0)


func teardown() -> void:
	RouteDoors.now_tick = 0
	super.teardown()


static func _length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length()
	return total


func test_the_twin_is_a_candidate_with_two_doors_on_one_schedule() -> void:
	var loaded := Arena.load_layout("terminus_doors")
	assert_true(not loaded.has("error"), "terminus_doors loads: %s" % loaded.get("error", ""))
	if loaded.has("error"):
		return
	assert_true(Arena.CANDIDATES.has("terminus_doors") and Arena.is_fixture(loaded["layout"]), "a candidate: played by name, never dealt")
	var doors := BlastDoors.from_layout(loaded["layout"], 12933)
	assert_eq(doors.ids(), PackedStringArray(["west_gate", "east_gate"]), "west and east")
	var same := true
	for tick in range(0, SimClock.ticks(300.0), 9):
		same = same and doors.open_at("west_gate", tick) == doors.open_at("east_gate", tick)
	assert_true(same, "one schedule: both sides meet the same doors")


func test_the_route_takes_the_door_only_with_its_bit() -> void:
	var arena := await ArenaFixture.build(self, "terminus_doors")
	await wait_physics_frames(3)
	var map := arena.get_world_3d().navigation_map
	var bit: int = (arena.doors.links["west_gate"] as NavigationLink3D).navigation_layers
	assert_eq(bit, RouteDoors.layer_of(0), "the west door is route's slot 0 (registered by ArenaDoors)")
	var round := _length(NavigationServer3D.map_get_path(map, NORTH, SOUTH, true, RouteDoors.BASE_LAYERS))
	var through := _length(NavigationServer3D.map_get_path(map, NORTH, SOUTH, true, RouteDoors.BASE_LAYERS | bit))
	assert_true(through < 45.0, "with the door's bit: straight down the street (%.0f m)" % through)
	assert_true(round > through + 40.0, "without it: round by the ring roads (%.0f m)" % round)
	# RouteDoors asks for the bit only while BlastDoors says open now and at arrival (C47.8).
	var probe := Node3D.new()
	add_to_tree(probe)
	var first := BlastDoors.active.next_change("west_gate", 0)
	RouteDoors.now_tick = 0
	assert_true(RouteDoors.mask(probe, NORTH) & bit != 0, "open now and at arrival: the bit is in the mask")
	RouteDoors.now_tick = first + 5
	assert_true(RouteDoors.mask(probe, NORTH) & bit == 0, "shut: the bit is out")
	RouteDoors.now_tick = first - 3
	assert_true(RouteDoors.mask(probe, Vector3(-70.0, 0.0, 120.0)) & bit == 0,
			"open now but shut by the time a crew 120 m away arrives: out")
