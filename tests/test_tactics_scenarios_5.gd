extends TestCase
## The quick subset of the battle-drill scenarios (tests/tactics/tactics_scenarios.gd), so `make check`
## guards the drills that work. The full set, with the measurements, runs faster than real time with
## `make tactics-drills` and `make tactics-measure`.
## Round 30 (brains B7, C30.9): split in two by each test's measured time (builder0, 5272d612, `make scenario-times`:
## 574 s alone, the floor of any shard plan at 5-6 shards); the tests are the same, byte for byte. Its other half:
## tests/test_tactics_scenarios_2.gd.
## Round 31 (C31.9 / R31.9): part of test_tactics_scenarios.gd, split by measured time (98 s alone); the same test.


func test_an_element_travels_in_formation_on_the_way() -> void:
	# The lead: "a formula to form up" — the visible half is holding the shape while travelling, not only at the end.
	# RE-SPECIFIED (round 12). The lead, playing 2026-09-26: *"they all split apart and navigated their own way to the
	# destination"*. Round 10 had made that true: its least-driving seating rarely puts the leader at the front, and
	# the round-7 flow only ran when it did, so a plain move had NO shape in transit. The travelling anchor (ElementPlan's
	# TRANSIT block) replaces the flow on this path. The measure is unchanged — each member's distance from its place
	# around the leader while the squad is on the way — and the control arm is round 10's shipped path, transit off.
	var travelling: Dictionary = await TacticsScenarios.element_transit(self, true)
	var snapping: Dictionary = await TacticsScenarios.element_transit(self, true, 40.0, false, false)
	print("MEASURE element_transit travelling %s; round-10 path %s" % [travelling, snapping])
	assert_true(float(travelling["transit_gap_m"]) < float(snapping["transit_gap_m"]),
			"on the way, members hold their places around the leader tighter than when each drove its own route (%.1f m vs %.1f m)"
			% [travelling["transit_gap_m"], snapping["transit_gap_m"]])
	assert_true(int(travelling["samples"]) > 0, "setup: the squad was measured while travelling")
	assert_true(float(travelling["arrived_s"]) > 0.0, "and it still gets there (%.1f s)" % travelling["arrived_s"])
	assert_true(float(travelling["worst_off_slot_m"]) <= 8.0, "formed up on the spot (worst %.1f m)" % travelling["worst_off_slot_m"])
	assert_true(int(travelling["orders_last_10s"]) <= 2, "and quiet after (%d orders in the last 10 s)" % travelling["orders_last_10s"])
