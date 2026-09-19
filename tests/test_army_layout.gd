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
	var zone := {"center": Vector3(0, 0, 102), "size": Vector2(150, 32)}
	var frame := {"right": Vector3.RIGHT, "forward": Vector3.FORWARD}
	var laid := ArmyLayout.plan(squads, zone, frame)
	assert_eq(laid.size(), 25, "every vehicle has a place")
	var by_squad := {}
	for unit: String in laid:
		var at: Vector3 = laid[unit]["position"]
		(by_squad.get_or_add(laid[unit]["squad"], []) as Array).append(at)
		assert_true(absf(at.x) <= 75.0 and absf(at.z - 102.0) <= 16.0, "%s stands inside the spawn zone (%s)" % [unit, at])
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
