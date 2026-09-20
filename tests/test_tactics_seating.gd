extends TestCase
## Round 9, squad X4 (catalogue A10): who stands in which slot, and how stable that answer is.
##
## `TacticsFormation.seat()` is a pure function, so the two quantities A10 pre-registered can be measured here rather
## than in a match: spurious re-assignments under a small perturbation, and path-crossing assignments on a formation
## change. This file is the BEFORE measurement as well as the after — the MEASURE lines print either way, so the two
## can be compared on the same machine at two commits.
##
## A10's falsifier: **zero path-crossing slot assignments on a formation transition, and spurious re-assignments
## under a small perturbation at 0%.** Plus the number the `fixed` flag was added for in round 7 (a CPU five-squad
## idle-order count of 4-6 → 0), which lives in `test_tactics_scenarios` and must still be 0 without the flag.

## How far a member is nudged for the perturbation test (metres). Small enough that no seating SHOULD change: it is
## a hundredth of a doctrine spacing, and a vehicle's own station-keeping error is many times it.
const NUDGE_M := 0.5
## Seeds for the perturbation sweep. A fixed list, not a random count: the same numbers at every commit.
const SEEDS: Array[int] = [1, 3, 7, 11, 23, 41, 57, 73]


func _members(count: int, at: Array) -> Array:
	var members: Array = []
	for i in count:
		members.append({"name": "Green_%d" % (i + 1), "unit": "tank", "role": "tank", "position": at[i]})
	return members


