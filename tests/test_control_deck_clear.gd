extends TestCase
## Round 35 (orders D6, R35.38): a squad's place is never so near a bridge deck that its seats reach it, unless he clicked
## on or beside the deck. Planner's Crossing 5 route s3643: a place at the west bridge's mouth laid seats past the deck on
## the far bank, and two squads drove over a bridge he had not clicked across. Pure: SelectionSquads.deck_clear.

const DECK := [-99.0, -3.0, -85.0, 31.0]  # the Crossing's west deck [min_x, min_z, max_x, max_z]


func teardown() -> void:
	SelectionSquads.DECK_CLEAR = true
	super.teardown()


func _near(p: Vector3, reach: float) -> bool:
	return p.x >= DECK[0] - reach and p.x <= DECK[2] + reach and p.z >= DECK[1] - reach and p.z <= DECK[3] + reach


func _same(p: Vector3) -> Vector3:
	return p


func test_a_place_at_the_bridge_mouth_steps_back_until_its_seats_clear() -> void:
	var anchors: Array[Vector3] = [Vector3(-100.5, 0, 38.9), Vector3(-30, 0, 60)]
	var out := SelectionSquads.deck_clear(anchors, [20.0, 20.0], Vector3(-92, 0, 60), Vector3(0, 0, 1), _near, _same)
	assert_true(not _near(out[0], 20.0), "the mouth place clears the deck by its reach (%s)" % out[0])
	assert_true(out[0].z > anchors[0].z, "stepped back the way the squad came (%s)" % out[0])
	assert_eq(out[1], anchors[1], "a place clear of every deck stands")


func test_a_click_on_the_bridge_is_his_choice() -> void:
	var anchors: Array[Vector3] = [Vector3(-92, 0, 33)]
	assert_eq(SelectionSquads.deck_clear(anchors, [20.0], Vector3(-92, 0, 30), Vector3(0, 0, 1), _near, _same), anchors,
			"he clicked the deck: the place stands")


func test_switched_off() -> void:
	SelectionSquads.DECK_CLEAR = false
	var anchors: Array[Vector3] = [Vector3(-100.5, 0, 38.9)]
	assert_eq(SelectionSquads.deck_clear(anchors, [20.0], Vector3(-92, 0, 60), Vector3(0, 0, 1), _near, _same), anchors, "off: as laid")
