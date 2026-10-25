extends TestCase
## O1 (orders, round 40): Bar G1 v5's "locks 5 click places outside 8 -> 8" (s6204-6207, squads 1 and 2, both arms). The
## column is not laid there because today's body already stands on the ground he clicked: his click lands on the open west
## quay ~6 m east of a floodlight at (-14, 20), and the corridor read (RtsControls.gate_width, GATE_STEP_M steps) stops at
## the floodlight's hole in the navmesh, 4-6 m from the click, so the probe counts two squads on the same open quay as
## outside it. `past_posts` reads past an obstacle no wider than RtsControls.POST_SPAN_M; a building still ends the read.

const CLICK := Vector3(-8.3, 0, 24.5)  # s6204's click (ORDERS_PROBE_CORRIDOR)
const ACROSS := Vector3(1.0, 0, -0.2)  # across s6204's approach (ORDERS_PROBE_CORRIDOR)

var _lab: TacticsLab


func teardown() -> void:
	if _lab != null:
		_lab.dispose()
	_lab = null
	super.teardown()


func _ground() -> Tank:
	_lab = TacticsLab.create(self, 6204, "locks")
	var ground := _lab.unit(Match.Team.GREEN, "Green_Alpha_1", Vector3(-8.0, 0, 60.0), 0.0, "tank")
	await _lab.start()
	return ground


func test_the_quay_corridor_reads_past_the_floodlight() -> void:
	var ground := await _ground()
	var drive := SelectionSquads.drive_on(ground)
	var crosses := SelectionSquads.crosses_on(ground)
	var across := ACROSS.normalized()
	var gate := RtsControls.gate_width(CLICK, across, drive, crosses, SelectionSquads.GROUP_SCAN_M)
	var posts := RtsControls.gate_width(CLICK, across, drive, crosses, SelectionSquads.GROUP_SCAN_M, RtsControls.POST_SPAN_M)
	print("CORRIDOR_POSTS quay: gate %s, past posts %s" % [gate, posts])
	# The reproduction: round 39's read stops at the floodlight (the bar's ORDERS_PROBE_CORRIDOR: left 4.0).
	assert_true(gate[0] <= 8.0, "round 39's read stops at the floodlight (left %.0f m)" % gate[0])
	# Squads 1 and 2's places stood 39.4 and 19.7 m west of the click on the open quay: inside the read past the post.
	assert_true(posts[0] >= 40.0, "past the post the quay reads open west of the click (left %.0f m)" % posts[0])
	assert_true(posts[1] >= gate[1], "the open side is unchanged or wider (%.0f v %.0f m)" % [posts[1], gate[1]])


func test_a_building_still_ends_the_read() -> void:
	var ground := await _ground()
	var drive := SelectionSquads.drive_on(ground)
	var crosses := SelectionSquads.crosses_on(ground)
	# The lock house block at (30, 42): read east from (8, 42), the block's west face ends both reads alike.
	var at := Vector3(8.0, 0, 42.0)
	var gate := RtsControls.gate_width(at, Vector3.RIGHT, drive, crosses, SelectionSquads.GROUP_SCAN_M)
	var posts := RtsControls.gate_width(at, Vector3.RIGHT, drive, crosses, SelectionSquads.GROUP_SCAN_M, RtsControls.POST_SPAN_M)
	print("CORRIDOR_POSTS block: gate %s, past posts %s" % [gate, posts])
	assert_true(gate[1] < 30.0, "the block ends the read east (%.0f m)" % gate[1])
	assert_eq(posts[1], gate[1], "a building is not a post: the read past posts ends at it too")
