extends TestCase
## Mapkit P2 (round 47): the blast doors' RULES (game/match/blast_doors.gd) -- a schedule that is a pure function of the
## layout and the match seed, so replays reproduce it, the route can ask about any tick (C47.8), and both sides meet
## the same doors (C47.9). The collider and the crew-safe hold are tests/mapkit/test_arena_doors.gd.

func _layout(extra := {}) -> Dictionary:
	var west := {"name": "west_gate", "group": "flank_gates", "position": [-60.0, 20.0], "rotation_deg": 90.0}
	var east := {"name": "east_gate", "group": "flank_gates", "position": [60.0, -20.0], "rotation_deg": 270.0}
	west.merge(extra)
	east.merge(extra)
	return {"doors": [west, east]}


func test_a_door_opens_and_shuts_by_tick_on_its_cycle() -> void:
	var doors := BlastDoors.from_layout(_layout({"open_s": 40.0, "shut_s": 25.0}), 12901)
	var first := doors.next_change("west_gate", 0)
	assert_true(first >= SimClock.ticks(BlastDoors.FIRST_MIN_S) and first <= SimClock.ticks(BlastDoors.FIRST_MAX_S),
			"the first change lands in the window: tick %d" % first)
	assert_true(doors.is_open("west_gate", 0), "doors start open by default")
	assert_true(doors.is_open("west_gate", first - 1), "open up to the change")
	assert_true(not doors.is_open("west_gate", first), "shut at the change")
	var reopen := first + SimClock.ticks(25.0)
	assert_eq(doors.next_change("west_gate", first), reopen, "shut lasts shut_s")
	assert_true(not doors.is_open("west_gate", reopen - 1), "still shut the tick before")
	assert_true(doors.is_open("west_gate", reopen), "open again after shut_s")
	assert_eq(doors.next_change("west_gate", reopen), reopen + SimClock.ticks(40.0), "open lasts open_s")
	assert_true(not doors.is_open("west_gate", reopen + SimClock.ticks(40.0)), "and shuts again: a fixed cycle")


func test_the_warning_comes_before_every_change() -> void:
	var doors := BlastDoors.from_layout(_layout(), 12902)
	var first := doors.next_change("west_gate", 0)
	var warn := SimClock.ticks(BlastDoors.WARN_S)
	assert_eq(doors.state("west_gate", first - warn - 1), "open", "quiet before the warning")
	assert_eq(doors.state("west_gate", first - warn), "closing", "the warning: still open, shutting soon")
	assert_eq(doors.state("west_gate", first), "shut", "shut")
	var reopen := doors.next_change("west_gate", first)
	assert_eq(doors.state("west_gate", reopen - warn), "opening", "the warning before it opens")


func test_a_replay_of_the_same_seed_is_the_same_schedule() -> void:
	var a := BlastDoors.from_layout(_layout(), 12903)
	var b := BlastDoors.from_layout(_layout(), 12903)
	var other := BlastDoors.from_layout(_layout(), 12904)
	var same := true
	for tick in range(0, SimClock.ticks(300.0), 7):
		same = same and a.is_open("west_gate", tick) == b.is_open("west_gate", tick)
	assert_true(same, "two builds from one seed agree on every tick over 300 s")
	assert_eq(a.events_between(0, SimClock.ticks(300.0)), b.events_between(0, SimClock.ticks(300.0)), "and on every event")
	# Different seeds can draw the same first tick; over three seeds at least one must differ, or the seed is ignored.
	var firsts := {a.next_change("west_gate", 0): true, other.next_change("west_gate", 0): true,
			BlastDoors.from_layout(_layout(), 12905).next_change("west_gate", 0): true}
	assert_true(firsts.size() > 1, "the seed moves the first change: %s" % [firsts.keys()])


