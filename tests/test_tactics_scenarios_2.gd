extends TestCase
## The quick subset of the battle-drill scenarios (tests/tactics/tactics_scenarios.gd), so `make check`
## guards the drills that work. The full set, with the measurements, runs faster than real time with
## `make tactics-drills` and `make tactics-measure`.
## Round 30 (brains B7, C30.9): split in two by each test's measured time (builder0, 5272d612, `make scenario-times`:
## 574 s alone, the floor of any shard plan at 5-6 shards); the tests are the same, byte for byte. Its other half:
## tests/test_tactics_scenarios.gd.


func test_an_element_ambushed_at_close_range_assaults_through_it() -> void:
	# The lead: "if a unit gets ambushed, the standard operating procedure is to face the direction of the
	# ambush and charge forward."
	# 22 s, the scenario's own default. The check used 18 until round 6, when the element came through at 18.5 s: nav
	# bisected it (00c99bf4, CP4 before nav: 531 ticks = 17.7 s; 7cce78af, nav's merge: 555 = 18.5 s; every nav mechanism
	# off at once: still 555; round 5's _around_friends sidestep back on alone: 531). The cause is the removal of that
	# overtaking sidestep — followers no longer pass a friend in the same lane, so the column stays a column and reaches
	# the far side 0.8 s later. The assault itself is unchanged (~12.7 s). Not slack: a deliberate behaviour change.
	var result: Dictionary = await TacticsScenarios.near_ambush(self)
	var drills: Array = result["drills"]
	assert_true(drills.has("near_ambush"), "the element recognises a near ambush (ran %s)" % [drills])
	assert_true(drills.has("assault_through"), "and assaults through it (ran %s)" % [drills])
	assert_true(int(result["through_tick"]) > 0, "it actually drove past the ambush position")


func test_a_move_ends_formed_up_on_the_spot_and_stops_issuing() -> void:
	var result: Dictionary = await TacticsScenarios.task_posture(self, "move", 30.0)
	print("MEASURE task_posture %s" % result)
	assert_true(float(result["center_to_point_m"]) <= 8.0, "the element's middle is where it was sent (%.1f m off)"
			% result["center_to_point_m"])
	assert_true(float(result["worst_off_slot_m"]) <= 8.0, "every vehicle is in its slot (worst %.1f m)"
			% result["worst_off_slot_m"])
	assert_true(int(result["orders_last_10s"]) <= 2, "and the leader has stopped re-issuing (%d orders in the last 10 s)"
			% result["orders_last_10s"])


func test_an_attack_closes_into_its_band_and_every_gun_fights() -> void:
	var result: Dictionary = await TacticsScenarios.task_posture(self, "attack", 30.0)
	print("MEASURE task_posture %s" % result)
	assert_true(float(result["closest_m"]) <= 45.0, "the element closes to where its guns count (closest %.0f m)"
			% result["closest_m"])
	assert_true(int(result["shooters"]) >= 3, "and the vehicles fight it, not one of them (%d of 4 fired)" % result["shooters"])


func test_a_hold_stays_where_it_was_told_in_an_all_round_halt() -> void:
	var result: Dictionary = await TacticsScenarios.task_posture(self, "hold", 20.0)
	print("MEASURE task_posture %s" % result)
	assert_true(["herringbone", "coil"].has(String(result["formation"])), "a halt formation (%s)" % result["formation"])
	assert_true(float(result["center_to_point_m"]) <= 8.0, "on the spot it stood on when told (%.1f m off)"
			% result["center_to_point_m"])
	assert_true(int(result["orders_last_10s"]) <= 2, "and settled (%d orders in the last 10 s)" % result["orders_last_10s"])


func test_five_squads_moved_in_quick_succession_go_quiet_on_their_spots() -> void:
	# The lead's sequence (control's squad_orders_playtest, headless): press 1, right-click, press 2, right-click...
	var result: Dictionary = await TacticsScenarios.five_squads(self, true)
	print("MEASURE five_squads players %s" % result)
	assert_true(int(result["idle_orders"]) <= 2, "nobody touching anything, the leaders stop ordering (%d orders in the last 10 s)"
			% result["idle_orders"])
	for off: float in result["anchor_off_m"]:
		assert_true(off < 0.5, "every formation stands on the spot it was sent to (anchor %.1f m off)" % off)
	assert_true(float(result["mean_off_slot_m"]) <= 8.0, "and its vehicles are in their slots (mean %.1f m)"
			% result["mean_off_slot_m"])


func test_attack_move_decisions_measured() -> void:
	# Round 7: a measurement first (the bar comes after the fix, from what it measures).
	var result: Dictionary = await TacticsScenarios.attack_move_decisions(self)
	print("MEASURE attack_move_decisions %s" % result)
	assert_true(float(result["unit_minutes"]) > 3.0, "setup: six units fought for most of a minute")
