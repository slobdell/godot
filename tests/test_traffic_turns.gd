extends TestCase
## Round 28 (traffic T1, his call: TAKE TURNS): the friendly rule, pure (Traffic.shape over a table loaded by hand).
## Forward is -Z and a hull's right is +X when it faces -Z (trip-up 2). Rows: [name, team, x, z, vx, vz, heading_x,
## heading_z, radius, moving, group].

const R := 3.0


func teardown() -> void:
	Traffic.set_off("turns", false)
	Traffic.set_off("streetright", false)
	Traffic.set_off("streetturns", false)
	Traffic.street_override = null
	super.teardown()


## Squad N (two crews) comes south (-Z) to the origin, squad W (two crews) east (+X), at 10 m/s; N's lead `n_lead` m out.
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
	Traffic.load_rows([
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
	Traffic.load_rows([
		["A", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:S"],
		["B", 0, -20.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:S"],
	])
	assert_eq(Traffic.shape("A", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "squadmates: ORCA and the give-way")
	assert_eq(Traffic.shape("B", Vector2(10.0, 0.0)), Vector2(10.0, 0.0), "squadmates: ORCA and the give-way")


func test_never_against_an_enemy_or_a_parked_friend() -> void:
	Traffic.load_rows([
		["N1", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:N"],
		["W1", 1, -27.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
	])
	assert_eq(Traffic.shape("W1", Vector2(10.0, 0.0)), Vector2(10.0, 0.0), "an enemy: unchanged (it may block)")
	Traffic.load_rows([
		["N1", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, false, "e:N"],
		["W1", 0, -27.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
	])
	assert_eq(Traffic.shape("W1", Vector2(10.0, 0.0)), Vector2(10.0, 0.0), "a parked friend: ORCA and the give-way")


func _head_on() -> void:
	Traffic.load_rows([
		["A", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:A"],
		["B", 0, 0.0, -20.0, 0.0, 10.0, 0.0, 1.0, R, true, "e:B"],
	])


func test_head_on_in_a_street_both_keep_right() -> void:
	Traffic.set_off("streetturns", true)  # v1's keep-right runs only without v2c's turns
	Traffic.street_override = true
	_head_on()
	var a := Traffic.shape("A", Vector2(0.0, -10.0))
	var b := Traffic.shape("B", Vector2(0.0, 10.0))
	assert_true(a.x > 0.5 and b.x < -0.5, "each turns to its own right: %s %s" % [a, b])
	assert_near(a.length(), 10.0, 0.001, "the speed is kept")


func test_head_on_on_open_ground_is_left_to_orca() -> void:
	Traffic.street_override = false
	_head_on()
	assert_eq(Traffic.shape("A", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "open ground: unchanged")


func test_no_keeping_right_into_a_squadmate_abeam() -> void:
	Traffic.set_off("streetturns", true)
	Traffic.street_override = true
	Traffic.load_rows([
		["A", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:A"],
		["C", 0, 6.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:A"],
		["B", 0, 0.0, -20.0, 0.0, 10.0, 0.0, 1.0, R, true, "e:B"],
	])
	assert_eq(Traffic.shape("A", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "a friend abeam on the right")
	assert_true(Traffic.shape("B", Vector2(0.0, 10.0)).x < 0.0, "B, with room on its right, keeps right")


func test_switched_off_nothing_changes() -> void:
	Traffic.street_override = true
	Traffic.set_off("streetright", true)
	_head_on()
	assert_eq(Traffic.shape("A", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "--traffic-off=streetright")
	Traffic.set_off("turns", true)
	_crossing(20.0, 27.0)
	assert_eq(Traffic.shape("W1", Vector2(10.0, 0.0)), Vector2(10.0, 0.0), "--traffic-off=turns")


func test_v2b_the_whole_yielding_squad_slows_not_only_the_crews_that_meet() -> void:
	# W3 trails W's file 30 m back: it meets nobody inside the horizon, but its squad is yielding, so it slows too.
	Traffic.load_rows([
		["N1", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:N"],
		["N2", 0, 0.0, 30.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:N"],
		["W1", 0, -27.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
		["W3", 0, -57.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
	])
	var w1 := Traffic.shape("W1", Vector2(10.0, 0.0))
	assert_true(w1.length() < 9.5, "W1 yields: %s" % w1)
	assert_near(Traffic.shape("W3", Vector2(10.0, 0.0)).length(), w1.length(), 0.01, "W3 keeps its squad's share")
	Traffic.set_off("wholesquad", true)
	Traffic.load_rows([
		["N1", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:N"],
		["W1", 0, -27.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
		["W3", 0, -57.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true, "e:W"],
	])
	Traffic.shape("W1", Vector2(10.0, 0.0))
	assert_eq(Traffic.shape("W3", Vector2(10.0, 0.0)), Vector2(10.0, 0.0), "--traffic-off=wholesquad: only who meets")
	Traffic.set_off("wholesquad", false)


func test_v2b_crews_deflected_inside_a_head_on_meeting_are_not_a_crossing() -> void:
	# Two squads head-on (mean headings opposite); one crew of each angled 60 deg off its squad's way, meeting the other.
	Traffic.street_override = false
	Traffic.load_rows([
		["A1", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:A"],
		["A2", 0, 8.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:A"],
		["A3", 0, -8.0, 20.0, -8.66, -5.0, -0.866, -0.5, R, true, "e:A"],
		["B1", 0, 0.0, -20.0, 0.0, 10.0, 0.0, 1.0, R, true, "e:B"],
		["B2", 0, 8.0, -20.0, 0.0, 10.0, 0.0, 1.0, R, true, "e:B"],
		["B3", 0, -20.0, -1.93, 0.0, 10.0, 0.0, 1.0, R, true, "e:B"],
	])
	assert_eq(Traffic.shape("A3", Vector2(-8.66, -5.0)), Vector2(-8.66, -5.0), "head-on squads: ORCA's")
	assert_eq(Traffic.shape("B3", Vector2(0.0, 10.0)), Vector2(0.0, 10.0), "head-on squads: ORCA's")
	# The falsifier: per crew direction (v1) A3 and B3 ARE a crossing (they reach (-20, 13) 0.1 s apart).
	Traffic.set_off("squadheading", true)
	var a3 := Traffic.shape("A3", Vector2(-8.66, -5.0))
	var b3 := Traffic.shape("B3", Vector2(0.0, 10.0))
	assert_true(a3.length() < 9.5 or b3.length() < 9.5, "v1 made one of them yield: %s %s" % [a3, b3])
	Traffic.set_off("squadheading", false)


## Two squads head-on down a street along z: S (south, at z > 0) comes north (-Z), N (north) comes south (+Z), leads
## `gap` m apart; the street is everything with |z| < `street_half` (outside it, the open).
func _street_head_on(s_lead_z: float, n_lead_z: float, street_half: float) -> void:
	Traffic.street_override = func(_x: float, z: float) -> bool: return absf(z) < street_half
	Traffic.load_rows([
		["S1", 0, 0.0, s_lead_z, 0.0, -10.0, 0.0, -1.0, R, true, "e:S"],
		["S2", 0, 6.0, s_lead_z + 9.0, 0.0, -10.0, 0.0, -1.0, R, true, "e:S"],
		["N1", 0, 1.0, n_lead_z, 0.0, 10.0, 0.0, 1.0, R, true, "e:N"],
		["N2", 0, -6.0, n_lead_z - 9.0, 0.0, 10.0, 0.0, 1.0, R, true, "e:N"],
	])


func test_v2c_head_on_in_a_street_the_squad_still_in_the_open_waits() -> void:
	# N's lead is already in the street (z = -20, street |z| < 30); S's is still in the open (z = 45): S waits, N comes on.
	_street_head_on(45.0, -20.0, 30.0)
	var s1 := Traffic.shape("S1", Vector2(0.0, -10.0))
	assert_near(s1.length(), Traffic.STREET_FLOOR * 10.0, 0.001, "S's lead slows to the street floor: %s" % s1)
	assert_near(Traffic.shape("S2", Vector2(0.0, -10.0)).length(), Traffic.STREET_FLOOR * 10.0, 0.001, "and its squad")
	Traffic.set_off("streetfloor", true)
	_street_head_on(45.0, -20.0, 30.0)
	assert_near(Traffic.shape("S1", Vector2(0.0, -10.0)).length(), Traffic.YIELD_FLOOR * 10.0, 0.001, "v2c's floor")
	Traffic.set_off("streetfloor", false)
	assert_eq(Traffic.shape("N1", Vector2(0.0, 10.0)), Vector2(0.0, 10.0), "N comes through the street")
	assert_eq(Traffic.shape("N2", Vector2(0.0, 10.0)), Vector2(0.0, 10.0), "all of it")


func test_v2c_head_on_on_open_ground_is_still_orcas() -> void:
	_street_head_on(30.0, -30.0, 0.0)  # no street anywhere
	assert_eq(Traffic.shape("S1", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "open ground: unchanged")
	assert_eq(Traffic.shape("N1", Vector2(0.0, 10.0)), Vector2(0.0, 10.0), "open ground: unchanged")


func test_v2c_both_in_the_street_the_later_waits_and_switched_off_nothing() -> void:
	# Both leads in the street; S's lead 40 m from the middle-ish, N's 20 m: by the middle of the pair both are level
	# (the middle is between them), so by time to the middle... S1 at z 40, N1 at z -20: middle z 10, S 3 s, N 3 s: a tie,
	# and the greater id ("e:S" > "e:N") waits.
	_street_head_on(40.0, -20.0, 100.0)
	assert_true(Traffic.shape("S1", Vector2(0.0, -10.0)).length() < 9.0, "S waits")
	assert_eq(Traffic.shape("N1", Vector2(0.0, 10.0)), Vector2(0.0, 10.0), "N holds")
	Traffic.set_off("streetturns", true)
	_street_head_on(40.0, -20.0, 100.0)
	assert_eq(Traffic.shape("S1", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "--traffic-off=streetturns")
	Traffic.set_off("streetturns", false)
