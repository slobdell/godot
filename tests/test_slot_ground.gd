extends TestCase
## Round 6, squad X2: a formation slot is somewhere a vehicle can stand. A slot laid inside an obstacle is pushed to the
## nearest standable point (the arena's navmesh), and a slot in the open is left exactly where the formation put it.

const ARENA := preload("res://game/arena/arena.tscn")


func _arena() -> Node3D:
	var arena := add_to_tree(ARENA.instantiate()) as Node3D
	for i in 60:
		await tree.physics_frame
		if TacticsLab.navigation_is_this_arenas(arena):
			break
	# Not just "a navmesh is ready": THIS arena's, and no other test's (lesson 36).
	assert_true(TacticsLab.navigation_is_this_arenas(arena), "setup: the navmesh is this arena's")
	return arena


func test_a_slot_inside_an_obstacle_moves_out_of_it_and_one_in_the_open_stays() -> void:
	var arena := await _arena()
	var biggest: Dictionary = {}
	for feature: Dictionary in arena.call("cover_features"):
		var footprint: Vector3 = feature["size"]
		if footprint.y >= 1.5 and (biggest.is_empty() or footprint.x * footprint.z > (biggest["size"] as Vector3).x * (biggest["size"] as Vector3).z):
			biggest = feature
	assert_true(not biggest.is_empty(), "setup: the arena has a solid obstacle")
	var inside: Vector3 = biggest["position"]
	var moved := SlotGround.standable(arena, inside)
	var size: Vector3 = biggest["size"]
	assert_true(Vector2(moved.x - inside.x, moved.z - inside.z).length() >= minf(size.x, size.z) * 0.5 - 0.1,
			"a slot in the middle of a %s is pushed out of it (%s -> %s)" % [biggest["type"], inside, moved])
	assert_true(SlotGround.is_standable(arena, moved), "to a point that is itself standable")
	var open := Vector3(-100, 0, 40)  # the open western strip every scenario uses
	assert_eq(SlotGround.standable(arena, open), open, "a slot in the open is left where the formation put it")


func test_without_a_navmesh_nothing_changes() -> void:
	assert_eq(SlotGround.standable(null, Vector3(3, 0, 4)), Vector3(3, 0, 4), "no world, no opinion")
