extends TestCase
## A2: the switching cost is derived from the vehicle's own profile, so every case here is hand-computable from
## `Units.PROFILES` and nothing in it is a fitted number. If one of these fails, either the formula moved or a
## profile did — and both are things the round wants to hear about.


## A situation with one crew and any number of contacts, the shape `TankBrain.build_situation()` returns.
func _situation(unit_id: String, speed: float, contacts: Dictionary) -> Dictionary:
	var forward := Vector3(0, 0, -1)
	var list: Array = []
	for name: String in contacts:
		list.append({"name": name, "position": contacts[name], "visible": true})
	return {"self": {"name": "Green_1", "unit": unit_id, "position": Vector3.ZERO, "forward": forward,
			"velocity": forward * speed, "class": Units.role_of(unit_id)}, "contacts": list}


func _cost(unit_id: String, speed: float, contacts: Dictionary, from: Dictionary, to: Dictionary) -> float:
	return SwitchingCost.seconds(_situation(unit_id, speed, contacts), from, to)


const AHEAD := Vector3(0, 0, -50)
const RIGHT := Vector3(50, 0, 0)
const BEHIND := Vector3(0, 0, 50)
## These hand-built situations carry no `sight_radius`, so the lay term reads its default.
const SIGHT := 120.0


## The lay a crew throws away when it points the gun at a DIFFERENT target: Engagement's gate-2 shape at this range
## (`engagement.gd:133`). At 50 m of a 120 m sight that is lerp(0.3, 1.6, 0.4167) = 0.842 s, and a scout crew, which
## acquires in SCOUT_ACQUIRE_SCALE of the time, throws away 0.463 s.
func _lay(unit_id: String, distance: float) -> float:
	var seconds := lerpf(Engagement.ACQUIRE_NEAR_SECONDS, Engagement.ACQUIRE_FAR_SECONDS, distance / SIGHT)
	return seconds * (Engagement.SCOUT_ACQUIRE_SCALE if Units.role_of(unit_id) == "scout" else 1.0)


## A turreted tracked hull standing still pays its turret and the lay it abandons, and nothing else: 90 degrees at the
## tank's 50 deg/s, plus the acquisition it had invested in the target it is leaving.
func test_a_stopped_turret_pays_the_slew_and_the_lay() -> void:
	var cost := _cost("tank", 0.0, {"A": AHEAD, "B": RIGHT},
			{"option": "ENGAGE", "target": "A"}, {"option": "ENGAGE", "target": "B"})
	assert_near(cost, 90.0 / 50.0 + _lay("tank", 50.0), 0.001,
			"1.8 s of turret + %.3f s of abandoned lay (got %.3f)" % [_lay("tank", 50.0), cost])


## Moving, it also pays for the velocity that stops serving: at a right angle that is all of it, shed at braking_mps2.
func test_a_moving_turret_also_pays_the_braking() -> void:
	var cost := _cost("tank", 9.0, {"A": AHEAD, "B": RIGHT},
			{"option": "ENGAGE", "target": "A"}, {"option": "ENGAGE", "target": "B"})
	assert_near(cost, 90.0 / 50.0 + 9.0 / 12.0 + _lay("tank", 50.0), 0.001,
			"1.8 s of slew + 0.75 s of braking + %.3f s of lay (got %.3f)" % [_lay("tank", 50.0), cost])


## A fixed gun comes round with the hull, and on wheels the hull cannot pivot: it drives an arc of its own minimum
## radius. Stopped, that arc is timed at ARC_SPEED_FLOOR of its top speed rather than at zero.
func test_a_fixed_gun_on_wheels_drives_the_arc() -> void:
	var cost := _cost("gang_scout", 0.0, {"A": AHEAD, "B": RIGHT},
			{"option": "ENGAGE", "target": "A"}, {"option": "ENGAGE", "target": "B"})
	var arc_m := 4.5 * PI / 2.0
	var expected := maxf(90.0 / 150.0, arc_m / (18.0 * SwitchingCost.ARC_SPEED_FLOOR)) + _lay("gang_scout", 50.0)
	assert_near(cost, expected, 0.001, "the arc (1.571 s) beats the in-place yaw (0.600 s), plus the lay: %.3f s (got %.3f)" % [
			expected, cost])


