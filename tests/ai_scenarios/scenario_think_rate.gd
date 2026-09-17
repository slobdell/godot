extends TestCase
## Round-5 reopening (ai): what does THINKING LESS OFTEN cost in reaction? After the 30 Hz move the unit controllers are
## ~85% of a tick, and the one big lever left is the rate a brain in contact thinks at: the champion thinks 7.5 times a
## second, x6t5 five times, x6t4 3.75. Round 4's lesson 20 (a cost cut that quietly deleted most of a behaviour) says to
## measure this against the behaviours that live on reaction time. Two of them, each against the champion on the same
## seeds — the beaten zone matters most: noticing a wall of bullets is the behaviour slow thinking should destroy
## first, and combat's ready_to_fire fix has made that fire denser than any earlier measurement.
##   dodging — shells fired by a leading cannon that land (scenario_evasion's duel, more seeds);
##   the beaten zone — ticks an ordered unit spends in a lane two machine guns sweep (scenario_suppression's crossing).

const EVASION := preload("res://tests/ai_scenarios/scenario_evasion.gd")
const SUPPRESSION := preload("res://tests/ai_scenarios/scenario_suppression.gd")
const SEEDS := [1, 2, 3, 4, 5, 6]
const CHALLENGERS := ["x6t5", "x6t4"]
const CHAMPION := BrainVariants.CHAMPION


func _helper(script: GDScript) -> TestCase:
	var helper: TestCase = script.new()
	helper.tree = tree
	return helper


func test_thinking_less_often_and_dodging() -> void:
	var evasion := _helper(EVASION)
	var rates := {}
	for unit: String in ["ifv", "tank"]:
		for variant: String in [CHAMPION] + CHALLENGERS:
			var fired := 0
			var hits := 0
			for seed_value: int in SEEDS:
				var result: Array = await evasion._duel(variant, unit, seed_value)
				fired += int(result[0])
				hits += int(result[1])
			rates["%s/%s" % [unit, variant]] = 1.0 - float(hits) / maxf(fired, 1)
			print("MEASURE ai_think_rate_dodge %s %s: %d of %d shells hit (dodge rate %.0f%%)" % [unit, variant, hits, fired,
					100.0 * (1.0 - float(hits) / maxf(fired, 1))])
	evasion.teardown()
	# No assertion on the challengers: this scenario REPORTS what thinking less often costs, for the lead to weigh
	# against army size. The champion's own dodging is the thing that must not rot unnoticed.
	assert_true(float(rates["ifv/%s" % CHAMPION]) > 0.0, "the champion dodges something (%.0f%%)" % (100.0 * float(rates["ifv/%s" % CHAMPION])))


func test_thinking_less_often_and_the_beaten_zone() -> void:
	var suppression := _helper(SUPPRESSION)
	var results := {}
	for variant: String in [CHAMPION] + CHALLENGERS:
		BrainVariants.use(Match.Team.GREEN, variant)
		results[variant] = await suppression._cross_the_lane(true)
		BrainVariants.reset()
		print("MEASURE ai_think_rate_beaten_zone %s: %d ticks in the beaten zone, arrived %s, worst suppression %.2f" % [variant,
				int(results[variant]["in_zone"]), results[variant]["arrived"], float(results[variant]["suppression"])])
	suppression.teardown()
	assert_true(bool(results[CHAMPION]["arrived"]), "the champion still gets where it was sent")
	for variant: String in CHALLENGERS:
		print("      %s spent %.0f%% of the champion's time in the beaten zone (%d vs %d ticks), arrived %s" % [variant,
				100.0 * float(results[variant]["in_zone"]) / maxf(float(results[CHAMPION]["in_zone"]), 1.0),
				int(results[variant]["in_zone"]), int(results[CHAMPION]["in_zone"]), results[variant]["arrived"]])
