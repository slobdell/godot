extends TestCase
## Round 10 (nav's drive test, relayed): a right-click on a selection put each crew's formation slot where the SHAPE
## said, and 11 of 13 arrival misses on the default path were slots 4-10 m inside a block. Orders now grounds every
## goal on the navmesh (squad's SlotGround, with the hull's clearance once squad's call lands) and the order says how
## far it moved, which the unit card shows.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func test_a_right_click_slot_inside_an_obstacle_is_moved_onto_ground_and_says_so() -> void:
	var arena := add_to_tree(ARENA.instantiate()) as Node3D
	for i in 60:
		await tree.physics_frame
		if TacticsLab.navigation_is_this_arenas(arena):
			break
	assert_true(TacticsLab.navigation_is_this_arenas(arena), "setup: the navmesh is this arena's")
	var game_match := MATCH.instantiate() as Match
	add_to_tree(game_match)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "T", "squads": [{"name": "A", "units": [{"unit": "tank"}]}]}), "", "setup")
	var biggest: Dictionary = {}
	for feature: Dictionary in arena.call("cover_features"):
		var footprint: Vector3 = feature["size"]
		if footprint.y >= 1.5 and (biggest.is_empty() or footprint.x * footprint.z > (biggest["size"] as Vector3).x * (biggest["size"] as Vector3).z):
			biggest = feature
	var inside: Vector3 = biggest["position"]
	var tank := game_match.tanks.get_child(0) as Tank
	tank.global_position = inside + Vector3(0, 0, 40)
	tank.reset_physics_interpolation()
	var orders := Orders.new()
	Orders.attach(game_match, orders)
	assert_eq(orders.issue({"units": [String(tank.name)], "verb": "move", "to": [inside.x, inside.z], "source": "player"}), "", "ordered")
	var order := orders.current(String(tank.name))
	var goal := Vector3(float(order["goal"][0]), 0.0, float(order["goal"][1]))
	assert_true(SlotGround.is_standable(arena, goal), "the goal is on ground a vehicle can stand on (%s)" % goal)
	assert_true(float(order.get("grounded_m", 0.0)) >= 1.0, "and the order says how far it moved (%s)" % order.get("grounded_m"))
	assert_eq(order["to"], [inside.x, inside.z], "the click itself is kept: the pin stays where he clicked")
	var open := Vector3(-100, 0, 40)
	orders.issue({"units": [String(tank.name)], "verb": "move", "to": [open.x, open.z], "source": "player"})
	assert_true(not orders.current(String(tank.name)).has("grounded_m"), "a slot in the open is left alone")