## The point of A2: the roster prices itself. The same switch in the same situation costs the 14 m War Rig a multiple
## of what it costs a rat rod, with no per-class constant anywhere.
func test_the_rig_pays_a_multiple_of_what_the_rat_rod_pays() -> void:
	var far_left := Vector3(-50.0 * sin(deg_to_rad(140.0)), 0, -50.0 * cos(deg_to_rad(140.0)))
	var contacts := {"A": AHEAD, "B": far_left}
	var from := {"option": "ENGAGE", "target": "A"}
	var to := {"option": "ENGAGE", "target": "B"}
	var rig := _cost("gang_tank", 10.0, contacts, from, to)
	var rod := _cost("gang_scout", 14.0, contacts, from, to)
	print("MEASURE switch_cost_by_class 140 deg at speed: war rig %.2f s, rat rod %.2f s (x%.2f)" % [rig, rod, rig / rod])
	assert_near(rig, 140.0 / 60.0 + 10.0 * (1.0 - cos(deg_to_rad(140.0))) / 8.0 + _lay("gang_tank", 50.0), 0.01,
			"the rig slews at 60 deg/s, sheds at 8 m/s^2, and drops its lay (got %.3f)" % rig)
	assert_true(rig >= rod * 2.0, "the rig pays at least twice the rat rod (%.2f s vs %.2f s)" % [rig, rod])


## Keeping the current option and target is not a switch and discards nothing. Keeping the gun where it is also keeps
## the lay, which is what lets the lay be charged at all without making a crew slower to take up a fresh contact.
func test_staying_on_the_same_fight_is_free() -> void:
	var cost := _cost("tank", 9.0, {"A": AHEAD}, {"option": "ENGAGE", "target": "A"}, {"option": "ENGAGE", "target": "A"})
	assert_eq(cost, 0.0, "the option it is already carrying out costs nothing")


## The measured consequence of removing the stance floor, asserted so it is a recorded property rather than a surprise:
## changing OPTION on one target -- same bearing, same lay -- now costs exactly nothing. Five arms x three seeds said
## the floor bought no reduction in switches or reversals worth its complication (lesson 25). If ENGAGE <-> SUPPRESS
## thrash ever shows up in a measurement, the fix is a discard charged only to options that fight from a standstill,
## not this floor again.
func test_changing_stance_on_one_target_is_now_free_and_that_is_deliberate() -> void:
	var moving := _cost("tank", 9.0, {"A": AHEAD}, {"option": "ENGAGE", "target": "A"}, {"option": "SUPPRESS", "target": "A"})
	assert_eq(moving, 0.0, "same target, same bearing, lay kept: a switch that discards nothing is charged nothing")
	# A target change from the same fight is still priced, so the removal did not hollow the mechanism out.
	var swapped := _cost("tank", 9.0, {"A": AHEAD, "B": RIGHT},
			{"option": "ENGAGE", "target": "A"}, {"option": "SUPPRESS", "target": "B"})
	assert_true(swapped > 2.0, "a target change still pays its slew, braking and lay (%.3f s)" % swapped)


## CLEAR_LANE is not a change of mind: it steps aside to shoot the target this crew is already engaging.
func test_clearing_the_lane_is_never_charged() -> void:
	var cost := _cost("tank", 9.0, {"A": AHEAD, "B": RIGHT},
			{"option": "ENGAGE", "target": "A"}, {"option": "CLEAR_LANE", "target": "A"})
	assert_eq(cost, 0.0, "CLEAR_LANE serves the fight it is in, so it discards nothing")


