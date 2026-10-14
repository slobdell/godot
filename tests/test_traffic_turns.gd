extends TestCase
## Round 29 (traffic T3, his call: TAKE TURNS): two friendly squads CROSSING take turns, pure (Traffic.shape over a table
## loaded by hand). Round 28's v3 tests (`traffic-t1-v3`), the crossing ones. Forward is -Z and a hull's right is +X when
## it faces -Z (trip-up 2). Rows: [name, team, x, z, vx, vz, heading_x, heading_z, radius, moving, group].

const R := 3.0


func _rows(rows: Array) -> void:
	Traffic.set_off("turns", false)
	Traffic.load_rows(rows)


func teardown() -> void:
	Traffic.set_off("turns", false)
	super.teardown()


func _crossing(n_lead: float, w_lead: float) -> void:
	Traffic.load_rows([
		["N1", 0, 0.0, n_lead, 0.0, -10.0, 0.0, -1.0, R, true, "e:N"],
		["N2", 0, 0.0, n_lead + 10.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:N"],
		["W1", 0, -w_lead, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
		["W2", 0, -w_lead - 10.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
	])


func test_the_later_squad_yields_as_a_whole_and_the_earlier_holds() -> void:
	# N's lead is 20 m out (2.0 s), W's 27 m (2.7 s): W is later and yields — every crew of it that meets N's.
	_crossing(20.0, 27.0)
	var w1 := Traffic.shape("W1", Vector2(10.0, 0.0))
	assert_true(w1.length() < 9.5, "W's lead slows: %s" % w1)
	assert_true(w1.x > 0.0 and absf(w1.y) < 0.001, "and keeps its heading")
	assert_eq(Traffic.shape("N1", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "N's lead holds its line")
	assert_eq(Traffic.shape("N2", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "and so does N's second crew")


func test_one_verdict_per_squad_pair_even_where_a_crew_pair_says_otherwise() -> void:
	# W's SECOND crew meets N's second crew earlier than N2 does (W2 20 m out against N2's 30 m), which per crew pair
	# (round 26's v4) made N2 yield to W2 while W1 yielded to N1. The squad pair's verdict (N first) holds for both.
	_rows([
		["N1", 0, 0.0, 12.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:N"],
		["N2", 0, 0.0, 26.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:N"],
		["W1", 0, -16.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
		["W2", 0, -24.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
	])
	Traffic.shape("W1", Vector2(10.0, 0.0))  # the first meeting decides the squad pair
	assert_eq(Traffic.shape("N2", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "N2 holds: N passes first")
	assert_true(Traffic.shape("W2", Vector2(10.0, 0.0)).length() < 9.5, "W2 yields with its squad")


func test_a_yield_slows_but_never_stops() -> void:
	# W's lead 12 m out, N's 4 m: W yields; the cap is under the floor, so it keeps the floor.
	_crossing(4.0, 12.0)
	var w1 := Traffic.shape("W1", Vector2(10.0, 0.0))
	assert_near(w1.length(), Traffic.YIELD_FLOOR * 10.0, 0.001, "the floor (%s)" % w1)


func test_a_yielding_crew_already_at_the_zone_clears_out() -> void:
	# W1 is 5 m from the crossing (the zone's edge, clearance 7.5 m, is behind it): it never stops inside N's way.
	_crossing(2.0, 5.0)
	assert_eq(Traffic.shape("W1", Vector2(10.0, 0.0)), Vector2(10.0, 0.0), "committed: it drives on")


func test_a_tie_gives_priority_to_the_right() -> void:
	# Both leads 20 m out: N (facing -Z) has W on its left (-X); W (facing +X, its right +Z) has N on its right: W yields.
	_crossing(20.0, 20.0)
	assert_eq(Traffic.shape("N1", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "N holds")
	assert_true(Traffic.shape("W1", Vector2(10.0, 0.0)).length() < 9.5, "W yields")


func test_crews_of_one_squad_never_take_turns_with_each_other() -> void:
	_rows([
		["A", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:S"],
		["B", 0, -20.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:S"],
	])
	assert_eq(Traffic.shape("A", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "squadmates: ORCA and the give-way")
	assert_eq(Traffic.shape("B", Vector2(10.0, 0.0)), Vector2(10.0, 0.0), "squadmates: ORCA and the give-way")


func test_never_against_an_enemy_or_a_parked_friend() -> void:
	_rows([
		["N1", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:N"],
		["W1", 1, -27.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
	])
	assert_eq(Traffic.shape("W1", Vector2(10.0, 0.0)), Vector2(10.0, 0.0), "an enemy: unchanged (it may block)")
	_rows([
		["N1", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, false, "e:N"],
		["W1", 0, -27.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
	])
	assert_eq(Traffic.shape("W1", Vector2(10.0, 0.0)), Vector2(10.0, 0.0), "a parked friend: ORCA and the give-way")


func test_the_whole_yielding_squad_slows_not_only_the_crews_that_meet() -> void:
	# W3 trails W's file 30 m back: it meets nobody inside the horizon, but its squad is yielding, so it slows too.
	_rows([
		["N1", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:N"],
		["N2", 0, 0.0, 30.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:N"],
		["W1", 0, -27.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
		["W3", 0, -57.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
	])
	var w1 := Traffic.shape("W1", Vector2(10.0, 0.0))
	assert_true(w1.length() < 9.5, "W1 yields: %s" % w1)
	assert_near(Traffic.shape("W3", Vector2(10.0, 0.0)).length(), w1.length(), 0.01, "W3 keeps its squad's share")


func test_crews_deflected_inside_a_head_on_meeting_are_not_a_crossing() -> void:
	# Two squads head-on (mean headings opposite); one crew of each angled 60 deg off its squad's way, meeting the other.
	_rows([
		["A1", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:A"],
		["A2", 0, 8.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:A"],
		["A3", 0, -8.0, 20.0, -8.66, -5.0, -0.866, -0.5, R, true, "e:A"],
		["B1", 0, 0.0, -20.0, 0.0, 10.0, 0.0, 1.0, R, true, "e:B"],
		["B2", 0, 8.0, -20.0, 0.0, 10.0, 0.0, 1.0, R, true, "e:B"],
		["B3", 0, -20.0, -1.93, 0.0, 10.0, 0.0, 1.0, R, true, "e:B"],
	])
	assert_eq(Traffic.shape("A3", Vector2(-8.66, -5.0)), Vector2(-8.66, -5.0), "head-on squads: ORCA's (or the hold)")
	assert_eq(Traffic.shape("B3", Vector2(0.0, 10.0)), Vector2(0.0, 10.0), "head-on squads: ORCA's (or the hold)")


func test_switched_off_nothing_changes() -> void:
	_crossing(20.0, 27.0)
	Traffic.set_off("turns", true)
	assert_eq(Traffic.shape("W1", Vector2(10.0, 0.0)), Vector2(10.0, 0.0), "--traffic-off=turns")


func test_the_counters_show_it_fired() -> void:
	Traffic.reset_counters()
	_crossing(20.0, 27.0)
	Traffic.shape("W1", Vector2(10.0, 0.0))
	assert_eq(int(Traffic.report()["tr_cross_verdicts"]), 1, "one squad-pair verdict")
	assert_true(int(Traffic.report()["tr_cross_slowed"]) > 0, "and a slowed wish")



func test_a_squad_waiting_at_a_street_mouth_is_left_to_the_hold() -> void:
	# The hold's squad pair (A waits for B at a street mouth): its crews pulling aside across B's way are not a crossing.
	_crossing(20.0, 27.0)
	Traffic._waits["e:W"] = {"passer": "e:N", "key": "e:N|e:W", "since": 0, "dir": Vector2(1.0, 0.0), "spots": {},
			"released": {}}
	assert_eq(Traffic.shape("W1", Vector2(10.0, 0.0)), Vector2(10.0, 0.0), "the waiting squad: the hold's, not the crossing's")
	assert_eq(Traffic.shape("N1", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "nor the squad it waits for")
	Traffic._waits.erase("e:W")
