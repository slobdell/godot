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


## Physics bodies one test leaves behind for the next one. A stale body makes a unit "spawn inside a wall" on a map
## that has no wall there, and nothing says so: the failure lands on whichever test runs afterwards.
##
## Counted in TEARDOWN, not at setup, deliberately: **the test that leaked is the one that should go red.** Checking at
## the start of the next test names the victim and leaves the culprit green, which is how this class of bug survives.
##
## **BODIES ONLY, AND NAVIGATION REGIONS DELIBERATELY NOT.** The first version of this guard counted regions too and
## failed three tests in other streams' files. It was wrong, and measurably: `free()` takes an arena's bodies to 0 in
## the same call, but its NAVIGATION REGIONS are dropped by the server on the NEXT FRAME --
## `SPAWN_ISO_REGIONS before=2 with_arena=2 then after free: [2, 0, 0, 0]` (frames 0,1,2,3, round 9). `teardown()` is
## synchronous, so it can only ever sample frame 0, where a correctly-freed arena still shows its regions.
## **A guard that fails inside a settling window is the same defect as the test it was written to explain**, which in
## this case was a spawn test measuring a depenetration recovery at frame 1 that resolves by frame 3. Bodies have no
## such window, so bodies are the only claim this makes.
static var _world_baseline := -1


func _world_left_behind() -> Dictionary:
	return {"bodies": _count_bodies(tree.root)}


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
	var total: int = int(_world_left_behind()["bodies"])
	# A high-water mark, so this reports a LOWER BOUND on leakers: once the count has risen, a later test leaking
	# below that mark is not blamed. Deliberate -- the alternative is blaming a test for someone else's residue.
	if _world_baseline >= 0 and total > _world_baseline:
		failures.append(("left %d physics bodies in the world (was %d before this test). Whatever runs next will see "
				+ "them and may fail instead of this one: free every node you add, and if a helper builds the arena, "
				+ "free it there.") % [total, _world_baseline])
	_world_baseline = maxi(_world_baseline, total)
