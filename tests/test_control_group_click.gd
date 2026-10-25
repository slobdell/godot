extends TestCase
## Round 37 (orders, R37.29; the lead's playtest 2026-10-21, Terminus s44742, recording 21-52-44): selecting all and clicking
## one point, "the target waypoints for each squad was all over at far away places ... A bunch of units drove through
## streets ... I immediately lost control of the army". His click at tick 1108: (-29.3, 85.8), his three squads and four
## loose Lancers bunched round (-3, 55). Today's body (`SelectionSquads.ranks`) lays the squads three abreast ACROSS the
## click, 71 m apart, as if the ground were open: (-93.2, 54.4), (-29.3, 85.8), (34.6, 117.2) in the recording. This lab
## pins that on the real Terminus navmesh (the reproduction) and is where the column of wedges
## (references/round37/orders/group-click-column-note.md) will be judged.

const CLICK := Vector3(-29.3, 0, 85.8)
## His vehicles where they stood at tick 1080 (the census before the click), by squad.
const SQUADS := {
	"Hunters": [["Green_Hunters_1", "syn_ifv", Vector3(-6.2, 0, 45.3)], ["Green_Hunters_2", "syn_ifv", Vector3(-1.1, 0, 59.9)]],
	"Battery": [["Green_Battery_1", "syn_artillery", Vector3(-9.9, 0, 85.4)], ["Green_Battery_2", "syn_artillery", Vector3(-8.7, 0, 93.2)],
			["Green_Battery_3", "syn_artillery", Vector3(-2.8, 0, 70.0)], ["Green_Battery_4", "syn_scout", Vector3(-11.3, 0, 28.0)],
			["Green_Battery_5", "syn_lancer", Vector3(-1.6, 0, 41.2)]],
	"Eyes": [["Green_Eyes_1", "syn_scout", Vector3(0.9, 0, 57.0)], ["Green_Eyes_2", "syn_scout", Vector3(31.1, 0, 84.3)],
			["Green_Eyes_3", "syn_scout", Vector3(0.7, 0, 64.9)], ["Green_Eyes_4", "syn_scout", Vector3(-4.2, 0, 53.4)],
			["Green_Eyes_5", "syn_scout", Vector3(-25.4, 0, 38.6)]],
}
const LOOSE := [["Green_Lances_1", "syn_lancer", Vector3(-1.8, 0, 66.0)], ["Green_Lances_2", "syn_lancer", Vector3(2.4, 0, 60.6)],
		["Green_Lances_3", "syn_lancer", Vector3(-8.8, 0, 38.9)], ["Green_Lances_4", "syn_lancer", Vector3(5.4, 0, 72.3)]]

var _lab: TacticsLab


func teardown() -> void:
	SelectionSquads.GROUP_LAY = OS.get_cmdline_user_args().has("--group-lay=column")
	SelectionSquads.CLEAR_AT_CLICK = not OS.get_cmdline_user_args().has("--group-clear=rank")
	SelectionSquads.LEG_WIDTH_ALONG = OS.get_cmdline_user_args().has("--group-leg-width=along")
	SelectionSquads.PLACE_CLEAR_NEAR = OS.get_cmdline_user_args().has("--place-clear-trigger=near")
	SelectionSquads.RANK_SHIFT_HALF = OS.get_cmdline_user_args().has("--group-rank-shift=half")
	SelectionSquads.GROUP_WHOLE_CLICK = OS.get_cmdline_user_args().has("--group-whole=click")
	SelectionSquads.CLEAR_REACHED = OS.get_cmdline_user_args().has("--group-clear=reached")
	SelectionSquads.GROUP_LEAD = OS.get_cmdline_user_args().has("--group-lead=drive")
	SelectionSquads.SIDES_BOTH = OS.get_cmdline_user_args().has("--group-sides=both")
	SelectionSquads.PLACE_CLEAR_LANE = OS.get_cmdline_user_args().has("--place-clear-lane=on")
	SelectionSquads.LANE_COLUMN = OS.get_cmdline_user_args().has("--place-clear-lane=column")
	SelectionSquads.ROUTE_CORNER = OS.get_cmdline_user_args().has("--group-route-corner=line")
	if _lab != null:
		_lab.dispose()
	_lab = null
	super.teardown()


func _block(members: Array, width: float) -> Dictionary:
	var c := Vector3.ZERO
	for m: Array in members:
		c += m[2]
	return {"center": c / members.size(), "width": width, "depth": SelectionSquads.depth("auto", members.size())}


## His click as today lays it: the anchors, how far apart, and which the click reaches only round a block (another street).
func test_his_terminus_click_today_spreads_his_squads_into_other_streets() -> void:
	_lab = TacticsLab.create(self, 44742, "terminus")
	var ground: Tank = null
	for squad: String in SQUADS:
		for m: Array in SQUADS[squad]:
			var t := _lab.unit(Match.Team.GREEN, String(m[0]), m[2], 0.0, String(m[1]))
			ground = t if ground == null else ground
	for m: Array in LOOSE:
		_lab.unit(Match.Team.GREEN, String(m[0]), m[2], 0.0, String(m[1]))
	await _lab.start()
	# Each squad's slot as the recording shows it: 71 m apart = a five-vehicle halt frontage (57 m at 14 m) + GAP_M.
	var blocks: Array = []
	for squad: String in SQUADS:
		blocks.append(_block(SQUADS[squad], SelectionSquads.width("wedge", 5)))
	blocks.append(_block(LOOSE, SelectionSquads.width("auto", LOOSE.size())))
	var anchors := SelectionSquads.ranks(blocks, CLICK, null, Match.team_frame(Match.Team.GREEN)["forward"])
	anchors = SelectionSquads.ground_cap(anchors, CLICK, SelectionSquads.drive_on(ground), SelectionSquads.crosses_on(ground),
			func(p: Vector3) -> Vector3: return Orders.clamp_to_arena(p))
	var spread := 0.0
	var off_street := 0
	var drive := SelectionSquads.drive_on(ground)
	for i in anchors.size():
		for j in range(i + 1, anchors.size()):
			spread = maxf(spread, Vector2(anchors[i].x - anchors[j].x, anchors[i].z - anchors[j].z).length())
		var straight := Vector2(anchors[i].x - CLICK.x, anchors[i].z - CLICK.z).length()
		var by_ground := float(drive.call(CLICK, anchors[i]))
		if straight > 5.0 and by_ground > straight * 1.5 + 1.0:
			off_street += 1
		print("GROUP_CLICK anchor %d (%.1f, %.1f) straight %.1f m, by ground %.1f m" % [i, anchors[i].x, anchors[i].z, straight, by_ground])
	# The corridor at his click (the gate's read: ground reached within 1.5 x straight, no deck), across the approach.
	var ahead := SelectionSquads.approach_of(blocks, CLICK, Match.team_frame(Match.Team.GREEN)["forward"])
	var across := Vector3(-ahead.z, 0.0, ahead.x)
	var sides := RtsControls.gate_width(CLICK, across, drive, SelectionSquads.crosses_on(ground))
	var outside := 0
	for a: Vector3 in anchors:
		var aside := (a - CLICK).dot(across)
		if aside < -sides[0] - 0.5 or aside > sides[1] + 0.5:
			outside += 1
	print("GROUP_CLICK today: spread %.1f m, anchors in another street %d of %d, corridor at the click %.0f + %.0f m, anchors outside it %d" % [
			spread, off_street, anchors.size(), sides[0], sides[1], outside])
	# The reproduction (today's behaviour, the bug): the squads' anchors land ~130 m end to end, as in his recording.
	assert_true(spread > 100.0, "today: his one click spreads the squads over %.1f m (recording: ~130 m)" % spread)
	assert_true(outside >= 2, "today: %d anchors stand outside the corridor at his click (the far streets he saw)" % outside)


