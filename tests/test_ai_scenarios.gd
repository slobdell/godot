extends TestCase
## The quick subset of the AI behavior scenarios (tests/ai_scenarios/), so `make test` and `make check`
## guard behaviors that already work. Each delegates to the scenario itself; the full set, including
## pending behaviors, runs faster than real time with `make ai-scenarios`.

const FIRE_DISCIPLINE := preload("res://tests/ai_scenarios/scenario_fire_discipline.gd")
const COVER := preload("res://tests/ai_scenarios/scenario_cover.gd")
const ORDERS := preload("res://tests/ai_scenarios/scenario_orders.gd")
const ELEMENTS := preload("res://tests/ai_scenarios/scenario_elements.gd")


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


func test_a_move_order_is_executed_within_3_ticks_whatever_the_brain_was_doing() -> void:
	await _delegate(ORDERS, "test_a_move_order_is_executed_within_3_ticks_whatever_the_brain_was_doing")


func test_attack_move_fights_on_the_way_then_arrives() -> void:
	await _delegate(ORDERS, "test_attack_move_fights_on_the_way_then_arrives")


func test_an_idle_unit_pushed_off_its_post_regroups() -> void:
	await _delegate(ORDERS, "test_an_idle_unit_pushed_off_its_post_regroups")


func test_no_option_is_kept_forever() -> void:
	await _delegate(ORDERS, "test_no_option_is_kept_forever")


func test_a_tank_blocked_by_a_parked_friend_moves_to_clear_the_lane() -> void:
	await _delegate(FIRE_DISCIPLINE, "test_a_tank_blocked_by_a_parked_friend_moves_to_clear_the_lane")


func test_each_unit_covers_its_own_sector_of_fire() -> void:
	await _delegate(ELEMENTS, "test_each_unit_covers_its_own_sector_of_fire")


func test_a_bounding_unit_rushes_and_halts_on_the_leaders_call() -> void:
	await _delegate(ELEMENTS, "test_a_bounding_unit_rushes_and_halts_on_the_leaders_call")