## `count` members scattered deterministically around the origin by `seed`.
func _scattered(count: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var at: Array = []
	for i in count:
		at.append(Vector3(rng.randf_range(-40.0, 40.0), 0.0, rng.randf_range(-40.0, 40.0)))
	return _members(count, at)


func _seat(members: Array, formation: String, previous := {}, spacing := 14.0) -> Dictionary:
	var shape := TacticsFormation.centered(TacticsFormation.group_offsets(formation, members.size(), spacing))
	var opts := {"policy": "exposure", "spacing": spacing}
	if not previous.is_empty():
		opts["previous"] = previous
	return TacticsFormation.seat(members, shape, Vector3.ZERO, Vector3.FORWARD, opts)


func _nudged(members: Array, by: Vector3) -> Array:
	var moved: Array = []
	for member: Dictionary in members:
		var copy := (member as Dictionary).duplicate()
		copy["position"] = (member["position"] as Vector3) + by
		moved.append(copy)
	return moved


## Every member nudged INDEPENDENTLY, up to `amount` metres in any direction.
##
## THIS IS THE PERTURBATION, and the rigid `_nudged` above is not. Moving every member by one shared vector slides the
## whole element relative to the slots and leaves the members' geometry relative to each other exactly as it was, so
## the assignment it produces is very nearly forced to be the old one. That version of this test reported
## "0 of 384 assignments changed" and I shipped A10 on it; `make check` then failed four tests that perturb members
## independently, two of them in a stream that is not mine. What a vehicle actually does is drift on its own -- the
## measured CPU station-keeping error is 9.3 m, per unit, in its own direction -- and that is what has to not re-seat
## anybody. Lesson 164's third coat: a "0 of N" is evidence only once the instrument has been shown able to produce a
## non-zero at all.
func _jittered(members: Array, seed_value: int, amount: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var moved: Array = []
	for member: Dictionary in members:
		var copy := (member as Dictionary).duplicate()
		var at: Vector3 = member["position"]
		moved.append(copy)
		copy["position"] = at + Vector3(rng.randf_range(-amount, amount), 0.0,
				rng.randf_range(-amount, amount))
	return moved


func test_a_small_perturbation_does_not_re_seat_anybody() -> void:
	# The measurement A10 pre-registered: nudge every member half a metre, re-seat, count the changes. A seating that
	# re-shuffles for half a metre re-issues every order behind it, and every new order resets what a brain was doing
	# (the round-3 lesson). This is the number the two hysteresis patches existed to hold down.
	var spurious := 0
	var total := 0
	for seed_value in SEEDS:
		for count in [3, 5, 8]:
			for formation in ["wedge", "line", "column", "vee"]:
				var members := _scattered(count, seed_value + count)
				var first := _seat(members, formation)
				var again := _seat(_jittered(members, seed_value + count, NUDGE_M), formation, first)
				for unit_name: String in first:
					total += 1
					if int(again[unit_name]) != int(first[unit_name]):
						spurious += 1
	print("MEASURE seating_spurious %d of %d assignments changed for a %.1f m nudge (%d cases)" \
			% [spurious, total, NUDGE_M, SEEDS.size() * 3 * 4])
	assert_eq(spurious, 0, "a %.1f m nudge re-seated %d of %d units" % [NUDGE_M, spurious, total])


func test_no_two_units_cross_paths_on_a_formation_change() -> void:
	# The other pre-registered quantity, and it has to be measured on the paths the units actually DRIVE: from where
	# each one is now to the slot it was just given. A minimum-total-distance matching never has two of those
	# crossing (if two did, swapping their ends would be shorter), so every crossing here is evidence that something
	# ABOVE the matching produced it — which, before A10, is a hysteresis rule keeping a seating that is no longer a
	# matching at all. Measuring old-slot-to-new-slot instead would count crossings that are nobody's fault: units
	# are not standing on their old slots, so those segments are not paths anybody drives.
	# THE INCUMBENCY IS CLEARED ON A SHAPE CHANGE, and measuring it any other way measures a case the game cannot
	# produce. `ElementPlan._previous_seating` returns {} whenever the formation NAME or the member COUNT differs from
	# the one the seating was recorded under, so a formation transition always re-solves from scratch. My first version
	# of this test passed `previous` across the transition by hand and reported 8 crossings before A10 and 47 after —
	# both of them measurements of a configuration that does not exist. The fourth instrument defect of the night, and
	# the same class as the other three: the right question asked in a place where the answer could not appear.
	var crossings := 0
	var transitions := 0
	var kept := 0
	for seed_value in SEEDS:
		for count in [3, 5, 8]:
			var members := _scattered(count, seed_value + count)
			for pair in [["column", "line"], ["wedge", "column"], ["line", "wedge"], ["vee", "line"]]:
				var before := _seat(members, String(pair[0]))
				# What the game hands the solver on a shape change: nothing. `before` is computed and deliberately
				# NOT passed, which is what `_previous_seating` does for us in the real path.
				var after := _seat(members, String(pair[1]))
				transitions += 1
				if before.is_empty():
					kept += 1
				crossings += _crossings(members, String(pair[1]), after)
	print("MEASURE seating_crossings %d crossing driving paths over %d formation transitions (incumbency cleared, as the game clears it)" \
			% [crossings, transitions])
	assert_eq(crossings, 0, "%d pairs of units drive across each other on a formation change" % crossings)


## How many pairs of units drive across each other: their paths from where they are to the slot they were given.
func _crossings(members: Array, shape: String, seating: Dictionary, spacing := 14.0) -> int:
	var slots := TacticsFormation.centered(TacticsFormation.group_offsets(shape, members.size(), spacing))
	var at := {}
	for member: Dictionary in members:
		var position: Vector3 = member["position"]
		at[String(member["name"])] = Vector2(position.x, position.z)
	var names: Array = seating.keys()
	names.sort()
	var count := 0
	for a in names.size():
		for b in range(a + 1, names.size()):
			var a_to: Vector2 = slots[int(seating[names[a]])]
			var b_to: Vector2 = slots[int(seating[names[b]])]
			if Geometry2D.segment_intersects_segment(at[names[a]], a_to, at[names[b]], b_to) != null:
				count += 1
	return count


func test_the_seating_is_a_matching_whatever_the_hysteresis_says() -> void:
	# Whatever keeps a seating stable, it must never produce two units in one slot: an assignment that is not a
	# permutation is two vehicles driving to the same place, and no amount of stability is worth that.
	for seed_value in SEEDS:
		var members := _scattered(6, seed_value)
		var first := _seat(members, "wedge")
		var moved := _seat(_nudged(members, Vector3(30.0, 0.0, -20.0)), "line", first)
		for seating: Dictionary in [first, moved]:
			var taken := {}
			for unit_name: String in seating:
				assert_true(not taken.has(int(seating[unit_name])),
						"seed %d: slot %d is taken twice" % [seed_value, int(seating[unit_name])])
				taken[int(seating[unit_name])] = true
			assert_eq(taken.size(), members.size(), "seed %d: every unit has its own slot" % seed_value)


func test_the_leader_keeps_the_point_and_armour_goes_where_the_fire_is() -> void:
	# The cost STRUCTURE that A10 keeps: rule 1 (the leader holds slot 0) and rule 2 (toughness against exposure).
	# Only the solver and the hysteresis change, so these must read the same before and after.
	var at := [Vector3(30, 0, 0), Vector3(-30, 0, 0), Vector3(0, 0, 30)]
	var members := _members(3, at)
	members[1]["unit"] = "scout"
	members[1]["role"] = "scout"
	var shape := TacticsFormation.centered(TacticsFormation.group_offsets("wedge", 3, 14.0))
	var seats := TacticsFormation.seat(members, shape, Vector3.ZERO, Vector3.FORWARD,
			{"policy": "exposure", "leader": "Green_1", "spacing": 14.0})
	assert_eq(int(seats["Green_1"]), 0, "the leader keeps the shape's own point, whatever the driving costs")
	# The scout is the least tough, so it must not take the most exposed of the remaining slots.
	var scout_slot: Vector2 = shape[int(seats["Green_2"])]
	var tank_slot: Vector2 = shape[int(seats["Green_3"])]
	assert_true(TacticsFormation.exposure_of(scout_slot) <= TacticsFormation.exposure_of(tank_slot) + 0.001,
			"the fragile vehicle does not take the more exposed slot (%.1f vs %.1f)" \
			% [TacticsFormation.exposure_of(scout_slot), TacticsFormation.exposure_of(tank_slot)])


func test_seating_is_deterministic_and_independent_of_member_order() -> void:
	# Two peers may iterate their members in different orders; the seating may not depend on it (determinism.md).
	for seed_value in SEEDS:
		var members := _scattered(5, seed_value)
		var reversed_members: Array = members.duplicate()
		reversed_members.reverse()
		var forward := _seat(members, "wedge")
		var backward := _seat(reversed_members, "wedge")
		for unit_name: String in forward:
			assert_eq(int(backward[unit_name]), int(forward[unit_name]),
					"seed %d: %s is seated the same whichever order the members were listed in" \
					% [seed_value, unit_name])


## A10's solver against the reference, on matrices shaped like the ones `seat()` actually builds.
##
## This is the test that would have caught what shipped. `seat()` squares its cost matrix to `max(slots, members)`, and
## a shape routinely has more slots than members (`test_formation_slots::test_the_contract_shape` asserts exactly
## that), so the matrix carries padded MEMBER rows. Those rows were costed at 0.0 for **every** slot, real ones
## included -- under the Hungarian reference an indifferent row is harmless, because it cannot change the minimum. Under
## an auction it is poison: a bidder whose best and second-best are equal raises the price by exactly
## `AUCTION_EPSILON`, so an indifferent row crawls, displacing real members from real slots one epsilon at a time until
## the bid cap trips and the deterministic fallback hands back whatever is left. The failure is invisible in small
## exact-fit cases and certain in big ones, which is why control's eight-vehicle group tests went red and none of mine
## did.
func test_the_auction_finds_what_the_reference_solver_finds() -> void:
	var worse := 0
	var cases := 0
	var gap_total := 0.0
	for seed_value in SEEDS:
		for members in [3, 5, 8]:
			for slots in [members, members + 1, members + 3]:
				cases += 1
				var built := _matrix(members, slots, seed_value)
				var cost: Array = built["cost"]
				var auction := TacticsFormation._auction(built["utility"])
				var reference := TacticsFormation._hungarian(cost)
				var mine := _total(cost, auction)
				var theirs := _total(cost, reference)
				gap_total += mine - theirs
				# The auction is an epsilon-approximation, so it may be worse by at most n * epsilon of utility.
				var slack := float(slots) * float(TacticsFormation.AUCTION_EPSILON) / float(TacticsFormation.UTILITY_SCALE)
				if mine > theirs + slack + 0.001:
					worse += 1
	print("MEASURE seating_solver %d of %d matrices where the auction lost to the reference, total excess %.2f m" \
			% [worse, cases, gap_total])
	assert_eq(worse, 0, "the auction returned a worse assignment than the reference on %d of %d matrices" \
			% [worse, cases])


## A square cost matrix with `members` real rows and `slots` real columns, padded exactly as `seat()` pads it, plus the
## integer utilities the auction is given. Distances stand in for driving cost; the structure is what matters.
func _matrix(members: int, slots: int, seed_value: int) -> Dictionary:
	var n := maxi(members, slots)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 104729 + members * 31 + slots
	var at: Array[Vector2] = []
	for i in members:
		at.append(Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(-40.0, 40.0)))
	var slot_at: Array[Vector2] = []
	for j in slots:
		slot_at.append(Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0)))
	var cost: Array = []
	var utility: Array = []
	for i in n:
		var row := PackedFloat64Array()
		row.resize(n)
		var util := PackedInt64Array()
		util.resize(n)
		for j in n:
			var value: float
			if i >= members:
				# A padded member, costed EXACTLY as `seat()` costs it -- indifferent across every slot, real ones
				# included. Writing what it ought to be here instead is how my first version of this test passed
				# while the bug stood: it compared the two solvers on the matrix I meant to build, not the one the
				# game builds. An instrument that encodes the fix cannot see the defect.
				value = 0.0
			elif j >= slots:
				value = TacticsFormation._PINNED
			else:
				value = at[i].distance_to(slot_at[j])
			row[j] = value
			util[j] = int(round(-value * TacticsFormation.UTILITY_SCALE))
		cost.append(row)
		utility.append(util)
	return {"cost": cost, "utility": utility}