## His lab, built once: the lab, a ground tank, the blocks (squads then the loose Lancers) and the approach.
func _his_click() -> Dictionary:
	_lab = TacticsLab.create(self, 44742, "terminus")
	var ground: Tank = null
	for squad: String in SQUADS:
		for m: Array in SQUADS[squad]:
			var t := _lab.unit(Match.Team.GREEN, String(m[0]), m[2], 0.0, String(m[1]))
			ground = t if ground == null else ground
	for m: Array in LOOSE:
		_lab.unit(Match.Team.GREEN, String(m[0]), m[2], 0.0, String(m[1]))
	await _lab.start()
	var blocks: Array = []
	for squad: String in SQUADS:
		blocks.append(_block(SQUADS[squad], SelectionSquads.width("wedge", 5)))
	blocks.append(_block(LOOSE, SelectionSquads.width("auto", LOOSE.size())))
	var drive := SelectionSquads.drive_on(ground)
	var crosses := SelectionSquads.crosses_on(ground)
	return {"blocks": blocks, "drive": drive, "crosses": crosses, "ground": ground,
			"approach": SelectionSquads.approach_of(blocks, CLICK, Match.team_frame(Match.Team.GREEN)["forward"]),
			"width_at": func(p: Vector3, across: Vector3) -> Array:
				return RtsControls.gate_width(p, across, drive, SelectionSquads.crosses_or_edge(crosses), SelectionSquads.GROUP_SCAN_M)}


## R37.29, the column of wedges on his click: every place inside the corridor read at its own rank, and the squad nearest
## the click in front, the farthest at the back (the orchestrator's order check).
func test_his_click_as_a_column_stays_in_the_corridor_nearest_squad_in_front() -> void:
	var f := await _his_click()
	var blocks: Array = f["blocks"]
	var ahead: Vector3 = f["approach"]
	var across := Vector3(-ahead.z, 0.0, ahead.x)
	# G1 (v2): today's body is what the caller would lay; the column engages because two of its places stand off the ground.
	var today := SelectionSquads.ground_cap(SelectionSquads.ranks(blocks, CLICK, null, Match.team_frame(Match.Team.GREEN)["forward"]),
			CLICK, f["drive"], f["crosses"], func(p: Vector3) -> Vector3: return Orders.clamp_to_arena(p))
	var body := Vector3.ZERO
	for block: Dictionary in blocks:
		body += (block["center"] as Vector3) / blocks.size()
	var anchors := SelectionSquads.column_lay(blocks, CLICK, ahead, f["width_at"], func(p: Vector3) -> Vector3: return Orders.clamp_to_arena(p), today,
			func() -> PackedVector3Array: return Pathing.find_path(f["ground"], CLICK, body),
			func(p: Vector3) -> bool: return SelectionSquads.reached_from(CLICK, p, f["drive"], f["crosses"]))
	assert_eq(anchors.size(), blocks.size(), "today's places stand off the ground he clicked: a column is laid")
	var spread := 0.0
	for i in anchors.size():
		for j in range(i + 1, anchors.size()):
			spread = maxf(spread, Vector2(anchors[i].x - anchors[j].x, anchors[i].z - anchors[j].z).length())
		# Inside the corridor read at the anchor's own rank point (on the approach line through the click).
		var point := CLICK - ahead * (CLICK - anchors[i]).dot(ahead)
		var sides: Array = (f["width_at"] as Callable).call(point, across)
		var aside := (anchors[i] - point).dot(across)
		print("GROUP_CLICK column anchor %d (%.1f, %.1f) back %.1f m, aside %.1f m in [-%.0f, %.0f]" % [i, anchors[i].x, anchors[i].z,
				(CLICK - anchors[i]).dot(ahead), aside, float(sides[0]), float(sides[1])])
		assert_true(aside >= -float(sides[0]) - 0.5 and aside <= float(sides[1]) + 0.5, "anchor %d stands inside its corridor" % i)
		# G1: no place laid past the arena's edge (the clamp would pile it onto its neighbour).
		assert_true(Orders.clamp_to_arena(anchors[i]).distance_to(anchors[i]) < 0.01, "anchor %d is inside the arena unclamped" % i)
	print("GROUP_CLICK column: spread %.1f m" % spread)
	# The order check: front to back by how far along the approach each block already is.
	var along := []
	for i in blocks.size():
		along.append([((blocks[i]["center"] as Vector3) - CLICK).dot(ahead), i])
	along.sort()
	var nearest := int(along[along.size() - 1][1])
	var farthest := int(along[0][1])
	var back_of := func(i: int) -> float: return (CLICK - anchors[i]).dot(ahead)
	for i in blocks.size():
		assert_true(float(back_of.call(nearest)) <= float(back_of.call(i)) + 0.5, "the squad nearest the click is in front (v %d)" % i)
		assert_true(float(back_of.call(farthest)) >= float(back_of.call(i)) - 0.5, "the farthest squad is at the back (v %d)" % i)


## Open ground (the scan reaches GROUP_SCAN_M both sides): no column, today's body stands (the yard_open no-change cell).
func test_open_ground_lays_no_column() -> void:
	var open := func(_p: Vector3, _across: Vector3) -> Array: return [SelectionSquads.GROUP_SCAN_M, SelectionSquads.GROUP_SCAN_M]
	var blocks := [{"center": Vector3(0, 0, 60), "width": 57.0, "depth": 30.0}, {"center": Vector3(30, 0, 60), "width": 57.0, "depth": 30.0}]
	assert_eq(SelectionSquads.column_lay(blocks, Vector3.ZERO, Vector3(0, 0, -1), open, func(p: Vector3) -> Vector3: return p).size(), 0,
			"open ground: [] (the caller keeps today's ranks)")


## A street narrower than one squad: single file on the approach line, front to back.
func test_a_narrow_street_is_single_file() -> void:
	var narrow := func(_p: Vector3, _across: Vector3) -> Array: return [10.0, 10.0]
	var blocks := [{"center": Vector3(0, 0, 60), "width": 57.0, "depth": 30.0}, {"center": Vector3(0, 0, 100), "width": 57.0, "depth": 30.0}]
	var out := SelectionSquads.column_lay(blocks, Vector3.ZERO, Vector3(0, 0, -1), narrow, func(p: Vector3) -> Vector3: return p)
	assert_true(absf(out[0].x) < 0.01 and absf(out[1].x) < 0.01, "both on the approach line (%s)" % [out])
	assert_true(out[0].z < out[1].z, "the nearer squad in front (%s)" % [out])



## G1 (round 38, R37.38's yard_open failure): walls inside the 100 m scan, but every place of today's body already on the
## clear ground: today's body stands (v1 laid a column here because the scan stopped short of 100 m).
func test_g1_todays_body_on_clear_ground_is_kept() -> void:
	var walled := func(_p: Vector3, _across: Vector3) -> Array: return [70.0, 70.0]
	var blocks := [{"center": Vector3(-40, 0, 60), "width": 57.0, "depth": 30.0}, {"center": Vector3(40, 0, 60), "width": 57.0, "depth": 30.0}]
	var today: Array[Vector3] = [Vector3(-35.5, 0, 0), Vector3(35.5, 0, 0)]
	var kept := SelectionSquads.bodies_kept
	assert_eq(SelectionSquads.column_lay(blocks, Vector3.ZERO, Vector3(0, 0, -1), walled, func(p: Vector3) -> Vector3: return p, today).size(), 0,
			"today's places inside the walls: [] (the caller keeps today's body)")
	assert_eq(SelectionSquads.bodies_kept, kept + 1, "counted as a body kept")
	assert_eq(SelectionSquads.column_lay(blocks, Vector3.ZERO, Vector3(0, 0, -1), walled, func(p: Vector3) -> Vector3: return p).size(), 2,
			"v1's test (no body given) laid a column on the same ground")


