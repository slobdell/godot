extends TestCase
## The test runner's own handling of engine errors and warnings.
##
## `ErrorCollector` used to implement `_log_error` and ignore `_error_type`, so a `push_warning` on any
## production path a test exercised arrived as "engine error: ..." and failed that test -- with no way to tell
## an error from a warning and no way to declare an expected one. feel's city-block determinism test could not
## pass as written for that reason.
##
## Warnings still FAIL by default: a warning on a path a test drives is a defect in that path until someone
## says otherwise, in writing, with `expect_warning`. These tests pin both halves, because an exemption
## mechanism that is too easy to reach is worse than none.


func _entry(text: String, warning: bool) -> Dictionary:
	return {"text": text, "warning": warning}


func test_an_engine_error_fails_the_test_and_is_counted_as_an_error() -> void:
	var result := TestCase.reconcile_engine_messages([_entry("boom (a.gd:3 in f)", false)], PackedStringArray())
	var failures: PackedStringArray = result["failures"]
	assert_eq(int(result["errors"]), 1, "one error")
	assert_eq(int(result["warnings"]), 0, "no warnings")
	assert_true(failures[1].begins_with("engine error: "), "labelled an error")


func test_an_undeclared_warning_still_fails_the_test() -> void:
	var result := TestCase.reconcile_engine_messages([_entry("odd (a.gd:3 in f)", true)], PackedStringArray())
	var failures: PackedStringArray = result["failures"]
	assert_eq(int(result["warnings"]), 1, "one warning")
	assert_eq(int(result["errors"]), 0, "no errors")
	assert_true(failures[1].begins_with("engine warning: "), "labelled a warning")


func test_errors_and_warnings_are_counted_separately_in_the_failure() -> void:
	var entries := [
		_entry("boom (a.gd:1 in f)", false),
		_entry("odd (a.gd:2 in f)", true),
		_entry("odd again (a.gd:3 in f)", true),
	]
	var result := TestCase.reconcile_engine_messages(entries, PackedStringArray())
	var failures: PackedStringArray = result["failures"]
	assert_eq(int(result["errors"]), 1, "one error")
	assert_eq(int(result["warnings"]), 2, "two warnings")
	assert_eq(failures[0], "1 engine errors, 2 engine warnings", "the count line leads")


func test_a_clean_test_gets_no_count_line_at_all() -> void:
	var result := TestCase.reconcile_engine_messages([], PackedStringArray())
	var failures: PackedStringArray = result["failures"]
	assert_eq(failures.size(), 0, "nothing to say")


func test_a_declared_warning_is_consumed_and_does_not_fail() -> void:
	var result := TestCase.reconcile_engine_messages(
			[_entry("colour name unknown (theme.gd:9 in pick)", true)],
			PackedStringArray(["colour name unknown"]))
	var failures: PackedStringArray = result["failures"]
	assert_eq(failures.size(), 0, "declared, so not a failure")
	assert_eq(int(result["warnings"]), 0, "a declared warning is not counted against the run")


func test_a_declared_warning_that_never_arrives_fails() -> void:
	## The half that matters most: an expectation that silently holds for a warning that no longer happens
	## is how a test stops testing anything. This branch cannot be staged by a real test, only by this call.
	var result := TestCase.reconcile_engine_messages([], PackedStringArray(["a warning nobody emits"]))
	var failures: PackedStringArray = result["failures"]
	assert_eq(failures.size(), 1, "one failure")
	assert_true(failures[0].contains("no matching warning arrived"), "says which way it failed")
	assert_true(failures[0].contains("a warning nobody emits"), "names the pattern")


func test_one_declaration_consumes_exactly_one_warning() -> void:
	var entries := [_entry("same (a.gd:1 in f)", true), _entry("same (a.gd:2 in f)", true)]
	var result := TestCase.reconcile_engine_messages(entries, PackedStringArray(["same"]))
	assert_eq(int(result["warnings"]), 1, "the second one is still a failure")


func test_a_declaration_does_not_excuse_an_error() -> void:
	## An exemption for warnings must never quietly cover an error: they are different severities and the
	## whole reason for this change is that the runner could not tell them apart.
	var result := TestCase.reconcile_engine_messages([_entry("boom (a.gd:1 in f)", false)],
			PackedStringArray(["boom"]))
	var failures: PackedStringArray = result["failures"]
	assert_eq(int(result["errors"]), 1, "the error stands")
	assert_true(failures[2].contains("no matching warning arrived"), "and the declaration is unmet")


func test_a_glob_pattern_matches() -> void:
	var result := TestCase.reconcile_engine_messages(
			[_entry("shader 'neon_42' failed to compile (fx.gd:8 in load)", true)],
			PackedStringArray(["*failed to compile*"]))
	var failures: PackedStringArray = result["failures"]
	assert_eq(failures.size(), 0, "glob consumed it")


func test_an_empty_pattern_swallows_nothing() -> void:
	## `"anything".contains("")` is true, so an accidental `expect_warning("")` would be a blanket exemption
	## that reads like a specific one -- the same shape as a lint over zero files reporting success.
	var result := TestCase.reconcile_engine_messages([_entry("odd (a.gd:1 in f)", true)],
			PackedStringArray([""]))
	assert_eq(int(result["warnings"]), 1, "the warning still fails")


func test_expect_warning_records_the_pattern() -> void:
	var case := TestCase.new()
	case.expect_warning("something")
	assert_eq(case.expected_warnings.size(), 1, "recorded")


