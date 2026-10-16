extends TestCase
## The quick subset of the battle-drill scenarios (tests/tactics/tactics_scenarios.gd), so `make check`
## guards the drills that work. The full set, with the measurements, runs faster than real time with
## `make tactics-drills` and `make tactics-measure`.
## Round 30 (brains B7, C30.9): split in two by each test's measured time (builder0, 5272d612, `make scenario-times`:
## 574 s alone, the floor of any shard plan at 5-6 shards); the tests are the same, byte for byte. Its other half:
## tests/test_tactics_scenarios_2.gd.
## Round 31 (C31.9 / R31.9): part of test_tactics_scenarios.gd, split by measured time; the tests are the same.


func test_an_ambush_holds_its_fire_until_the_kill_zone_is_full() -> void:
	# The lead: "We want to be able to set up ambushes, do flanking maneuvers."
	var result: Dictionary = await TacticsScenarios.ambush(self)
	print("MEASURE ambush %s" % result)
	assert_true(int(result["entered_tick"]) > 0, "setup: the enemy drove into the kill zone")
	assert_eq(int(result["shots_before"]), 0, "not one shot before it was in the kill zone")
	assert_true(int(result["sprung_tick"]) >= int(result["entered_tick"]), "sprung when it arrived, not before")
	assert_true(int(result["shots_after"]) > 0, "and then every gun fired")
	# The lead: facing matters "for trying to emplace units in an ambush".
	assert_true(int(result["facing_zone"]) >= 3, "the ambush points at its kill zone (%d of 4 facing it)" % result["facing_zone"])


func test_a_cpu_army_under_the_same_orders_is_not_re_ordered_for_fighting_from_its_slots() -> void:
	# Its idle units fight from within their slot's leash (round 4 X1); before round 6's fix the leaders re-sent every
	# one that stopped short, over and over: 43 orders in the last 10 s of this scenario.
	var result: Dictionary = await TacticsScenarios.five_squads(self, false)
	print("MEASURE five_squads cpu %s" % result)
	assert_true(int(result["idle_orders"]) <= 2, "the leaders leave them to it (%d orders in the last 10 s)" % result["idle_orders"])
	for off: float in result["anchor_off_m"]:
		assert_true(off < 0.5, "every formation stands on the spot it was sent to (anchor %.1f m off)" % off)