## With no current choice there is nothing to switch away from, so nothing is priced (and the counter says so).
func test_a_crew_with_no_current_choice_is_not_charged() -> void:
	var s := _situation("tank", 9.0, {"A": AHEAD})
	var ctx := SwitchingCost.context(s, {})
	assert_eq(SwitchingCost.seconds_for(ctx, "ENGAGE", "A"), 0.0, "no incumbent, no switch")
	assert_true(not bool(ctx["consulted"]), "and the arm counter records that it was never consulted")


## The reaction-latency guarantee, and the reason the lay term is backward-looking. A crew that is not yet laid on
## anything — driving, holding, advancing — discards no acquisition, so taking up a newly seen contact is charged
## nothing at all for it. A forward-looking "time to acquire the new target" would have quietly spent the round's
## `reaction latency <= 2 ticks` criterion on a term nobody would have thought to look at.
func test_taking_up_a_fight_from_no_fight_is_never_charged_for_the_lay() -> void:
	var s := _situation("tank", 9.0, {"A": AHEAD})
	var ctx := SwitchingCost.context(s, {"option": "ADVANCE", "target": ""})
	assert_eq(float(ctx["lay_s"]), 0.0, "a crew laid on nothing has no lay to throw away")
	# Driving straight at it, there is no bearing change either, so the whole switch is free -- correctly: nothing
	# physical is thrown away by opening fire on the thing you were already driving toward.
	assert_eq(SwitchingCost.seconds_for(ctx, "ENGAGE", "A"), 0.0, "and no bearing change, so nothing at all")


## P3's guarantee in a test: the price is capped, so a decisive advantage always wins. A reversal at speed in the
## heaviest hull in the game is the worst case, and it still buys only MAX_PENALTY.
func test_the_price_is_capped_so_it_can_never_veto() -> void:
	var s := _situation("gang_tank", 12.0, {"A": AHEAD, "B": BEHIND})
	var ctx := SwitchingCost.context(s, {"option": "ENGAGE", "target": "A"})
	var worst := SwitchingCost.seconds_for(ctx, "ENGAGE", "B")
	var priced := SwitchingCost.penalty(ctx, "ENGAGE", "B")
	print("MEASURE switch_cost_worst_case war rig reversing at 12 m/s: %.2f s -> %.3f utility (cap %.2f)" % [
			worst, priced, SwitchingCost.MAX_PENALTY])
	assert_true(worst > SwitchingCost.MAX_PENALTY / SwitchingCost.PRICE_PER_SECOND, "the worst case is past the cap")
	assert_eq(priced, SwitchingCost.MAX_PENALTY, "and is charged the cap, not the cost")


## The cost rises with the angle turned through, monotonically: no knee for a heuristic to hide in.
func test_the_cost_rises_with_the_angle() -> void:
	var last := -1.0
	for degrees in [0.0, 15.0, 45.0, 90.0, 135.0, 180.0]:
		var spot := Vector3(-50.0 * sin(deg_to_rad(degrees)), 0, -50.0 * cos(deg_to_rad(degrees)))
		var cost := _cost("tank", 9.0, {"A": AHEAD, "B": spot},
				{"option": "ENGAGE", "target": "A"}, {"option": "ENGAGE", "target": "B"})
		assert_true(cost > last, "%.0f deg costs more than the angle before it (%.3f vs %.3f)" % [degrees, cost, last])
		last = cost


