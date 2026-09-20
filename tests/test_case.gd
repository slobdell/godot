class_name TestCase
extends RefCounted
## Base class for tests discovered by tests/run_tests.gd.
##
## Each `test_*` method gets a fresh instance. Assertions record failures instead
## of aborting, so one run reports everything that is wrong. Nodes added with
## `add_to_tree()` are freed after the test.

var tree: SceneTree
var failures: PackedStringArray = []
var expected_warnings: PackedStringArray = []
var _owned_nodes: Array[Node] = []


## Declare that this test EXPECTS one engine warning matching [param pattern], and that it is not a defect.
##
## Engine warnings fail a test by default, which is the right default: `push_warning` on a production path a
## test exercises is a defect in that path until someone says otherwise. But a test that deliberately drives
## a path INTO its warning -- a rejected config, a clamped value, a refused load -- then has no way to say so,
## and feel's city-block determinism test could not pass as written for exactly that reason.
##
## One call consumes one matching warning. Declaring it and getting none FAILS the test too: an expectation
## that silently holds for a warning that no longer happens is how a test stops testing anything.
##
## Matching is substring, or glob (`String.match`) when the pattern contains `*` or `?`. It may be called
## before or after the warning: reconciliation happens once, after teardown.
func expect_warning(pattern: String) -> void:
	expected_warnings.append(pattern)


## The same for a `push_error`, which is what a LOUD REFUSAL path emits. Without this, a refusal that correctly
## errors cannot be tested at all: the runner fails any test that logs an engine error, so the only testable
## refusals would be the quiet ones — precisely backwards. Declared before the call that should raise it, and a
## pattern that never arrives fails the test, so this cannot be used to silence an error that stopped happening.
var expected_errors: PackedStringArray = []


func expect_error(pattern: String) -> void:
	expected_errors.append(pattern)


## Reconcile one test's collected engine messages against the warnings it declared.
##
## Returns {"errors": int, "warnings": int, "failures": PackedStringArray}. Static, and separate from the
## runner, so every branch can be driven from a test with synthetic input -- including the one branch a real
## test cannot stage, an expectation that never arrives.
static func reconcile_engine_messages(entries: Array, expected: PackedStringArray,
		expected_err: PackedStringArray = PackedStringArray()) -> Dictionary:
	var errors := 0
	var warnings := 0
	var failures: PackedStringArray = []
	var outstanding := expected.duplicate()
	var outstanding_err := expected_err.duplicate()
	for entry: Dictionary in entries:
		var text: String = entry.get("text", "")
		if bool(entry.get("warning", false)):
			var index := _first_match(outstanding, text)
			if index >= 0:
				outstanding.remove_at(index)
				continue
			warnings += 1
			failures.append("engine warning: " + text)
		else:
			var index_err := _first_match(outstanding_err, text)
			if index_err >= 0:
				outstanding_err.remove_at(index_err)
				continue
			errors += 1
			failures.append("engine error: " + text)
	for pattern: String in outstanding:
		failures.append('expect_warning("%s") was declared and no matching warning arrived' % pattern)
	for pattern: String in outstanding_err:
		failures.append('expect_error("%s") was declared and no matching error arrived' % pattern)
	if errors + warnings > 0:
		failures.insert(0, "%d engine errors, %d engine warnings" % [errors, warnings])
	return {"errors": errors, "warnings": warnings, "failures": failures}


## The first outstanding pattern that matches, or -1. An EMPTY pattern matches nothing: `contains("")` is
## true for every string, so an accidental `expect_warning("")` would swallow the first warning of every
## kind -- a blanket exemption that reads like a specific one.
static func _first_match(patterns: PackedStringArray, text: String) -> int:
	for index in patterns.size():
		var pattern := patterns[index]
		if pattern == "":
			continue
		if pattern.contains("*") or pattern.contains("?"):
			if text.match(pattern):
				return index
		elif text.contains(pattern):
			return index
	return -1


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


