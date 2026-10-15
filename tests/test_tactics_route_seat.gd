extends TestCase
## Round 30 (brains B3b, DECLARED): seats beyond a crossing every crew's route goes through are taken in CROSSING order.
## Traced (his bridge, rust t16 seed 2, builder0): when the drill ended the attack-move seated by straight line; the
## westmost crew on the near bank took the westmost far seat while every route crossed the east bridge, so the seats
## crossed and two squadmates gave way to it at the rim. With `via` the crew nearest the crossing takes the seat
## farthest from it. Pure: TacticsFormation.seat on hand-laid positions.


func _members() -> Array:
	# Four crews on the near bank (z = -15), west to east; the crossing is at the EAST end (x = 90).
	return [{"name": "W", "unit": "law_tank", "position": Vector3(55, 0, -14)},
			{"name": "M1", "unit": "law_tank", "position": Vector3(62, 0, -18)},
			{"name": "M2", "unit": "law_tank", "position": Vector3(66, 0, -14)},
			{"name": "E", "unit": "law_tank", "position": Vector3(70, 0, -16)}]


func _seats(opts: Dictionary) -> Dictionary:
	# A line across the far bank (z = 12), heading north, seats spread west to east.
	var offsets: Array[Vector2] = [Vector2(-18, 0), Vector2(-6, 0), Vector2(6, 0), Vector2(18, 0)]
	var base := {"spacing": 8.0, "policy": "exposure"}
	base.merge(opts, true)
	return TacticsFormation.seat(_members(), offsets, Vector3(62, 0, 12), Vector3.BACK, base)


func _seat_x(seats: Dictionary, name: String, opts_anchor := Vector3(62, 0, 12)) -> float:
	var offsets: Array[Vector2] = [Vector2(-18, 0), Vector2(-6, 0), Vector2(6, 0), Vector2(18, 0)]
	return TacticsFormation.to_world(opts_anchor, Vector3.BACK, offsets[int(seats[name])]).x


func test_by_the_crossing_the_crew_nearest_it_takes_the_seat_farthest_from_it() -> void:
	var via := [Vector3(88, 0, -8), Vector3(88, 0, 4)]
	var seats := _seats({"via": via})
	var order := ["E", "M2", "M1", "W"]  # nearest the east crossing first
	var xs: Array = order.map(func(n: String) -> float: return _seat_x(seats, n))
	for i in range(1, xs.size()):
		assert_true(float(xs[i]) > float(xs[i - 1]), "seat order follows crossing order: %s by %s" % [xs, order])
	assert_true(_seat_x(seats, "E") < _seat_x(seats, "W"), "the first across drives farthest along the far bank")


func test_without_a_crossing_the_seating_is_unchanged() -> void:
	assert_eq(_seats({}), _seats({"via": []}), "no crossing, today's seating")


func test_the_control_switch_turns_it_off() -> void:
	assert_true(Element.ROUTE_SEAT_ENABLED, "on by default (--route-seat=off is the control arm)")
