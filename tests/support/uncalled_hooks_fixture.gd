extends TestCase
## Round 43 (N6): a case that relies on hooks TestCase never calls (tests/test_runner_hooks.gd reads it; it is not a test_ file,
## so the runner never runs it). `_setup()` is a helper the test calls itself, and is allowed.

var armed := false


func before_each() -> void:
	armed = true


func after_all() -> void:
	armed = false


func _setup() -> void:
	armed = true


func test_relies_on_the_hook() -> void:
	assert_true(armed, "armed by before_each, which never runs")
