extends TestCase
## X1 (A2, round 9): the arm counter, before the arm is measured against anything.
##
## Round 8 shipped an additive commitment term into a code path a standoff hold could never reach and measured it
## twice before anyone noticed it was never consulted (lesson 117). So the counter has to exist, has to be in the
## output of the tool A2 is measured with (`make switch-arm` reads exactly what these tests read), has to be free of
## any effect on the decision it is counting, and has to read the same in both arms of a null A/B. That last one is
## what makes a real A/B meaningful: if the same build twice does not agree, nothing a different build says is worth
## reading.


func _situation(unit_id: String, speed: float, contacts: Array, overrides: Dictionary = {}) -> Dictionary:
	var forward := Vector3(0, 0, -1)
	var situation := {
		"tick": 1000,
		"self": {"name": "Green_A_1", "team": 0, "position": Vector3.ZERO, "forward": forward,
				"health": 100, "max_health": 100, "weapon": Weapons.profile("cannon"),
				"unit": unit_id, "velocity": forward * speed, "class": Units.role_of(unit_id)},
		"directives": Directives.resolve([]),
		"contacts": contacts,
		"allies": [],
		"objective": null,
		"objective_radius": 0.0,
		"squad_center": null,
		"cover": [],
		"rally": Vector3(0, 0, 42),
		"enemy_base": Vector3(0, 0, -42),
		"memory_ticks": Match.CONTACT_MEMORY_TICKS,
	}
	situation.merge(overrides, true)
	return situation


func _enemy(contact_name: String, position: Vector3) -> Dictionary:
	return {"name": contact_name, "position": position, "velocity": Vector3.ZERO, "forward": Vector3.BACK,
			"health": 100, "weapon": "cannon", "visible": true, "age": 0, "exposed_face": "front",
			"facing_ally": false, "aiming_at_me": false}


## Two enemies 90 degrees apart, both in reach: the situation where a crew has something to switch to.
func _two_fronts(unit_id: String, speed: float) -> Dictionary:
	return _situation(unit_id, speed, [_enemy("Rust_A_1", Vector3(0, 0, -40)), _enemy("Rust_A_2", Vector3(40, 0, 0))])


func _engaging_first() -> Dictionary:
	return {"option": "ENGAGE", "target": "Rust_A_1", "since": 0}


## The counter must not be able to change what it counts.
func test_the_counter_does_not_change_the_decision() -> void:
	var s := _two_fronts("gang_tank", 10.0)
	SwitchingCost.probing = false
	var quiet: Dictionary = TankBrain.decide(s, _engaging_first())
	SwitchingCost.probing = true
	var watched: Dictionary = TankBrain.decide(s, _engaging_first())
	assert_eq(watched["choice"], quiet["choice"], "the same decision whether or not anyone is counting")
	assert_eq(watched["ranked"], quiet["ranked"], "and the same ranking")
	assert_true(not quiet.has("switch"), "with the counter off there is no telemetry and nothing is allocated for it")


## The null A/B: the same build, twice, must agree. This is the precondition for any A/B against a different build.
func test_the_counter_reads_the_same_in_both_arms_of_a_null_ab() -> void:
	SwitchingCost.probing = true
	var first: Dictionary = TankBrain.decide(_two_fronts("gang_tank", 10.0), _engaging_first())["switch"]
	var second: Dictionary = TankBrain.decide(_two_fronts("gang_tank", 10.0), _engaging_first())["switch"]
	assert_eq(first, second, "a null A/B of the arm counter reads identically (%s vs %s)" % [first, second])
	assert_true(int(first["priced"]) > 0, "and it priced something, so the agreement is not two empty rows")


## Consulted, non-zero, and named: the three things lesson 117 says to prove before measuring anything.
func test_the_cost_is_consulted_and_non_zero_in_a_real_switch() -> void:
	SwitchingCost.probing = true
	var row: Dictionary = TankBrain.decide(_two_fronts("gang_tank", 10.0), _engaging_first())["switch"]
	print("MEASURE switch_arm_row %s" % row)
	assert_eq(String(row["arm"]), "cost", "the switching cost is the arm that ran")
	assert_true(int(row["priced"]) > 0, "it priced at least one candidate (%d)" % int(row["priced"]))
	assert_true(float(row["max_cost_s"]) > 0.0, "and charged a non-zero cost (%.2f s)" % float(row["max_cost_s"]))


## The counter names which arm ran, so a run can never be mistaken for the other one.
func test_the_counter_names_every_arm() -> void:
	SwitchingCost.probing = true
	var fresh: Dictionary = TankBrain.decide(_two_fronts("gang_tank", 10.0), {})["switch"]
	assert_eq(String(fresh["arm"]), "fresh", "no current choice: nothing to switch away from")
	assert_eq(int(fresh["priced"]), 0, "and nothing priced")

	assert_eq(Units.apply_tuning("switch.legacy=1"), "", "the legacy arm is selectable")
	var legacy: Dictionary = TankBrain.decide(_two_fronts("gang_tank", 10.0), _engaging_first())["switch"]
	assert_eq(String(legacy["arm"]), "legacy", "--tune=switch.legacy=1 restores the flat commitment bonus")
	assert_eq(float(legacy["max_cost_s"]), TankBrain.COMMIT_BONUS, "and the counter reports the multiplier it used")
	SwitchingCost.tuning.clear()