## G1: one of today's places past a wall: the column is laid, every place inside.
func test_g1_a_place_past_a_wall_lays_the_column() -> void:
	var walled := func(_p: Vector3, _across: Vector3) -> Array: return [70.0, 20.0]
	var blocks := [{"center": Vector3(-40, 0, 60), "width": 57.0, "depth": 30.0}, {"center": Vector3(40, 0, 60), "width": 57.0, "depth": 30.0}]
	var today: Array[Vector3] = [Vector3(-35.5, 0, 0), Vector3(35.5, 0, 0)]
	var out := SelectionSquads.column_lay(blocks, Vector3.ZERO, Vector3(0, 0, -1), walled, func(p: Vector3) -> Vector3: return p, today)
	assert_eq(out.size(), 2, "a column (%s)" % [out])
	# across = (-ahead.z, 0, ahead.x) = (1, 0, 0) for ahead (0, 0, -1): left wall at x = -70, right at x = 20.
	for at: Vector3 in out:
		assert_true(at.x >= -70.5 and at.x <= 20.5, "inside the walls (%s)" % [at])


## G1: a rear-rank place read at ITS rank: wide open at the click, a 30 m street behind it; today's rear place 40 m aside in
## that street's wall -> the column (v1 would have kept today's body: the click's own read reaches the scan limit).
func test_g1_a_rear_place_is_read_at_its_own_rank() -> void:
	SelectionSquads.CLEAR_AT_CLICK = false  # v2's per-rank read (v3 reads the click's width: the next case)
	var street_behind := func(p: Vector3, _across: Vector3) -> Array:
		return [100.0, 100.0] if p.z < 10.0 else [15.0, 15.0]
	var blocks := [{"center": Vector3(0, 0, 60), "width": 29.0, "depth": 20.0}, {"center": Vector3(0, 0, 100), "width": 29.0, "depth": 20.0}]
	var today: Array[Vector3] = [Vector3(0, 0, 0), Vector3(40, 0, 34)]
	var out := SelectionSquads.column_lay(blocks, Vector3.ZERO, Vector3(0, 0, -1), street_behind, func(p: Vector3) -> Vector3: return p, today)
	assert_eq(out.size(), 2, "a column (%s)" % [out])
	assert_true(SelectionSquads.on_clear_ground(out, Vector3.ZERO, Vector3(0, 0, -1), street_behind, street_behind.call(Vector3.ZERO, Vector3.RIGHT)),
			"every place on the clear ground at its own rank (%s)" % [out])


## G1 (dev read 942533413: crossing 5 click stacked five herringbones ~20 m apart): a column rank is as deep as the halt
## the squad is priced to deploy in, not its formation.
func test_g1_a_rank_is_as_deep_as_the_halt() -> void:
	for shape: String in ["herringbone", "coil", "wedge", "column"]:
		print("GROUP_CLICK halt footprint %s x5 at 14 m: %s" % [shape, SelectionSquads.halt_footprint(shape, 5, 14.0)])
	var block := {"center": Vector3.ZERO, "width": 50.0, "depth": 20.0, "count": 5, "halt": "herringbone", "pitch_v": Vector2(14, 14)}
	assert_true(SelectionSquads.column_depth(block) >= SelectionSquads.halt_footprint("herringbone", 5, 14.0).y - 0.01,
			"the herringbone's depth (%.1f)" % SelectionSquads.column_depth(block))
	assert_true(SelectionSquads.column_depth(block) > 20.0, "deeper than the formation's 20 m")


## G1/G2 (laptop probe smoke, 4141ae445, terminus 5 squads, first leg of a route down the east street at (70, 50)): the
## column stacked straight back 276 m from a waypoint 50 m from the army, off the map, and the clamp piled three squads on
## the base's edge (z 117). Laid back along the drive to the body, every place stands inside the arena, apart.
const ARMY := [Vector3(-58.1, 0, 95.8), Vector3(-26.7, 0, 94.2), Vector3(2.2, 0, 87.8), Vector3(32.4, 0, 92.5), Vector3(59.0, 0, 93.3)]
func test_g1_a_column_near_the_army_follows_the_road_and_stays_on_the_map() -> void:
	_lab = TacticsLab.create(self, 3801, "terminus")
	var ground: Tank = null
	for i in ARMY.size():
		var t := _lab.unit(Match.Team.GREEN, "Green_S%d_1" % i, ARMY[i], 0.0, "law_tank")
		ground = t if ground == null else ground
	await _lab.start()
	var click := Vector3(70, 0, 50)
	var blocks: Array = []
	var body := Vector3.ZERO
	for c: Vector3 in ARMY:
		blocks.append({"center": c, "width": SelectionSquads.width("wedge", 4), "depth": SelectionSquads.depth("wedge", 4),
				"halt_depth": SelectionSquads.depth("coil", 4)})
		body += c / ARMY.size()
	var drive := SelectionSquads.drive_on(ground)
	var crosses := SelectionSquads.crosses_or_edge(SelectionSquads.crosses_on(ground))
	var ahead := SelectionSquads.approach_of(blocks, click, Match.team_frame(Match.Team.GREEN)["forward"])
	var clamp := func(p: Vector3) -> Vector3: return Orders.clamp_to_arena(p)
	var today := SelectionSquads.fit_inside(SelectionSquads.ranks(blocks, click, null, ahead), clamp)
	var out := SelectionSquads.column_lay(blocks, click, ahead,
			func(p: Vector3, across: Vector3) -> Array: return RtsControls.gate_width(p, across, drive, crosses, SelectionSquads.GROUP_SCAN_M),
			clamp, today, func() -> PackedVector3Array: return Pathing.find_path(ground, click, body),
			func(p: Vector3) -> bool: return SelectionSquads.reached_from(click, p, drive, crosses))
	print("GROUP_CLICK near-army column: %s" % [out])
	if out.is_empty():
		return  # today's body already on clear ground: nothing to check
	for i in out.size():
		assert_true(Orders.clamp_to_arena(out[i]).distance_to(out[i]) < 0.01, "place %d inside the arena (%s)" % [i, out[i]])
		# Nobody's place past his click (beyond the front rank's width).
		assert_true((out[i] - click).dot(ahead.normalized()) <= 1.0, "place %d not past the click (%s)" % [i, out[i]])
		for j in range(i + 1, out.size()):
			assert_true(Vector2(out[i].x - out[j].x, out[i].z - out[j].z).length() >= 20.0, "places %d and %d apart (%s / %s)" % [i, j, out[i], out[j]])


## G1 (dev read 4e25c1eab, crossing / locks 5: two squads given one place where the column ran off the map): a column
## longer than the ground behind it is laid with closer ranks, every squad its own place, all on the map.
func test_g1_a_column_too_long_for_the_ground_squeezes_its_ranks() -> void:
	var street := func(_p: Vector3, _across: Vector3) -> Array: return [15.0, 15.0]
	var edge := func(p: Vector3) -> Vector3: return Vector3(p.x, p.y, minf(p.z, 90.0))  # the map ends 90 m behind the click
	var blocks := []
	for z: float in [100.0, 130.0, 160.0]:
		blocks.append({"center": Vector3(0, 0, z), "width": 29.0, "depth": 40.0})
	var today: Array[Vector3] = [Vector3(-40, 0, 0), Vector3(0, 0, 0), Vector3(40, 0, 0)]
	var out := SelectionSquads.column_lay(blocks, Vector3.ZERO, Vector3(0, 0, -1), street, edge, today)
	assert_eq(out.size(), 3, "a column (%s)" % [out])
	for i in out.size():
		assert_true(out[i].z <= 90.0 + 0.01, "place %d on the map (%s)" % [i, out])
		for j in range(i + 1, out.size()):
			assert_true(out[i].distance_to(out[j]) >= 20.0, "places %d and %d apart (%s)" % [i, j, out])
	assert_true(out[0].z < out[1].z and out[1].z < out[2].z, "still nearest in front (%s)" % [out])


