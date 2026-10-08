extends TestCase
## Round 21 (orders, O1). Five squads ordered with one click go as a BODY: at most three abreast and at most
## SelectionSquads.MAX_FRONTAGE_M wide, the rest in ranks behind, never the 400 m row that pinned his outer squads at
## ±116 m (round 20: 25 Rat Rods in five squads of five, vees at the gangs' 18 m pitch). Pure: SelectionSquads.ranks.

## A gang vee of five at the gangs' 18 m pitch, as his squads stood in both of his round-20 recordings.
const VEE_W := 64.8
const VEE_D := 36.0
## The click, 150 m north (−Z) of a start line.
const CLICK := Vector3(0, 0, -50)


func _abreast(count: int, width: float, depth: float, spacing := 80.0, z := 100.0) -> Array:
	var blocks: Array = []
	for i in count:
		blocks.append({"center": Vector3((i - (count - 1) * 0.5) * spacing, 0, z), "width": width, "depth": depth})
	return blocks


func _frontage(anchors: Array[Vector3], blocks: Array, heading: Vector3) -> Dictionary:
	# {distance behind the click: frontage of that rank, outer edge to outer edge}
	var across := Vector3(-heading.z, 0, heading.x)
	var by_rank := {}
	for i in anchors.size():
		var behind := snappedf((CLICK - anchors[i]).dot(heading), 0.1)
		var half := float(blocks[i]["width"]) * 0.5
		var span: Array = by_rank.get(behind, [INF, -INF])
		span[0] = minf(span[0], anchors[i].dot(across) - half)
		span[1] = maxf(span[1], anchors[i].dot(across) + half)
		by_rank[behind] = span
	var result := {}
	for key: float in by_rank:
		result[key] = float(by_rank[key][1]) - float(by_rank[key][0])
	return result


