extends TestCase
## Round 25 (brains F2): THROUGH A CROSSING AND OPEN AGAIN. "The formation is wider than the bridge, so since units are
## trying to maintain formation, they end up getting stuck crossing the bridge." (2026-10-10, the Crossing.) The plain
## move's travelling shape files through a choke its lanes cannot pass abreast (ElementPlan.funnel), in the order the
## crews arrive (ElementPlan.file_ranks), and opens again after it.

const PITCH := Vector2(12.0, 12.0)


func _wedge() -> Array[Vector2]:
	return TacticsFormation.centered(TacticsFormation.offsets_at("wedge", 5, PITCH))


## A straight 200 m route with a `deck` m wide deck from s = 100 to 130 (the profile: open, then the deck, then open).
func _transit(s: float, deck := 6.0) -> Dictionary:
	var profile: Array = []
	var at := 2.0
	while at < 200.0:
		var on_deck := at > 100.0 and at < 130.0
		profile.append([at, deck if on_deck else INF, 2.0 if on_deck else 0.0, on_deck])
		at += 4.0
	return {"route": [Vector3.ZERO, Vector3(0, 0, -200)], "s": s, "profile": profile, "hull_w": 3.4}


func test_the_shape_files_through_a_deck_and_opens_after_it() -> void:
	var far := ElementPlan.funnel(_wedge(), PITCH, _transit(20.0))
	assert_eq(float(far["weight"]), 0.0, "far from the deck the wedge keeps its shape")
	var mouth := ElementPlan.funnel(_wedge(), PITCH, _transit(100.0))
	assert_eq(float(mouth["weight"]), 1.0, "with its front at a one-hull deck it is a file")
	assert_eq(int(mouth["lanes"]), 1, "one lane")
	var target: Array = mouth["target"]
	var along: Array = []
	for offset: Vector2 in target:
		assert_near(offset.x, 0.0, 0.01, "every seat of the file is on the centre line")
		along.append(offset.y)
	along.sort()
	for i in range(1, along.size()):
		assert_near(float(along[i]) - float(along[i - 1]), PITCH.y, 0.01, "one pitch apart")
	assert_near(ElementPlan.corridor_centre(mouth["centre"], 115.0), 2.0, 0.01,
			"on the deck the file runs down the corridor's middle, not the route's edge")
	var through := ElementPlan.funnel(_wedge(), PITCH, _transit(180.0))
	assert_true(float(through["weight"]) > 0.0, "it stays a file while its tail is still on the deck")
	var after := ElementPlan.funnel(_wedge(), PITCH, _transit(260.0))
	assert_eq(float(after["weight"]), 0.0, "and opens again once the tail is well clear")


func test_a_column_and_an_open_map_are_left_alone() -> void:
	var column := TacticsFormation.centered(TacticsFormation.offsets_at("column", 5, PITCH))
	assert_eq(float(ElementPlan.funnel(column, PITCH, _transit(100.0))["weight"]), 0.0, "a column fits any deck")
	var open := _transit(100.0)
	open["profile"] = []
	assert_eq(float(ElementPlan.funnel(_wedge(), PITCH, open)["weight"]), 0.0, "no profile, no funnel")
	ElementPlan.FUNNEL_ENABLED = false
	var off := ElementPlan.funnel(_wedge(), PITCH, _transit(100.0))
	ElementPlan.FUNNEL_ENABLED = true
	assert_eq(float(off["weight"]), 0.0, "the control arm")


func test_the_file_goes_in_the_order_the_crews_arrive() -> void:
	var route := [Vector3.ZERO, Vector3(0, 0, -100)]
	var ranks := ElementPlan.file_ranks([{"name": "Back", "position": Vector3(5, 0, -10)},
			{"name": "Front", "position": Vector3(-8, 0, -40)}, {"name": "Middle", "position": Vector3(0, 0, -25)}], route)
	assert_eq(ranks, {"Front": 0, "Middle": 1, "Back": 2}, "furthest along the route goes first, whatever its seat")


func test_a_deck_that_holds_two_abreast_takes_two_lanes_not_a_file() -> void:
	var wide := ElementPlan.funnel(_wedge(), PITCH, _transit(100.0, 12.0))
	assert_eq(int(wide["lanes"]), 2, "a 12 m deck holds two hulls abreast")
	var xs := {}
	for offset: Vector2 in wide["target"]:
		xs[snappedf(offset.x, 0.01)] = int(xs.get(snappedf(offset.x, 0.01), 0)) + 1
	assert_eq(xs.size(), 2, "the wedge goes to two lanes (%s)" % xs)
	for x: float in xs:
		assert_true(absf(x) * 2.0 <= 12.0 - 2.0 * ElementPlan.FUNNEL_MARGIN_M + 0.01, "both lanes on the deck (%.1f)" % x)


func test_a_narrow_street_is_not_a_crossing() -> void:
	# The same corridor walled, not watered: round 24's shape (round 23's line forms on the way in the streets).
	var walled := _transit(100.0)
	for sample: Array in walled["profile"]:
		sample[3] = false
	assert_eq(float(ElementPlan.funnel(_wedge(), PITCH, walled)["weight"]), 0.0, "a street keeps the shape")