## G3 (settle's S2 trace, R38.10, crossing 5 click s3866: two places 6.3 m apart): the place farther from the click steps
## back along the approach until its footprint is clear of the nearer one's.
func test_g3_a_place_on_another_squads_halt_moves_aside() -> void:
	# G3 dev read 1 (builder0, 42377862a, crossing 3 click s3801): main laid squads 2 and 3 2.8 m apart, herringbones.
	var blocks := [{"center": Vector3(0, 0, 100), "width": 25.4, "depth": 54.8}, {"center": Vector3(60, 0, 0), "width": 25.4, "depth": 54.8}]
	var places: Array[Vector3] = [Vector3(0, 0, 0), Vector3(2.7, 0, 0.5)]
	var out := SelectionSquads.place_clear(places, blocks, Vector3.ZERO, Vector3(0, 0, -1), func(_p: Vector3) -> bool: return true)
	assert_eq(out[0], places[0], "the squad with the longer drive keeps its place")
	var need := 25.4
	assert_true(out[1].distance_to(out[0]) >= need - 0.01, "the other clears its short side (%s)" % [out])
	assert_true(out[1].distance_to(places[1]) <= need, "by about the shortfall, not a road length back (%s)" % [out])
	assert_true(out[1].x > places[1].x and absf(out[1].z - places[1].z) < 0.01, "aside, toward its own vehicles (%s)" % [out])


func test_g3_aside_blocked_it_steps_back_and_never_far() -> void:
	var blocks := [{"center": Vector3(0, 0, 100), "width": 25.4, "depth": 54.8}, {"center": Vector3(5, 0, 90), "width": 25.4, "depth": 54.8}]
	var places: Array[Vector3] = [Vector3(0, 0, 0), Vector3(2.7, 0, 0.5)]
	var street := func(p: Vector3) -> bool: return absf(p.x) < 6.0
	var out := SelectionSquads.place_clear(places, blocks, Vector3.ZERO, Vector3(0, 0, -1), street)
	assert_true(out[1].distance_to(out[0]) >= 25.4 - 0.01 and absf(out[1].x - 2.7) < 0.01,
			"a street: straight back along the approach (%s)" % [out])
	var walled := func(p: Vector3) -> bool: return p.distance_to(Vector3(2.7, 0, 0.5)) < 1.0
	assert_eq(SelectionSquads.place_clear(places, blocks, Vector3.ZERO, Vector3(0, 0, -1), walled), places,
			"nowhere clear within PLACE_CLEAR_MAX_M: the place is kept")
	assert_true(SelectionSquads.PLACE_CLEAR_MAX_M <= 40.0, "never a road length back (dev read 1 moved squads 60-90 m)")


## G3 v5 (judged 9986a1cba, crossing 5 route s4603: v4 stepped squad 4's place across the river, its crews crossed the
## bridge and never got in). A moved place must be reached from where it was without a crossing (`crosses(from, to)`).
func test_g3_a_moved_place_never_crosses_the_river() -> void:
	var blocks := [{"center": Vector3(0, 0, 100), "width": 25.4, "depth": 54.8}, {"center": Vector3(5, 0, 90), "width": 25.4, "depth": 54.8}]
	var places: Array[Vector3] = [Vector3(0, 0, 0), Vector3(2.7, 0, 0.5)]
	var street := func(p: Vector3) -> bool: return absf(p.x) < 6.0
	var river := func(from: Vector3, to: Vector3) -> bool: return (from.z > 10.0) != (to.z > 10.0)
	var v4 := SelectionSquads.place_clear(places, blocks, Vector3.ZERO, Vector3(0, 0, -1), street)
	assert_true(v4[1].z > 10.0, "v4: straight back, over the river at z 10 (%s)" % [v4])
	assert_eq(SelectionSquads.place_clear(places, blocks, Vector3.ZERO, Vector3(0, 0, -1), street, river), places,
			"v5: no clear way on this bank, so the place is kept")


func test_g3_of_the_clear_ways_the_one_nearest_the_squad() -> void:
	# G3 dev reads 3-4 (builder0, 527d62cd2): a squad moved aside away from its neighbour drove further and missed the
	# probe's limit where main only just got in. Of the ways clear at a step, the one nearest the squad's own vehicles.
	var blocks := [{"center": Vector3(0, 0, 80), "width": 25.4, "depth": 54.8}, {"center": Vector3(-40, 0, 20), "width": 25.4, "depth": 54.8}]
	var places: Array[Vector3] = [Vector3(0, 0, 0), Vector3(2.7, 0, 0.5)]
	var out := SelectionSquads.place_clear(places, blocks, Vector3.ZERO, Vector3(0, 0, -1), func(_p: Vector3) -> bool: return true)
	assert_true(out[1].x < 0.0, "aside toward its own vehicles, past its neighbour's far side (%s)" % [out])
	assert_true(out[1].distance_to(out[0]) >= 25.4 - 0.01, "clear (%s)" % [out])


func test_g3_the_slowest_squad_keeps_its_place() -> void:
	# R38.15's ruling: G3 never lengthens the trip of the squad that is already the slowest. Of two places too close,
	# the squad with the shorter remaining drive yields, nearer the click or not.
	var blocks := [{"center": Vector3(0, 0, 30), "width": 25.4, "depth": 54.8}, {"center": Vector3(0, 0, 150), "width": 25.4, "depth": 54.8}]
	var places: Array[Vector3] = [Vector3(0, 0, 0), Vector3(2.7, 0, 0.5)]
	var out := SelectionSquads.place_clear(places, blocks, Vector3.ZERO, Vector3(0, 0, -1), func(_p: Vector3) -> bool: return true)
	assert_eq(out[1], places[1], "the far squad (150 m to drive) keeps its place")
	assert_true(out[0] != places[0] and out[0].distance_to(out[1]) >= 25.4 - 0.01, "the near squad yields (%s)" % [out])


## G3 v4 (judged a67afc951, his 5 click: g3 moved squad 3 off a place 15.6 m from squad 5's, not a pair the bar counts,
## into the gap before squad 4; its seats landed 4 m from squad 5's 38 m-deep halt, which re-packed, twitch 13.8 -> 26.0 m).
## `--place-clear-trigger=near`: only a pair closer than PLACE_CLEAR_TRIGGER_M moves; it still clears the short sides.
func test_g3_near_trigger_moves_only_pairs_on_each_other() -> void:
	var blocks := [{"center": Vector3(45, 0, 88), "width": 25.4, "depth": 28.0}, {"center": Vector3(2, 0, 88), "width": 20.4, "depth": 14.0}]
	var his: Array[Vector3] = [Vector3(8, 0, 66.5), Vector3(-7.5, 0, 68.5)]
	var any := func(_p: Vector3) -> bool: return true
	SelectionSquads.PLACE_CLEAR_NEAR = false
	assert_true(SelectionSquads.place_clear(his, blocks, Vector3(-29.3, 0, 85.8), Vector3(0, 0, -1), any) != his,
			"v3: 15.6 m is inside the short sides' 19.7 m, so a place moves")
	SelectionSquads.PLACE_CLEAR_NEAR = true
	assert_eq(SelectionSquads.place_clear(his, blocks, Vector3(-29.3, 0, 85.8), Vector3(0, 0, -1), any), his,
			"near: 15.6 m apart is no squad on another's halt; both kept")
	var on_it: Array[Vector3] = [Vector3(8, 0, 66.5), Vector3(2, 0, 69.6)]  # settle's S2 case: 6.3 m apart
	var out := SelectionSquads.place_clear(on_it, blocks, Vector3(-29.3, 0, 85.8), Vector3(0, 0, -1), any)
	assert_eq(out[0], on_it[0], "the longer drive keeps its place")
	assert_true(out[1].distance_to(out[0]) >= 19.7 - 0.01, "a pair on each other still clears the short sides (%s)" % [out])


