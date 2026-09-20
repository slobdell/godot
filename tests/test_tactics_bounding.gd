extends TestCase
## Round 9, squad X3 (catalogue A9): bounding overwatch as an EXPLICIT two-phase machine, and time-synchronised
## co-arrival off one bottleneck.
##
## Before round 9 "bounding overwatch" was a technique name and a boolean: `bounding` said which half had the current
## leg, the halves swapped whenever the movers closed up, and nothing guaranteed that anybody was stationary or that
## a phase lasted long enough for a spectator to see it. The lead's standing complaint is that base-of-fire-and-
## manoeuvre is not legible, and this is the row that buys it.
##
## A9's falsifier is ">= 50% of squad firepower stationary at every tick". Two alternating halves of an ODD-sized
## element cannot meet it (ceil(n/2) moving leaves floor(n/2) still: 2 of 5 = 40%), so an odd-sized element leaves a
## permanent BASE OF FIRE and bounds the rest in two equal teams. These tests assert that structure directly, which
## is what makes the falsifier hold by construction rather than by a run that happens to pass.


func _table(faction := "standard") -> DoctrineTable:
	DoctrineTable.clear_cache()
	var loaded := DoctrineTable.load_table(faction)
	assert_true(loaded.has("table"), "the %s table loads: %s" % [faction, loaded.get("error", "")])
	return loaded.get("table")