## Wait until the world's navigation map holds no regions, so the NEXT test starts on an empty map however it built
## its arena. `ArenaFixture` drains before it instantiates, but **20+ test files call `ARENA.instantiate()` directly**
## and never reach that path — so the fixture's drain is a belt and this is the braces.
##
## Why it must live here and be awaited: `free()` is **synchronous**, and `NavigationServer3D` drops the freed
## arena's regions when it next **syncs**, a frame or two later. A test boundary is not a synchronisation point, so
## the next test bakes into the previous one's geometry — two full arenas of edges in one rasterization space, which
## the engine reports as *"more than 2 edges tried to occupy the same map rasterization space"* and `run_tests.gd`
## then charges to **whatever test is running when the warning lands**. combat lost 14 of 18 in one shard that way,
## with the warning standing beside a test that builds no arena at all; nav saw 4 of the same errors from building
## terminus twice inside one test.
##
## **EMPTY, not "back to the count we started with".** scale's drain probe printed `before=2 with_arena=2` — equal,
## so a baseline guard is satisfied having waited for nothing, and that `before=2` **was** the previous test's
## regions mid-drain. "Stops changing" fails too: a drain spanning two syncs reads `2, 2` as settled while both
## samples are pre-drain. Zero is the resting state and the only predicate with no false-satisfied case.
## 4 s of frames, not the 30 nav first wrote. scale measured the drain completing by **frame 1** on an idle box, so
## 30 looked generous — and on builder0 under five parallel shards it was not: `test_combat_sim_cost` reported
## "left 2 navigation region(s)" while **the same run produced ZERO edge errors**, which is the proof that the
## regions did drain and only the bound was short. A guard whose budget is tighter than the thing it measures
## reports a leak that is not there, which is scale's own question about their teardown guard — *"is the guard
## crying wolf?"* — arriving at nav from the other side one day later.
##
## The budget costs nothing in the normal case: the loop returns the moment the map is empty, which is almost always
## the first frame. It is only spent when something genuinely lingers, and then it is spent once.
const DRAIN_FRAMES := 120


func drain_navigation() -> void:
	var viewport := tree.root as Viewport
	if viewport == null or viewport.world_3d == null:
		return
	var map := viewport.world_3d.navigation_map
	for frame in DRAIN_FRAMES:
		if NavigationServer3D.map_get_regions(map).is_empty():
			return
		await tree.physics_frame
	# CONTAINMENT. The budget expiring means a node somewhere still OWNS these regions -- `test_combat_sim_cost`
	# holds an arena past teardown and its two regions survive all 120 frames. Without this, the next test bakes
	# over them and one leaking test becomes 22 failures in a shard, all carrying the 284-edge-error warning and
	# none of them the culprit. So: detach the leftovers, name them, and let the LEAKING test fail alone.
	#
	# `region_set_map(rid, RID())` and NOT `free_rid`: the leak is a live node still holding the arena, and that
	# node owns these RIDs. Freeing a RID out from under its owner is a crash waiting for the next frame; detaching
	# it from the map is enough, because the map is the only thing the next bake collides with.
	var leftovers := NavigationServer3D.map_get_regions(map)
	var left := leftovers.size()
	if left > 0:
		for rid: RID in leftovers:
			NavigationServer3D.region_set_map(rid, RID())
		print("TEST_DRAIN: detached %d leaked navigation region(s) so the rest of the shard survives" % left)
		failures.append(("left %d navigation region(s) on the map after %d frames (4 s) - a node here still OWNS "
				+ "them. They have been detached from the map so the next test does not bake over them, but THIS "
				+ "test is the leak: free every node it adds. Undetached, the engine's 'more than 2 edges tried to "
				+ "occupy the same map rasterization space' would be charged to whichever test ran next.")
				% [left, DRAIN_FRAMES])


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
	# LAST, and awaited by the runner: leave the navigation map empty so the next test cannot bake into this one's
	# regions. Placed after the body guard so that guard's timing is unchanged, and after `free()` so there is
	# something to drain. Every test gets this without asking, which is the point -- 20+ files instantiate the arena
	# scene directly and would never call it themselves.
	await drain_navigation()
