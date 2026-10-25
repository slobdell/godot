extends TestCase
## Round 40 (CP40.0, native N1): GUARD_RESULT's per-unit counts (guard_line.gd's UnitTally) on a fixture fight's events.

const GuardLine := preload("res://tests/ai_scenarios/guard_line.gd")


## Green: g1 (gun), g2 (mortar), g3 (flamer). Rust: r1, r2, r3. Cost and faction ride through as given.
func _fixture() -> RefCounted:
	var tally: RefCounted = GuardLine.UnitTally.new()
	tally.register("g1", 0, "tank", "law", 200)
	tally.register("g2", 0, "mortar", "law", 220)
	tally.register("g3", 0, "flamer", "law", 220)
	tally.register("r1", 1, "buggy", "gangs", 70)
	tally.register("r2", 1, "buggy", "gangs", 70)
	tally.register("r3", 1, "rig", "gangs", 175)
	tally.register("r3", 1, "ignored", "x", 1)  # a second register keeps the first row
	tally.fired({"projectile_id": 1, "shooter": "g1"})
	tally.fired({"projectile_id": 2, "shooter": "g2"})
	tally.fired({"projectile_id": 3, "shooter": "r1"})
	tally.fired({"projectile_id": 4, "shooter": "r1"})
	tally.impact({"projectile_id": 1, "target": "r1", "damage": 40.0, "killed": true})
	tally.impact({"projectile_id": 3, "target": "g1", "damage": 12.5})
	tally.impact({"projectile_id": 4, "target": "r2", "damage": 9.0})  # friendly fire: not counted
	tally.impact({"projectile_id": 9, "target": "r2", "damage": 5.0})  # no known shooter: not counted
	tally.impact({"projectile_id": 2, "target": "r2", "damage": 30.0,  # a burst: its victims, not its sum
			"victims": [{"target": "r2", "damage": 20.0}, {"target": "r3", "damage": 10.0}]})
	tally.spray_before({"r2": 50.0, "r3": 175.0})
	tally.spray_after("g3", {"r3": 170.0})  # r2 burned out of the list: the whole 50
	tally.destroyed({"tick": 300, "unit": "r1", "killer": "g1", "cause": "enemy"})
	tally.destroyed({"tick": 410, "unit": "r2", "killer": "g3", "cause": "enemy"})
	tally.destroyed({"tick": 500, "unit": "g2", "killer": "g1", "cause": "friendly_fire"})
	tally.destroyed({"tick": 520, "unit": "r3", "killer": "hazard:mine", "cause": "hazard"})
	return tally


func _row(report: Dictionary, unit: String) -> Dictionary:
	for side: String in report:
		for row: Dictionary in report[side]:
			if row["id"] == unit:
				return row
	return {}


func test_a_sides_unit_kills_sum_to_its_enemy_kills() -> void:
	var report: Dictionary = _fixture().report()
	assert_eq(report["green"].size(), 3, "three green rows")
	assert_eq(report["rust"].size(), 3, "three rust rows")
	var kills := 0
	for row: Dictionary in report["green"]:
		kills += int(row["kills"])
	assert_eq(kills, 2, "green's enemy kills (the friendly and hazard deaths count for nobody)")
	assert_eq(_row(report, "g1")["kills"], 1, "g1 killed r1")
	assert_eq(_row(report, "g3")["kills"], 1, "g3 killed r2")


func test_deaths_carry_the_tick_and_the_killer() -> void:
	var report: Dictionary = _fixture().report()
	assert_eq(_row(report, "r1")["death"], 300, "r1 died at 300")
	assert_eq(_row(report, "g2")["killer"], "g1", "friendly fire names its shooter")
	assert_eq(_row(report, "r3")["killer"], "hazard:mine", "a hazard")
	assert_eq(_row(report, "g1")["death"], -1, "g1 lived")


func test_damage_counts_enemies_only_and_balances_across_sides() -> void:
	var report: Dictionary = _fixture().report()
	assert_eq(_row(report, "g1")["dealt"], 40.0, "g1's shell")
	assert_eq(_row(report, "g2")["dealt"], 30.0, "g2's burst victims")
	assert_eq(_row(report, "g3")["dealt"], 55.0, "g3's cone: 50 + 5")
	assert_eq(_row(report, "r1")["dealt"], 12.5, "r1's friendly round not counted")
	assert_eq(_row(report, "r2")["taken"], 70.0, "20 burst + 50 cone (the unknown and friendly rounds are not)")
	var dealt := {"green": 0.0, "rust": 0.0}
	var taken := {"green": 0.0, "rust": 0.0}
	for side: String in report:
		for row: Dictionary in report[side]:
			dealt[side] += float(row["dealt"])
			taken[side] += float(row["taken"])
	assert_eq(dealt["green"], taken["rust"], "green's dealt is rust's taken")
	assert_eq(dealt["rust"], taken["green"], "rust's dealt is green's taken")


func test_rows_carry_type_faction_and_cost() -> void:
	var row := _row(_fixture().report(), "r3")
	assert_eq(row["type"], "rig", "the first register's type")
	assert_eq(row["faction"], "gangs", "faction")
	assert_eq(row["cost"], 175, "cost")
