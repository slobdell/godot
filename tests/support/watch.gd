class_name Watch
extends RefCounted
## Connect a test's watcher to a signal, and have the runner disconnect it when the test ends (ship, round 18).
##
##     Watch.on(orders.order_changed, func(unit_name: String) -> void: changed.append(unit_name))
##
## Two defects of one shape reached the exit report this round. A lambda connected from a test to the signal of an
## object that outlives the test -- a RefCounted like `Orders` or `MatchMood`, or a node the test does not free -- is
## still attached when the test's coroutine frame dies: picker's `test_previewing_a_formation_issues_nothing` then
## corrupted the heap at exit (exit 134 on glibc 2.39), and `test_tactics_reissue`'s watchers, which captured `orders`
## itself, kept Orders, the test case and their scripts alive to the leak report. `tests/run_tests.gd` calls
## `Watch.release_all()` after every test's teardown, so a watcher connected through here cannot outlive its test.

static var _held: Array = []


## Connects `callable` to `sig` until the end of the current test.
static func on(sig: Signal, callable: Callable, flags: int = 0) -> void:
	sig.connect(callable, flags)
	_held.append([sig, callable])


## Disconnects every watcher still connected; returns how many were. The runner calls it after each test.
static func release_all() -> int:
	var released := 0
	for pair: Array in _held:
		var sig: Signal = pair[0]
		var callable: Callable = pair[1]
		if not sig.is_null() and is_instance_valid(sig.get_object()) and sig.is_connected(callable):
			sig.disconnect(callable)
			released += 1
	_held.clear()
	return released