func _segments_cross(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> bool:
	var o := func(p: Vector3, q: Vector3, r: Vector3) -> float: return (q.x - p.x) * (r.z - p.z) - (q.z - p.z) * (r.x - p.x)
	var d1: float = o.call(a, b, c)
	var d2: float = o.call(a, b, d)
	var d3: float = o.call(c, d, a)
	var d4: float = o.call(c, d, b)
	return d1 * d2 < -1e-6 and d3 * d4 < -1e-6


func test_rank_sizes() -> void:
	assert_eq(SelectionSquads.rank_sizes(1, VEE_W), [1] as Array[int], "one squad, one rank")
	assert_eq(SelectionSquads.rank_sizes(5, VEE_W), [2, 2, 1] as Array[int],
			"five gang vees at 18 m: three abreast is 222 m, over the cap, so 2 + 2 + 1")
	assert_eq(SelectionSquads.rank_sizes(5, 54.0), [3, 2] as Array[int], "five Law wedges at 15 m: 190 m fits, 3 + 2")
	assert_eq(SelectionSquads.rank_sizes(4, VEE_W), [2, 2] as Array[int], "four: two and two, not three and one")
	assert_eq(SelectionSquads.rank_sizes(6, 40.0), [3, 3] as Array[int], "six narrow squads: three and three")
	assert_eq(SelectionSquads.rank_sizes(3, 250.0), [1, 1, 1] as Array[int], "a squad wider than the cap stands alone")


func test_two_squads_are_still_the_row() -> void:
	# His approved round-19 case, even for two shapes too wide for one rank together.
	for width: float in [56.0, VEE_W, 137.0]:
		var blocks := _abreast(2, width, VEE_D)
		assert_eq(SelectionSquads.ranks(blocks, CLICK), SelectionSquads.row(blocks, CLICK),
				"two squads %.0f m wide: side by side exactly as round 19" % width)


func test_three_that_fit_are_one_row() -> void:
	var blocks := _abreast(3, 54.0, 30.0)
	assert_eq(SelectionSquads.ranks(blocks, CLICK), SelectionSquads.row(blocks, CLICK), "three wedges at 15 m: one row")


func test_five_gang_vees_stand_as_a_body() -> void:
	var blocks := _abreast(5, VEE_W, VEE_D)
	var anchors := SelectionSquads.ranks(blocks, CLICK)
	var heading := Vector3(0, 0, -1)
	var fronts := _frontage(anchors, blocks, heading)
	assert_eq(fronts.size(), 3, "three ranks (%s)" % [fronts])
	for behind: float in fronts:
		assert_true(float(fronts[behind]) <= SelectionSquads.MAX_FRONTAGE_M + 0.01,
				"the rank %.0f m behind the click is %.1f m wide, within the cap" % [behind, fronts[behind]])
		assert_true(behind >= -0.01, "nobody stands past the click (a rank %.1f m behind it)" % behind)
	assert_true(fronts.has(0.0), "the front rank stands across the click")
	# Slots never overlap: any two anchors are a whole slot apart across, or a whole slot apart along.
	for i in anchors.size():
		for j in range(i + 1, anchors.size()):
			var d := anchors[i] - anchors[j]
			assert_true(absf(d.x) >= VEE_W + SelectionSquads.GAP_M - 0.01 or absf(d.z) >= VEE_D + SelectionSquads.GAP_M - 0.01,
					"squads %d and %d stand clear of each other (%s, %s)" % [i, j, anchors[i], anchors[j]])
			assert_true(not _segments_cross(blocks[i]["center"], anchors[i], blocks[j]["center"], anchors[j]),
					"squads %d and %d do not cross on the way" % [i, j])
	# The whole body is no wider than the cap: the 380 m row is gone.
	var west := INF
	var east := -INF
	for p in anchors:
		west = minf(west, p.x - VEE_W * 0.5)
		east = maxf(east, p.x + VEE_W * 0.5)
	assert_true(east - west <= SelectionSquads.MAX_FRONTAGE_M, "the body is %.0f m wide (the row was 380 m)" % (east - west))


func test_the_ranks_are_centred_and_stepped_by_a_depth_and_a_gap() -> void:
	var blocks := _abreast(5, 54.0, 30.0)
	var anchors := SelectionSquads.ranks(blocks, CLICK)
	var zs := {}
	for p in anchors:
		zs[snappedf(p.z, 0.1)] = (zs.get(snappedf(p.z, 0.1), []) as Array) + [p.x]
	assert_eq(zs.size(), 2, "five Law-sized squads: two ranks")
	assert_true(zs.has(CLICK.z), "the front rank on the click")
	assert_true(zs.has(CLICK.z + 30.0 + SelectionSquads.GAP_M), "the second one depth plus a gap behind (%s)" % [zs.keys()])
	for z: float in zs:
		var xs: Array = zs[z]
		var middle := 0.0
		for x: float in xs:
			middle += x
		assert_near(middle / xs.size(), CLICK.x, 0.01, "the rank at z %.1f is centred on the click" % z)
	assert_eq((zs[CLICK.z] as Array).size(), 3, "three in front")


func test_a_drawn_heading_lays_the_ranks_across_it() -> void:
	var blocks := _abreast(5, VEE_W, VEE_D)
	var anchors := SelectionSquads.ranks(blocks, CLICK, Vector3(1, 0, 0))  # face east
	for p in anchors:
		assert_true(p.x <= CLICK.x + 0.01, "facing east, every rank stands at or west of the click (%s)" % p)
	var front := 0
	for p in anchors:
		if absf(p.x - CLICK.x) < 0.01:
			front += 1
	assert_eq(front, 2, "two in the front rank, north and south of each other")


## Round 21 (the orchestrator's ruling on O1b): the front rank stands ON the click, nothing beyond it (round 19: "arrive
## at the point he clicked"; on an attack-move a squad past it drives into contact he did not choose). A rear squad with
## a short way to go simply gets there first; what must hold is that every squad goes TOWARD the click.
func test_every_squad_moves_toward_the_click() -> void:
	var blocks := _abreast(5, VEE_W, VEE_D)
	var anchors := SelectionSquads.ranks(blocks, CLICK)
	for i in anchors.size():
		var start: Vector3 = blocks[i]["center"]
		assert_true(anchors[i].distance_to(CLICK) < start.distance_to(CLICK),
				"squad %d ends closer to the click than it started (%.0f m < %.0f m)" % [i, anchors[i].distance_to(CLICK), start.distance_to(CLICK)])
		assert_true((anchors[i] - start).dot(CLICK - start) > 0.0, "squad %d moves toward the click" % i)


func test_the_outer_squads_do_not_drive_sideways_first() -> void:
	# His case: five abreast 150 m short of the click. The worst sideways move is the slot offset, never the 116 m wall.
	var blocks := _abreast(5, VEE_W, VEE_D, 80.0)
	var anchors := SelectionSquads.ranks(blocks, CLICK)
	for i in anchors.size():
		assert_true(absf(anchors[i].x) <= SelectionSquads.MAX_FRONTAGE_M * 0.5,
				"squad %d's anchor is within the body's half-width of the click (x %.1f)" % [i, anchors[i].x])
		var start: Vector3 = blocks[i]["center"]
		assert_true(absf(anchors[i].x) <= absf(start.x) + 0.01,
				"squad %d moves inward or straight, never outward (%.1f → %.1f)" % [i, start.x, anchors[i].x])


func test_a_body_near_a_wall_slides_inward_whole() -> void:
	var square := func(p: Vector3) -> Vector3:
		return Vector3(clampf(p.x, -116.0, 116.0), p.y, clampf(p.z, -116.0, 116.0))
	var blocks := _abreast(5, VEE_W, VEE_D)
	var near_wall := Vector3(100, 0, -50)
	var laid := SelectionSquads.ranks(blocks, near_wall)
	var fitted := SelectionSquads.fit_inside(laid, square)
	for i in fitted.size():
		assert_true(absf(fitted[i].x) <= 116.01, "squad %d is inside the wall (%s)" % [i, fitted[i]])
		for j in range(i + 1, fitted.size()):
			assert_true((fitted[i] - fitted[j]).distance_to(laid[i] - laid[j]) < 0.01,
					"squads %d and %d keep their places in the body" % [i, j])
	var inside := SelectionSquads.ranks(blocks, CLICK)
	assert_eq(SelectionSquads.fit_inside(inside, square), inside, "a body that fits is left exactly where it was laid")


func test_more_blocks_than_the_search_still_get_one_slot_each() -> void:
	var blocks := _abreast(8, 30.0, 20.0, 30.0)
	var anchors := SelectionSquads.ranks(blocks, CLICK)
	var seen := {}
	for p in anchors:
		seen[Vector2(snappedf(p.x, 0.1), snappedf(p.z, 0.1))] = true
	assert_eq(seen.size(), 8, "eight squads, eight different slots")


## Round 22 (orders O3): ten squads a side. The front ranks are filled first and the rest stand behind them (ten Law
## wedges: 3 + 3 + 3 + 1, three platoons and a reserve), the front rank on the click, no rank over the cap.
func test_rank_sizes_at_six_eight_ten() -> void:
	assert_eq(SelectionSquads.rank_sizes(6, 54.0), [3, 3] as Array[int], "six wedges: 3 + 3")
	assert_eq(SelectionSquads.rank_sizes(8, 54.0), [3, 3, 2] as Array[int], "eight wedges: 3 + 3 + 2")
	assert_eq(SelectionSquads.rank_sizes(10, 54.0), [3, 3, 3, 1] as Array[int], "ten wedges: 3 + 3 + 3 + 1")
	assert_eq(SelectionSquads.rank_sizes(10, VEE_W), [2, 2, 2, 2, 2] as Array[int], "ten gang vees: two abreast, five ranks")
	assert_eq(SelectionSquads.rank_sizes(7, VEE_W), [2, 2, 2, 1] as Array[int], "seven gang vees: 2 + 2 + 2 + 1")


func _check_body(count: int, width: float, depth: float, spacing: float, rows := 1, start_z := 100.0) -> void:
	var blocks: Array = []
	var per_row := ceili(float(count) / rows)
	for i in count:
		var column := i % per_row
		var row := i / per_row
		blocks.append({"center": Vector3((column - (per_row - 1) * 0.5) * spacing, 0, start_z + row * 40.0), "width": width, "depth": depth})
	var anchors := SelectionSquads.ranks(blocks, CLICK)
	var heading := Vector3(0, 0, -1)
	var fronts := _frontage(anchors, blocks, heading)
	var sizes := SelectionSquads.rank_sizes(count, width)
	assert_eq(fronts.size(), sizes.size(), "%d blocks: %d ranks (%s)" % [count, sizes.size(), fronts])
	assert_true(fronts.has(0.0), "%d blocks: the front rank is on the click" % count)
	var deepest := 0.0
	for behind: float in fronts:
		assert_true(behind >= -0.01, "%d blocks: nobody past the click (%.1f)" % [count, behind])
		assert_true(float(fronts[behind]) <= SelectionSquads.MAX_FRONTAGE_M + 0.01, "%d blocks: the rank %.0f m back is %.0f m wide"
				% [count, behind, fronts[behind]])
		deepest = maxf(deepest, behind)
	assert_near(deepest, (sizes.size() - 1) * (depth + SelectionSquads.GAP_M), 0.1, "%d blocks: ranks one depth and a gap apart" % count)
	var seen := {}
	for i in anchors.size():
		seen[Vector2(snappedf(anchors[i].x, 0.1), snappedf(anchors[i].z, 0.1))] = true
		for j in range(i + 1, anchors.size()):
			var d := anchors[i] - anchors[j]
			assert_true(absf(d.x) >= width + SelectionSquads.GAP_M - 0.01 or absf(d.z) >= depth + SelectionSquads.GAP_M - 0.01,
					"%d blocks: squads %d and %d stand clear" % [count, i, j])
			assert_true(not _segments_cross(blocks[i]["center"], anchors[i], blocks[j]["center"], anchors[j]),
					"%d blocks: squads %d and %d do not cross on the way" % [count, i, j])
	assert_eq(seen.size(), count, "%d blocks: one slot each" % count)
	for i in anchors.size():
		var start: Vector3 = blocks[i]["center"]
		assert_true(anchors[i].distance_to(CLICK) < start.distance_to(CLICK),
				"%d blocks: squad %d ends closer to the click (%.0f < %.0f)" % [count, i, anchors[i].distance_to(CLICK), start.distance_to(CLICK)])


func test_six_eight_ten_squads_stand_as_a_body() -> void:
	for count: int in [6, 8, 10]:
		_check_body(count, 54.0, 30.0, 70.0)
		_check_body(count, 54.0, 30.0, 70.0, 2)  # the start as ArmyLayout deals ten: two lines
	# Ten gang vees stand two abreast in five ranks, 200 m from front to rear rank: from 300 m out every squad still
	# closes on the click. (From 150 m out the rear rank's slot is behind where it started: the body is deeper than
	# the order is long. Known, in Status.)
	_check_body(10, VEE_W, VEE_D, 70.0, 2, 250.0)


## Ten squads are past the exhaustive search; the assignment is still the least total driving, so no two paths cross
## even when the whole army starts abreast (a greedy deal sent the west squads to the front across the middle ones).
func test_ten_abreast_do_not_cross() -> void:
	var blocks := _abreast(10, 54.0, 30.0, 60.0)
	var anchors := SelectionSquads.ranks(blocks, CLICK)
	for i in anchors.size():
		for j in range(i + 1, anchors.size()):
			assert_true(not _segments_cross(blocks[i]["center"], anchors[i], blocks[j]["center"], anchors[j]),
					"squads %d and %d do not cross" % [i, j])


func test_a_ten_squad_body_near_a_wall_slides_inward_whole() -> void:
	var square := func(p: Vector3) -> Vector3:
		return Vector3(clampf(p.x, -116.0, 116.0), p.y, clampf(p.z, -116.0, 116.0))
	var blocks := _abreast(10, 54.0, 30.0, 40.0)
	var laid := SelectionSquads.ranks(blocks, Vector3(100, 0, -50))
	var fitted := SelectionSquads.fit_inside(laid, square)
	for i in fitted.size():
		assert_true(absf(fitted[i].x) <= 116.01 and absf(fitted[i].z) <= 116.01, "squad %d inside (%s)" % [i, fitted[i]])
		for j in range(i + 1, fitted.size()):
			assert_true((fitted[i] - fitted[j]).distance_to(laid[i] - laid[j]) < 0.01, "squads %d and %d keep their places" % [i, j])


## The Hungarian assignment finds the same least total as the exhaustive search wherever both run.
func test_least_total_matches_the_exhaustive_search() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	for trial in 20:
		var centers: Array[Vector3] = []
		var slots: Array[Vector3] = []
		for i in 6:
			centers.append(Vector3(rng.randf_range(-150, 150), 0, rng.randf_range(0, 200)))
			slots.append(Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-150, 0)))
		var fast := SelectionSquads.least_total(centers, slots)
		var slow := SelectionSquads._assign(centers, slots)
		var cost := func(given: Array[int]) -> float:
			var total := 0.0
			for i in given.size():
				total += centers[i].distance_to(slots[given[i]])
			return total
		var seen := {}
		for j in fast:
			seen[j] = true
		assert_eq(seen.size(), 6, "trial %d: a slot each" % trial)
		assert_near(cost.call(fast), cost.call(slow), 0.001, "trial %d: the same least total" % trial)


