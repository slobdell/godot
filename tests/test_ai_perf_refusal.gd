extends TestCase
## Round 34 (brains, the orchestrator's ruling): scenario_perf's CPU budget is NOT JUDGED under native-verify-scenarios
## (both paths run: the budget measures the verifier; check's perf-judge judges the shipped budget). Every other run
## refuses exactly as before: no nominal, an unpinned hybrid core, or a loaded reference.

const Perf := preload("res://tests/ai_scenarios/scenario_perf.gd")


func test_under_verify_the_budget_is_not_judged() -> void:
	assert_true(Perf.refusal(true, 0.9, "builder2", "-", 1.1, true).begins_with("reason=verify"), "verify: not judged")


func test_a_quiet_plain_run_still_judges() -> void:
	assert_eq(Perf.refusal(true, 0.9, "builder2", "-", 1.1, false), "", "plain, quiet, a nominal: judged")
	assert_eq(Perf.refusal(true, 0.9, "builder0", "P", 1.4, false), "", "pinned to a P-core under the line: judged")


func test_the_old_refusals_stand() -> void:
	assert_true(Perf.refusal(true, 0.0, "x", "-", 1.0, false).begins_with("reason=no_nominal"), "no nominal")
	assert_true(Perf.refusal(true, 0.9, "builder0", "E", 1.0, false).begins_with("reason=unpinned"), "an E-core")
	assert_true(Perf.refusal(true, 0.9, "builder2", "-", 1.51, false).begins_with("reason=loaded"), "loaded")


func test_perf_refuse_off_judges_everything() -> void:
	assert_eq(Perf.refusal(false, 0.0, "x", "E", 3.0, true), "", "--perf-refuse=off: judged regardless")