## `seconds_for` is the hot path and `components` is the readable one, and they compute the same thing twice. That is
## a deliberate duplication — the scorer runs it per candidate per think and must not allocate a dictionary to do it —
## so the drift is caught here rather than discovered in a measurement six weeks later.
func test_the_fast_path_and_the_breakdown_agree() -> void:
	for unit_id in ["tank", "scout", "gang_tank", "gang_scout", "syn_tank", "law_ifv"]:
		for degrees in [0.0, 30.0, 90.0, 150.0, 180.0]:
			for speed in [0.0, 6.0, 13.0]:
				var spot := Vector3(-60.0 * sin(deg_to_rad(degrees)), 0, -60.0 * cos(deg_to_rad(degrees)))
				var s := _situation(unit_id, speed, {"A": AHEAD, "B": spot})
				for pair in [["ENGAGE", "B"], ["SUPPRESS", "A"], ["ORBIT", "B"], ["HOLD", ""]]:
					var ctx := SwitchingCost.context(s, {"option": "ENGAGE", "target": "A"})
					var fast := SwitchingCost.seconds_for(ctx, pair[0], pair[1])
					var slow: Dictionary = SwitchingCost.components(ctx, pair[0], pair[1])
					assert_near(fast, float(slow["total_s"]), 0.0001,
							"%s %s at %.0f deg, %.0f m/s: %.4f vs %.4f" % [unit_id, pair[0], degrees, speed, fast, slow["total_s"]])


## The breakdown carries the bearing the cost was computed FROM, which is the half of the round's central question
## that lives on this side. A turret aims without its hull, so a turreted unit may be charged for coming round onto a
## new bearing and then simply drive on; metrics' trajectory log measures the rotation actually performed, and the
## pair says whether A2 prices work the vehicle really does.
func test_the_breakdown_reports_the_bearing_the_cost_was_computed_from() -> void:
	var s := _situation("tank", 9.0, {"A": AHEAD, "B": RIGHT})
	var ctx := SwitchingCost.context(s, {"option": "ENGAGE", "target": "A"})
	var parts: Dictionary = SwitchingCost.components(ctx, "ENGAGE", "B")
	assert_near(float(parts["angle_deg"]), 90.0, 0.01, "the two targets are 90 deg apart (got %.2f)" % parts["angle_deg"])
	assert_near(float(parts["slew_s"]), 90.0 / 50.0, 0.001, "the turret term alone")
	assert_near(float(parts["brake_s"]), 9.0 / 12.0, 0.001, "the braking term alone")
	assert_near(float(parts["lay_s"]), _lay("tank", 50.0), 0.001, "the abandoned lay alone")


## Stateless by construction: the same situation prices the same twice, and pricing one candidate does not change
## what the next one is charged. This is what lets the sim stay deterministic with the term in the loop.
func test_pricing_is_stateless() -> void:
	var s := _situation("law_tank", 8.0, {"A": AHEAD, "B": RIGHT})
	var first := SwitchingCost.context(s, {"option": "ENGAGE", "target": "A"})
	var second := SwitchingCost.context(s, {"option": "ENGAGE", "target": "A"})
	var a := SwitchingCost.penalty(first, "ENGAGE", "B")
	assert_eq(SwitchingCost.penalty(first, "ENGAGE", "B"), a, "the same candidate prices the same twice")
	assert_eq(SwitchingCost.penalty(second, "ENGAGE", "B"), a, "a fresh context prices it the same")
	assert_eq(int(first["priced"]), 2, "and the counter counted both prices it was asked for")


## The control arm every A/B needs: `--tune=switch.price=0` removes the cost without removing the code path, so the
## treatment and its control are the same build (lesson 117).
func test_the_price_can_be_tuned_to_zero_for_a_control_arm() -> void:
	var s := _situation("tank", 9.0, {"A": AHEAD, "B": RIGHT})
	var ctx := SwitchingCost.context(s, {"option": "ENGAGE", "target": "A"})
	assert_true(SwitchingCost.penalty(ctx, "ENGAGE", "B") > 0.0, "priced by default")
	var error := Units.apply_tuning("switch.price=0")
	assert_eq(error, "", "switch.price is a tunable knob")
	assert_eq(SwitchingCost.penalty(ctx, "ENGAGE", "B"), 0.0, "and zero turns the price off")
	assert_true(SwitchingCost.seconds_for(ctx, "ENGAGE", "B") > 0.0, "while the cost is still computed and reported")
	SwitchingCost.tuning.clear()


func teardown() -> void:
	SwitchingCost.tuning.clear()
