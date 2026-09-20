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
## Returns {"errors": int, "warnings": int, "failures": PackedStringArray, "texts": PackedStringArray}.
## `texts` is what this test was CHARGED with, so the runner can tell one cause from many victims: a leaked
## object outlives the test that made it, so its warning lands on whoever runs next, and one arena holder in
## combat's sim_cost test failed 22 tests in one shard (2026-09-20). Twenty-two red tests sharing a message
## are one defect, and a reader should not have to work that out.
##
## Static, and separate from the runner, so every branch can be driven from a test with synthetic input --
## including the one branch a real test cannot stage, an expectation that never arrives.
static func reconcile_engine_messages(entries: Array, expected: PackedStringArray,
		expected_err: PackedStringArray = PackedStringArray(),
		allowed: PackedStringArray = PackedStringArray()) -> Dictionary:
	var errors := 0
	var warnings := 0
	var allowed_seen := 0
	var failures: PackedStringArray = []
	var charged: PackedStringArray = []
	var matched_allow: PackedStringArray = []
	var outstanding := expected.duplicate()
	var outstanding_err := expected_err.duplicate()
	for entry: Dictionary in entries:
		var text: String = entry.get("text", "")
		# A message the test did not CAUSE and cannot control, allowed by name in
		# tests/baselines/engine_expected.txt. Checked before the declarations below, and before the type is
		# looked at: `expect_warning`/`expect_error` belong to the test that causes a message, and whether
		# the engine types a job-system saturation as a warning or an error is the engine's business.
		# Neither charged nor counted against the test -- but counted and named, because an exemption that
		# is silent cannot be told from a run in which nothing happened.
		var allow_index := _first_match(allowed, text)
		if allow_index >= 0:
			allowed_seen += 1
			if not matched_allow.has(allowed[allow_index]):
				matched_allow.append(allowed[allow_index])
			continue
		if bool(entry.get("warning", false)):
			var index := _first_match(outstanding, text)
			if index >= 0:
				outstanding.remove_at(index)
				continue
			warnings += 1
			charged.append(text)
			failures.append("engine warning: " + text)
		else:
			var index_err := _first_match(outstanding_err, text)
			if index_err >= 0:
				outstanding_err.remove_at(index_err)
				continue
			errors += 1
			charged.append(text)
			# The numeric type is printed when it is known, because "engine error" is a CLASSIFICATION and
			# this one has already been surprising once (a console `WARNING:` arriving as a non-warning).
			var kind := "engine error" if not entry.has("type") else "engine error (type %d)" % int(entry["type"])
			failures.append(kind + ": " + text)
	for pattern: String in outstanding:
		failures.append('expect_warning("%s") was declared and no matching warning arrived' % pattern)
	for pattern: String in outstanding_err:
		failures.append('expect_error("%s") was declared and no matching error arrived' % pattern)
	if errors + warnings > 0:
		failures.insert(0, "%d engine errors, %d engine warnings" % [errors, warnings])
	return {"errors": errors, "warnings": warnings, "failures": failures, "texts": charged,
			"allowed_seen": allowed_seen, "allow_matched": matched_allow}


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
## its arena. **This is a coroutine: `await` it, and `await teardown()` if you call that yourself** — see
## `_draining` above for what a bare call does and how it is caught. `ArenaFixture` drains before it instantiates, but **20+ test files call `ARENA.instantiate()` directly**
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

## **`drain_navigation()` MUST BE AWAITED, and this flag is why.** It is a coroutine: called bare, it returns at
## once and keeps waiting in the background while the caller carries on. `test_combat_sim_cost` calls `teardown()`
## bare inside its own loop, so a detached drain sat in its 120-frame wait **while the loop built the next arena**
## and then counted that LIVE arena as leftover — reporting a leak that was someone else's working state. nav read
## that report as a real holder and said so; it was this.
##
## A second concurrent drain therefore **fails loudly instead of measuring**. Counting a shared, global thing
## (the world's navigation map) from two overlapping coroutines cannot give either one an answer about itself, and
## a guard that returned quietly would leave the bare `teardown()` in place and un-diagnosed.
static var _draining := false


