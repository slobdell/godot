extends TestCase
## Round 35 (orders D3, C35.4): TIGHT PACKING ON THE DEPLOY STEP. With the deploy step on, several AUTO squads sent to one
## click are packed by their HALT seats on the approach heading, fixed at the order: hull clearance between squads (his
## correction 1: wedges nest), each squad on its own side, nobody sent back past where it stands, nothing on ground the
## seat test refuses. Pure: SelectionSquads.pack_halts with stub ground.

const CLICK := Vector3(0, 0, -50)
const AHEAD := Vector3(0, 0, -1)
const PITCH := Vector2(14.0, 14.0)


func teardown() -> void:
	SelectionSquads.PACK = true
	super.teardown()


func _blocks(count: int, halt := "coil", crews := 5, spacing := 60.0, z := 100.0) -> Array:
	var blocks: Array = []
	for i in count:
		blocks.append({"center": Vector3((i - (count - 1) * 0.5) * spacing, 0, z), "width": 40.0, "depth": 30.0,
				"shape": "wedge", "count": crews, "pitch_v": PITCH, "halt": halt})
	return blocks


func _any(_p: Vector3) -> bool:
	return true


## Every halt seat of block i at anchor a, in the world (the frame pack_halts uses: x across to the right, y ahead).
func _seats(block: Dictionary, anchor: Vector3, heading := AHEAD) -> Array[Vector3]:
	var across := Vector3(-heading.z, 0, heading.x)
	var out: Array[Vector3] = []
	for s: Vector2 in SelectionSquads.halt_offsets(String(block["halt"]), int(block["count"]), (block["pitch_v"] as Vector2).x):
		out.append(anchor + across * s.x + heading * s.y)
	return out


func _closest_between(blocks: Array, anchors: Array[Vector3]) -> float:
	var best := INF
	for i in blocks.size():
		for j in range(i + 1, blocks.size()):
			for p in _seats(blocks[i], anchors[i]):
				for q in _seats(blocks[j], anchors[j]):
					best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
	return best


func test_three_squads_pack_by_hull_clearance() -> void:
	for halt: String in ["coil", "herringbone", "wedge"]:
		var blocks := _blocks(3, halt)
		var anchors := SelectionSquads.pack_halts(blocks, CLICK, AHEAD, _any, _any)
		assert_eq(anchors.size(), 3, "%s: a place for each squad" % halt)
		var closest := _closest_between(blocks, anchors)
		assert_true(closest >= SelectionSquads.HALT_CLEAR_M - 0.01, "%s: no two squads' seats closer than 9 m (%.1f)" % [halt, closest])
		assert_true(closest < SelectionSquads.HALT_CLEAR_M + SelectionSquads.PACK_STEP_M * 2.0,
				"%s: packed TIGHT, the nearest seats of two squads within a grid step or two of 9 m (%.1f)" % [halt, closest])


func test_the_middle_squad_stands_on_the_click_and_the_sides_keep_their_side() -> void:
	var blocks := _blocks(3)
	var anchors := SelectionSquads.pack_halts(blocks, CLICK, AHEAD, _any, _any)
	assert_true(anchors[1].distance_to(CLICK) < 0.01, "the squad nearest the click takes it (%s)" % anchors[1])
	assert_true(anchors[0].x < 0.0, "the left squad stands left of the click's line (%s)" % anchors[0])
	assert_true(anchors[2].x > 0.0, "the right squad stands right of it (%s)" % anchors[2])


func test_tighter_than_the_ranks() -> void:
	# Five coils: the farthest anchor from the click is nearer than round 34's ranks put it.
	var blocks := _blocks(5, "coil", 5, 50.0)
	for block: Dictionary in blocks:
		var foot := SelectionSquads.halt_footprint("coil", 5, PITCH.x)
		block["width"] = foot.x
		block["depth"] = foot.y
		block["halt_depth"] = foot.y
	var packed := SelectionSquads.pack_halts(blocks, CLICK, AHEAD, _any, _any)
	var ranks := SelectionSquads.ranks(blocks, CLICK)
	var far := func(anchors: Array[Vector3]) -> float:
		var worst := 0.0
		for a in anchors:
			worst = maxf(worst, a.distance_to(CLICK))
		return worst
	assert_true(float(far.call(packed)) < float(far.call(ranks)),
			"packed body's farthest squad %.1f m from the click v the ranks' %.1f m" % [far.call(packed), far.call(ranks)])
	assert_true(_closest_between(blocks, packed) >= SelectionSquads.HALT_CLEAR_M - 0.01, "and still 9 m clear")


func test_nobody_is_sent_back_past_where_it_stands() -> void:
	# Five squads already close in front of the click's line: none is laid farther back than its own centre.
	var blocks := _blocks(5, "coil", 5, 50.0, -30.0)
	var anchors := SelectionSquads.pack_halts(blocks, CLICK, AHEAD, _any, _any)
	for i in blocks.size():
		var behind_now := ((blocks[i]["center"] as Vector3) - CLICK).dot(-AHEAD)
		var behind_then := (anchors[i] - CLICK).dot(-AHEAD)
		assert_true(behind_then <= maxf(behind_now, 0.0) + 0.01,
				"squad %d: %.1f m behind the click, it stood %.1f m behind" % [i, behind_then, behind_now])


func test_no_seat_on_refused_ground() -> void:
	# A building east of x = 60: no seat of any squad stands on it.
	var dry := func(p: Vector3) -> bool: return p.x < 60.0
	var blocks := _blocks(3)
	var anchors := SelectionSquads.pack_halts(blocks, CLICK, AHEAD, dry, _any)
	assert_eq(anchors.size(), 3, "a place for each")
	for i in blocks.size():
		for p in _seats(blocks[i], anchors[i]):
			assert_true(p.x < 60.0, "squad %d's seat %s is off the building" % [i, p])


