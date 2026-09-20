extends SceneTree
## Behavior scenario runner: `make ai-scenarios` (FILTER=substring). Runs every test_* method in
## res://tests/ai_scenarios/scenario_*.gd, under --fixed-fps 60 so battles run faster than real time.
##
## A scenario script lists behaviors that aren't built yet in `const PENDING := ["test_..."]`. A pending
## scenario is EXPECTED to fail (it prints PENDING and the reason); if it passes, the run fails with
## "UNEXPECTED PASS" so the behavior gets promoted (removed from PENDING, maybe added to the quick subset
## in tests/test_ai_scenarios.gd). Engine errors fail a scenario, like tests/run_tests.gd.

const ROOT := "res://tests/ai_scenarios"


## THIS RUNNER HAD ITS OWN COPY, and the copy was the old one: it ignored `_error_type` and labelled every
## message "engine error". That is why a Jolt job-system message Godot's console printed as `WARNING:`
## failed `scenario_stride` as an ERROR on a loaded builder0 (2026-09-20) -- not a classification subtlety
## in the engine, which a probe had already exonerated, but a duplicate implementation fixed in one place.
##
## Two runners, one rule, and they drifted in every way they could: warnings told apart from errors,
## `expect_warning`, `expect_error`, the engine-message allowlist and nav's awaited `teardown()` all existed
## in `tests/run_tests.gd` and none of them here. It now shares `TestCase.reconcile_engine_messages`.
class ErrorCollector extends Logger:
	var entries: Array[Dictionary] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		entries.append({
			"warning": error_type == Logger.ERROR_TYPE_WARNING,
			"type": error_type,
			"text": "%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function],
		})
		_mutex.unlock()

	func take() -> Array[Dictionary]:
		_mutex.lock()
		var taken := entries
		entries = []
		_mutex.unlock()
		return taken


const ALLOWLIST := "res://tests/baselines/engine_expected.txt"


## Engine messages allowed by name; the same file `tests/run_tests.gd` reads, because one rule with two
## files is how these two runners drifted apart in the first place.
func _read_allowlist() -> PackedStringArray:
	var patterns: PackedStringArray = []
	var file := FileAccess.open(ALLOWLIST, FileAccess.READ)
	if file == null:
		return patterns
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line != "" and not line.begins_with("#"):
			patterns.append(line)
	return patterns


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var errors := ErrorCollector.new()
	OS.add_logger(errors)
	var allowed := _read_allowlist()
	var allowed_total := 0
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var counts := {"passed": 0, "failed": 0, "pending": 0, "unexpected": 0}
	var files := Array(DirAccess.get_files_at(ROOT)).filter(func(f: String) -> bool:
		return f.begins_with("scenario_") and f.ends_with(".gd"))
	files.sort()
	for file: String in files:
		var script: GDScript = load(ROOT.path_join(file))
		if script == null:
			# A scenario file that doesn't parse used to leave the run green with nothing run at all.
			counts["failed"] += 1
			print("  FAIL  %s (does not parse; see the parse errors above)" % file.get_basename())
			continue
		var pending: Array = script.get_script_constant_map().get("PENDING", [])
		var methods := script.get_script_method_list()
		if not methods.any(func(m: Dictionary) -> bool: return String(m["name"]).begins_with("test_")):
			# A file that fails to compile still loads, with no methods: it used to leave the run green.
			counts["failed"] += 1
			print("  FAIL  %s (no test_ methods; see the parse errors above)" % file.get_basename())
			continue
		for method in methods:
			var method_name: String = method["name"]
			var label := "%s::%s" % [file.get_basename(), method_name]
			if not method_name.begins_with("test_") or (filter != "" and not label.contains(filter)):
				continue
			var case: TestCase = script.new()
			case.tree = self
			errors.take()
			var started := Time.get_ticks_msec()
			await case.call(method_name)
			# AWAITED, as in tests/run_tests.gd: `teardown()` drains the navigation map and that needs
			# frames; un-awaited it drains after the NEXT scenario has started.
			await case.teardown()
			var engine: Dictionary = TestCase.reconcile_engine_messages(
					errors.take(), case.expected_warnings, case.expected_errors, allowed)
			var engine_failures: PackedStringArray = engine["failures"]
			case.failures.append_array(engine_failures)
			allowed_total += int(engine["allowed_seen"])
			var seconds := (Time.get_ticks_msec() - started) / 1000.0
			var is_pending := pending.has(method_name)
			if case.failures.is_empty():
				counts["unexpected" if is_pending else "passed"] += 1
				print("  %s  %s (%.1fs)" % ["UNEXPECTED PASS" if is_pending else "PASS", label, seconds])
			else:
				counts["pending" if is_pending else "failed"] += 1
				print("  %s  %s (%.1fs)" % ["PENDING" if is_pending else "FAIL", label, seconds])
				for failure in case.failures:
					print("          ", failure)
	# On its OWN line, never inside the summary the gate parses (that line's four numbers ARE the gate).
	if not allowed.is_empty():
		print("\nexpected engine messages: %d seen, from %d allowed pattern(s) in %s"
				% [allowed_total, allowed.size(), ALLOWLIST])
	print("\nscenarios: %d passed, %d failed, %d pending, %d unexpectedly passing" % [counts["passed"], counts["failed"],
			counts["pending"], counts["unexpected"]])
	quit(1 if counts["failed"] + counts["unexpected"] > 0 else 0)
