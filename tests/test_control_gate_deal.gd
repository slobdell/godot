extends TestCase
## Round 35 (orders D5, C35.5): an in-between waypoint's GATE is dealt by where each squad's previous leg ends: the squads
## nearest the gate (farthest along the approach) take its front rank, left to right within a rank; ranks behind it step
## by the shape squads travel in, not their halt. Planner's Locks 5-squad route: the middle squad was dealt the gate's far
## end and two squads gate places 11-15 m BEHIND their previous leg; they crossed and jammed ~55 s (all in 43.3 s, laptop
## GDScript; 16.9 s with the deal). Pure: RtsControls.gate_anchors on stub ground.

const GATE := Vector3(0, 0, 0)
const AHEAD := Vector3(0, 0, -1)


var _was := RtsControls.GATE_DEAL


func teardown() -> void:
	RtsControls.GATE_DEAL = _was
	super.teardown()


func _drive(a: Vector3, b: Vector3) -> float:
	return a.distance_to(b)


func _never(_a: Vector3, _b: Vector3) -> bool:
	return false


## Squads 40 m wide, 55 m deep halted, 20 m deep travelling (the stub ground is open: two fit abreast).
func _blocks(centres: Array) -> Array:
	var out: Array = []
	for c: Vector3 in centres:
		out.append({"center": c, "width": 40.0, "depth": 55.0, "travel_depth": 20.0})
	return out


func test_nearest_the_gate_goes_first() -> void:
	RtsControls.GATE_DEAL = true  # parked OFF by default (D5's re-read)
	# Three squads coming up one street at 20, 50 and 80 m behind the gate, listed out of order.
	var blocks := _blocks([Vector3(0, 0, 80), Vector3(0, 0, 20), Vector3(0, 0, 50)])
	var gate := RtsControls.gate_anchors(blocks, GATE, AHEAD, _drive, _never, func(p: Vector3) -> Vector3: return p)
	# The street fits two abreast: the two nearest (20 m, 50 m) take the front rank, the farthest (80 m) the one behind.
	assert_near(gate[1].z, gate[2].z, 0.01, "the two nearest stand in the front rank (%s)" % [gate])
	assert_true(gate[0].z > gate[1].z + 1.0, "the farthest stands behind them (%s)" % [gate])


func test_ranks_step_by_the_travel_shape() -> void:
	RtsControls.GATE_DEAL = true
	var blocks := _blocks([Vector3(-30, 0, 20), Vector3(30, 0, 40), Vector3(0, 0, 60)])
	var gate := RtsControls.gate_anchors(blocks, GATE, AHEAD, _drive, _never, func(p: Vector3) -> Vector3: return p)
	var zs: Array = gate.map(func(p: Vector3) -> float: return p.z)
	zs.sort()
	for i in range(1, zs.size()):
		if float(zs[i]) - float(zs[i - 1]) > 0.5:
			assert_true(float(zs[i]) - float(zs[i - 1]) <= 20.0 + SelectionSquads.GAP_M + 0.01,
					"a rank behind steps the travel depth plus the gap, not the halt's (%.1f m)" % (float(zs[i]) - float(zs[i - 1])))


func test_switched_off_is_round_34() -> void:
	RtsControls.GATE_DEAL = false
	var blocks := _blocks([Vector3(0, 0, 80), Vector3(0, 0, 20), Vector3(0, 0, 50)])
	var gate := RtsControls.gate_anchors(blocks, GATE, AHEAD, _drive, _never, func(p: Vector3) -> Vector3: return p)
	# Round 34 dealt left to right by where they stand (all on x 0: list order), whoever is nearest, with the HALT's depth
	# between ranks: the farthest squad (index 0) in the front rank.
	assert_near(gate[0].z, gate[1].z, 0.01, "list order fills the front rank (%s)" % [gate])
	assert_near(gate[2].z - gate[0].z, 55.0 + SelectionSquads.GAP_M, 0.01, "ranks a halt's depth plus the gap apart")