## The true cost of an assignment, counting only the real members' real slots -- padding is bookkeeping, not driving.
func _total(cost: Array, seating: PackedInt32Array) -> float:
	var sum := 0.0
	for i in seating.size():
		var value: float = (cost[i] as PackedFloat64Array)[seating[i]]
		if value < TacticsFormation._PINNED:
			sum += value
	return sum


## `seat()` itself against a brute-force optimum, on the real path, with more slots than members.
##
## Uniform vehicles, so every tier term is zero and the cost is pure driving distance -- which makes the optimum
## enumerable and removes any need for this test to restate the cost function. Restating it is what went wrong in the
## solver test above, twice over. Small counts only, because this is n! by construction.
func test_a_shape_with_room_to_spare_still_seats_everybody_optimally() -> void:
	var worse := 0
	var cases := 0
	var excess := 0.0
	for seed_value in SEEDS:
		for count in [3, 4, 5]:
			for room in [0, 1, 3]:
				cases += 1
				var members := _scattered(count, seed_value + count)
				var shape := TacticsFormation.centered(
						TacticsFormation.group_offsets("line", count + room, 14.0))
				var seating := TacticsFormation.seat(members, shape, Vector3.ZERO, Vector3.FORWARD,
						{"policy": "exposure", "spacing": 14.0})
				var mine := 0.0
				for member: Dictionary in members:
					mine += _drive(member, shape[int(seating[String(member["name"])])])
				var best := _brute_force(members, shape)
				excess += mine - best
				# The auction is an epsilon-approximation BY DESIGN -- its own doc-comment promises within
				# n x AUCTION_EPSILON of optimal, "a quarter of a metre of driving for a five-vehicle element" -- so
				# the property to assert is that bound, not exact optimality. Demanding exact optimality here reported
				# 1 case of 72 at 0.05 m, which is one epsilon, and that is the instrument disagreeing with the
				# contract rather than a defect in the seating.
				var slack := float(shape.size()) * float(TacticsFormation.AUCTION_EPSILON) \
						/ float(TacticsFormation.UTILITY_SCALE)
				if mine > best + slack + 0.001:
					worse += 1
	print("MEASURE seating_room %d of %d cases seated worse than optimal, total excess driving %.2f m" \
			% [worse, cases, excess])
	assert_eq(worse, 0, "%d of %d seatings drove further than necessary when the shape had spare slots" \
			% [worse, cases])


func _drive(member: Dictionary, slot: Vector2) -> float:
	var world := TacticsFormation.to_world(Vector3.ZERO, Vector3.FORWARD, slot)
	var at: Vector3 = member["position"]
	return Vector2(at.x - world.x, at.z - world.z).length()


## The least total driving over every way of putting `members` into distinct slots of `shape`.
func _brute_force(members: Array, shape: Array[Vector2]) -> float:
	var best := INF
	var chosen: Array[int] = []
	best = _search(members, shape, 0, chosen, 0.0, best)
	return best


func _search(members: Array, shape: Array[Vector2], index: int, taken: Array[int], sum: float,
		best: float) -> float:
	if sum >= best:
		return best
	if index >= members.size():
		return sum
	for j in shape.size():
		if taken.has(j):
			continue
		taken.append(j)
		best = _search(members, shape, index + 1, taken, sum + _drive(members[index], shape[j]), best)
		taken.pop_back()
	return best