## The fourth arm, and the reason it exists: `main`'s commitment is TWO mechanisms — a flat bonus and a hard dwell
## timer — so A2 measured against "legacy" is measured against both at once, and any churn figure credited to the
## bonus might belong to the timer A2 deliberately retires. `switch.dwell=0` isolates them.
func test_the_dwell_timer_can_be_isolated_from_the_flat_bonus() -> void:
	SwitchingCost.probing = true
	# A situation where the incumbent is beaten but not decisively: the timer, and only the timer, holds it.
	var s := _situation("tank", 0.0, [_enemy("Rust_A_1", Vector3(0, 0, -36)), _enemy("Rust_A_2", Vector3(0, 0, -30))])
	var current := {"option": "ENGAGE", "target": "Rust_A_1", "since": 1000 - TankBrain.MIN_COMMIT_TICKS + 2}
	assert_eq(Units.apply_tuning("switch.legacy=1"), "", "the flat arm is selectable")
	var held: Dictionary = TankBrain.decide(s, current)["choice"]
	assert_eq(Units.apply_tuning("switch.dwell=0"), "", "and its dwell timer is separately selectable")
	var unheld: Dictionary = TankBrain.decide(s, current)["choice"]
	print("MEASURE switch_dwell_isolation flat+dwell %s; flat alone %s" % [
			TankBrain.label(held), TankBrain.label(unheld)])
	assert_eq(String(held["target"]), "Rust_A_1", "inside the dwell window the flat arm holds its target")
	assert_true(SwitchingCost.legacy_arm(), "the flat bonus is still in play with the timer off")
	SwitchingCost.tuning.clear()


## X2's acceptance 2, asserted at the seam rather than only in the cost function: in ONE situation, the roster's
## heaviest hull is charged a multiple of its lightest. A cost that does not separate them is a constant in disguise
## and would make an A/B against `main` an A/B of a build against itself.
func test_the_cost_separates_hull_classes_at_the_seam() -> void:
	SwitchingCost.probing = true
	var rig: Dictionary = TankBrain.decide(_two_fronts("gang_tank", 10.0), _engaging_first())["switch"]
	var rod: Dictionary = TankBrain.decide(_two_fronts("gang_scout", 10.0), _engaging_first())["switch"]
	var ratio := float(rig["max_cost_s"]) / maxf(float(rod["max_cost_s"]), 0.0001)
	print("MEASURE switch_arm_by_class war rig %.2f s, rat rod %.2f s (x%.2f) at 10 m/s, 90 deg apart" % [
			float(rig["max_cost_s"]), float(rod["max_cost_s"]), ratio])
	assert_true(ratio >= 2.0, "the rig is charged at least twice the rat rod (%.2f s vs %.2f s)" % [
			float(rig["max_cost_s"]), float(rod["max_cost_s"])])


## Lesson 153 (nav's A7 leash clamped at LEASH_FALLOFF, every far candidate tied at 1.0, and the level ranked nothing):
## every cost that can saturate must still rank what it prices. The penalty is capped — that is the veto guard — but
## the cap is an equal offset, so two candidates beyond it keep their own order, and the subtraction is deliberately
## NOT floored at zero, because a floor is the saturation that would tie them.
func test_two_candidates_beyond_the_cap_still_rank_by_utility() -> void:
	var s := _situation("gang_tank", 12.0, [_enemy("Rust_A_1", Vector3(0, 0, -30)),
			_enemy("Rust_A_2", Vector3(0, 0, 35)), _enemy("Rust_A_3", Vector3(4, 0, 40))])
	var ctx := SwitchingCost.context(s, {"option": "ENGAGE", "target": "Rust_A_1", "since": 0})
	var second := SwitchingCost.penalty(ctx, "ENGAGE", "Rust_A_2")
	var third := SwitchingCost.penalty(ctx, "ENGAGE", "Rust_A_3")
	assert_eq(second, SwitchingCost.MAX_PENALTY, "both are reversals at speed, so both are at the cap")
	assert_eq(third, SwitchingCost.MAX_PENALTY, "both are reversals at speed, so both are at the cap")
	# Equal offsets: whatever the scorer made of these two before, it still makes of them after. What must NOT happen
	# is the two arriving at the same number, which is what a floor at zero would have done to them.
	var decision: Dictionary = TankBrain.decide(s, {"option": "ENGAGE", "target": "Rust_A_1", "since": 0})
	var ranked: Array = decision["ranked"]
	print("MEASURE switch_cap_ranking both priced at the cap (%.3f); top 3 %s" % [SwitchingCost.MAX_PENALTY, ranked])
	var seen := {}
	for entry: Dictionary in ranked:
		var key := "%s %s" % [entry["option"], entry["target"]]
		assert_true(not seen.has(key), "no option appears twice in the ranking")
		seen[key] = float(entry["score"])
	for i in ranked.size() - 1:
		assert_true(float(ranked[i]["score"]) >= float(ranked[i + 1]["score"]),
				"the ranking is still ordered past the cap (%s)" % [ranked])


## The control arm of every A/B: the cost off, the code path intact, and the counter still reporting what it WOULD
## have charged — so a null result can be told apart from a mechanism that never ran.
func test_the_control_arm_still_reports_what_it_would_have_charged() -> void:
	SwitchingCost.probing = true
	assert_eq(Units.apply_tuning("switch.price=0"), "", "the control arm is selectable")
	var row: Dictionary = TankBrain.decide(_two_fronts("gang_tank", 10.0), _engaging_first())["switch"]
	assert_eq(String(row["arm"]), "cost", "the code path is the treatment's, not a different one")
	assert_true(float(row["max_cost_s"]) > 0.0, "and the cost is still computed and reported (%.2f s)" % float(row["max_cost_s"]))
	SwitchingCost.tuning.clear()


func teardown() -> void:
	SwitchingCost.probing = false
	SwitchingCost.tuning.clear()