func drain_navigation() -> void:
	if _draining:
		failures.append("drain_navigation() was re-entered while a previous drain was still waiting. A coroutine "
				+ "teardown() was called WITHOUT `await`, so the first drain is counting whatever the caller built "
				+ "after it - not a leak. Await teardown(), or call drain_navigation() directly and await that.")
		return
	var viewport := tree.root as Viewport
	if viewport == null or viewport.world_3d == null:
		return
	_draining = true
	var map := viewport.world_3d.navigation_map
	for frame in DRAIN_FRAMES:
		if NavigationServer3D.map_get_regions(map).is_empty():
			_draining = false
			return
		await tree.physics_frame
	# REPORT, DO NOT REMOVE. An earlier version detached the leftovers here (`region_set_map(rid, RID())`) so that
	# one leaking test could not cascade. **Measured: it made things far worse** -- 1401/117 against 1516/2, with
	# the 284 edge errors returning. The regions it detached were not orphans: detaching navigation out from under
	# something that still needed it broke arenas across whole files, and the cascade it was written to prevent is
	# the cascade it caused. Containment needs to know an orphan from a live region and this could not, so it is
	# gone until something can.
	var left := NavigationServer3D.map_get_regions(map).size()
	if left > 0:
		failures.append(("left %d navigation region(s) on the map after %d frames (4 s) - a node here still OWNS "
				+ "them. The next test may bake into them and the engine's 'more than 2 edges tried to occupy the "
				+ "same map rasterization space' would then be charged to whichever test was running when it "
				+ "landed, not to this one. Free every node this test adds.") % [left, DRAIN_FRAMES])
	_draining = false


## Free everything this test added. Safe to call mid-test, and the ONLY supported way to do that — a test that
## wants a clean world part-way through calls this, not `teardown()`.
func free_owned() -> void:
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.free()
	_owned_nodes.clear()


## **SEALED. The runner awaits this, and it owns the order: hook, free, body guard, drain.**
##
## The drain must be awaited, and a `teardown()` that must be awaited but can be declared `-> void` **cannot be made
## safe by review**: five files called `teardown()` or `super.teardown()` un-awaited, so the runner's `await`
## returned at once and the drain detached — and **four of them, all viewport-resizing tests, had silently skipped
## the drain for as long as it existed.** Nobody did anything wrong; the signature allowed it.
##
## So the sequence is not overridable. `teardown()` below is a **synchronous hook** and is never responsible for the
## drain. An override that forgets to call `super` now loses nothing, because the base no longer holds anything an
## override needs.
##
## Hook FIRST, then free: that is the order overrides already assumed, since they did their own cleanup and called
## `super.teardown()` last.
func _teardown() -> void:
	teardown()
	free_owned()
	var total: int = int(_world_left_behind()["bodies"])
	# A high-water mark, so this reports a LOWER BOUND on leakers: once the count has risen, a later test leaking
	# below that mark is not blamed. Deliberate -- the alternative is blaming a test for someone else's residue.
	if _world_baseline >= 0 and total > _world_baseline:
		failures.append(("left %d physics bodies in the world (was %d before this test). Whatever runs next will see "
				+ "them and may fail instead of this one: free every node you add, and if a helper builds the arena, "
				+ "free it there.") % [total, _world_baseline])
	_world_baseline = maxi(_world_baseline, total)
	# LAST, and awaited by the runner via `_teardown()`: leave the navigation map empty so the next test cannot bake into this one's
	# regions. Placed after the body guard so that guard's timing is unchanged, and after `free()` so there is
	# something to drain. Every test gets this without asking, which is the point -- 20+ files instantiate the arena
	# scene directly and would never call it themselves.
	await drain_navigation()


## Overridable, synchronous, and it **still frees this test's nodes exactly as it always did** — so a mid-test
## `teardown()` call keeps working and an override's `super.teardown()` keeps meaning what its author intended.
##
## Making this a bare hook was measured and reverted: `test_control_panel` calls `teardown()` **mid-test** to get a
## clean world, and with the free moved out it froze nothing and took ten tests with it. **The sealing was supposed
## to move only the part that needs frames — the drain — and it moved the part everyone depends on as well.**
##
## What it must NOT do is drain: that needs `await`, and a `-> void` signature cannot force a caller to use it.
## `_teardown()` owns the drain for exactly that reason.
func teardown() -> void:
	free_owned()
