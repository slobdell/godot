extends TestCase
## The army starts as an army (round 6, the lead): *"the units should start out like an army where there actually is a
## starting formation where each squad is separated."* Squads stand side by side across their spawn zone, each in its own
## formation, facing the enemy — laid out by ArmyLayout when Match.load_doctrine spawns them.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


static func _centroid(points: Array) -> Vector3:
	var sum := Vector3.ZERO
	for point: Vector3 in points:
		sum += point
	return sum / maxf(points.size(), 1.0)


## Each squad's positions; asserts the squads are separate (every gap between two squads' nearest vehicles is wider than
## any vehicle's distance from its own squad's centre... of its NEAREST squad-mate).
func _assert_separated(by_squad: Dictionary, why: String) -> void:
	var names: Array = by_squad.keys()
	for a in names.size():
		for b in range(a + 1, names.size()):
			var closest_between := INF
			for p: Vector3 in by_squad[names[a]]:
				for q: Vector3 in by_squad[names[b]]:
					closest_between = minf(closest_between, Vector2(p.x - q.x, p.z - q.z).length())
			var widest_within := 0.0
			for group: String in [names[a], names[b]]:
				var points: Array = by_squad[group]
				for i in points.size():
					var nearest := INF
					for j in points.size():
						if i != j:
							nearest = minf(nearest, (points[i] as Vector3).distance_to(points[j]))
					if is_finite(nearest):
						widest_within = maxf(widest_within, nearest)
			assert_true(closest_between > widest_within,
					"%s: %s and %s are separate squads (%.1f m apart at their closest; a vehicle's nearest squad-mate is at most %.1f m)"
					% [why, names[a], names[b], closest_between, widest_within])


func test_the_plan_puts_squads_side_by_side_in_formation_facing_the_enemy() -> void:
	var squads: Array = []
	for s in 5:
		var members: Array = []
		for i in 5:
			members.append({"name": "S%d_%d" % [s, i], "unit": "tank"})
		squads.append({"name": "S%d" % s, "members": members, "leader": "S%d_0" % s})
	# The zone is as wide as five wedges of THESE hulls need, derived from the live floor (round 10: the lateral floor
	# is the hull's diagonal + DRESS_MARGIN_M, 10.42 m for the CP3 bus, so five 5-bus wedges need ~210 m; the literal
	# 150 m zone this test used made them stack in ranks, which is the case the next test covers).
	var wedge := 4.0 * TacticsFormation.hull_floor([{"unit": "tank"}]).x + 10.0
	var zone := {"center": Vector3(0, 0, 102), "size": Vector2(5.0 * wedge, 32)}
	var frame := {"right": Vector3.RIGHT, "forward": Vector3.FORWARD}
	var laid := ArmyLayout.plan(squads, zone, frame)
	assert_eq(laid.size(), 25, "every vehicle has a place")
	var by_squad := {}
	for unit: String in laid:
		var at: Vector3 = laid[unit]["position"]
		(by_squad.get_or_add(laid[unit]["squad"], []) as Array).append(at)
		assert_true(absf(at.x) <= 2.5 * wedge and absf(at.z - 102.0) <= 16.0, "%s stands inside the spawn zone (%s)" % [unit, at])
		assert_true((laid[unit]["facing"] as Vector3).is_equal_approx(Vector3.FORWARD), "%s faces the enemy" % unit)
	_assert_separated(by_squad, "plan")
	# Left to right in the order given.
	var xs: Array = []
	for s in 5:
		xs.append(_centroid(by_squad["S%d" % s]).x)
	for s in range(1, 5):
		assert_true(xs[s] > xs[s - 1], "the squads stand in order across the front")
	# The leader is the point of its wedge: nearest the enemy in its squad.
	for s in 5:
		var lead: Vector3 = laid["S%d_0" % s]["position"]
		for p: Vector3 in by_squad["S%d" % s]:
			assert_true(lead.z <= p.z + 0.01, "S%d's leader leads its wedge" % s)


