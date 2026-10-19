extends TestCase
## Round 34 (R34.12; planner's O5 probe): a rank never stands behind its own squad. Five squads clicked from close behind:
## round 23's ranks laid the back rank 71.6 m behind the click (the Locks), at or behind where those squads already stood,
## so they "arrived" at once or drove away from his click (the Terminus, 7-15 m).

const CLICK := Vector3(0, 0, 0)


func teardown() -> void:
	SelectionSquads.RANK_FORWARD = true
	super.teardown()


## Five squads of five standing 40 m behind the click (the approach is north, -z): today's back rank stands behind them.
func _five_close_behind() -> Array:
	var blocks := []
	for i in 5:
		blocks.append({"center": Vector3((i - 2) * 30.0, 0, 40.0), "width": 56.0, "depth": 28.0})
	return blocks


func test_setup_todays_back_rank_stands_behind_its_squads() -> void:
	var blocks := _five_close_behind()
	var anchors := SelectionSquads.ranks(blocks, CLICK)
	var behind := 0
	for i in anchors.size():
		if anchors[i].z > (blocks[i]["center"] as Vector3).z + 0.5:
			behind += 1
	assert_true(behind >= 1, "round 23's ranks put at least one anchor behind its own squad (%s)" % [anchors])


func test_no_anchor_stands_behind_its_own_squad() -> void:
	var blocks := _five_close_behind()
	var heading := SelectionSquads.approach_of(blocks, CLICK)
	var anchors := SelectionSquads.never_behind(SelectionSquads.ranks(blocks, CLICK), blocks, CLICK, heading)
	for i in anchors.size():
		assert_true(anchors[i].z <= (blocks[i]["center"] as Vector3).z + 0.01,
				"squad %d's anchor %s is not behind where it stands (%s)" % [i, anchors[i], blocks[i]["center"]])


func test_a_front_rank_and_its_place_across_are_untouched() -> void:
	var blocks := _five_close_behind()
	var heading := SelectionSquads.approach_of(blocks, CLICK)
	var laid := SelectionSquads.ranks(blocks, CLICK)
	var anchors := SelectionSquads.never_behind(laid, blocks, CLICK, heading)
	for i in anchors.size():
		assert_near(anchors[i].x, laid[i].x, 0.01, "squad %d keeps its place across the approach" % i)
		if laid[i].z <= (blocks[i]["center"] as Vector3).z:
			assert_eq(anchors[i], laid[i], "squad %d was not behind: unchanged" % i)


func test_the_switch_off_is_round_23s_ranks() -> void:
	SelectionSquads.RANK_FORWARD = false
	var blocks := _five_close_behind()
	var laid := SelectionSquads.ranks(blocks, CLICK)
	assert_eq(SelectionSquads.never_behind(laid, blocks, CLICK, Vector3(0, 0, -1)), laid, "--rank-forward=off: unchanged")
