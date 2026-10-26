extends TestCase
## Round 42 (engage E2, C42.2): "IN RANGE" MEANS A CLEAR SHOT. His playtest after round 41 (Locks, seed 49326): a Rat Rod
## under his attack order stood 37 s behind a 20-ft container, 26 m from the Missile Ring, NOT FIRING, because
## `ElementPlan._engage` gave `attack` by distance. The hand-built case: one crew in distance-range with a box between it
## and the target; today it gets `attack` (the `--attack-shot=off` arm, pinned here as the control), under the rule it
## gets a move to a spot with a clear line, toward the enemy, with the target named.

const TARGET := Vector3(0.0, 0.0, -22.0)
## The 20-ft container (arena_kit: 6.06 x 2.59 x 2.44) across the line from the crew to the target, its long side across.
const BOX := {"position": [0.0, -11.0], "size": [6.06, 2.59, 2.44], "rotation_deg": 90.0}


func teardown() -> void:
	ElementPlan.ATTACK_SHOT = false
	super.teardown()


func _table() -> DoctrineTable:
	DoctrineTable.clear_cache()
	var loaded := DoctrineTable.load_table("standard")
	assert_true(loaded.has("table"), "the standard table loads: %s" % loaded.get("error", ""))
	return loaded.get("table")


func _member(name: String, at: Vector3) -> Dictionary:
	# A Rat Rod: the spear's 30 m, effective 24 m, minimum 8 m.
	return {"name": name, "position": at, "forward": Vector3.FORWARD, "role": "scout", "unit": "gang_scout", "speed": 18.0,
			"range": 30.0, "effective_range": 24.0, "preferred_min": 8.0, "sight": 105.0, "health": 1.0, "suppression": 0.0,
			"taking_fire": false}


## `blocked` stands behind the box, 22 m from the target (in the spear's reach, no line); `clear` stands 20 m off to the
## side with a clear line. One Missile Ring at TARGET, seen a while ago (no "sudden" drill), the threat "contact".
func _situation(features: Array = [BOX]) -> Dictionary:
	var map := CoverMap.from_features(features)
	var members: Array = [_member("Green_blocked", Vector3.ZERO), _member("Green_clear", Vector3(-20.0, 0.0, -10.0))]
	var center := Vector3(-10.0, 0.0, -5.0)
	var listed := [{"name": "Rust_1", "position": TARGET, "role": "artillery", "unit": "syn_artillery", "visible": true,
			"age": 200, "distance": TARGET.distance_to(center), "bearing_deg": 0.0, "strength": 380.0, "speed": 0.0,
			"velocity": Vector3.ZERO, "seen_tick": 1000}]
	ElementSituation.shots_into(members, listed, map)
	return {"tick": 1000, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": "Green_clear",
			"members": members, "contacts": listed, "terrain": "open",
			"threat": ElementSituation.threat_from(listed, false), "composition": "light", "strength": 200.0,
			"enemy_strength": 380.0, "taking_fire": false, "arrived": false, "cover_map": map, "lanes": [], "sight": 105.0}


func _state(extra: Dictionary = {}) -> Dictionary:
	var state := {"task": {"verb": "attack", "target": "Rust_1"}, "drill": "", "drill_tick": 0, "drill_point": null,
			"drill_target": "", "drill_why": "", "anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD,
			"seats": {}, "player": true}
	state.merge(extra, true)
	return state


func test_the_shot_read_sees_the_box() -> void:
	var situation := _situation()
	var blocked: Dictionary = situation["members"][0]
	var clear: Dictionary = situation["members"][1]
	assert_eq(blocked["shot"], {"Rust_1": false}, "the crew behind the box has no shot (%s)" % [blocked["shot"]])
	assert_eq(clear["shot"], {"Rust_1": true}, "the crew to the side has one (%s)" % [clear["shot"]])
	var far := _member("Green_far", Vector3(0.0, 0.0, 80.0))
	ElementSituation.shots_into([far], situation["contacts"], situation["cover_map"])
	assert_eq(far["shot"], {}, "a contact beyond the read's reach is not read (%s)" % [far["shot"]])
	assert_true(ElementPlan.has_shot(far, "Rust_1"), "and an unread pair is no refusal")


func test_today_a_crew_behind_a_box_in_distance_range_gets_attack() -> void:
	ElementPlan.ATTACK_SHOT = false
	var plan := ElementPlan.build(_situation(), _state(), _table())
	var order: Dictionary = plan["orders"]["Green_blocked"]
	assert_eq(order["verb"], "attack", "round 41: in distance-range is `attack`, box or no box (%s)" % [order])


func test_under_the_rule_it_is_sent_to_a_spot_with_a_shot() -> void:
	ElementPlan.ATTACK_SHOT = true
	var situation := _situation()
	var plan := ElementPlan.build(situation, _state(), _table())
	var order: Dictionary = plan["orders"]["Green_blocked"]
	assert_eq(order["verb"], "move", "no shot: a move for one (%s)" % [order])
	assert_eq(order["target"], "Rust_1", "naming the target (the gun stays laid on it; the HUD reads carrying out)")
	assert_true(order["to"] is Vector3, "to a spot (%s)" % [order])
	var spot: Vector3 = order["to"]
	var map: CoverMap = situation["cover_map"]
	assert_true(map.clear_line(spot, TARGET), "with a clear line to the target (%s)" % spot)
	assert_true(spot.distance_to(TARGET) <= 24.0 and spot.distance_to(TARGET) >= 8.0,
			"inside the gun's band (%.1f m)" % spot.distance_to(TARGET))
	assert_true(spot.distance_to(TARGET) <= Vector3.ZERO.distance_to(TARGET) + 1.0,
			"toward the enemy, never away (%.1f m of the target, the crew at %.1f)" % [spot.distance_to(TARGET), 22.0])
	assert_true(spot.distance_to(Vector3(-20.0, 0.0, -10.0)) >= FiringPosition.FRIEND_CLEAR_M,
			"not on its friend's spot (%s)" % spot)
	assert_eq(plan["slots"]["Green_blocked"], spot, "the spot is its slot (carried back for hysteresis)")
	var clear: Dictionary = plan["orders"]["Green_clear"]
	assert_eq(clear["verb"], "attack", "the crew with a shot is told to attack (%s)" % [clear])