## Round 22 (orders O3, ruling (c)): ranks of the same shape nest. Ten gang vees (18 m) stand two abreast; each rank
## behind steps back only as far as keeps every slot one pitch (18 m) from every slot of the rank in front: 26 m, not
## the vee's depth plus a gap (50 m). Mixed shapes, or AUTO (no offsets), step as round 21.
func test_ranks_of_vees_nest() -> void:
	var offsets := TacticsFormation.offsets("vee", 5, 18.0)
	var step := SelectionSquads.rank_step(2, 2, VEE_W, VEE_D, offsets, 18.0)
	print("MEASURE nested vee rank step %.1f m (plain %.1f m)" % [step, VEE_D + SelectionSquads.GAP_M])
	assert_near(step, 26.0, 0.6, "two gang vees abreast: the next rank 26 m back")
	var blocks: Array = []
	for i in 10:
		blocks.append({"center": Vector3((i % 5 - 2) * 70.0, 0, 250.0 + (i / 5) * 40.0), "width": VEE_W, "depth": VEE_D,
				"shape": "vee", "count": 5, "pitch_v": Vector2(18.0 - (i % 2) * 0.5, 18.0)})  # a floor here and there
	var anchors := SelectionSquads.ranks(blocks, CLICK)
	var deepest := 0.0
	for p in anchors:
		deepest = maxf(deepest, (p - CLICK).dot(Vector3(0, 0, 1)))
	assert_near(deepest, 4.0 * step, 0.6, "five ranks: %.0f m from front to rear (200 m before)" % deepest)
	# Every vehicle's slot stays GAP_M from every other squad's (side by side in a rank they always stood one gap apart;
	# the nested ranks keep a whole pitch).
	var slots: Array = []
	for i in anchors.size():
		for offset: Vector2 in offsets:
			slots.append([i, TacticsFormation.to_world(anchors[i], Vector3(0, 0, -1), offset)])
	for a in slots.size():
		for b in range(a + 1, slots.size()):
			if int(slots[a][0]) != int(slots[b][0]):
				assert_true((slots[a][1] as Vector3).distance_to(slots[b][1]) >= SelectionSquads.GAP_M - 0.01,
						"squads %d and %d: slots a gap apart" % [slots[a][0], slots[b][0]])
	var mixed := blocks.duplicate(true)
	mixed[3]["shape"] = "wedge"
	assert_eq(SelectionSquads.nested_offsets(mixed), [], "one wedge among the vees: no nesting")
	var plain := blocks.duplicate(true)
	for block: Dictionary in plain:
		block.erase("shape")
	var laid := SelectionSquads.ranks(plain, CLICK)
	var back := 0.0
	for p in laid:
		back = maxf(back, (p - CLICK).dot(Vector3(0, 0, 1)))
	assert_near(back, 4.0 * (VEE_D + SelectionSquads.GAP_M), 0.1, "AUTO squads step their depth and a gap, as round 21")
