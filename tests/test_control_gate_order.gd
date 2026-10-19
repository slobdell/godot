extends TestCase
## Round 34 (planner's O5, the Locks route cells): a route leg whose squads all come through one gate is dealt FIRST
## THROUGH, FARTHEST ALONG (SelectionSquads.gate_order): the squad reaching the gate first takes the place farthest past
## it, the gate-mouth place goes last, so nobody parks in the mouth of the way the others still need.
## The fake ground: a street from the north down to a gate at (0, 25), then a quay running east-west at z = 18.

const GATE := Vector3(0, 0, 25)


func teardown() -> void:
	SelectionSquads.GATE_ORDER = true
	super.teardown()


## Every path from the north (z > 25) comes down the street to the gate, then along the quay.
static func _path(a: Vector3, b: Vector3) -> PackedVector3Array:
	if a.z > GATE.z and b.z < GATE.z:
		# Down the street (x = 0) from wherever the squad is on it, through the gate, then along the quay.
		return PackedVector3Array([a, Vector3(0, 0, minf(a.z, 40.0)), GATE, b])
	return PackedVector3Array([a, b])


static func _drive(a: Vector3, b: Vector3) -> float:
	var p := _path(a, b)
	var d := 0.0
	for i in range(1, p.size()):
		d += p[i - 1].distance_to(p[i])
	return d


func test_the_first_through_the_gate_takes_the_farthest_place() -> void:
	# Three places along the quay: the gate's mouth, 35 m west, 70 m west.
	var places: Array[Vector3] = [Vector3(-70, 0, 18), Vector3(2, 0, 18), Vector3(-35, 0, 18)]
	# Squad 0 waits nearest the gate, squad 2 farthest back up the street.
	var starts := [Vector3(0, 0, 45), Vector3(0, 0, 70), Vector3(0, 0, 95)]
	var dealt := SelectionSquads.gate_order(places, starts, _path, _drive)
	assert_eq(dealt[0], Vector3(-70, 0, 18), "first through: the farthest place")
	assert_eq(dealt[1], Vector3(-35, 0, 18), "second: the middle")
	assert_eq(dealt[2], Vector3(2, 0, 18), "last: the gate's mouth")


func test_without_a_shared_gate_the_places_stand() -> void:
	var places: Array[Vector3] = [Vector3(-70, 0, 18), Vector3(2, 0, 18)]
	var starts := [Vector3(-70, 0, 10), Vector3(2, 0, 10)]  # already south of the gate: straight lines, nothing shared
	assert_eq(SelectionSquads.gate_order(places, starts, _path, _drive), places, "no gate: unchanged")


func test_a_place_in_the_gates_mouth_goes_to_the_last_squad() -> void:
	var places: Array[Vector3] = [Vector3(0, 0, 24), Vector3(-70, 0, 18)]  # one place in the mouth
	var starts := [Vector3(0, 0, 45), Vector3(0, 0, 70)]
	var dealt := SelectionSquads.gate_order(places, starts, _path, _drive)
	assert_eq(dealt[1], Vector3(0, 0, 24), "the mouth to the squad that comes through last")


func test_the_switch_off_is_round_33s_dealing() -> void:
	SelectionSquads.GATE_ORDER = false
	var places: Array[Vector3] = [Vector3(-70, 0, 18), Vector3(2, 0, 18), Vector3(-35, 0, 18)]
	var starts := [Vector3(0, 0, 45), Vector3(0, 0, 70), Vector3(0, 0, 95)]
	assert_eq(SelectionSquads.gate_order(places, starts, _path, _drive), places, "--gate-order=off: unchanged")