func test_both_sides_meet_the_same_doors() -> void:
	var doors := BlastDoors.from_layout(_layout(), 12906)
	var same := true
	for tick in range(0, SimClock.ticks(400.0), 5):
		same = same and doors.is_open("west_gate", tick) == doors.is_open("east_gate", tick)
	assert_true(same, "a door and its mirror (one group) share every tick")


func test_events_are_the_schedule_in_order() -> void:
	var doors := BlastDoors.from_layout(_layout(), 12907)
	var events := doors.events_between(0, SimClock.ticks(200.0))
	var kinds := events.filter(func(e: Dictionary) -> bool: return e["door"] == "west_gate").map(
			func(e: Dictionary) -> String: return e["kind"])
	assert_true(kinds.size() >= 4, "at least one full cycle in 200 s: %s" % [kinds])
	assert_eq(kinds.slice(0, 4), ["warn_close", "shut", "warn_open", "open"], "warn, shut, warn, open")
	for e: Dictionary in events:
		var tick := int(e["tick"])
		match String(e["kind"]):
			"shut":
				assert_true(not doors.is_open(e["door"], tick) and doors.is_open(e["door"], tick - 1), "shut event at the change")
			"open":
				assert_true(doors.is_open(e["door"], tick) and not doors.is_open(e["door"], tick - 1), "open event at the change")
	# Splitting the window anywhere gives the same events: polling every tick sees each exactly once.
	var stitched: Array[Dictionary] = []
	var last := 0
	for cut in range(37, SimClock.ticks(200.0) + 37, 37):
		var upto := mini(cut, SimClock.ticks(200.0))
		stitched.append_array(doors.events_between(last, upto))
		last = upto
	assert_eq(stitched, events, "polled in slices, the same events once each")


func test_a_door_that_starts_shut() -> void:
	var doors := BlastDoors.from_layout(_layout({"start": "shut"}), 12908)
	var first := doors.next_change("west_gate", 0)
	assert_true(not doors.is_open("west_gate", 0), "shut at kick-off")
	assert_true(doors.is_open("west_gate", first), "opens at its first change")


func test_doorway_footprint() -> void:
	var doors := BlastDoors.from_layout(_layout(), 12909)
	# west_gate turned 90 degrees: its 14 m span runs along z, its 1.6 m depth along x.
	assert_true(doors.in_doorway("west_gate", Vector2(-60.0, 26.0)), "inside the span")
	assert_true(not doors.in_doorway("west_gate", Vector2(-60.0, 28.0)), "past the jamb")
	assert_true(not doors.in_doorway("west_gate", Vector2(-58.0, 20.0)), "beside the slab")
	assert_true(doors.in_doorway("west_gate", Vector2(-58.0, 20.0), 2.0), "within a hull's margin")


func test_validation_refuses_unfair_or_impossible_doors() -> void:
	var tol := Arena.SYMMETRY_TOLERANCE
	assert_eq(BlastDoors.validate_doors(_layout()["doors"], tol), "", "a mirrored pair in one group is fine")
	var split: Array = _layout()["doors"].duplicate(true)
	split[1]["group"] = "other"
	assert_true(BlastDoors.validate_doors(split, tol).contains("no mirror"), "a pair split across groups is refused")
	var alone: Array = [_layout()["doors"][0]]
	assert_true(BlastDoors.validate_doors(alone, tol).contains("no mirror"), "a door without its mirror is refused")
	var narrow: Array = _layout({"width": 10.0})["doors"]
	assert_true(BlastDoors.validate_doors(narrow, tol).contains("wide"), "a door narrower than a street is refused")
	var fast: Array = _layout({"shut_s": 3.0})["doors"]
	assert_true(BlastDoors.validate_doors(fast, tol).contains("warning"), "a state shorter than its warning is refused")
	var twice: Array = _layout()["doors"].duplicate(true)
	twice[1]["name"] = "west_gate"
	assert_true(BlastDoors.validate_doors(twice, tol).contains("twice"), "duplicate names are refused")
