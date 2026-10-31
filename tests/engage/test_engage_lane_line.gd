extends TestCase
## Round 46 (engage L3, C46.5): the feed line for a crew in his selection that holds its shot for a friend in the lane:
## "<crew> holding fire: <friend> in the way", after LANE_HOLD_SECONDS, only while it is still being held, at most once per
## LANE_REPEAT_SECONDS per crew, through HudMessages' own duplicate / rate rules; none with `--lane-clear=off`.

var _lines: Array = []


func _feed() -> HudMessages:
	var messages := HudMessages.new()
	_lines = []
	messages.posted.connect(func(text: String, _severity: int) -> void: _lines.append(text))
	return messages


func _row(held_s: float, blocker := "Green_Guns_4") -> Array:
	return [{"unit": "Green_Hunters_1", "blocked_ticks": int(held_s * SimClock.TICK_RATE), "blocker": blocker}]


func test_a_crew_held_over_two_seconds_says_who_is_in_the_way() -> void:
	var messages := _feed()
	messages.check_lanes(_row(1.0))
	messages.check_lanes(_row(1.5))
	assert_eq(_lines.size(), 0, "not before 2 s (%s)" % [_lines])
	messages.check_lanes(_row(2.5))
	assert_eq(_lines, ["Hunters 1 holding fire: Guns 4 in the way"], "the line names the crew and the friend in the way")
	messages.free()


func test_it_is_not_repeated_within_eight_seconds_and_needs_a_growing_hold() -> void:
	var messages := _feed()
	messages.check_lanes(_row(0.0))
	messages.check_lanes(_row(3.0))
	messages.advance(2.0)
	messages.check_lanes(_row(5.0, "Green_Wrenches_3"))
	assert_eq(_lines.size(), 1, "once per crew within LANE_REPEAT_SECONDS, whoever is in the way (%s)" % [_lines])
	messages.advance(HudMessages.LANE_REPEAT_SECONDS)
	messages.check_lanes(_row(5.0, "Green_Wrenches_3"))
	assert_eq(_lines.size(), 1, "a count that stopped growing is not a crew holding fire (%s)" % [_lines])
	messages.check_lanes(_row(6.0, "Green_Wrenches_3"))
	assert_eq(_lines.size(), 2, "still held later: said again (%s)" % [_lines])
	assert_eq(String(_lines[1]), "Hunters 1 holding fire: Wrenches 3 in the way", "the friend now in the way")
	messages.free()


func test_the_escape_switch_removes_it() -> void:
	var saved := TankBrain.LANE_CLEAR
	TankBrain.LANE_CLEAR = false
	var messages := _feed()
	messages.check_lanes(_row(0.0))
	messages.check_lanes(_row(3.0))
	TankBrain.LANE_CLEAR = saved
	assert_eq(_lines.size(), 0, "--lane-clear=off: no line (%s)" % [_lines])
	messages.free()


## Round 47 (engage, round 46's leftover): the phone layout's touch map has no `selection_state`; its `selected()` squad's
## roster is his selection, so the line reaches the phone too.
class TouchMapStub extends RefCounted:
	var squad: Squad = null
	func selected() -> Squad:
		return squad


class DesktopStub extends RefCounted:
	func selection_state() -> Dictionary:
		return {"units": ["Green_Hunters_1"]}


func test_his_selection_is_read_from_the_touch_map_too() -> void:
	var touch := TouchMapStub.new()
	assert_eq(HudMessages.selected_units(touch), [], "nothing selected on the phone: no crews")
	touch.squad = Squad.new("Hunters", 0, PackedStringArray(["Green_Hunters_1", "Green_Hunters_2"]))
	assert_eq(HudMessages.selected_units(touch), ["Green_Hunters_1", "Green_Hunters_2"], "the selected squad's crews")
	assert_eq(HudMessages.selected_units(DesktopStub.new()), ["Green_Hunters_1"], "the desktop controls as before")
	assert_eq(HudMessages.selected_units(null), [], "no source: no crews")
