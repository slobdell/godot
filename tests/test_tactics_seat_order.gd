extends TestCase
## Round 23 (brains, stretch b): the travel seating keeps a column's order AND never crosses a diagonal pair. Orders'
## known issue 3 (round 22): within one line a seat swap crossed two of his six APCs (the interleaved probe on the
## Sumps: Green_Alpha_1 and Green_Alpha_2 of the dealt line 4, their seats at x ~115 facing east while they approached
## from the south-west). The squared cost preferred the crossing pair by 0.5 %; the sum prefers the straight pair by
## 0.28 m. Now the sum decides and the squared term breaks its ties (TacticsFormation.TRAVEL_SUM_FIRST).

const SPACING := 14.0


func teardown() -> void:
	TacticsFormation.TRAVEL_SUM_FIRST = true
	super.teardown()


static func _cross(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> bool:
	return Geometry2D.segment_intersects_segment(Vector2(a0.x, a0.z), Vector2(a1.x, a1.z), Vector2(b0.x, b0.z), Vector2(b1.x, b1.z)) != null


## His line 4 as the probe seated it: three APCs, a line of three facing east, anchored where the probe's slots were.
func _his_line(sum_first: bool) -> Dictionary:
	TacticsFormation.TRAVEL_SUM_FIRST = sum_first
	var members: Array = [{"name": "Green_Alpha_1", "position": Vector3(66.1, 0, -72.3), "unit": "law_ifv"},
			{"name": "Green_Alpha_2", "position": Vector3(55.9, 0, -80.1), "unit": "law_ifv"},
			{"name": "Green_Bravo_1", "position": Vector3(63.1, 0, -64.2), "unit": "law_ifv"}]
	var offsets := TacticsFormation.offsets("line", 3, SPACING)
	var anchor := Vector3(115.1, 0, 14.9)
	var heading := Vector3(1, 0, 0)  # the slots ran (113, 23.7) -> (117, 6): across z, facing east
	var seats := TacticsFormation.seat(members, offsets, anchor, heading, {"policy": "travel", "spacing": SPACING})
	var to := {}
	for member: Dictionary in members:
		to[member["name"]] = TacticsFormation.to_world(anchor, heading, offsets[int(seats[member["name"]])])
	var crossings := 0
	for i in members.size():
		for j in range(i + 1, members.size()):
			if _cross(members[i]["position"], to[members[i]["name"]], members[j]["position"], to[members[j]["name"]]):
				crossings += 1
	return {"seats": seats, "crossings": crossings}


func test_his_diagonal_pair_no_longer_crosses() -> void:
	var old := _his_line(false)
	var now := _his_line(true)
	print("MEASURE seat_order his line 4: crossings squared %d -> sum-first %d; seats %s -> %s" % [old["crossings"], now["crossings"], old["seats"], now["seats"]])
	assert_eq(int(old["crossings"]), 1, "round 10's squared cost crossed the pair (the probe's finding)")
	assert_eq(int(now["crossings"]), 0, "the sum first: no crossing")


## Round 10's reason for the squared cost, kept: a column moving straight along its own axis keeps its order (every
## matching has the same total length; the tie-break keeps the head at the head).
func test_a_column_moving_along_its_axis_keeps_its_order() -> void:
	TacticsFormation.TRAVEL_SUM_FIRST = true
	var members: Array = []
	for i in 4:
		members.append({"name": "C%d" % i, "position": Vector3(0, 0, -32 + i * 12), "unit": "law_tank"})  # C0 at the head (-z is forward)
	var offsets := TacticsFormation.offsets("column", 4, 12.0)
	var seats := TacticsFormation.seat(members, offsets, Vector3(0, 0, -60), Vector3(0, 0, -1), {"policy": "travel", "spacing": 12.0})
	var order: Array = []
	for i in 4:
		order.append(int(seats["C%d" % i]))
	var expected: Array = []
	for i in 4:
		expected.append(i)
	# Slot indices run head first for a column.
	var head_first := true
	for i in 3:
		head_first = head_first and (offsets[i].y < offsets[i + 1].y)
	assert_true(head_first, "column offsets run head first: %s" % [offsets])
	assert_eq(order, expected, "the head keeps the head: %s" % seats)


## The sum-first seating is still the least total driving (no crossing on random starts, as test_formation_slots).
func test_sum_first_paths_never_cross() -> void:
	TacticsFormation.TRAVEL_SUM_FIRST = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for trial in 20:
		var members: Array = []
		for i in 5:
			members.append({"name": "U%d" % i, "position": Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60)), "unit": "law_ifv"})
		var shape: String = ["wedge", "line", "column"][trial % 3]
		var offsets := TacticsFormation.offsets(shape, 5, 12.0)
		var anchor := Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(80, 120))
		var seats := TacticsFormation.seat(members, offsets, anchor, Vector3(0, 0, 1), {"policy": "travel", "spacing": 12.0})
		for a in 5:
			for b in range(a + 1, 5):
				var ta := TacticsFormation.to_world(anchor, Vector3(0, 0, 1), offsets[int(seats["U%d" % a])])
				var tb := TacticsFormation.to_world(anchor, Vector3(0, 0, 1), offsets[int(seats["U%d" % b])])
				assert_true(not _cross(members[a]["position"], ta, members[b]["position"], tb), "trial %d (%s): U%d and U%d cross" % [trial, shape, a, b])