func test_an_anchor_the_click_does_not_reach_is_passed_over() -> void:
	var reached := func(p: Vector3) -> bool: return p.z > CLICK.z - 0.01 and absf(p.x) < 60.0
	var anchors := SelectionSquads.pack_halts(_blocks(3), CLICK, AHEAD, _any, reached)
	for a in anchors:
		assert_true(absf(a.x) < 60.0, "every anchor reached by ground from the click (%s)" % a)


func test_two_columns_keep_his_28_m() -> void:
	var blocks := _blocks(2, "column")
	var anchors := SelectionSquads.pack_halts(blocks, CLICK, AHEAD, _any, _any)
	assert_true(_closest_between(blocks, anchors) >= SelectionSquads.COLUMN_GAP_M - 0.01,
			"two columns' files %.1f m apart" % _closest_between(blocks, anchors))


func test_a_rotated_approach_packs_the_same() -> void:
	var heading := Vector3(1, 0, -1).normalized()
	var blocks := _blocks(3)
	for block: Dictionary in blocks:
		block["center"] = CLICK - heading * 150.0 + Vector3(-heading.z, 0, heading.x) * float((block["center"] as Vector3).x)
	var anchors := SelectionSquads.pack_halts(blocks, CLICK, heading, _any, _any)
	var best := INF
	for i in blocks.size():
		for j in range(i + 1, blocks.size()):
			for p in _seats(blocks[i], anchors[i], heading):
				for q in _seats(blocks[j], anchors[j], heading):
					best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
	assert_true(best >= SelectionSquads.HALT_CLEAR_M - 0.01, "on a diagonal approach still 9 m clear (%.1f)" % best)


func test_does_not_apply() -> void:
	var blocks := _blocks(3)
	(blocks[1] as Dictionary).erase("halt")
	assert_true(SelectionSquads.pack_halts(blocks, CLICK, AHEAD, _any, _any).is_empty(), "a squad with no halt (his pick): the ranks")
	assert_true(SelectionSquads.pack_halts(_blocks(1), CLICK, AHEAD, _any, _any).is_empty(), "one squad: nothing to pack")
	SelectionSquads.PACK = false
	assert_true(SelectionSquads.pack_halts(_blocks(3), CLICK, AHEAD, _any, _any).is_empty(), "--pack=off: the ranks")


const Fixture := preload("res://tests/support/control_fixture.gd")


## Through the real controls: three AUTO squads of five, one click in the open, the deploy step on. Each squad's task
## carries its packed halt (where = its destination, the shape, the approach heading), and those seats stand 9 m clear.
func test_the_controls_hand_each_squad_its_packed_halt() -> void:
	var was := ElementPlan.DEPLOY_STEP
	ElementPlan.DEPLOY_STEP = true
	var f := Fixture.new(self)
	await f.build_scale(15)
	var squads: Array = []
	for number in range(1, 4):
		var names := f.controls.groups.members(number)
		for i in names.size():
			f.place(names[i], Vector3((number - 2) * 40.0 + (i - 2) * 6.0, 0, 90))
		squads.append(names)
	await wait_physics_frames(2)
	var all: Array[String] = []
	for names: Array[String] in squads:
		all.append_array(names)
	f.controls.selection.set_units(all)
	var packs_before := SelectionSquads.packed
	assert_eq(f.controls.order_selection("move", {"to": [0.0, 0.0]}), "", "the order is taken")
	assert_eq(SelectionSquads.packed, packs_before + 1, "the order was packed")
	var blocks: Array = []
	var anchors: Array[Vector3] = []
	for names: Array[String] in squads:
		var task: Dictionary = f.controls.elements.of(names[0]).task
		assert_true(task.has("halt_at") and task.has("halt_shape") and task.has("lay"), "a packed task: %s" % [task])
		assert_eq(task["halt_at"], task["to"], "it drives to where it will halt")
		anchors.append(Vector3(float(task["halt_at"][0]), 0, float(task["halt_at"][1])))
		blocks.append({"halt": task["halt_shape"], "count": names.size(), "pitch_v": PITCH})
	var heading := Vector3(float(f.controls.elements.of(squads[0][0]).task["lay"][0]), 0,
			float(f.controls.elements.of(squads[0][0]).task["lay"][1]))
	var best := INF
	for i in blocks.size():
		for j in range(i + 1, blocks.size()):
			for p in _seats(blocks[i], anchors[i], heading):
				for q in _seats(blocks[j], anchors[j], heading):
					best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
	print("MEASURE packed three squads: anchors %s, nearest seats of two squads %.1f m" % [anchors, best])
	assert_true(best >= SelectionSquads.HALT_CLEAR_M - 0.01, "9 m clear (%.1f)" % best)
	ElementPlan.DEPLOY_STEP = was


func test_pack_off_gives_the_ranks() -> void:
	SelectionSquads.PACK = false
	var f := Fixture.new(self)
	await f.build_scale(15)
	var all: Array[String] = []
	for number in range(1, 4):
		var names := f.controls.groups.members(number)
		for i in names.size():
			f.place(names[i], Vector3((number - 2) * 40.0 + (i - 2) * 6.0, 0, 90))
		all.append_array(names)
	await wait_physics_frames(2)
	f.controls.selection.set_units(all)
	assert_eq(f.controls.order_selection("move", {"to": [0.0, 0.0]}), "", "the order is taken")
	assert_false(f.controls.elements.of(all[0]).task.has("halt_at"), "--pack=off: no packed halt")