func test_the_spot_is_kept_while_it_stays_good() -> void:
	ElementPlan.ATTACK_SHOT = true
	var situation := _situation()
	var first := ElementPlan.build(situation, _state(), _table())
	var spot: Vector3 = first["orders"]["Green_blocked"]["to"]
	# Next update: the crew has driven 3 m toward the spot; the best fresh candidate may differ by a metre or two.
	var moved := _situation()
	(moved["members"][0] as Dictionary)["position"] = Vector3.ZERO + (spot - Vector3.ZERO).normalized() * 3.0
	ElementSituation.shots_into(moved["members"], moved["contacts"], moved["cover_map"])
	var second := ElementPlan.build(moved, _state({"issued_slots": {"Green_blocked": spot}}), _table())
	assert_eq(second["orders"]["Green_blocked"]["to"], spot, "the same spot stands (no dither between two spots of equal worth)")


func test_no_spot_in_the_bounded_search_keeps_closing_straight() -> void:
	ElementPlan.ATTACK_SHOT = true
	# A 50 m block round the target: every ring spot is inside it (nowhere to stand), so the search has nothing to offer.
	# (A long wall is not that case: a spot behind it is reachable round its end, and the search offers it.)
	var block := {"position": [0.0, -22.0], "size": [50.0, 3.0, 50.0], "rotation_deg": 0.0}
	var situation := _situation([block])
	var plan := ElementPlan.build(situation, _state(), _table())
	var order: Dictionary = plan["orders"]["Green_blocked"]
	assert_eq(order["verb"], "attack_move", "no spot: the crew keeps closing (%s)" % [order])
	assert_eq(order["target"], "Rust_1", "on the target")


func test_find_is_pure_and_bounded() -> void:
	var map := CoverMap.from_features([BOX])
	var a := FiringPosition.find(map, Vector3.ZERO, TARGET, 24.0, 8.0, [])
	var b := FiringPosition.find(map, Vector3.ZERO, TARGET, 24.0, 8.0, [])
	assert_eq(a, b, "the same inputs give the same spot")
	assert_true(not a.is_empty() and map.clear_line(a["point"], TARGET), "a spot with a line (%s)" % [a])
	var far := FiringPosition.find(map, Vector3(0.0, 0.0, 200.0), TARGET, 24.0, 8.0, [])
	assert_true(far.is_empty(), "nothing within the bounded search from far away (%s)" % [far])
	var taken: Array = []
	for direction: Array in FiringPosition.DIRECTIONS:
		for fraction: float in FiringPosition.RING_FRACTIONS:
			taken.append(TARGET + Vector3(float(direction[0]), 0.0, float(direction[1])) * 24.0 * fraction)
	assert_true(FiringPosition.find(map, Vector3.ZERO, TARGET, 24.0, 8.0, taken).is_empty(),
			"every ring spot held by a friend: none")


## E5: a target the TEAM cannot see (remembered at its last position): the same read on that position, the same move.
func test_a_remembered_target_behind_the_box_gets_the_same_move() -> void:
	ElementPlan.ATTACK_SHOT = true
	var situation := _situation()
	(situation["contacts"][0] as Dictionary)["visible"] = false
	situation["threat"] = ElementSituation.threat_from(situation["contacts"], false)
	var plan := ElementPlan.build(situation, _state(), _table())
	var order: Dictionary = plan["orders"]["Green_blocked"]
	assert_eq(order["verb"], "move", "no line to where it was last seen: a move for one (%s)" % [order])
	assert_eq(order["target"], "Rust_1", "naming it")
	assert_true(order["to"] is Vector3 and (situation["cover_map"] as CoverMap).clear_line(order["to"], TARGET),
			"to a spot that sees that position (%s)" % [order.get("to")])


## E5: a covering crew (`_hold`) fights only what it has a line to; it keeps its spot either way.
func test_a_covering_crew_without_a_line_holds_its_spot() -> void:
	ElementPlan.ATTACK_SHOT = true
	var situation := _situation()
	var plan := {"orders": {}, "slots": {}}
	ElementPlan._hold(plan, situation["members"], situation, Vector3.FORWARD, "test")
	assert_eq(plan["orders"]["Green_blocked"]["verb"], "hold", "behind the box: hold, guns toward the facing (%s)" % [plan["orders"]["Green_blocked"]])
	assert_eq(plan["orders"]["Green_clear"]["verb"], "attack", "with a line: attack (%s)" % [plan["orders"]["Green_clear"]])
	assert_eq(plan["slots"]["Green_blocked"], Vector3.ZERO, "and it keeps its spot")
	ElementPlan.ATTACK_SHOT = false
	plan = {"orders": {}, "slots": {}}
	ElementPlan._hold(plan, situation["members"], situation, Vector3.FORWARD, "test")
	assert_eq(plan["orders"]["Green_blocked"]["verb"], "attack", "OFF: round 41, attack by distance")
