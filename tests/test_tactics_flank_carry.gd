extends TestCase
## Round 28, brains B1 (his call 4: "you chose the flank; it carries out the order even if it costs crews"): A DRAWN FLANK
## IS CARRIED OUT. Round 27's B0 rule came round to the side against a passive target but, in a live fight (traced on
## the even roster, seed 4): it went round at its own guns' reach (gun trucks, 35 m) inside the target's 60 m autocannon;
## a target shuffling at 2 m/s turned it into a pursuit, which has no side; and once round, a "near ambush" by the
## target itself sent it charging through the middle for 30 s. These hold the new rule at the plan level:
##   - going round, the ring is wide of the target SQUAD's guns (their reach + a margin), not at the crews' own reach;
##   - going round, it is a pursuit only when the target has been RUNNING (>= 6 m/s) for 2 s;
##   - for the whole task the target's squad closing is not a near ambush; a third party still is one;
##   - going round, being outgunned does not break it off;
##   - `--approach-carry=off` (APPROACH_CARRY false) is B0's rule, and with no approach nothing changes.

const TARGET := Vector3.ZERO
## The gun trucks' twin MG: their own reach, and B0's ring.
const OWN_RANGE := 35.0
const OWN_BAND := 28.0


func teardown() -> void:
	ElementPlan.APPROACH_CARRY = true
	DoctrineTable.clear_cache()  # one test widens the cached standard table's drills
	super.teardown()


func _table() -> DoctrineTable:
	DoctrineTable.clear_cache()
	return DoctrineTable.load_table("standard").get("table")