func test_g3_staggered_or_apart_places_are_kept() -> void:
	var blocks := [{"center": Vector3(0, 0, 80), "width": 25.4, "depth": 54.8}, {"center": Vector3(5, 0, 90), "width": 25.4, "depth": 54.8}]
	# dev read 1, crossing 3 click s3802 squads 1 / 2: 28 m apart, one behind the other (the old full-depth box moved one 46 m).
	var staggered: Array[Vector3] = [Vector3(-96.4, 0, 31.6), Vector3(-101.3, 0, 59.1)]
	assert_eq(SelectionSquads.place_clear(staggered, blocks, Vector3(-96.4, 0, 31.6), Vector3(0, 0, -1), func(_p: Vector3) -> bool: return true),
			staggered, "staggered 28 m: kept")
	var apart: Array[Vector3] = [Vector3(-30, 0, 0), Vector3(30, 0, 0)]
	assert_eq(SelectionSquads.place_clear(apart, blocks, Vector3.ZERO, Vector3(0, 0, -1), func(_p: Vector3) -> bool: return true), apart,
			"places already clear are kept")


## G1 v3 (judged 4a765e6e2, yard_open s3889 / s3891: today's rear rank beside the yard's containers laid a column): open at
## the click, a rear place narrow at its own rank but inside the click's width keeps today's body.
func test_g1v3_a_rear_place_beside_containers_keeps_todays_body() -> void:
	var containers_behind := func(p: Vector3, _across: Vector3) -> Array:
		return [100.0, 100.0] if p.z < 10.0 else [15.0, 15.0]
	var blocks := [{"center": Vector3(0, 0, 60), "width": 29.0, "depth": 20.0}, {"center": Vector3(0, 0, 100), "width": 29.0, "depth": 20.0}]
	var today: Array[Vector3] = [Vector3(0, 0, 0), Vector3(40, 0, 34)]
	assert_eq(SelectionSquads.column_lay(blocks, Vector3.ZERO, Vector3(0, 0, -1), containers_behind, func(p: Vector3) -> Vector3: return p, today).size(), 0,
			"inside the click's width: today's body stands")


## G1 v4 (judged b55757fee, locks 3 click s3960: the click's clear width ran 13 m west and the canal road 100 m east; the
## front rank stood all three abreast slid 39 m east, squad 3 79.5 m from the click, stuck behind squad 2's halt, never in).
## `--group-rank-shift=half`: a rank slides at most half a place off the column's line; who does not fit stands a rank back.
func test_g1v4_a_rank_slides_half_a_place_at_most() -> void:
	var canal_road := func(p: Vector3, _across: Vector3) -> Array:
		return [13.0, 100.0] if p.z < 5.0 else [10.0, 10.0]
	var blocks := [{"center": Vector3(-28, 0, 96), "width": 25.4, "depth": 28.0}, {"center": Vector3(3, 0, 90), "width": 25.4, "depth": 28.0},
			{"center": Vector3(31, 0, 88), "width": 25.4, "depth": 28.0}]
	var today: Array[Vector3] = [Vector3(-37, 0, 3), Vector3(0, 0, 0), Vector3(34, 0, -3)]
	var lay := func() -> Array[Vector3]:
		return SelectionSquads.column_lay(blocks, Vector3.ZERO, Vector3(0, 0, -1), canal_road, func(p: Vector3) -> Vector3: return p, today)
	SelectionSquads.RANK_SHIFT_HALF = false
	var v3: Array[Vector3] = lay.call()
	var worst := 0.0
	for p: Vector3 in v3:
		worst = maxf(worst, p.length())
	assert_true(worst > 70.0, "v3: the front rank slid down the canal road, one place ~79 m off (%s)" % [v3])
	SelectionSquads.RANK_SHIFT_HALF = true
	var v4: Array[Vector3] = lay.call()
	assert_eq(v4.size(), 3, "a column is laid (%s)" % [v4])
	for p: Vector3 in v4:
		assert_true(absf(p.x) <= 25.4 * 0.5 + 0.01, "every place within half a place of the column's line (%s)" % [v4])
		assert_true(p.z >= -0.01, "never past the click (%s)" % [v4])


## G1 v5 (`--group-whole=click`): squads stay whole on a plain group click; a queued leg is dealt as today.
func test_g1v5_squads_whole_on_his_click_only() -> void:
	SelectionSquads.GROUP_LAY = true
	SelectionSquads.GROUP_WHOLE_CLICK = false
	assert_true(SelectionSquads.whole_on(false) and SelectionSquads.whole_on(true), "v3: whole on every group move")
	SelectionSquads.GROUP_WHOLE_CLICK = true
	assert_true(SelectionSquads.whole_on(false), "a plain click keeps every squad's own vehicles")
	assert_true(not SelectionSquads.whole_on(true), "a queued leg is dealt as today")
	SelectionSquads.GROUP_LAY = false
	assert_true(not SelectionSquads.whole_on(false), "switch off: today's dealing")


## G1 v4 (three-arm dev read 7bfb06384, yard_open 5 click s3806: the click's clear width read 36 m left, today's place
## stood 39.3 m left on the same open yard, and a column was laid on open ground). `--group-clear=reached`: a place past
## the click's width that the click reaches straight by ground is on the ground he clicked; one round a block is not.
func test_g1v4_a_place_the_click_reaches_straight_keeps_todays_body() -> void:
	var yard := func(_p: Vector3, _across: Vector3) -> Array: return [36.0, 100.0]
	var blocks := [{"center": Vector3(-59, 0, 95), "width": 25.4, "depth": 28.0}, {"center": Vector3(3, 0, 88), "width": 20.4, "depth": 14.0},
			{"center": Vector3(59, 0, 93), "width": 25.4, "depth": 28.0}]
	var today: Array[Vector3] = [Vector3(-39.3, 0, -2.5), Vector3(0, 0, 0), Vector3(39.3, 0, 2.5)]
	var lay := func(reached: Callable) -> Array[Vector3]:
		return SelectionSquads.column_lay(blocks, Vector3.ZERO, Vector3(0, 0, -1), yard, func(p: Vector3) -> Vector3: return p, today,
				Callable(), reached)
	var straight := func(_p: Vector3) -> bool: return true
	var round_a_block := func(p: Vector3) -> bool: return p.x > -30.0
	SelectionSquads.CLEAR_REACHED = false
	assert_eq((lay.call(straight) as Array).size(), 3, "v3: 39.3 m past a 36 m width lays a column")
	SelectionSquads.CLEAR_REACHED = true
	assert_eq((lay.call(straight) as Array).size(), 0, "reached straight: today's body stands")
	assert_eq((lay.call(round_a_block) as Array).size(), 3, "a place round a block is another street: a column")


