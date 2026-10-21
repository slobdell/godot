extends TestCase
## Round 37 (cover, K3 / C37.4): TacticalQuery.low_cover_seat, the hull-down seat orders asks for ONCE when it lays a
## halt seat. Pure geometry here (no navmesh: `node` null); the seat it gives must be one the damage rule counts.

const HULL := Vector3(3.0, 1.5, 4.0)


func _barricade(at: Vector2, rotation_deg := 0.0) -> Dictionary:
	return {"position": at, "size": [6.0, 0.9, 0.8], "rotation_deg": rotation_deg, "height": 0.9, "type": "barricade"}


func test_the_seat_is_behind_the_barricade_nose_a_metre_off_it() -> void:
	var map := CoverMap.from_features([_barricade(Vector2(0.0, -6.0))])
	var seat: Variant = TacticalQuery.low_cover_seat(map, Vector3.ZERO, Vector3(0, 0, -1), 4.0, HULL)
	assert_true(seat != null, "a barricade 5.6 m ahead of a crew facing it gives a seat")
	if seat == null:
		return
	# Near side at z = -5.6; nose 1 m short of it; the hull's centre half its 4 m length further back.
	assert_near((seat as Vector3).z, -2.6, 0.001, "nose SEAT_GAP_M short of the near side")
	assert_true(absf((seat as Vector3).x) <= 1.5 + 0.001, "the whole 3 m width behind the 6 m barricade")
	var screen := map.low_screen(Vector2(seat.x, seat.z), Vector2(0, -1), Vector2(0, -1), HULL)
	assert_near(float(screen["fraction"]), 0.9 / 1.5, 0.001, "the damage rule reads the seat as hull-down")


func test_the_same_question_gets_the_same_seat() -> void:
	var map := CoverMap.from_features([_barricade(Vector2(0.0, -6.0)), _barricade(Vector2(3.0, -6.0), 20.0)])
	var a: Variant = TacticalQuery.low_cover_seat(map, Vector3(0.7, 0, 0.3), Vector3(0.2, 0, -1), 4.0, HULL)
	var b: Variant = TacticalQuery.low_cover_seat(map, Vector3(0.7, 0, 0.3), Vector3(0.2, 0, -1), 4.0, HULL)
	assert_eq(a, b, "deterministic")


func test_no_seat_beyond_the_shift() -> void:
	var map := CoverMap.from_features([_barricade(Vector2(0.0, -6.0))])
	assert_eq(TacticalQuery.low_cover_seat(map, Vector3.ZERO, Vector3(0, 0, -1), 2.0, HULL), null,
			"the seat is 2.6 m away: more than a 2 m shift")


func test_no_seat_when_the_cover_is_on_the_wrong_side() -> void:
	var map := CoverMap.from_features([_barricade(Vector2(0.0, -6.0))])
	assert_eq(TacticalQuery.low_cover_seat(map, Vector3.ZERO, Vector3(0, 0, 1), 4.0, HULL), null,
			"the threat is the other way: the barricade would be behind the crew")


func test_tall_cover_gives_no_hull_down_seat() -> void:
	var map := CoverMap.from_features([{"position": Vector2(0.0, -6.0), "size": [6.0, 3.0, 0.8], "rotation_deg": 0.0,
			"height": 3.0}])
	assert_eq(TacticalQuery.low_cover_seat(map, Vector3.ZERO, Vector3(0, 0, -1), 4.0, HULL), null,
			"a 3 m wall is all-or-nothing cover (find_cover's business), not a hull-down seat")


func test_a_seat_a_hull_cannot_fit_is_skipped() -> void:
	# A container standing where the seat would be: no seat overlaps it.
	var map := CoverMap.from_features([_barricade(Vector2(0.0, -6.0)),
			{"position": Vector2(0.0, -2.0), "size": [6.06, 2.59, 2.44], "rotation_deg": 0.0, "height": 2.59}])
	var seat: Variant = TacticalQuery.low_cover_seat(map, Vector3.ZERO, Vector3(0, 0, -1), 4.0, HULL)
	if seat != null:
		assert_true(not map.path_blocked(Vector2(seat.x, seat.z - 0.5), Vector2(seat.x, seat.z + 0.5), 1.5),
				"whatever seat it found does not overlap the container")
	else:
		assert_true(true, "no room behind the barricade: no seat")


func test_a_hull_wider_than_short_cover_centres_on_it() -> void:
	var map := CoverMap.from_features([{"position": Vector2(0.0, -6.0), "size": [2.0, 0.9, 0.8], "rotation_deg": 0.0,
			"height": 0.9}])
	var seat: Variant = TacticalQuery.low_cover_seat(map, Vector3.ZERO, Vector3(0, 0, -1), 4.0, HULL)
	assert_true(seat != null and absf((seat as Vector3).x) < 0.001, "a 3 m hull behind 2 m of cover sits centred on it")
