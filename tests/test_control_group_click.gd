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
	return {"blocks": blocks, "drive": drive, "crosses": crosses,
			"approach": SelectionSquads.approach_of(blocks, CLICK, Match.team_frame(Match.Team.GREEN)["forward"]),
			"width_at": func(p: Vector3, across: Vector3) -> Array:
				return RtsControls.gate_width(p, across, drive, crosses, SelectionSquads.GROUP_SCAN_M)}


## R37.29, the column of wedges on his click: every place inside the corridor read at its own rank, and the squad nearest
## the click in front, the farthest at the back (the orchestrator's order check).
func test_his_click_as_a_column_stays_in_the_corridor_nearest_squad_in_front() -> void:
	var f := await _his_click()
	var blocks: Array = f["blocks"]
	var ahead: Vector3 = f["approach"]
	var across := Vector3(-ahead.z, 0.0, ahead.x)
	var anchors := SelectionSquads.column_lay(blocks, CLICK, ahead, f["width_at"], func(p: Vector3) -> Vector3: return Orders.clamp_to_arena(p))
	assert_eq(anchors.size(), blocks.size(), "his street is not open ground: a column is laid")
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

