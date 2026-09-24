extends TestCase
## Round 11 (nav R2, the lead: *"in terminus when I tell a squad to go to a point, it appears as though a unit's target
## position ends up inside of a building"*). The assertion is on the ISSUED goal, never on where the unit ends up: a
## goal inside a solid cannot be arrived at, whatever the driver does, so this is measured apart from the driver (R1).
##
## The oracle is the layout's own colliders (`Arena.active["obstacles"]`, every colliding prop with its size), NOT the
## navmesh the fix grounds on, so the test cannot agree with a wrong answer by construction. A goal is good when the
## hull's turning envelope (half its diagonal, from the catalogue) clears every collider — minus `SLACK_M`, the
## grounding's own tolerance — and no two crews of one order share a spot.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## A mixed squad with the War Rig (the longest hull: 14 m, envelope ~7.2 m) in it.
const ROSTER := ["gang_tank", "tank", "ifv", "scout", "lancer", "artillery"]
## The click: the ring road, 4 m off the north face of the (40, 0) city block, with the (30, 62) block across the road.
const CLICK := Vector2(45.0, 24.0)
## Where the squad starts: the ring road west of the plaza, so the travel (and the formation's frame) runs east.
const START := Vector3(-20.0, 0.0, 31.0)
## The grounding call's own tolerance (SlotGround.TOLERANCE_M), plus the 8-probe polygon's shortfall at a corner.
const SLACK_M := 1.5


func _terminus() -> Arena:
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = "terminus"
	add_to_tree(arena)
	for i in 120:
		await tree.physics_frame
		if TacticsLab.navigation_is_this_arenas(arena):
			break
	assert_true(TacticsLab.navigation_is_this_arenas(arena), "setup: the navmesh is the Terminus'")
	assert_eq(String(Arena.active.get("name", "")), "terminus", "setup: the Terminus layout (lesson 80)")
	return arena


func _squad(formation := "") -> Match:
	var game_match := MATCH.instantiate() as Match
	add_to_tree(game_match)
	var squad := {"name": "A", "units": ROSTER.map(func(unit: String) -> Dictionary: return {"unit": unit})}
	if formation != "":
		squad["formation"] = formation
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "T", "squads": [squad]}), "", "setup: the squad")
	var i := 0
	for tank: Tank in game_match.tanks.get_children():
		tank.global_position = START + Vector3(-float(i) * 16.0, 0.0, 0.0)
		tank.rotation.y = -PI / 2.0  # nose east (-Z is forward)
		tank.reset_physics_interpolation()
		i += 1
	return game_match


## How far `goal` is from the nearest collider in the layout (0 inside one), and which.
static func _clearance(goal: Vector3) -> Array:
	var best := INF
	var which := ""
	for obstacle: Dictionary in Arena.active["obstacles"]:
		var size := Arena.obstacle_size(obstacle)
		var d := ArenaKit.distance_to_footprint(Vector2(goal.x, goal.z),
				Vector2(float(obstacle["position"][0]), float(obstacle["position"][1])), size, float(obstacle.get("rotation_deg", 0.0)))
		if d < best:
			best = d
			which = "%s@%s" % [obstacle.get("type", "?"), obstacle["position"]]
	return [best, which]


## Every goal clears its own hull's envelope, and no two goals overlap (side by side at least).
func _assert_goals(goals: Dictionary, units: Dictionary, what: String) -> void:
	assert_eq(goals.size(), ROSTER.size(), "%s: every crew was given a goal" % what)
	for unit_name: String in goals:
		var goal: Vector3 = goals[unit_name]
		var unit_id: String = units[unit_name]
		var need := SlotGround.envelope_of(unit_id) - SLACK_M
		var found: Array = _clearance(goal)
		assert_true(float(found[0]) >= need, "%s: %s (%s) goal %s clears its hull: %.2f m from %s, needs %.2f" %
				[what, unit_name, unit_id, goal, found[0], found[1], need])
	var names := goals.keys()
	for a in names.size():
		for b in range(a + 1, names.size()):
			var width_a: float = float((Units.stat(units[names[a]], "hull_size", [0, 0, 0]) as Array)[0])
			var width_b: float = float((Units.stat(units[names[b]], "hull_size", [0, 0, 0]) as Array)[0])
			var apart := Vector2(goals[names[a]].x - goals[names[b]].x, goals[names[a]].z - goals[names[b]].z).length()
			assert_true(apart >= 0.5 * (width_a + width_b), "%s: %s and %s are given spots %.2f m apart, less than side by side (%.2f)" %
					[what, names[a], names[b], apart, 0.5 * (width_a + width_b)])


func _ids(game_match: Match) -> Dictionary:
	var ids := {}
	for tank: Tank in game_match.tanks.get_children():
		ids[String(tank.name)] = tank.unit_id
	return ids


## The player's right-click, and the same order from every other source that issues a move (a script, the agent
## bridge, anything without `source`): the goal a crew is handed is somewhere its hull fits.
func test_a_group_move_beside_a_block_hands_every_hull_a_goal_it_fits() -> void:
	await _terminus()
	for source: String in ["player", ""]:
		var game_match := _squad()
		await wait_physics_frames(2)
		var orders := Orders.new()
		Orders.attach(game_match, orders)
		var names: Array = game_match.tanks.get_children().map(func(t: Tank) -> String: return String(t.name))
		var command := {"units": names, "verb": "move", "to": [CLICK.x, CLICK.y]}
		if source != "":
			command["source"] = source
		assert_eq(orders.issue(command), "", "ordered (source '%s')" % source)
		var goals := {}
		for unit_name: String in names:
			var order := orders.current(unit_name)
			goals[unit_name] = Vector3(float(order["goal"][0]), 0.0, float(order["goal"][1]))
		_assert_goals(goals, _ids(game_match), "Orders source '%s'" % source)
		game_match.free()


## The squad path (the CPU commander and the tactical map: Match.command_squad → Squad.context_for), which grounded a
## slot on the mesh CENTRE with 1 m of tolerance: a War Rig centred on the navmesh edge has its nose in the building.
func test_a_squad_command_beside_a_block_hands_every_hull_a_slot_it_fits() -> void:
	await _terminus()
	var game_match := _squad("line")
	await wait_physics_frames(2)
	assert_eq(game_match.command_squad(Match.Team.GREEN, {"squad": "A", "verb": "move", "to": [CLICK.x, CLICK.y]}), "", "ordered")
	var by_name := game_match.tanks_by_name()
	var squad := game_match.squad_for(game_match.tanks.get_child(0) as Tank)
	assert_true(squad != null, "setup: the squad")
	# Anchored at the destination (hold-like frame): the slots the squad will settle on, which are what goes wrong.
	squad.arrived = true
	var goals := {}
	for member in squad.formation_order(by_name):
		var context := squad.context_for(member, by_name)
		goals[member] = context["slot"]
	_assert_goals(goals, _ids(game_match), "Squad.context_for")
