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
	var depth_sum := 0.0
	for behind: float in fronts:
		assert_true(float(fronts[behind]) <= SelectionSquads.MAX_FRONTAGE_M + 0.01,
				"the rank %.0f m behind the click is %.1f m wide, within the cap" % [behind, fronts[behind]])
		depth_sum += behind
	assert_true(fronts.has(0.0), "the middle rank stands across the click: the click is the body's centre (%s)" % [fronts.keys()])
	assert_near(depth_sum, 0.0, 0.5, "as far ahead of the click as behind it")
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
	var half := (30.0 + SelectionSquads.GAP_M) * 0.5
	assert_true(zs.has(snappedf(CLICK.z - half, 0.1)), "the front rank half a step ahead of the click (%s)" % [zs.keys()])
	assert_true(zs.has(snappedf(CLICK.z + half, 0.1)), "the second one depth plus a gap behind it (%s)" % [zs.keys()])
	for z: float in zs:
		var xs: Array = zs[z]
		var middle := 0.0
		for x: float in xs:
			middle += x
		assert_near(middle / xs.size(), CLICK.x, 0.01, "the rank at z %.1f is centred on the click" % z)
	assert_eq((zs[snappedf(CLICK.z - half, 0.1)] as Array).size(), 3, "three in front")


func test_a_drawn_heading_lays_the_ranks_across_it() -> void:
	var blocks := _abreast(5, VEE_W, VEE_D)
	var anchors := SelectionSquads.ranks(blocks, CLICK, Vector3(1, 0, 0))  # face east
	var front := 0
	for p in anchors:
		if p.x > CLICK.x + 1.0:
			front += 1
	assert_eq(front, 2, "facing east, two in the front rank east of the click, north and south of each other")
	var counts := {}
	for p in anchors:
		counts[snappedf(p.x, 0.1)] = int(counts.get(snappedf(p.x, 0.1), 0)) + 1
	assert_eq(counts.size(), 3, "three ranks along the east-west line (%s)" % [counts])


## Round 21 (the orchestrator, from the wall frame): every squad goes a real way toward the click. With the front rank
## on the click, the rear squad's slot was 48 m from its start and it stood idle after 4 s while the rest drove 150 m.
func test_every_squad_goes_most_of_the_way() -> void:
	var blocks := _abreast(5, VEE_W, VEE_D)
	var anchors := SelectionSquads.ranks(blocks, CLICK)
	var to_click := (blocks[2]["center"] as Vector3).distance_to(CLICK)
	for i in anchors.size():
		var start: Vector3 = blocks[i]["center"]
		assert_true(start.distance_to(anchors[i]) >= to_click * 0.6,
				"squad %d drives %.0f m of the %.0f m to the click" % [i, start.distance_to(anchors[i]), to_click])


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