## G2 (dev, `--group-leg-width=along`; d2ed6ef10's finding: v3's click-width test kept today's spread body on route legs):
## a shifted leg wide at its click but driven through a 16 m street keeps no spread body; the drive's narrowest width rules.
func test_g2_a_leg_through_a_narrow_street_lays_the_column() -> void:
	var street_on_the_way := func(p: Vector3, _across: Vector3) -> Array:
		return [100.0, 100.0] if p.z < 10.0 or p.z > 90.0 else [8.0, 8.0]
	var blocks := [{"center": Vector3(-20, 0, 100), "width": 29.0, "depth": 20.0}, {"center": Vector3(20, 0, 100), "width": 29.0, "depth": 20.0}]
	var spread: Array[Vector3] = [Vector3(-20, 0, 0), Vector3(20, 0, 0)]
	var narrow: Array[Vector3] = [Vector3(-4, 0, 0), Vector3(4, 0, 6)]
	var drive := func() -> PackedVector3Array: return PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 100)])
	var lay := func(today: Array[Vector3]) -> Array[Vector3]:  # lambdas capture by value: the body is passed in
		return SelectionSquads.column_lay(blocks, Vector3.ZERO, Vector3(0, 0, -1), street_on_the_way, func(p: Vector3) -> Vector3: return p,
				today, drive, Callable(), false, true)
	SelectionSquads.LEG_WIDTH_ALONG = false
	assert_eq(lay.call(spread).size(), 0, "switch off: wide at the click, today's spread body stands (v3)")
	SelectionSquads.LEG_WIDTH_ALONG = true
	assert_eq(lay.call(spread).size(), 2, "switch on: 40 m spread through a 16 m street lays the column")
	assert_eq(lay.call(narrow).size(), 0, "a body that fits the street stands")
	var plain := SelectionSquads.column_lay(blocks, Vector3.ZERO, Vector3(0, 0, -1), street_on_the_way, func(p: Vector3) -> Vector3: return p,
			[Vector3(-20, 0, 0), Vector3(20, 0, 0)] as Array[Vector3], drive)
	assert_eq(plain.size(), 0, "a plain click (not a leg) is judged at its click only")


## G2 (dev read 1, terminus 5 avenue): a leg ending at a turn reads the cross street at its click; under the switch its ranks
## are no wider than the street it drove (single file here), not three abreast down the cross street.
func test_g2_a_leg_ending_at_a_turn_stands_in_the_street_it_drove() -> void:
	var turn := func(p: Vector3, across: Vector3) -> Array:
		if absf(across.z) > 0.9:  # read across a west-going leg: the cross street at the click, else the 16 m street
			return [100.0, 100.0] if p.x < -40.0 else [8.0, 8.0]
		return [8.0, 8.0]
	var blocks := [{"center": Vector3(10, 0, -30), "width": 29.0, "depth": 20.0}, {"center": Vector3(20, 0, -30), "width": 29.0, "depth": 20.0},
			{"center": Vector3(30, 0, -30), "width": 29.0, "depth": 20.0}]
	var today: Array[Vector3] = [Vector3(-50, 0, -60), Vector3(-50, 0, -30), Vector3(-50, 0, 0)]
	var drive := func() -> PackedVector3Array: return PackedVector3Array([Vector3(-50, 0, -30), Vector3(30, 0, -30)])
	SelectionSquads.LEG_WIDTH_ALONG = true
	var out := SelectionSquads.column_lay(blocks, Vector3(-50, 0, -30), Vector3(-1, 0, 0), turn, func(p: Vector3) -> Vector3: return p,
			today, drive, Callable(), false, true)
	assert_eq(out.size(), 3, "a column (%s)" % [out])
	for at: Vector3 in out:
		assert_true(absf(at.z + 30.0) <= 10.0, "in the street it drove, not down the cross street (%s)" % [at])


## G1 v5 (round 39; R38.51's trace, crossing 3 click s4710): a leading squad never stands behind one it leads.
func test_g1v5lead_breaks_count_a_leader_placed_behind() -> void:
	assert_eq(SelectionSquads.lead_breaks([10.0, 50.0], [0.0, 30.0]), 0, "the leader takes the far place")
	assert_eq(SelectionSquads.lead_breaks([10.0, 50.0], [30.0, 0.0]), 1, "the leader placed behind")
	assert_eq(SelectionSquads.lead_breaks([10.0, 13.0], [30.0, 0.0]), 0, "level squads (inside the slack) take either")
	assert_eq(SelectionSquads.lead_breaks([10.0, 50.0], [2.0, 0.0]), 0, "places abreast (inside the slack) take either")
	assert_eq(SelectionSquads.lead_breaks([10.0, 50.0, 90.0], [60.0, 30.0, 0.0]), 3, "a column laid backwards: every pair")


## s4710's shape, flat: the street runs from the click (-87, 37.6) up to (-40, 88) and east along z ~ 90; Alpha's crews
## stand nearest the street's mouth, Bravo's behind them, and the column's places are the head (front) and one rank back.
## Straight lines from the crews to the places choose to send Bravo to the head (round 38's swap); by the drive, Alpha
## (leading) takes the head and Bravo follows it in.
func test_g1v5lead_the_squad_in_front_takes_the_far_place() -> void:
	var squads: Array = [{"number": 1, "units": ["A1", "A2", "A3", "A4"]}, {"number": 2, "units": ["B1", "B2", "B3"]}]
	var at := {"A1": Vector3(-20, 0, 104), "A2": Vector3(-34, 0, 90), "A3": Vector3(-24, 0, 96), "A4": Vector3(-28, 0, 100),
			"B1": Vector3(0, 0, 86), "B2": Vector3(8, 0, 94), "B3": Vector3(4, 0, 90)}
	var head := Vector3(-75.4, 0, 45.4)
	var back := Vector3(-43.1, 0, 86.2)
	var position := func(n: String) -> Vector3: return at[n]
	# By ground: the street's mouth bend at (-40, 88); every drive goes through it.
	var bend := Vector3(-40, 0, 88)
	var click := Vector3(-87, 0, 37.6)
	var by_ground := func(from: Vector3, to: Vector3) -> float:
		return Vector2(from.x - bend.x, from.z - bend.z).length() + Vector2(bend.x - to.x, bend.z - to.z).length()
	var leads: Array = []
	for squad: Dictionary in squads:
		var sum := 0.0
		for n: String in squad["units"]:
			sum += float(by_ground.call(at[n], click))
		leads.append(sum / (squad["units"] as Array).size())
	assert_true(float(leads[0]) < float(leads[1]) - SelectionSquads.LEAD_SLACK_M, "Alpha leads (%s)" % [leads])
	var arc := func(p: Vector3) -> float: return Vector2(p.x - click.x, p.z - click.z).length()
	for order: Array in [[head, back], [back, head]]:
		var anchors: Array[Vector3] = [order[0], order[1]]
		SelectionSquads.untangle_whole(squads, anchors, position, leads, arc)
		assert_eq(anchors[0], head, "Alpha (leading) takes the head, from %s" % [order])
		assert_eq(anchors[1], back, "Bravo follows it in, from %s" % [order])
	# Without the leads: today's untangle (the reference this fixes) still decides on straight lines.
	var today: Array[Vector3] = [head, back]
	SelectionSquads.untangle_whole(squads, today, position)
	print("GROUP_CLICK g1v5 straight-line untangle gives Alpha %s, Bravo %s" % [today[0], today[1]])
	assert_eq(today[0], back, "today: straight lines send the trailing squad to the head (s4710)")