func _members(count: int, roles: Array = []) -> Array:
	var members: Array = []
	for i in count:
		var role := String(roles[i]) if i < roles.size() else "tank"
		members.append({"name": "Green_%d" % (i + 1), "position": Vector3(i * 10.0 - count * 5.0, 0.0, 0.0),
				"forward": Vector3.FORWARD, "role": role, "unit": "tank", "speed": 9.0, "range": 90.0,
				"effective_range": 70.0, "sight": 90.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	return members


func _situation(count: int, tick: int, roles: Array = []) -> Dictionary:
	var members := _members(count, roles)
	var center := Vector3.ZERO
	for member: Dictionary in members:
		center += member["position"] as Vector3
	center /= float(maxi(members.size(), 1))
	return {"tick": tick, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": "Green_1",
			"members": members, "contacts": [], "terrain": "open", "threat": "possible", "composition": "heavy",
			"strength": 800.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": false}


func _state(extra: Dictionary = {}) -> Dictionary:
	var state := {"task": {"verb": "move", "to": [0.0, -240.0]}, "drill": "", "drill_tick": 0, "drill_point": null,
			"drill_target": "", "drill_why": "", "anchor": null, "bounding": 0, "arrived": false,
			"heading": Vector3.FORWARD, "seats": {}, "technique": "bounding_overwatch", "bound": {}}
	state.merge(extra, true)
	return state


## A bounding plan, forced by asking the table for a technique it will not pick on its own.
func _bound(count: int, tick: int, carried: Dictionary = {}, roles: Array = []) -> Dictionary:
	var table := _table()
	var situation := _situation(count, tick, roles)
	var plan := {"formation": "wedge", "technique": "bounding_overwatch", "drill": "", "why": "",
			"anchor": carried.get("anchor"), "heading": Vector3.FORWARD, "bounding": 0, "arrived": false,
			"orders": {}, "slots": {}, "sectors": {}, "seats": {}, "leader": "Green_1", "previous_seats": {},
			"route": [], "route_index": 0, "corridor_m": INF, "file": 0.0, "bound": {}}
	var state := _state(carried)
	ElementPlan._plan_bounding(plan, situation, state, table, ElementPlan.slot_order(situation),
			Vector3(0, 0, -240), Vector3.FORWARD, table.spacing("open"), "attack_move")
	return plan


func test_an_odd_sized_element_leaves_a_base_of_fire_and_bounds_two_equal_teams() -> void:
	# The shape the falsifier forces. Five vehicles: 1 + 2 + 2, and the base is the vehicle worth most standing
	# still -- the most protected role, which slot_order puts last.
	var situation := _situation(5, 100, ["tank", "tank", "tank", "tank", "artillery"])
	var split := ElementPlan.bound_teams(ElementPlan.slot_order(situation))
	assert_eq((split["teams"][0] as Array).size(), 2, "two vehicles in the first team")
	assert_eq((split["teams"][1] as Array).size(), 2, "two in the second")
	assert_eq((split["base"] as Array).size(), 1, "and one permanent base of fire")
	assert_eq(String((split["base"] as Array)[0]["role"]), "artillery",
			"the base is the gun worth most from a static position, not whoever happened to be last")


func test_at_least_half_the_element_is_stationary_in_every_phase() -> void:
	# A9's falsifier, asserted for every squad size a doctrine can field rather than measured once.
	for count in range(2, 9):
		var split := ElementPlan.bound_teams(_members(count))
		var base: int = (split["base"] as Array).size()
		for phase in 2:
			var moving: int = (split["teams"][phase] as Array).size()
			var still: int = count - moving
			assert_true(float(still) / float(count) >= 0.5,
					"%d vehicles, phase %d: %d of %d stationary (base %d)" % [count, phase, still, count, base])


func test_a_single_vehicle_does_not_bound() -> void:
	var split := ElementPlan.bound_teams(_members(1))
	assert_true((split["teams"][0] as Array).is_empty() and (split["teams"][1] as Array).is_empty(),
			"one vehicle has nobody to cover it")
	assert_eq((split["base"] as Array).size(), 1, "it is its own base of fire")
	var plan := _bound(1, 100)
	assert_eq(plan["bound"], {}, "and the plan says it is not bounding rather than pretending to")
	assert_eq((plan["orders"] as Dictionary).size(), 1, "it still gets its order")


func test_a_phase_lasts_between_five_and_eight_seconds() -> void:
	# The minimum stops a shimmer when both teams close up at once; the maximum stops a team that never closes up
	# from parking the element. Both are why a spectator can see the alternation at all.
	var first := _bound(5, 1000)
	var phase: int = int((first["bound"] as Dictionary)["phase"])
	var since: int = int((first["bound"] as Dictionary)["since_tick"])
	# One tick later, with the movers standing right on their anchor: too early to swap.
	var early := _bound(5, 1000 + ElementPlan.BOUND_MIN_TICKS - 2,
			{"anchor": first["anchor"], "bound": first["bound"], "bounding": phase})
	assert_eq(int((early["bound"] as Dictionary)["phase"]), phase,
			"a phase younger than BOUND_MIN does not hand over, even standing on its anchor")
	# Past the maximum it hands over whatever the movers are doing.
	var late := _bound(5, 1000 + ElementPlan.BOUND_MAX_TICKS + 1,
			{"anchor": first["anchor"], "bound": first["bound"], "bounding": phase})
	assert_eq(int((late["bound"] as Dictionary)["phase"]), 1 - phase,
			"a phase older than BOUND_MAX hands over whatever happened, so a stuck team cannot park the element")
	assert_true(int((late["bound"] as Dictionary)["since_tick"]) > since, "and the new phase starts its own clock")


func test_the_covering_team_is_ordered_to_stand_and_the_moving_team_to_move() -> void:
	var plan := _bound(5, 1000)
	var bound: Dictionary = plan["bound"]
	assert_true(not (bound as Dictionary).is_empty(), "a five-vehicle element bounds")
	var movers: PackedStringArray = bound["movers"]
	var overwatch: PackedStringArray = bound["overwatch"]
	assert_eq(movers.size() + overwatch.size(), 5, "every vehicle is in one phase or the other")
	assert_true(float(bound["stationary_share"]) >= 0.5,
			"the phase reports its own stationary share (%s)" % bound["stationary_share"])
	for unit_name in movers:
		assert_true(String((plan["orders"][unit_name] as Dictionary)["verb"]) in ["move", "attack_move"],
				"%s is bounding, so it is told to move" % unit_name)
	for unit_name in overwatch:
		var verb := String((plan["orders"][unit_name] as Dictionary)["verb"])
		assert_true(verb in ["hold", "attack"], "%s is covering, so it holds or shoots (%s)" % [unit_name, verb])
	for unit_name in bound["base"]:
		assert_true(overwatch.has(unit_name), "%s is the base of fire, so it covers in this phase too" % unit_name)


func test_the_base_of_fire_covers_in_both_phases() -> void:
	var first := _bound(5, 1000)
	var base: PackedStringArray = (first["bound"] as Dictionary)["base"]
	assert_eq(base.size(), 1, "a five-vehicle element has one")
	var second := _bound(5, 1000 + ElementPlan.BOUND_MAX_TICKS + 1,
			{"anchor": first["anchor"], "bound": first["bound"], "bounding": int((first["bound"] as Dictionary)["phase"])})
	assert_true(int((second["bound"] as Dictionary)["phase"]) != int((first["bound"] as Dictionary)["phase"]),
			"the phase changed")
	for unit_name in base:
		assert_true((second["bound"] as Dictionary)["overwatch"].has(unit_name),
				"%s is still covering after the hand-over: that is what makes it a BASE of fire" % unit_name)
		assert_true(String((second["orders"][unit_name] as Dictionary)["verb"]) in ["hold", "attack"],
				"%s is ordered to stand in both phases" % unit_name)


func test_the_bottleneck_is_a_tick_count_and_the_laggard_drives_flat_out() -> void:
	# A9's co-arrival: one bottleneck, expressed in TICKS (Invariant 7), and every member paced by its share of it --
	# the leader included, which is what replaced Element._pace_leader_for_flow's separate heuristic.
	var etas := {"A": 4.0, "B": 8.0, "C": 12.0}
	assert_eq(FormUp.bottleneck_ticks(etas), FormUp.ticks_of(12.0), "the bottleneck is the worst member's, in ticks")
	assert_eq(FormUp.ticks_of(0.0), 0, "nothing to drive is no ticks")
	assert_true(FormUp.ticks_of(0.001) >= 1, "any part of a tick is a whole tick")
	assert_eq(FormUp.bottleneck_ticks({}), 0, "an element with nobody moving has no bottleneck")
	# The ratio is of integers, so the same ETAs give the same paces however the floats were summed.
	var ratio := float(FormUp.ticks_of(4.0)) / float(FormUp.ticks_of(12.0))
	assert_near(ratio, 1.0 / 3.0, 0.01, "a member a third of the way out drives at a third of its speed")


func test_the_pace_never_slows_a_units_first_response_to_an_order() -> void:
	# The K1 guarantee is about the FIRST response; co-arrival slows the cruise. A member within PACE_NEAR of its
	# slot -- and the laggard itself -- drive flat out, so nothing here can stall a unit that has just been ordered.
	assert_near(TacticsFormation.pace(TacticsFormation.PACE_NEAR - 0.1, 9.0, 30.0), 1.0, 0.001,
			"a unit already at its slot is not paced at all")
	assert_true(TacticsFormation.pace(200.0, 9.0, 30.0) >= TacticsFormation.PACE_FLOOR,
			"and nobody is ever paced below the floor")