func test_a_match_spawns_its_squads_as_an_army() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	var squads: Array = []
	for s in ["Alpha", "Bravo", "Charlie", "Delta", "Echo"]:
		squads.append({"name": s, "units": [{"unit": "tank"}, {"unit": "ifv"}, {"unit": "scout"}, {"unit": "tank"}]})
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "Army", "squads": squads}), "", "setup: the army loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, {"name": "Army", "squads": squads}), "", "setup: and the enemy's")
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		var by_squad := {}
		var forward: Vector3 = Match.team_frame(team)["forward"]
		for tank in game_match.sorted_team_tanks(team):
			(by_squad.get_or_add(game_match.squad_of(tank), []) as Array).append(tank.global_position)
			assert_true((-tank.global_basis.z).dot(forward) > 0.99, "%s faces the enemy" % tank.name)
		assert_eq(by_squad.size(), 5, "five squads")
		_assert_separated(by_squad, Match.TEAM_NAMES[team])


func test_a_rotated_neighbour_is_measured_on_its_own_axes() -> void:
	# Round 9 item 3 (squad): `_is_clear` projected every placed hull onto the DEPLOY frame's axes, sound only while all
	# of them share it. A neighbour turned 90 degrees (an arena whose spawn zones are not opposed, or the other team's
	# hull) is 8.6 m long across our heading, not 2.4 m wide. Here: our tank at the origin facing -Z, a tank 6 m to the
	# right facing +X. Its nose reaches x = 1.7; our flank is at x = 1.2, so 0.5 m apart, under STAND_CLEAR_M.
	var hull := Vector2(2.4, 8.6)
	var rotated := [[Vector3(6.0, 0.0, 0.0), 2.4, 8.6, Vector3(1.0, 0.0, 0.0)]]
	assert_true(not ArmyLayout._is_clear(Vector3.ZERO, hull, Vector3.FORWARD, rotated),
			"a neighbour turned 90 degrees is measured along its own length, and 0.5 m is not clear")
	var aligned := [[Vector3(6.0, 0.0, 0.0), 2.4, 8.6, Vector3.FORWARD]]
	assert_true(ArmyLayout._is_clear(Vector3.ZERO, hull, Vector3.FORWARD, aligned),
			"the same neighbour facing our way stands 3.6 m clear, as before")
	var legacy := [[Vector3(6.0, 0.0, 0.0), 2.4, 8.6]]
	assert_true(ArmyLayout._is_clear(Vector3.ZERO, hull, Vector3.FORWARD, legacy),
			"an entry without its own forward shares ours (the old three-field form)")
	var nose_to_tail := [[Vector3(0.0, 0.0, -9.0), 2.4, 8.6, Vector3.FORWARD]]
	assert_true(not ArmyLayout._is_clear(Vector3.ZERO, hull, Vector3.FORWARD, nose_to_tail),
			"nose to tail 0.4 m apart is not clear, aligned or not")



func test_an_army_too_wide_for_its_zone_stands_in_ranks_each_in_order() -> void:
	# The same five squads of five buses in a 150 m zone: at the diagonal pitch they cannot stand abreast (measured
	# 69c681ac + the pitch: three squads in a front rank, two behind). What must still hold: nobody overlaps, and each
	# rank stands in the order given, left to right.
	var squads: Array = []
	for s in 5:
		var members: Array = []
		for i in 5:
			members.append({"name": "S%d_%d" % [s, i], "unit": "tank"})
		squads.append({"name": "S%d" % s, "members": members, "leader": "S%d_0" % s})
	var laid := ArmyLayout.plan(squads, {"center": Vector3(0, 0, 102), "size": Vector2(150, 32)},
			{"right": Vector3.RIGHT, "forward": Vector3.FORWARD})
	assert_eq(laid.size(), 25, "every vehicle has a place")
	var by_squad := {}
	for unit: String in laid:
		(by_squad.get_or_add(laid[unit]["squad"], []) as Array).append(laid[unit]["position"])
	_assert_separated(by_squad, "ranks")
	var ranks := {}
	for s in 5:
		var c := _centroid(by_squad["S%d" % s])
		(ranks.get_or_add(snappedf(c.z, 5.0), []) as Array).append([s, c.x])
	print("MEASURE army_ranks %s" % str(ranks))
	for z: float in ranks:
		var rank: Array = ranks[z]
		for i in range(1, rank.size()):
			assert_true(float(rank[i][1]) > float(rank[i - 1][1]), "rank at z %.0f stands in the order given" % z)