## G2 v2 (round 39; R38.47, dev read 3 ab31e9bc2, terminus 5 east `70/50+70/-30+25/-30`): the last leg's column stacks back
## along his route, round the corner at (70, -30) and up the x = 70 street; its rear rank stood two abreast at z = 28,
## (50.3, 28.2) and (89.7, 28.2), ~20 m either side of the street the route runs down. On the real Terminus navmesh.
const EAST_ROUTE := [Vector3(70, 0, 50), Vector3(70, 0, -30), Vector3(25, 0, -30)]
func test_g2v2_rear_places_stand_on_his_route_round_the_corner() -> void:
	_lab = TacticsLab.create(self, 3801, "terminus")
	var ground: Tank = null
	for i in ARMY.size():
		var t := _lab.unit(Match.Team.GREEN, "Green_S%d_1" % i, ARMY[i], 0.0, "law_tank")
		ground = t if ground == null else ground
	await _lab.start()
	var drive := SelectionSquads.drive_on(ground)
	var crosses := SelectionSquads.crosses_or_edge(SelectionSquads.crosses_on(ground))
	var width_at := func(p: Vector3, across: Vector3) -> Array:
		return RtsControls.gate_width(p, across, drive, crosses, SelectionSquads.GROUP_SCAN_M)
	# The leg starts: five squads stacked back from the corner (70, -30) up the x = 70 street, as the gate leg leaves them.
	var blocks: Array = []
	for k in 5:
		blocks.append({"center": Vector3(70, 0, -30 + 30.0 * k), "width": SelectionSquads.width("wedge", 5),
				"depth": SelectionSquads.depth("wedge", 5), "halt_depth": SelectionSquads.depth("herringbone", 5)})
	var click: Vector3 = EAST_ROUTE[2]
	var line := PackedVector3Array([EAST_ROUTE[2], EAST_ROUTE[1], EAST_ROUTE[0]])
	var today := SelectionSquads.fit_inside(SelectionSquads.ranks(blocks, click, null, line[0] - line[1]),
			func(p: Vector3) -> Vector3: return Orders.clamp_to_arena(p))
	SelectionSquads.LEG_WIDTH_ALONG = true
	var lay := func() -> Array[Vector3]:
		return SelectionSquads.column_lay(blocks, click, line[0] - line[1], width_at, func(p: Vector3) -> Vector3: return Orders.clamp_to_arena(p),
				today, func() -> PackedVector3Array: return line, func(_p: Vector3) -> bool: return false, false, true)
	SelectionSquads.ROUTE_CORNER = false
	var before: Array[Vector3] = lay.call()
	SelectionSquads.ROUTE_CORNER = true
	var after: Array[Vector3] = lay.call()
	for i in after.size():
		var off_b := SelectionSquads._distance_to_path(before[i], line) if i < before.size() else -1.0
		var off_a := SelectionSquads._distance_to_path(after[i], line)
		print("GROUP_CLICK g2v2 place %d: v1 %s off %.1f m | v2 %s off %.1f m" % [i, before[i] if i < before.size() else null, off_b, after[i], off_a])
	assert_eq(after.size(), 5, "a column (%s)" % [after])
	for z in [-30, -10, 10, 20, 28, 40, 50]:
		print("GROUP_CLICK g2v2 x=70 street at z=%d: %s" % [z, width_at.call(Vector3(70, 0, z), Vector3(1, 0, 0))])
	for x in [25, 40, 55, 70]:
		print("GROUP_CLICK g2v2 z=-30 street at x=%d: %s" % [x, width_at.call(Vector3(x, 0, -30), Vector3(0, 0, 1))])
	for i in after.size():
		var on_x70 := after[i].z > -30.0 + 4.0
		var sides: Array = width_at.call(Vector3(70, 0, after[i].z), Vector3(1, 0, 0)) if on_x70 \
				else width_at.call(Vector3(after[i].x, 0, -30), Vector3(0, 0, 1))
		var aside := (after[i].x - 70.0) if on_x70 else (after[i].z + 30.0)
		assert_true(aside >= -float(sides[0]) - 0.5 and aside <= float(sides[1]) + 0.5 and absf(aside) <= 20.0,
				"place %d in his route's street, centred (%s, %.1f m aside in %s)" % [i, after[i], aside, sides])
		assert_true(after[i].z <= 50.0 + 0.5, "never back past his route's first click (%s)" % [after[i]])


## G3 v6 (round 39; R38.51's trace, crossing 3 route s5201): a cleared place must seat every crew without a re-seat.
func test_g3v6_a_moved_place_must_seat_its_crews() -> void:
	var blocks := [{"center": Vector3(0, 0, 100), "width": 25.4, "depth": 54.8}, {"center": Vector3(60, 0, 40), "width": 25.4, "depth": 54.8}]
	var places: Array[Vector3] = [Vector3(0, 0, 0), Vector3(2.7, 0, 0.5)]
	var any := func(_p: Vector3) -> bool: return true
	var v5 := SelectionSquads.place_clear(places, blocks, Vector3.ZERO, Vector3(0, 0, -1), any)
	assert_true(v5[1].x > 20.0 and absf(v5[1].z - 0.5) < 0.01, "v5: straight aside toward its vehicles (%s)" % [v5])
	# Aside the halt does not seat (x > 10, z < 10): v6 steps back along its own leg to where it does.
	var seats := func(_i: int, at: Vector3) -> bool: return not (at.x > 10.0 and at.z < 10.0)
	var v6 := SelectionSquads.place_clear(places, blocks, Vector3.ZERO, Vector3(0, 0, -1), any, Callable(), seats)
	assert_true(bool(seats.call(1, v6[1])), "v6: the moved place seats (%s)" % [v6])
	assert_true(v6[1].distance_to(v6[0]) >= 25.4 - 0.01, "and clears its neighbour (%s)" % [v6])
	var leg := (Vector3(60, 0, 40) - places[1]).normalized()
	var along := (v6[1] - places[1]).normalized()
	assert_true(along.dot(leg) > 0.99 or along.dot(Vector3(0, 0, 1)) > 0.99, "aside blocked: back toward its vehicles (%s)" % [v6])
	var nowhere := func(_i: int, _at: Vector3) -> bool: return false
	assert_eq(SelectionSquads.place_clear(places, blocks, Vector3.ZERO, Vector3(0, 0, -1), any, Callable(), nowhere), places,
			"nowhere seats: the place is kept")



func test_g3v6_seats_hold_on_the_same_ground_and_no_longer_leg() -> void:
	var given := {"shape": "herringbone", "spacing": 7.5, "worst_m": 6.7}
	assert_true(SelectionSquads.seats_hold(given, {"shape": "herringbone", "spacing": 7.5, "worst_m": 8.5}), "same ground, leg inside the slack")
	assert_true(not SelectionSquads.seats_hold(given, {"shape": "herringbone", "spacing": 10.0, "worst_m": 6.0}),
			"s5201: lanes' 10 m spacing v dense's 7.5 re-seats")
	assert_true(not SelectionSquads.seats_hold(given, {"shape": "coil", "spacing": 7.5, "worst_m": 6.0}), "another shape re-seats")
	assert_true(not SelectionSquads.seats_hold(given, {"shape": "herringbone", "spacing": 7.5, "worst_m": 12.0}), "a longer deploy leg")
	assert_true(SelectionSquads.seats_hold({}, {"shape": "coil"}), "no preview (one crew): holds")


## G1 v6 (round 40; the orchestrator's relay of settle's T1 read and orders' trace, his 5 click s6201, e7c896c8f): the
## body comes in from the east, but Alpha stands 29 m WEST of his click. v5 laid it second in the column, 34 m east: it
## drove 62 m through Bravo's halt at the click, Bravo gave way and only got in on the 10 s cap (the 28.4 m twitch).
## `--group-sides=both`: a squad past the click stands on its own side, a column out from the click the other way.
func test_g1v6_a_squad_past_the_click_keeps_to_its_own_side() -> void:
	var street := func(_p: Vector3, _across: Vector3) -> Array: return [10.0, 10.0]
	var blocks := [{"center": Vector3(-29, 0, 0), "width": 29.0, "depth": 20.0},  # Alpha, past the click
			{"center": Vector3(9, 0, 0), "width": 29.0, "depth": 20.0},  # Bravo, nearest on the way in
			{"center": Vector3(40, 0, 0), "width": 29.0, "depth": 20.0},
			{"center": Vector3(70, 0, 0), "width": 29.0, "depth": 20.0}]
	var west := Vector3(-1, 0, 0)  # the approach: from the body's middle (22.5, 0) to the click
	var clamp := func(p: Vector3) -> Vector3: return p
	var v5 := SelectionSquads.column_lay(blocks, Vector3.ZERO, west, street, clamp)
	print("GROUP_CLICK g1v6 one-sided (v5) %s" % [v5])
	assert_true(v5[0].x > -0.5, "v5: Alpha stacked behind the click, on the far side from where it stands (%s)" % [v5[0]])
	SelectionSquads.SIDES_BOTH = true
	var sided := SelectionSquads.column_lay(blocks, Vector3.ZERO, west, street, clamp)
	print("GROUP_CLICK g1v6 two-sided %s" % [sided])
	assert_eq(sided.size(), 4, "every squad placed")
	assert_true(sided[0].x < -10.0, "Alpha's place past the click, on its own side (%s)" % [sided[0]])
	for i in range(1, 4):
		assert_true(sided[i].x > -0.5, "squad %d on the near side (%s)" % [i, sided[i]])
	assert_true(sided[1].distance_to(Vector3.ZERO) < 0.5, "Bravo, nearest on the way in, at the click (%s)" % [sided[1]])
	for i in 4:
		for j in range(i + 1, 4):
			assert_true(sided[i].distance_to(sided[j]) >= 20.0, "places %d and %d apart (%s / %s)" % [i, j, sided[i], sided[j]])


