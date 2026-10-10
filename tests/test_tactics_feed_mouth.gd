extends TestCase
## Round 25 (brains F3'): a drill move FEEDS its crews to a bridge one at a time (ElementPlan.feed_mouth). His bridge
## (the Locks, his attack-move) across start ticks: three crews reached the swing bridge's mouth at once and the middle
## one was squeezed against the canal's rim. Pure: positions, seats, the decks and a "this leg crosses water" test.

const DECK := [-99.0, -12.0, -85.0, 12.0]  # the Locks' west swing bridge, [min_x, min_z, max_x, max_z]


func _crosses(from: Vector3, to: Vector3) -> bool:
	return signf(from.z) != signf(to.z)  # the canal runs along z = 0


func _crew(name: String, at: Vector3) -> Dictionary:
	return {"name": name, "position": at}


func test_the_crew_nearest_the_deck_goes_and_the_next_waits_its_turn() -> void:
	var members: Array = [_crew("Near", Vector3(-92, 0, 14)), _crew("Next", Vector3(-88, 0, 20)), _crew("Far", Vector3(-70, 0, 40))]
	var seats := {"Near": Vector3(-90, 0, -30), "Next": Vector3(-80, 0, -30), "Far": Vector3(-70, 0, -30)}
	var held := ElementPlan.feed_mouth(members, seats, [DECK], _crosses)
	assert_true(not held.has("Near"), "the crew nearest the deck goes")
	assert_eq(float(held.get("Next", -1.0)), 0.0, "the next one, within FEED_HOLD_M of the deck, stands")
	assert_true(not held.has("Far"), "one still far from the deck keeps driving up")


func test_once_the_first_is_on_the_deck_the_next_goes() -> void:
	var members: Array = [_crew("On", Vector3(-92, 0, 2)), _crew("Next", Vector3(-88, 0, 18))]
	var seats := {"On": Vector3(-90, 0, -30), "Next": Vector3(-80, 0, -30)}
	assert_true(ElementPlan.feed_mouth(members, seats, [DECK], _crosses).is_empty(),
			"a crew already on the deck holds nobody up at the mouth")


func test_crews_not_crossing_and_the_control_arm_are_left_alone() -> void:
	var members: Array = [_crew("A", Vector3(-92, 0, 14)), _crew("B", Vector3(-88, 0, 20))]
	var same_side := {"A": Vector3(-90, 0, 30), "B": Vector3(-80, 0, 30)}
	assert_true(ElementPlan.feed_mouth(members, same_side, [DECK], _crosses).is_empty(), "nobody crossing, nobody held")
	ElementPlan.FEED_MOUTH_ENABLED = false
	var off := ElementPlan.feed_mouth(members, {"A": Vector3(-90, 0, -30), "B": Vector3(-80, 0, -30)}, [DECK], _crosses)
	ElementPlan.FEED_MOUTH_ENABLED = true
	assert_true(off.is_empty(), "the control arm holds nobody")
