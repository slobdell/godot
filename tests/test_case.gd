class_name TestCase
extends RefCounted
## Base class for tests discovered by tests/run_tests.gd.
##
## Each `test_*` method gets a fresh instance. Assertions record failures instead
## of aborting, so one run reports everything that is wrong. Nodes added with
## `add_to_tree()` are freed after the test.

var tree: SceneTree
var failures: PackedStringArray = []
var _owned_nodes: Array[Node] = []


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, expected, actual])


func assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s (expected %s ± %s, got %s)" % [message, expected, tolerance, actual])


func add_to_tree(node: Node) -> Node:
	tree.root.add_child(node)
	_owned_nodes.append(node)
	return node


func wait_physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


## What one test can leave behind for the next one, counted. Physics bodies and navigation regions are the two that
## silently corrupt another test's world: a stale body makes a unit "spawn inside a wall" on a map that has no wall
## there, and a stale navigation region answers routing questions about an arena that is gone (the failure
## ArenaFixture exists for -- see its docstring). Round 9 lost a morning to the physics half of this, on a test that
## PASSES ALONE and fails only when an arena test runs before it in the same process.
##
## Counted in TEARDOWN, not at setup, deliberately: **the test that leaked is the one that should go red.** Checking
## at the start of the next test names the victim and leaves the culprit green, which is how this survived for rounds
## -- the failure always appeared in whichever test happened to run afterwards, so it read as that test's bug.
static var _world_baseline := -1


func _world_left_behind() -> Dictionary:
	var bodies := _count_bodies(tree.root)
	var regions := 0
	var viewport := tree.root as Viewport
	if viewport != null and viewport.world_3d != null:
		regions = NavigationServer3D.map_get_regions(viewport.world_3d.navigation_map).size()
	return {"bodies": bodies, "regions": regions}


func _count_bodies(node: Node) -> int:
	var n := 1 if node is CollisionObject3D else 0
	for child in node.get_children():
		n += _count_bodies(child)
	return n


func teardown() -> void:
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.free()
	_owned_nodes.clear()
	var left := _world_left_behind()
	var total: int = int(left["bodies"]) + int(left["regions"])
	if _world_baseline >= 0 and total > _world_baseline:
		failures.append(("left the world dirtier than it found it: %d physics bodies and %d navigation regions "
				+ "remain (was %d before this test). The next test to run will see them and may fail instead of "
				+ "this one -- free what you add, or build arenas through ArenaFixture.")
				% [left["bodies"], left["regions"], _world_baseline])
	_world_baseline = maxi(_world_baseline, total)
