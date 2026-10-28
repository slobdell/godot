extends TestCase
## Round 43 (N6): the runner FAILS a test file that defines a setup or teardown hook TestCase never calls (before_each,
## after_all, setup, ...), naming the method; a case's own `_setup()` helper and `teardown()` are not refused.

const RUNNER := preload("res://tests/run_tests.gd")
const FIXTURE := preload("res://tests/support/uncalled_hooks_fixture.gd")


func test_hooks_testcase_never_calls_are_named() -> void:
	assert_eq(RUNNER.uncalled_hooks(FIXTURE), PackedStringArray(["before_each", "after_all"]),
			"before_each and after_all are named, _setup is not")


func test_teardown_and_a_plain_case_are_not_refused() -> void:
	assert_eq(RUNNER.uncalled_hooks(get_script()), PackedStringArray(), "this file defines none")
	assert_eq(RUNNER.uncalled_hooks(preload("res://tests/test_case.gd")), PackedStringArray(),
			"TestCase's own teardown() and _teardown() are not hooks it fails to call")

