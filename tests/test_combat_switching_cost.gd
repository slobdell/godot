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


## A turreted tracked hull standing still pays only for its turret: 90 degrees at the tank's 50 deg/s.
func test_a_stopped_turret_pays_only_the_slew() -> void:
	var cost := _cost("tank", 0.0, {"A": AHEAD, "B": RIGHT},
			{"option": "ENGAGE", "target": "A"}, {"option": "ENGAGE", "target": "B"})
	assert_near(cost, 90.0 / 50.0, 0.001, "90 deg at 50 deg/s is 1.8 s (got %.3f)" % cost)


## Moving, it also pays for the velocity that stops serving: at a right angle that is all of it, shed at braking_mps2.
func test_a_moving_turret_also_pays_the_braking() -> void:
	var cost := _cost("tank", 9.0, {"A": AHEAD, "B": RIGHT},
			{"option": "ENGAGE", "target": "A"}, {"option": "ENGAGE", "target": "B"})
	assert_near(cost, 90.0 / 50.0 + 9.0 / 12.0, 0.001, "1.8 s of slew + 0.75 s of braking (got %.3f)" % cost)


## A fixed gun comes round with the hull, and on wheels the hull cannot pivot: it drives an arc of its own minimum
## radius. Stopped, that arc is timed at ARC_SPEED_FLOOR of its top speed rather than at zero.
func test_a_fixed_gun_on_wheels_drives_the_arc() -> void:
	var cost := _cost("gang_scout", 0.0, {"A": AHEAD, "B": RIGHT},
			{"option": "ENGAGE", "target": "A"}, {"option": "ENGAGE", "target": "B"})
	var arc_m := 4.5 * PI / 2.0
	var expected := maxf(90.0 / 150.0, arc_m / (18.0 * SwitchingCost.ARC_SPEED_FLOOR))
	assert_near(cost, expected, 0.001, "the arc (%.3f s) beats the in-place yaw (0.600 s), got %.3f" % [expected, cost])


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
	assert_near(rig, 140.0 / 60.0 + 10.0 * (1.0 - cos(deg_to_rad(140.0))) / 8.0, 0.01,
			"the rig slews at 60 deg/s and sheds at 8 m/s^2 (got %.3f)" % rig)
	assert_true(rig >= rod * 2.0, "the rig pays at least twice the rat rod (%.2f s vs %.2f s)" % [rig, rod])


## Keeping the current option and target is not a switch and discards nothing.
func test_staying_on_the_same_fight_is_free() -> void:
	var cost := _cost("tank", 9.0, {"A": AHEAD}, {"option": "ENGAGE", "target": "A"}, {"option": "ENGAGE", "target": "A"})
	assert_eq(cost, 0.0, "the option it is already carrying out costs nothing")


## Changing stance on the same target still throws away the velocity in flight, because engaging, suppressing and
## orbiting drive to different places. Without this floor, ENGAGE <-> SUPPRESS thrash is priced at zero.
func test_a_stance_change_on_one_target_still_sheds_its_speed() -> void:
	var stopped := _cost("tank", 0.0, {"A": AHEAD}, {"option": "ENGAGE", "target": "A"}, {"option": "SUPPRESS", "target": "A"})
	var moving := _cost("tank", 9.0, {"A": AHEAD}, {"option": "ENGAGE", "target": "A"}, {"option": "SUPPRESS", "target": "A"})
	assert_eq(stopped, 0.0, "a halted crew changing stance discards no momentum")
	assert_near(moving, 9.0 / 12.0, 0.001, "at 9 m/s it sheds 9 m/s at 12 m/s^2 (got %.3f)" % moving)


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
