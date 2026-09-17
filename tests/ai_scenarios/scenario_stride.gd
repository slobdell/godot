extends TestCase
## Round-5 X1 (ai): does the half-rate controller (x5b2: the whole controller every other physics tick, the tank keeping
## its last command in between) cost reactivity? The orchestrator's bar, and round 4's lesson 20: a cost cut has to be
## measured against the behaviours that live on reaction time, not just the clock. Two of them, each against the
## champion x4t9 on the same seeds:
##   dodging — shells fired by a leading cannon that land (scenario_evasion's duel, more seeds);
##   the beaten zone — ticks an ordered unit spends in a lane two machine guns sweep (scenario_suppression's crossing).

const EVASION := preload("res://tests/ai_scenarios/scenario_evasion.gd")
const SUPPRESSION := preload("res://tests/ai_scenarios/scenario_suppression.gd")
const SEEDS := [1, 2, 3, 4, 5, 6]
const CHALLENGER := "x5b2"
const CHAMPION := "x4t9"


func _helper(script: GDScript) -> TestCase:
	var helper: TestCase = script.new()
	helper.tree = tree
	return helper


func test_the_half_rate_controller_still_dodges() -> void:
	var evasion := _helper(EVASION)
	var rates := {}
	for unit: String in ["ifv", "tank"]:
		for variant: String in [CHAMPION, CHALLENGER]:
			var fired := 0
			var hits := 0
			for seed_value: int in SEEDS:
				var result: Array = await evasion._duel(variant, unit, seed_value)
				fired += int(result[0])
				hits += int(result[1])
			rates["%s/%s" % [unit, variant]] = 1.0 - float(hits) / maxf(fired, 1)
			print("MEASURE ai_stride_dodge %s %s: %d of %d shells hit (dodge rate %.0f%%)" % [unit, variant, hits, fired,
					100.0 * (1.0 - float(hits) / maxf(fired, 1))])
	evasion.teardown()
	for unit: String in ["ifv", "tank"]:
		assert_true(float(rates["%s/%s" % [unit, CHALLENGER]]) >= float(rates["%s/%s" % [unit, CHAMPION]]) - 0.1,
				"%s: dodging no more than 10 points worse at half rate (%.0f%% vs %.0f%%)" % [unit,
				100.0 * float(rates["%s/%s" % [unit, CHALLENGER]]), 100.0 * float(rates["%s/%s" % [unit, CHAMPION]])])


func test_the_half_rate_controller_still_keeps_out_of_a_beaten_zone() -> void:
	var suppression := _helper(SUPPRESSION)
	var results := {}
	for variant: String in [CHAMPION, CHALLENGER]:
		BrainVariants.use(Match.Team.GREEN, variant)
		results[variant] = await suppression._cross_the_lane(true)
		BrainVariants.reset()
		print("MEASURE ai_stride_beaten_zone %s: %d ticks in the beaten zone, arrived %s, worst suppression %.2f" % [variant,
				int(results[variant]["in_zone"]), results[variant]["arrived"], float(results[variant]["suppression"])])
	suppression.teardown()
	assert_true(bool(results[CHALLENGER]["arrived"]), "the half-rate unit still gets where it was sent")
	assert_true(int(results[CHALLENGER]["in_zone"]) <= int(results[CHAMPION]["in_zone"]) * 1.5 + 3,
			"and spends not much longer in the fire (%d vs %d ticks)" % [results[CHALLENGER]["in_zone"], results[CHAMPION]["in_zone"]])
