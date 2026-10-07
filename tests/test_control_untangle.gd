extends TestCase
## Round 22 (orders O1b). The lead: "I have 6 vehicles selected and I was trying to move them to a location in line
## formation. There were 2 resultant points ... the lines were criss-crossed in terms of current position versus what
## they were trying to achieve ... the vehicles were all basically bumping each other." His six were two squads of three
## (Green_Hunters 1, 5, 7 and 4, 6, 8) standing interleaved; the row laid the squads side by side, so the two threes
## drove through each other. SelectionSquads.untangle deals the vehicles to the laid places by least total driving
## whenever two squads' vehicles would cross, so each line is made of the vehicles already on its side. Pure.

## His six at tick 4410 of 2026-10-07T13-46-42-sumps (the Sumps, seed 5988), and his click between the two points.
const HIS := {"Green_Hunters_1": Vector3(66.1, 0, -72.3), "Green_Hunters_4": Vector3(63.1, 0, -64.2),
		"Green_Hunters_5": Vector3(55.9, 0, -80.1), "Green_Hunters_6": Vector3(47.9, 0, -82.6),
		"Green_Hunters_7": Vector3(43.2, 0, -87.9), "Green_Hunters_8": Vector3(57.0, 0, -71.7)}
const CLICK := Vector3(96.0, 0, 23.6)


func _squad(number: int, units: Array) -> Dictionary:
	var typed: Array[String] = []
	typed.assign(units)
	return {"number": number, "units": typed, "element": null}


func _middle(units: Array) -> Vector3:
	var sum := Vector3.ZERO
	for u: String in units:
		sum += HIS[u]
	return sum / units.size()


## Straight paths start -> slot of every vehicle, for two lines of three across `heading` at the row's anchors,
## each line seated by least total driving: how many pairs cross.
func _anchors(squads: Array, heading: Vector3) -> Array[Vector3]:
	var blocks: Array = []
	for squad: Dictionary in squads:
		blocks.append({"center": _middle(squad["units"]), "width": 28.0})
	return SelectionSquads.row(blocks, CLICK, heading)


## [between lines, within a line]: pairs of crossing paths of vehicles in different lines (what O1b fixes) and in the
## same line (the line's own seating, brains' "travel" policy: least SQUARED driving, which keeps a column's order
## and can swap two vehicles standing one behind the other).
func _crossings(squads: Array, anchors: Array[Vector3], heading: Vector3) -> Array[int]:
	var paths: Array = []
	for i in squads.size():
		var units: Array = squads[i]["units"]
		var offsets := TacticsFormation.offsets("line", units.size(), 14.0)
		var members: Array = units.map(func(u: String) -> Dictionary: return {"name": u, "position": HIS[u], "unit": "law_ifv"})
		var seats := TacticsFormation.seat(members, offsets, anchors[i], heading, {"policy": "travel", "spacing": 14.0})
		for u: String in units:
			paths.append([i, HIS[u], TacticsFormation.to_world(anchors[i], heading, offsets[int(seats[u])])])
	var between := 0
	var within := 0
	for a in paths.size():
		for b in range(a + 1, paths.size()):
			if Geometry2D.segment_intersects_segment(_v2(paths[a][1]), _v2(paths[a][2]), _v2(paths[b][1]), _v2(paths[b][2])) != null:
				if int(paths[a][0]) == int(paths[b][0]):
					within += 1
				else:
					between += 1
	return [between, within]


