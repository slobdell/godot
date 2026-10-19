extends TestCase
## R34.12b (planner's O5 probe, builder0: five squads, one click, the back rank's anchors 62-72 m behind the click, within
## ~9 m of where they stood: they "arrived" in 0.1 s and stayed home). O3 had priced an AUTO squad's rank depth at its
## herringbone halt (54.8 m), so the ranks stepped ~69 m. The step is now the travel shape's, widened only as far as the
## two ranks' HALT seats need for hull clearance (SelectionSquads.halt_clear_step; his correction 1).

const CLICK := Vector3(0, 0, 0)


## Five AUTO squads of five, standing ~70 m behind the click (the Terminus case), as _squad_block lays them under O3.
func _blocks() -> Array:
	var blocks := []
	for i in 5:
		blocks.append({"center": Vector3((i - 2) * 25.0, 0, 70.0), "width": SelectionSquads.halt_footprint("herringbone", 5, 14.0).x,
				"depth": SelectionSquads.depth("auto", 5, 14.0), "shape": "wedge", "count": 5, "pitch_v": Vector2(14, 14),
				"halt_depth": SelectionSquads.depth("coil", 5, 14.0), "halt": "herringbone"})
	return blocks


func test_the_back_rank_comes_toward_the_click() -> void:
	var blocks := _blocks()
	var anchors := SelectionSquads.ranks(blocks, CLICK)
	var deepest := 0.0
	for i in anchors.size():
		var advance := (blocks[i]["center"] as Vector3).z - anchors[i].z
		deepest = maxf(deepest, anchors[i].z)
		assert_true(advance >= 20.0, "squad %d drives %.1f m toward the click (>= 20; anchor %s)" % [i, advance, anchors[i]])
	print("MEASURE rank_halt_clear five AUTO herringbones: back rank %.1f m behind the click" % deepest)


func test_no_two_squads_halt_seats_within_hull_clearance() -> void:
	var blocks := _blocks()
	var anchors := SelectionSquads.ranks(blocks, CLICK)
	var seats := SelectionSquads.halt_offsets("herringbone", 5, 14.0)
	var closest := INF
	for a in anchors.size():
		for b in range(a + 1, anchors.size()):
			for p in seats:
				for q in seats:
					# halt_offsets' y is ahead along the approach (here -z): a seat stands at anchor + (x, 0, -y).
					var sa := anchors[a] + Vector3(p.x, 0, -p.y)
					var sb := anchors[b] + Vector3(q.x, 0, -q.y)
					closest = minf(closest, sa.distance_to(sb))
	assert_true(closest >= SelectionSquads.HALT_CLEAR_M - 0.01, "different squads' halt seats at least %.0f m apart (%.1f)" % [SelectionSquads.HALT_CLEAR_M, closest])


func test_the_step_widens_only_as_far_as_clearance_needs() -> void:
	var blocks := _blocks()
	var travel := SelectionSquads.depth("auto", 5, 14.0) + SelectionSquads.GAP_M
	var full := SelectionSquads.halt_footprint("herringbone", 5, 14.0).y + SelectionSquads.GAP_M
	var step := SelectionSquads.halt_clear_step(travel, 3, 2, float(blocks[0]["width"]), blocks)
	assert_true(step >= travel and step <= full, "between the travel step %.1f and the halt's full %.1f (%.1f)" % [travel, full, step])
