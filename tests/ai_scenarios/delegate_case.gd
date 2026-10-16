extends TestCase
## The quick subset of the AI behavior scenarios (tests/ai_scenarios/), so `make test` and `make check`
## guard behaviors that already work. Each delegates to the scenario itself; the full set, including
## pending behaviors, runs faster than real time with `make ai-scenarios`.
## Round 31 (C31.9 / R31.9): the shared part of test_ai_scenarios*.gd (split by time); no tests of its own.

const FIRE_DISCIPLINE := preload("res://tests/ai_scenarios/scenario_fire_discipline.gd")
const COVER := preload("res://tests/ai_scenarios/scenario_cover.gd")
const ORDERS := preload("res://tests/ai_scenarios/scenario_orders.gd")
const ELEMENTS := preload("res://tests/ai_scenarios/scenario_elements.gd")
const SUPPRESSION := preload("res://tests/ai_scenarios/scenario_suppression.gd")


func _delegate(script: GDScript, method: String) -> void:
	var scenario: TestCase = script.new()
	scenario.tree = tree
	await scenario.call(method)
	scenario.teardown()
	failures.append_array(scenario.failures)
