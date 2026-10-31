extends TestCase
## Round 47 (orders O5, C47.5): the order's recipient, obvious the moment he gives it. His Sumps game: the screen order he
## meant for his tanks (Bravo) went to his artillery (Charlie), selected 17 frames before, and nothing on screen said so. The
## vehicles that receive an order pulse (SelectionMarkers' "ordered" ring) and their group's chip flashes (GroupBar's `cue`),
## for RtsControls.CUE_PULSES pulses of CUE_PULSE_S; nobody else does.

const Fixture := preload("res://tests/support/control_fixture.gd")
const ALPHA := ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]
const BRAVO := ["Green_Bravo_1", "Green_Bravo_2"]


func teardown() -> void:
	RtsControls.clear_cues()
	super.teardown()


func test_the_cue_runs_its_pulses_then_stops() -> void:
	RtsControls.clear_cues()
	RtsControls._cued["Green_Alpha_1"] = 1000
	assert_eq(RtsControls.order_cue("Green_Alpha_1", 1000), 0.0, "a pulse starts at the order")
	assert_true(absf(RtsControls.order_cue("Green_Alpha_1", 1000 + int(RtsControls.CUE_PULSE_S * 500)) - 0.5) < 0.01, "half way through")
	assert_true(RtsControls.order_cue("Green_Alpha_1", 1000 + int(RtsControls.CUE_PULSE_S * 1000) + 10) < 0.1, "the second pulse starts")
	assert_eq(RtsControls.order_cue("Green_Alpha_1", 1000 + int(RtsControls.CUE_PULSE_S * RtsControls.CUE_PULSES * 1000)), -1.0, "then it stops")
	assert_eq(RtsControls.order_cue("Green_Bravo_1", 1000), -1.0, "a vehicle never ordered has none")
	assert_eq(RtsControls.group_cue(["Green_Bravo_1", "Green_Alpha_1"], 1000), 0.0, "a group's cue is its freshest vehicle's")


func test_an_order_pulses_its_recipients_ring_and_chip_only() -> void:
	RtsControls.clear_cues()
	var f := Fixture.new(self)
	await f.build()
	f.controls.elements = Elements.install(f.game_match, f.orders)
	f.controls.groups.save(1, ALPHA.duplicate())
	f.controls.groups.save(2, BRAVO.duplicate())
	var markers := SelectionMarkers.new()
	markers.game_match = f.game_match
	markers.selection = f.controls.selection
	markers.reveal_all = true
	add_to_tree(markers)
	var bar := GroupBar.new()
	bar.controls = f.controls
	add_to_tree(bar)
	f.controls.recall_group(1)
	markers.refresh()
	assert_true(not markers.last_placed.has("ordered"), "no cue before an order")
	assert_eq(f.controls.order_selection("move", {"to": [0.0, 0.0]}), "", "his move is taken")
	markers.refresh()
	var cued: Array = markers.last_placed.get("ordered", [])
	assert_eq(cued.size(), ALPHA.size(), "every Alpha vehicle wears the cue, nobody else: %d" % cued.size())
	var chips := {}
	for chip: Dictionary in bar.summary():
		chips[int(chip["number"])] = float(chip["cue"])
	assert_true(float(chips.get(1, -1.0)) >= 0.0, "Alpha's chip flashes")
	assert_eq(float(chips.get(2, 0.0)), -1.0, "Bravo's does not")
	markers.queue_free()
	bar.queue_free()