## G1 v6: the untangle never hands a squad a place on the other side of the click, even where v5's lead rule would
## (Alpha reaches the click 21 m before Charlie, yet its own-side place is farther from the click by ground).
func test_g1v6_the_untangle_keeps_each_squad_on_its_side() -> void:
	var squads: Array = [{"number": 1, "units": ["A1"]}, {"number": 3, "units": ["C1"]}]
	var at := {"A1": Vector3(-29, 0, 0), "C1": Vector3(40, 0, 0)}
	var position := func(n: String) -> Vector3: return at[n]
	var arc := func(p: Vector3) -> float: return absf(p.x)
	var leads: Array = [29.0, 50.0]
	var v5: Array[Vector3] = [Vector3(-44, 0, 0), Vector3(34, 0, 0)]
	SelectionSquads.untangle_whole(squads, v5, position, leads, arc)
	assert_eq(v5[0], Vector3(34, 0, 0), "v5: the lead rule sends Alpha across the click to the nearer place")
	var misplaced := func(i: int, p: Vector3) -> bool: return (i == 0) != (p.dot(Vector3(-1, 0, 0)) > 1.0)
	var sided: Array[Vector3] = [Vector3(-44, 0, 0), Vector3(34, 0, 0)]
	SelectionSquads.untangle_whole(squads, sided, position, leads, arc, misplaced)
	assert_eq(sided[0], Vector3(-44, 0, 0), "v6: Alpha keeps its own side's place")
	assert_eq(sided[1], Vector3(34, 0, 0), "v6: Charlie keeps the near side's")


## G3 v7 (round 40; R39's trace, crossing 5 route s6213): v6 stepped Delta back along its own leg onto the road Echo still
## had to drive in. `--place-clear-lane=on`: no step back inside the lane of a squad still to arrive; the given place is kept.
func test_g3v7_no_step_back_onto_a_later_squads_road() -> void:
	# Echo (0): the longest drive, from (100, 0, 0) west to its place at the origin; Delta (1): its given place 3 m off
	# Echo's, its vehicles east too, so its leg home runs back up Echo's road. Charlie (2): from the north, clear of it.
	var blocks := [{"center": Vector3(100, 0, 0), "width": 25.4, "depth": 54.8}, {"center": Vector3(60, 0, 6), "width": 25.4, "depth": 54.8},
			{"center": Vector3(0, 0, 80), "width": 25.4, "depth": 54.8}]
	var places: Array[Vector3] = [Vector3(0, 0, 0), Vector3(3, 0, 0.5), Vector3(-60, 0, 0)]
	var any := func(_p: Vector3) -> bool: return true
	# Aside and straight back never seat; along its leg (rising toward z = 6) it does.
	var only_back := func(i: int, at: Vector3) -> bool: return i != 1 or (at.x > 20.0 and at.z > 1.5)
	var v6 := SelectionSquads.place_clear(places, blocks, Vector3.ZERO, Vector3(-1, 0, 0), any, Callable(), only_back)
	print("GROUP_CLICK g3v7 v6 %s" % [v6])
	assert_true(v6[1].x > 20.0, "v6: Delta steps back east along its leg, onto Echo's road (%s)" % [v6[1]])
	var refused := SelectionSquads.places_off_lanes
	# Echo's road in: from its vehicles to its place (a straight drive here).
	var in_lane := func(i: int, at: Vector3) -> bool:
		return i != 0 and SelectionSquads.on_road(at, PackedVector3Array([blocks[0]["center"], places[0]]), SelectionSquads.lane_reach(blocks, i, 0))
	var v7 := SelectionSquads.place_clear(places, blocks, Vector3.ZERO, Vector3(-1, 0, 0), any, Callable(), only_back, in_lane)
	print("GROUP_CLICK g3v7 v7 %s" % [v7])
	assert_eq(v7[1], places[1], "v7: Delta keeps its given place")
	assert_true(SelectionSquads.places_off_lanes > refused, "counted (the back way's step and the leg's: %d)" % (SelectionSquads.places_off_lanes - refused))
	var road := PackedVector3Array([Vector3(100, 0, 0), Vector3(0, 0, 0)])
	assert_true(SelectionSquads.on_road(Vector3(50, 0, 5), road, 25.4), "a point beside the road is on it")
	assert_true(not SelectionSquads.on_road(Vector3(50, 0, 40), road, 25.4), "40 m off it is not")


func test_g3v9_a_road_is_a_column_wide() -> void:
	# Dev read (5bc304738, builder2, 3804-3809): 8 of the 10 pairs left were squads whose every step was refused, the
	# road read as wide as the driving squad's parked herringbone (17-20 m either side on crossing 3 / 5).
	var blocks := [{"center": Vector3(100, 0, 0), "width": 25.4, "depth": 54.8}, {"center": Vector3(60, 0, 6), "width": 12.0, "depth": 30.0}]
	SelectionSquads.LANE_COLUMN = false
	assert_near(SelectionSquads.lane_reach(blocks, 1, 0), 12.7 + 6.0, 0.01, "v7: half the driver's width + half the halt's short side")
	SelectionSquads.LANE_COLUMN = true
	assert_near(SelectionSquads.lane_reach(blocks, 1, 0), SelectionSquads.ROAD_HALF_M + 6.0, 0.01, "v9: half a column + half the halt's short side")
	var road := PackedVector3Array([Vector3(100, 0, 0), Vector3(0, 0, 0)])
	assert_true(not SelectionSquads.on_road(Vector3(50, 0, 14), road, SelectionSquads.lane_reach(blocks, 1, 0)), "a halt 14 m off the column is clear of it")
	assert_true(SelectionSquads.on_road(Vector3(50, 0, 8), road, SelectionSquads.lane_reach(blocks, 1, 0)), "8 m off it still blocks it")
	# v7's case still holds: Delta's step back up Echo's road is refused with a column's reach.
	var places: Array[Vector3] = [Vector3(0, 0, 0), Vector3(3, 0, 0.5)]
	var two := [{"center": Vector3(100, 0, 0), "width": 25.4, "depth": 54.8}, {"center": Vector3(60, 0, 6), "width": 25.4, "depth": 54.8}]
	var only_back := func(i: int, at: Vector3) -> bool: return i != 1 or (at.x > 20.0 and at.z > 1.5)
	var in_lane := func(i: int, at: Vector3) -> bool:
		return i != 0 and SelectionSquads.on_road(at, PackedVector3Array([two[0]["center"], places[0]]), SelectionSquads.lane_reach(two, i, 0))
	var v9 := SelectionSquads.place_clear(places, two, Vector3.ZERO, Vector3(-1, 0, 0), func(_p: Vector3) -> bool: return true,
			Callable(), only_back, in_lane)
	assert_eq(v9[1], places[1], "v9: Delta still keeps its given place")
