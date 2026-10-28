extends TestCase
## R43.11 (round 43, native N2b): SelectionSquads.untangle_whole memoises its crossing counts (the 30-unit click spent 247 of
## 260 ms in them: a six-squad column tries 720 permutations of its places, each re-running _pair_crosses). The contract is
## OUTPUT-IDENTICAL: the same places to the same squads for every click. `_reference` below is the function as it stood
## before the memo (b31d3ddea), verbatim but for its counters; the memoised one must give the same anchors, the same return
## and the same counters on every knot: random ones (2-6 squads, 1-5 crews, shared points and collinear drives included) and
## each optional reading (leads + arc, misplaced).

static var _ref_still_crossed := 0
static var _ref_swapped := 0


static func _reference(squads: Array, anchors: Array[Vector3], position: Callable, leads: Array = [],
		arc := Callable(), misplaced := Callable()) -> int:
	var by_lead := leads.size() == squads.size() and arc.is_valid()
	var starts := {}
	for i in squads.size():
		for unit_name: String in squads[i]["units"]:
			var p: Vector3 = position.call(unit_name)
			starts[unit_name] = Vector3(p.x, 0.0, p.z)
	var family: Array[int] = []
	for i in squads.size():
		family.append(i)
	for i in squads.size():
		for j in range(i + 1, squads.size()):
			if SelectionSquads._root(family, i) != SelectionSquads._root(family, j) and (by_lead or SelectionSquads._pair_crosses(squads[i]["units"], anchors[i], squads[j]["units"], anchors[j], starts) > 0):
				family[SelectionSquads._root(family, i)] = SelectionSquads._root(family, j)
	var groups := {}
	for i in squads.size():
		var root := SelectionSquads._root(family, i)
		if not groups.has(root):
			groups[root] = []
		(groups[root] as Array).append(i)
	var moved := 0
	for members: Array in groups.values():
		if members.size() < 2:
			continue
		var places: Array[Vector3] = []
		var place_arcs: Array = []
		var member_leads: Array = []
		for i: int in members:
			places.append(anchors[i])
			if by_lead:
				place_arcs.append(float(arc.call(anchors[i])))
				member_leads.append(float(leads[i]))
		var best: Array = []
		var best_key := [INF, INF, INF]
		var best_wrong := INF
		for perm: Array in SelectionSquads._permutations(members.size()):
			var wrong := 0
			if misplaced.is_valid():
				for a in members.size():
					if bool(misplaced.call(members[a], places[perm[a]])):
						wrong += 1
				if wrong > best_wrong:
					continue
			var breaks := 0
			if by_lead:
				var arcs: Array = []
				for a in members.size():
					arcs.append(place_arcs[perm[a]])
				breaks = SelectionSquads.lead_breaks(member_leads, arcs)
				if wrong == best_wrong and breaks > best_key[0]:
					continue
			var crossings := 0
			var drive := 0.0
			for a in members.size():
				var at: Vector3 = places[perm[a]]
				for unit_name: String in squads[members[a]]["units"]:
					drive += SelectionSquads._xz(starts[unit_name]).distance_to(SelectionSquads._xz(at))
				for b in range(a + 1, members.size()):
					crossings += SelectionSquads._pair_crosses(squads[members[a]]["units"], at, squads[members[b]]["units"], places[perm[b]], starts)
			if wrong < best_wrong or breaks < best_key[0] or (breaks == best_key[0] and (crossings < best_key[1]
					or (crossings == best_key[1] and drive < best_key[2] - 0.01))):
				best_wrong = wrong
				best_key = [breaks, crossings, drive]
				best = perm
		if best_key[1] > 0:
			_ref_still_crossed += 1
		for a in members.size():
			if int(best[a]) != a:
				moved += 1
			anchors[members[a]] = places[best[a]]
	_ref_swapped += moved
	return moved


static func _knot(rng: RandomNumberGenerator, squads_n: int, crowded: bool) -> Dictionary:
	var squads: Array = []
	var positions := {}
	var anchors: Array[Vector3] = []
	var grid := 4.0 if crowded else 0.0  # crowded: points on a coarse grid, so drives share ends and run collinear
	for i in squads_n:
		var units: Array = []
		for k in rng.randi_range(1, 5):
			var unit_name := "U%d_%d" % [i, k]
			var p := Vector3(rng.randf_range(-60.0, 60.0), 0.0, rng.randf_range(-60.0, 60.0))
			if crowded:
				p = Vector3(snappedf(p.x, grid * 4.0), 0.0, snappedf(p.z, grid * 4.0))
			positions[unit_name] = p
			units.append(unit_name)
		squads.append({"number": i + 1, "units": units})
		var at := Vector3(rng.randf_range(-60.0, 60.0), 0.0, rng.randf_range(-60.0, 60.0))
		if crowded:
			at = Vector3(snappedf(at.x, grid * 4.0), 0.0, snappedf(at.z, grid * 4.0))
		anchors.append(at)
	return {"squads": squads, "positions": positions, "anchors": anchors}


func test_the_memoised_untangle_gives_the_reference_places_on_every_knot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 43011
	var knots := 0
	var moved_any := 0
	for trial in 1500:
		var squads_n := 2 + trial % 5  # 2..6
		var knot := _knot(rng, squads_n, trial % 3 == 0)
		var position := func(n: String) -> Vector3: return knot["positions"][n]
		var leads: Array = []
		var arc := Callable()
		var misplaced := Callable()
		if trial % 4 == 1 or trial % 4 == 3:
			for i in squads_n:
				leads.append(snappedf(rng.randf_range(0.0, 80.0), 5.0 if trial % 8 == 1 else 0.001))
			arc = func(p: Vector3) -> float: return snappedf(p.length(), 5.0)
		if trial % 4 >= 2:
			var side := rng.randf_range(-1.0, 1.0)
			misplaced = func(i: int, p: Vector3) -> bool: return (i % 2 == 0) != (p.x > side * 30.0)
		var mine: Array[Vector3] = (knot["anchors"] as Array[Vector3]).duplicate()
		var theirs: Array[Vector3] = (knot["anchors"] as Array[Vector3]).duplicate()
		var still_before := SelectionSquads.whole_still_crossed
		var swapped_before := SelectionSquads.swapped_whole
		_ref_still_crossed = 0
		_ref_swapped = 0
		var got := SelectionSquads.untangle_whole(knot["squads"], mine, position, leads, arc, misplaced)
		var want := _reference(knot["squads"], theirs, position, leads, arc, misplaced)
		knots += 1
		moved_any += int(want > 0)
		if mine != theirs or got != want or SelectionSquads.whole_still_crossed - still_before != _ref_still_crossed \
				or SelectionSquads.swapped_whole - swapped_before != _ref_swapped:
			assert_true(false, "trial %d (%d squads): places %s v %s, moved %d v %d" % [trial, squads_n, mine, theirs, got, want])
			return
	assert_eq(knots, 1500, "every knot compared")
	assert_true(moved_any > 300, "the comparison exercised re-dealt places (%d of 1500 knots moved)" % moved_any)