func _v2(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


func test_his_interleaved_squads_are_dealt_by_where_they_stand() -> void:
	var squads := [_squad(1, ["Green_Hunters_1", "Green_Hunters_5", "Green_Hunters_7"]),
			_squad(2, ["Green_Hunters_4", "Green_Hunters_6", "Green_Hunters_8"])]
	var heading := (CLICK - _middle(HIS.keys())).normalized()
	var anchors := _anchors(squads, heading)
	var before := _crossings(squads, anchors, heading)
	var dealt := SelectionSquads.untangle(squads, anchors, func(u: String) -> Vector3: return HIS[u])
	assert_eq(dealt.size(), 2, "still two squads of three (five is a squad's most)")
	assert_eq((dealt[0]["units"] as Array).size() + (dealt[1]["units"] as Array).size(), 6, "all six")
	var after := _crossings(dealt, anchors, heading)
	print("MEASURE untangle his six: crossings between lines %d -> %d, within a line %d -> %d; %s / %s" % [before[0],
			after[0], before[1], after[1], dealt[0]["units"], dealt[1]["units"]])
	assert_true(before[0] > 0, "the row as it was sends crews through the other line (%d)" % before[0])
	assert_eq(after[0], 0, "dealt by position, no crew drives through the other line")
	for squad: Dictionary in dealt:
		assert_true(squad.get("dealt", false), "a re-dealt squad says so")
		assert_eq(squad["element"], null, "and forms a new element for the order")
	var numbers := [int(dealt[0]["number"]), int(dealt[1]["number"])]
	numbers.sort()
	assert_eq(numbers, [1, 2], "the two numbers are kept (his keys, formations and names)")


func test_squads_side_by_side_are_left_alone() -> void:
	var at := {"a1": Vector3(-40, 0, 0), "a2": Vector3(-30, 0, 0), "a3": Vector3(-20, 0, 0),
			"b1": Vector3(20, 0, 0), "b2": Vector3(30, 0, 0)}
	var a := _squad(1, ["a1", "a2", "a3"])
	var b := _squad(2, ["b1", "b2"])
	var anchors: Array[Vector3] = [Vector3(-30, 0, -100), Vector3(25, 0, -100)]
	var dealt := SelectionSquads.untangle([a, b], anchors, func(u: String) -> Vector3: return at[u])
	assert_true(dealt[0] == a and dealt[1] == b, "squads apart are untouched (their elements and numbers kept)")
	assert_true(not dealt[0].has("dealt"), "and not marked")


func test_one_squad_and_loose_nothing_to_deal() -> void:
	var at := {"a1": Vector3(0, 0, 0)}
	var a := _squad(1, ["a1"])
	var anchors: Array[Vector3] = [Vector3(0, 0, -50)]
	assert_eq(SelectionSquads.untangle([a], anchors, func(u: String) -> Vector3: return at[u]), [a], "one squad as it was")


## The body at ten (ranks) and an attack-move use the same deal: two squads of a body standing interleaved behind
## the rest are dealt to their two places by position, the other squads untouched.
func test_a_body_of_squads_untangles_only_the_interleaved_ones() -> void:
	var at := {}
	var squads: Array = []
	for i in 4:
		var units: Array = []
		for k in 5:
			var name := "s%d_%d" % [i, k]
			at[name] = Vector3((i - 1.5) * 70.0 + (k - 2) * 12.0, 0, 120.0)
			units.append(name)
		squads.append(_squad(i + 1, units))
	# Squads 5 and 6 stand interleaved in one column behind the line.
	var five: Array = []
	var six: Array = []
	for k in 5:
		at["s4_%d" % k] = Vector3(-6.0 + (k % 2) * 12.0, 0, 170.0 + k * 9.0)
		at["s5_%d" % k] = Vector3(6.0 - (k % 2) * 12.0, 0, 174.0 + k * 9.0)
		five.append("s4_%d" % k)
		six.append("s5_%d" % k)
	squads.append(_squad(5, five))
	squads.append(_squad(6, six))
	var blocks: Array = []
	for squad: Dictionary in squads:
		var sum := Vector3.ZERO
		for u: String in squad["units"]:
			sum += at[u]
		blocks.append({"center": sum / 5.0, "width": 54.0, "depth": 30.0})
	var anchors := SelectionSquads.ranks(blocks, Vector3(0, 0, -50))
	var position := func(u: String) -> Vector3: return at[u]
	var dealt := SelectionSquads.untangle(squads, anchors, position)
	var paths: Array = []
	for i in dealt.size():
		for u: String in dealt[i]["units"]:
			paths.append([i, at[u], anchors[i]])
	assert_true(not SelectionSquads._any_cross(paths), "no two squads' vehicles cross after the deal")
	var kept := 0
	for i in 4:
		if dealt[i] == squads[i]:
			kept += 1
	assert_eq(kept, 4, "the four squads in the line are untouched")


## Through the controls: two squads of three standing interleaved in one column, both selected, a line picked, one
## order ahead. The two lines are made of the vehicles on their own sides (no two crews' paths cross), there are two
## pins (one per line, not one per crew), and his groups 1 and 2 still hold the squads he made.
func test_through_the_controls_interleaved_squads_do_not_cross() -> void:
	var f := preload("res://tests/support/control_fixture.gd").new(self)
	await f.build_scale(10)
	var s1: Array[String] = f.controls.groups.members(1).slice(0, 3)
	var s2: Array[String] = f.controls.groups.members(2).slice(0, 3)
	f.controls.groups.save(1, s1)
	f.controls.groups.save(2, s2)
	# One column heading north, the two squads alternating: 1, 2, 1, 2, 1, 2 from the front, a step left and right.
	var column: Array[String] = []
	for i in 3:
		column.append(s1[i])
		column.append(s2[i])
	var starts := {}
	for i in column.size():
		var at := Vector3(-3.0 if i % 3 == 0 else 3.0, 0, 40.0 + i * 9.0)
		f.place(column[i], at)
		starts[column[i]] = at
	await wait_physics_frames(2)
	var six: Array[String] = s1 + s2
	f.controls.selection.set_units(six)
	f.controls.set_formation("line")
	assert_eq(f.controls.order_selection("move", {"to": [20.0, -90.0]}), "", "the order is taken")
	await wait_physics_frames(10)
	var paths: Array = []
	var lines := {}
	for unit_name in six:
		var element := f.controls.elements.of(unit_name)
		assert_true(element != null, "%s is in a line" % unit_name)
		if element == null:
			continue
		lines[element] = true
		var slot: Variant = f.controls.arrival_slot(unit_name)
		assert_true(slot is Vector3, "%s has a slot" % unit_name)
		if slot is Vector3:
			paths.append([element.id, starts[unit_name], Vector3((slot as Vector3).x, 0, (slot as Vector3).z)])
	assert_eq(lines.size(), 2, "two lines")
	assert_true(not SelectionSquads._any_cross(paths), "no crew drives through the other line (%s)" % [paths])
	assert_eq(f.controls.order_marks().size(), 2, "two pins, one per line")
	assert_eq(f.controls.groups.members(1), s1, "group 1 still holds the squad he made")
	assert_eq(f.controls.groups.members(2), s2, "and group 2 its own")
