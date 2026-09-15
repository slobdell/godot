extends TestCase
## The quick subset of the AI behavior scenarios (tests/ai_scenarios/), so `make test` and `make check`
## guard behaviors that already work. Each delegates to the scenario itself; the full set, including
## pending behaviors, runs faster than real time with `make ai-scenarios`.

const FIRE_DISCIPLINE := preload("res://tests/ai_scenarios/scenario_fire_discipline.gd")
const COVER := preload("res://tests/ai_scenarios/scenario_cover.gd")


func _delegate(script: GDScript, method: String) -> void:
	var scenario: TestCase = script.new()
	scenario.tree = tree
	await scenario.call(method)
	scenario.teardown()
	failures.append_array(scenario.failures)


func test_a_brain_fires_at_a_visible_enemy_with_a_clear_lane() -> void:
	await _delegate(FIRE_DISCIPLINE, "test_a_brain_fires_at_a_visible_enemy_with_a_clear_lane")


func test_a_hurt_tank_under_fire_gets_out_of_sight() -> void:
	await _delegate(COVER, "test_a_hurt_tank_under_fire_gets_out_of_sight")


func test_a_tank_blocked_by_a_parked_friend_moves_to_clear_the_lane() -> void:
	await _delegate(FIRE_DISCIPLINE, "test_a_tank_blocked_by_a_parked_friend_moves_to_clear_the_lane")