## Five gun trucks round `center`; the target, a Law IFV (autocannon, 60 m), at TARGET; `extra` contacts beside it.
func _situation(center: Vector3, extra: Array = [], target_age := 200) -> Dictionary:
	var members: Array = []
	for i in 5:
		members.append({"name": "Green_%d" % (i + 1), "position": center + Vector3(i * 8.0 - 16.0, 0.0, 0.0),
				"forward": Vector3.FORWARD, "role": "ifv", "unit": "gang_ifv", "speed": 12.0, "range": OWN_RANGE,
				"effective_range": OWN_BAND, "sight": 140.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	var listed := [{"name": "Rust_1", "position": TARGET, "role": "ifv", "unit": "law_ifv", "visible": true,
			"age": target_age, "distance": TARGET.distance_to(center), "bearing_deg": 0.0, "strength": 200.0,
			"speed": 0.0}]
	listed.append_array(extra)
	# ElementSituation lists contacts nearest first (Drills.nearest_contact reads the first).
	listed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
	return {"tick": 1000, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": "Green_1",
			"members": members, "contacts": listed, "terrain": "open",
			"threat": ElementSituation.threat_from(listed, false), "composition": "light", "strength": 1000.0,
			"enemy_strength": 200.0, "taking_fire": false, "arrived": false}


func _state(task: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "",
			"drill_why": "", "anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}}
	state.merge(extra, true)
	return state


func _attack(approach: Variant = [0.0, -1.0]) -> Dictionary:
	var task := {"verb": "attack", "target": "Rust_1"}
	if approach != null:
		task["approach"] = approach
	return task


## The element's centre `metres` from the target, `degrees` round from the side the approach [0, -1] comes from (south).
func _round(degrees: float, metres := 100.0) -> Vector3:
	var from := atan2(1.0, 0.0) + deg_to_rad(degrees)
	return Vector3(cos(from), 0.0, sin(from)) * metres


func _contact(contact_name: String, at: Vector3, unit: String, center: Vector3, age := 200) -> Dictionary:
	return {"name": contact_name, "position": at, "role": "tank", "unit": unit, "visible": true, "age": age,
			"distance": at.distance_to(center), "bearing_deg": 0.0, "strength": 200.0, "speed": 0.0}


func test_it_goes_round_wide_of_the_target_squads_guns() -> void:
	var table := _table()
	var situation := _situation(_round(170.0))
	var plan := ElementPlan.build(situation, _state(_attack()), table)
	var anchor: Vector3 = plan["anchor"]
	assert_near(anchor.distance_to(TARGET), 60.0 + ElementPlan.APPROACH_STANDOFF_MARGIN_M, 0.5,
			"round a Law IFV (60 m): its reach + the margin, not the trucks' 35 m (%.1f m)" % anchor.distance_to(TARGET))
	# Its squad's longest gun counts: a Law tank (assault gun, 80 m) 20 m from the target.
	var squad := _situation(_round(170.0), [_contact("Rust_2", Vector3(20.0, 0.0, 0.0), "law_tank", _round(170.0))])
	var wide: Vector3 = ElementPlan.build(squad, _state(_attack()), table)["anchor"]
	assert_near(wide.distance_to(TARGET), 80.0 + ElementPlan.APPROACH_STANDOFF_MARGIN_M, 0.5,
			"wide of the squad's longest gun (%.1f m)" % wide.distance_to(TARGET))
	# Someone else's tank 60 m away is not the target's squad.
	var apart := _situation(_round(170.0), [_contact("Rust_9", Vector3(60.0, 0.0, 0.0), "law_tank", _round(170.0))])
	var not_squad: Vector3 = ElementPlan.build(apart, _state(_attack()), table)["anchor"]
	assert_near(not_squad.distance_to(TARGET), 60.0 + ElementPlan.APPROACH_STANDOFF_MARGIN_M, 0.5,
			"a contact 60 m off the target is not its squad (%.1f m)" % not_squad.distance_to(TARGET))
	ElementPlan.APPROACH_CARRY = false
	var b0: Vector3 = ElementPlan.build(situation, _state(_attack()), table)["anchor"]
	assert_near(b0.distance_to(TARGET), OWN_RANGE, 0.5, "control (B0): round at its own reach (%.1f m)" % b0.distance_to(TARGET))


func test_a_shuffling_target_is_not_a_pursuit_while_it_goes_round() -> void:
	var table := _table()
	var situation := _situation(_round(170.0))
	var track := {"name": "Rust_1", "position": TARGET, "velocity": Vector3(4.0, 0.0, 0.0), "seen_tick": 1000}
	var plan := ElementPlan.build(situation, _state(_attack(), {"pursuit": track}), table)
	assert_true(not bool(plan["pursuing"]), "4 m/s: still going round")
	assert_true(not bool((plan["approach_round"] as Dictionary).get("in", true)), "and not in yet")
	# Even after it was a pursuit at 2 m/s under B0's sticky rule.
	var sticky := ElementPlan.build(situation, _state(_attack(), {"pursuit": track, "pursuing": true}), table)
	assert_true(not bool(sticky["pursuing"]), "not sticky while going round")
	ElementPlan.APPROACH_CARRY = false
	assert_true(bool(ElementPlan.build(situation, _state(_attack(), {"pursuit": track}), table)["pursuing"]),
			"control (B0): 4 m/s is a pursuit")


func test_a_running_target_is_a_pursuit_after_two_seconds() -> void:
	var table := _table()
	var situation := _situation(_round(170.0))
	# Fleeing: 7 m/s straight away from the element.
	var track := {"name": "Rust_1", "position": TARGET, "velocity": TacticsFormation.flat(TARGET - situation["center"]) * 7.0,
			"seen_tick": 1000}
	var first := ElementPlan.build(situation, _state(_attack(), {"pursuit": track}), table)
	assert_true(not bool(first["pursuing"]), "7 m/s, just started: not yet")
	assert_eq(int((first["approach_round"] as Dictionary).get("fast_since", -2)), 1000, "the clock starts")
	var held := int(ElementPlan.APPROACH_RUNNING_S * SimClock.TICK_RATE)
	var later := ElementPlan.build(situation, _state(_attack(), {"pursuit": track,
			"approach_round": {"in": false, "side": 1, "fast_since": 1000 - held}}), table)
	assert_true(bool(later["pursuing"]), "running for 2 s: a pursuit")
	var slowed := ElementPlan.build(situation, _state(_attack(), {"pursuit": {"name": "Rust_1", "position": TARGET,
			"velocity": Vector3(1.0, 0.0, 0.0), "seen_tick": 1000},
			"approach_round": {"in": false, "side": 1, "fast_since": 1000 - held}}), table)
	assert_true(not bool(slowed["pursuing"]), "slowed again: it goes round again")
	assert_eq(int((slowed["approach_round"] as Dictionary).get("fast_since", -2)), -1, "and the clock resets")


func test_the_target_squad_closing_is_not_a_near_ambush() -> void:
	var table := _table()
	var near := table.drill_number("near_ambush_m") * 0.5
	var center := _round(170.0, near + 5.0)
	# The target's squadmate, just seen, close: going round (and once in) it is the fight, not an ambush.
	var mate := _contact("Rust_2", center.lerp(TARGET, 0.2), "law_tank", center, 1)
	var situation := _situation(center, [mate])
	for kept: Dictionary in [{"in": false, "side": 1}, {"in": true, "side": 1}]:
		var drill := Drills.select(situation, _state(_attack(), {"approach_round": kept}), table)
		assert_true(not ["near_ambush", "assault_through"].has(String(drill["drill"])),
				"in=%s: the target's squad is not an ambush (%s)" % [kept["in"], drill["drill"]])
		var running := Drills.select(situation, _state(_attack(), {"approach_round": kept, "drill": "assault_through",
				"drill_target": "Rust_2", "drill_tick": 990}), table)
		assert_true(String(running["drill"]) != "assault_through", "in=%s: one already running stops" % kept["in"])
	# A stranger far from the target (the element 100 m off it), just seen, on top of us: still an ambush.
	var far := _round(170.0, 100.0)
	var stranger := _contact("Rust_9", far * 1.06, "law_tank", far, 1)
	var ambushed := Drills.select(_situation(far, [stranger]), _state(_attack(), {"approach_round": {"in": false,
			"side": 1}}), table)
	assert_eq(String(ambushed["drill"]), "near_ambush", "a third party on top of us is an ambush")
	ElementPlan.APPROACH_CARRY = false
	var b0 := Drills.select(situation, _state(_attack(), {"approach_round": {"in": true, "side": 1}}), table)
	assert_eq(String(b0["drill"]), "near_ambush", "control (B0): once in, the squadmate springs one")


func test_going_round_being_outgunned_does_not_break_it_off() -> void:
	var table := _table()
	# break_contact is off in every shipped table (DoctrineTable: since round 5); a table that runs it.
	table.drills["enabled"] = (table.drills.get("enabled", DoctrineTable.DRILL_DEFAULTS["enabled"]) as Array) \
			+ ["break_contact"]
	var center := _round(170.0, 100.0)
	var situation := _situation(center)
	situation["strength"] = 50.0
	situation["enemy_strength"] = 1000.0
	var control := Drills.select(situation, _state(_attack(null)), table)
	assert_eq(String(control["drill"]), "break_contact", "precondition: without a drawn flank it breaks contact")
	var drill := Drills.select(situation, _state(_attack(), {"approach_round": {"in": false, "side": 1}}), table)
	assert_true(String(drill["drill"]) != "break_contact", "going round: it carries on (%s)" % drill["drill"])


func test_with_no_approach_nothing_changes() -> void:
	var table := _table()
	var center := _round(170.0)
	var track := {"name": "Rust_1", "position": TARGET, "velocity": Vector3(4.0, 0.0, 0.0), "seen_tick": 1000}
	for extra: Dictionary in [{}, {"pursuit": track}]:
		var on := ElementPlan.build(_situation(center), _state(_attack(null), extra.duplicate(true)), table)
		ElementPlan.APPROACH_CARRY = false
		var off := ElementPlan.build(_situation(center), _state(_attack(null), extra.duplicate(true)), table)
		ElementPlan.APPROACH_CARRY = true
		assert_eq(on, off, "no approach: the plan is B0's (%s)" % str(extra.keys()))


func test_it_goes_round_in_a_column_on_the_ring() -> void:
	var table := _table()
	var plan := ElementPlan.build(_situation(_round(170.0)), _state(_attack()), table)
	assert_eq(String(plan["formation"]), "column", "round in a column")
	for unit_name: String in plan["slots"]:
		var slot: Vector3 = plan["slots"][unit_name]
		assert_true(slot.distance_to(TARGET) > 60.0, "%s rides wide of the IFV's 60 m (%.1f m)" % [unit_name,
				slot.distance_to(TARGET)])


func test_once_round_it_fights_from_a_line_on_the_side() -> void:
	var table := _table()
	var approach := Vector3(0.0, 0.0, -1.0)  # in from the south
	var center := _round(10.0, 40.0)
	var plan := ElementPlan.build(_situation(center), _state(_attack(), {"approach_round": {"in": true, "side": 1}}),
			table)
	assert_eq(String(plan["formation"]), "line", "a firing line")
	var anchor: Vector3 = plan["anchor"]
	assert_near(ElementPlan.approach_off_deg(anchor, TARGET, approach), 0.0, 0.5, "anchored on the side drawn")
	assert_near(anchor.distance_to(TARGET), maxf(OWN_BAND * ElementPlan.SBF_STANDOFF, ElementPlan.SBF_MIN_STANDOFF_M),
			0.5, "at the support-by-fire standoff (%.1f m)" % anchor.distance_to(TARGET))
	for unit_name: String in plan["slots"]:
		var slot: Vector3 = plan["slots"][unit_name]
		assert_true(absf(ElementPlan.approach_off_deg(slot, TARGET, approach)) < 60.0, "%s's place is on the side (%.0f)"
				% [unit_name, ElementPlan.approach_off_deg(slot, TARGET, approach)])
	# Contact does not pull it off the line (return fire would send crews in on free attacks).
	var situation := _situation(center)
	situation["threat"] = "contact"
	var drill := Drills.select(situation, _state(_attack(), {"approach_round": {"in": true, "side": 1}}), table)
	assert_true(not ["react_to_contact", "far_ambush"].has(String(drill["drill"])), "no contact drill (%s)" % drill["drill"])


func test_once_round_a_crew_fights_on_the_side_and_is_sent_back_off_it() -> void:
	var table := _table()
	var approach := Vector3(0.0, 0.0, -1.0)
	var situation := _situation(_round(10.0, 40.0))
	# Green_1 on the side 20 m out (in reach), Green_2 carried round to 90 deg, 20 m out.
	(situation["members"][0] as Dictionary)["position"] = _round(5.0, 20.0)
	(situation["members"][1] as Dictionary)["position"] = _round(90.0, 20.0)
	var plan := ElementPlan.build(situation, _state(_attack(), {"approach_round": {"in": true, "side": 1}}), table)
	assert_eq(String(plan["orders"]["Green_1"]["verb"]), "attack", "on the side, in reach: it fights")
	assert_eq(String(plan["orders"]["Green_2"]["verb"]), "move", "carried off the side: back to its place")
	assert_eq(String(plan["orders"]["Green_2"]["target"]), "Rust_1", "gun on the target on the way")
	# Already fighting at 50 deg: it keeps fighting (the wider sector); a fresh crew there is sent back.
	(situation["members"][1] as Dictionary)["position"] = _round(50.0, 20.0)
	var kept := ElementPlan.build(situation, _state(_attack(), {"approach_round": {"in": true, "side": 1},
			"attacking": {"Green_2": true}}), table)
	assert_eq(String(kept["orders"]["Green_2"]["verb"]), "attack", "fighting at 50 deg: keeps at it")
	var fresh := ElementPlan.build(situation, _state(_attack(), {"approach_round": {"in": true, "side": 1}}), table)
	assert_eq(String(fresh["orders"]["Green_2"]["verb"]), "move", "not fighting at 50 deg: back to its place")


func test_a_target_driving_at_the_squad_is_not_fleeing() -> void:
	var table := _table()
	var center := _round(170.0)
	# The target 100 m off, driving at the element at 10 m/s (its velocity toward `center`).
	var toward := TacticsFormation.flat(center - TARGET) * 10.0
	var held := int(ElementPlan.APPROACH_RUNNING_S * SimClock.TICK_RATE)
	var plan := ElementPlan.build(_situation(center), _state(_attack(), {"pursuit": {"name": "Rust_1",
			"position": TARGET, "velocity": toward, "seen_tick": 1000},
			"approach_round": {"in": false, "side": 1, "fast_since": 1000 - held}}), table)
	assert_true(not bool(plan["pursuing"]), "charging at us is not fleeing: still going round")
	assert_eq(int((plan["approach_round"] as Dictionary).get("fast_since", -2)), -1, "its clock is reset")


func test_a_target_driving_at_it_is_rounded_at_its_own_reach() -> void:
	var table := _table()
	var center := _round(170.0)
	var toward := TacticsFormation.flat(center - TARGET) * 5.0
	var plan := ElementPlan.build(_situation(center), _state(_attack(), {"pursuit": {"name": "Rust_1",
			"position": TARGET, "velocity": toward, "seen_tick": 1000}}), table)
	assert_near((plan["anchor"] as Vector3).distance_to(TARGET), OWN_RANGE, 0.5,
			"a target coming at it: round at its own reach, shooting (%.1f m)" % (plan["anchor"] as Vector3).distance_to(TARGET))