func test_the_messages_a_test_is_charged_with_are_reported_back() -> void:
	## The runner groups these to name ONE cause behind many failing tests. A declared warning is not
	## charged, so a test that owns its warning never appears in that group.
	var result := TestCase.reconcile_engine_messages(
			[_entry("leak (a.gd:1 in f)", true), _entry("boom (a.gd:2 in f)", false)], PackedStringArray())
	var texts: PackedStringArray = result["texts"]
	assert_eq(texts.size(), 2, "both the warning and the error are charged")
	assert_true(texts[0].contains("leak"), "the warning is there")
	assert_true(texts[1].contains("boom"), "the error is there")


func test_a_declared_warning_is_not_charged_to_the_test_that_declared_it() -> void:
	var result := TestCase.reconcile_engine_messages([_entry("expected (a.gd:1 in f)", true)],
			PackedStringArray(["expected"]))
	var texts: PackedStringArray = result["texts"]
	assert_eq(texts.size(), 0, "a test that owns its warning is not a victim of it")


func test_a_clean_test_is_charged_with_nothing() -> void:
	var result := TestCase.reconcile_engine_messages([], PackedStringArray())
	var texts: PackedStringArray = result["texts"]
	assert_eq(texts.size(), 0, "nothing charged")


func test_an_allowed_message_does_not_fail_the_test() -> void:
	## For messages a test did NOT cause and cannot control -- a leak from elsewhere, an engine job system
	## saturating under load. `expect_warning` is the wrong tool: it belongs to the test that causes one.
	var result := TestCase.reconcile_engine_messages([_entry("Jolt job system exceeded (a.cpp:1 in f)", true)],
			PackedStringArray(), PackedStringArray(["Jolt job system exceeded"]))
	var failures: PackedStringArray = result["failures"]
	assert_eq(failures.size(), 0, "allowed, so not a failure")
	assert_eq(int(result["warnings"]), 0, "and not counted against the run")
	assert_eq(int(result["allowed_seen"]), 1, "but COUNTED as allowed -- a silent exemption is not one")


func test_an_allowed_message_is_not_charged_to_the_test_it_landed_on() -> void:
	var result := TestCase.reconcile_engine_messages([_entry("Jolt job system exceeded (a.cpp:1 in f)", true)],
			PackedStringArray(), PackedStringArray(["Jolt job system exceeded"]))
	var texts: PackedStringArray = result["texts"]
	assert_eq(texts.size(), 0, "it is not this test's, so it is not a victim of it either")


func test_an_allowed_pattern_reports_that_it_matched() -> void:
	var result := TestCase.reconcile_engine_messages([_entry("Jolt job system exceeded (a.cpp:1 in f)", true)],
			PackedStringArray(), PackedStringArray(["Jolt job system exceeded", "never happens"]))
	var used: PackedStringArray = result["allow_matched"]
	assert_eq(used.size(), 1, "only the one that matched")
	assert_eq(used[0], "Jolt job system exceeded", "and it is named, so the unused one can be tightened away")


func test_an_allowed_pattern_covers_an_ERROR_too() -> void:
	## Whether an engine message arrives typed as a warning or an error is the engine's business, and a
	## message a test cannot control is not the test's fault either way.
	var result := TestCase.reconcile_engine_messages([_entry("Jolt job system exceeded (a.cpp:1 in f)", false)],
			PackedStringArray(), PackedStringArray(["Jolt job system exceeded"]))
	var failures: PackedStringArray = result["failures"]
	assert_eq(failures.size(), 0, "allowed by name, whatever its type")
	assert_eq(int(result["errors"]), 0, "and not counted as an error")


func test_an_unrelated_message_is_still_a_failure_with_an_allowlist_present() -> void:
	var result := TestCase.reconcile_engine_messages([_entry("something else entirely (a.gd:1 in f)", true)],
			PackedStringArray(), PackedStringArray(["Jolt job system exceeded"]))
	assert_eq(int(result["warnings"]), 1, "the allowlist exempts what it names and nothing more")


func test_an_empty_allow_pattern_exempts_nothing() -> void:
	## `contains("")` is true of every string, so one blank line would exempt the first message of every
	## kind -- a blanket exemption that reads like a specific one.
	var result := TestCase.reconcile_engine_messages([_entry("anything at all (a.gd:1 in f)", true)],
			PackedStringArray(), PackedStringArray([""]))
	assert_eq(int(result["warnings"]), 1, "still a failure")
	assert_eq(int(result["allowed_seen"]), 0, "and nothing was allowed")


func test_no_allowlist_behaves_exactly_as_before() -> void:
	var result := TestCase.reconcile_engine_messages([_entry("odd (a.gd:1 in f)", true)], PackedStringArray())
	assert_eq(int(result["warnings"]), 1, "warnings still fail by default")
	assert_eq(int(result["allowed_seen"]), 0, "nothing allowed")


func test_a_real_warning_declared_by_a_real_test_passes_end_to_end() -> void:
	## Everything above drives the reconciler directly. This one goes through the engine: the warning below
	## is raised for real, collected by the runner's Logger, and consumed by the declaration. If any link in
	## that chain is wrong -- the error type, the collector, the hand-off after teardown -- THIS test fails.
	expect_warning("deliberate warning from test_engine_warnings")
	push_warning("deliberate warning from test_engine_warnings")
