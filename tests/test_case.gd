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


## Reconcile one test's collected engine messages against the warnings it declared.
##
## Returns {"errors": int, "warnings": int, "failures": PackedStringArray}. Static, and separate from the
## runner, so every branch can be driven from a test with synthetic input -- including the one branch a real
## test cannot stage, an expectation that never arrives.
static func reconcile_engine_messages(entries: Array, expected: PackedStringArray) -> Dictionary:
	var errors := 0
	var warnings := 0
	var failures: PackedStringArray = []
	var outstanding := expected.duplicate()
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
			errors += 1
			failures.append("engine error: " + text)
	for pattern: String in outstanding:
		failures.append('expect_warning("%s") was declared and no matching warning arrived' % pattern)
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


func teardown() -> void:
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.free()
	_owned_nodes.clear()
