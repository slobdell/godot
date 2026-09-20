extends SceneTree
## Headless test runner: `make test`.
##
## Discovers res://tests/**/test_*.gd (each extends TestCase), runs every method
## named test_* on a fresh instance, and exits non-zero if anything failed.
## Deliberately tiny and dependency-free; see _agents/verification.md.
##
## A script error aborts the test function WITHOUT recording an assertion
## failure, which once let a crashing test print PASS. So every engine/script
## error logged while a test runs also fails that test. For the same reason a file that fails to load, or that has no
## test_ methods at all (what a parse error leaves behind), is reported as a failure instead of being skipped.

const TEST_ROOT := "res://tests"


## Collects every error the engine logs (script errors, push_error, failed checks).
class ErrorCollector extends Logger:
	## Errors and warnings are recorded SEPARATELY. This used to ignore `_error_type` entirely, so every
	## `push_warning` on a production path a test exercised arrived as "engine error: ..." and failed the
	## test with no way to tell the two apart and no way to declare an expected one -- feel's city-block
	## determinism test could not pass as written. Warnings still fail by default; they are now countable,
	## nameable, and declarable with TestCase.expect_warning().
	var entries: Array[Dictionary] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		entries.append({
			"warning": error_type == Logger.ERROR_TYPE_WARNING,
			"text": "%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function],
		})
		_mutex.unlock()

	func take() -> Array[Dictionary]:
		_mutex.lock()
		var taken := entries
		entries = []
		_mutex.unlock()
		return taken


func _initialize() -> void:
	# Defer so the SceneTree is fully running (physics frames tick) before tests start.
	_run.call_deferred()


func _run() -> void:
	var errors := ErrorCollector.new()
	OS.add_logger(errors)
	var passed := 0
	var failed := 0
	var total_engine_errors := 0
	var total_engine_warnings := 0
	# `make test FILTER=bot` passes --filter=bot: run only tests whose "file::method" contains it.
	# `|` separates ALTERNATIVES -- FILTER="bot|relay" runs tests matching either. It is not a regex, and
	# saying so matters: `make test FILTER="a|b"` used to reach a shell unquoted and exit 127 without running
	# anything (it bit combat twice on 2026-09-20), and merely quoting it through would have run nothing at
	# all while reporting success, which is worse.
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	# T1 (metrics, round 9): --shard=I/N runs only every Nth file, so `make check` can run the suite across
	# several processes instead of one. Round-robin over the SORTED discovery order, so the assignment is
	# deterministic and every shard gets a mix of cheap and expensive files rather than one shard getting all of
	# `tests/ai_scenarios/`. Absent, everything below behaves exactly as it always has -- including the final
	# line, which stays the bare `N passed, M failed` an unsharded run has always printed.
	var shard := -1
	var shards := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shard="):
			var parts := arg.trim_prefix("--shard=").split("/")
			if parts.size() == 2:
				shard = int(parts[0])
				shards = maxi(1, int(parts[1]))
	var filter_parts := PackedStringArray()
	for part in filter.split("|", false):
		var trimmed := part.strip_edges()
		if trimmed != "":
			filter_parts.append(trimmed)
	var discovered := _discover(TEST_ROOT)
	var mine := PackedStringArray()
	for index in discovered.size():
		if shard < 0 or index % shards == shard:
			mine.append(discovered[index])
	for path in mine:
		var script: GDScript = load(path)
		# A file that doesn't compile loads as null, and one whose parse failed has no test methods: both used to be
		# skipped silently, so a broken test file read as "everything passed" (ai, 2026-09-16).
		if script == null:
			failed += 1
			print("  FAIL  ", path.get_file().get_basename(), "::<file>")
			print("          the file did not load (a parse error, or it isn't a script)")
			continue
		var test_methods := 0
		for method in script.get_script_method_list():
			if String(method["name"]).begins_with("test_"):
				test_methods += 1
		var stem := path.get_file().get_basename()
		# tests/test_case.gd is the base class every case extends, not a case itself.
		if test_methods == 0 and stem != "test_case" and _matches(stem, filter_parts):
			failed += 1
			print("  FAIL  ", stem, "::<file>")
			print("          no test_ methods: a parse error leaves a loadable script with none")
			continue
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			if not _matches("%s::%s" % [path.get_file().get_basename(), method_name], filter_parts):
				continue
			var case: TestCase = script.new()
			case.tree = self
			errors.take()
			await case.call(method_name)
			# AWAITED: `teardown()` drains the navigation map, and that needs frames. Un-awaited it would return at
			# once and drain after the NEXT test had started -- a hook that looks wired up and does nothing.
			await case.teardown()
			var engine: Dictionary = TestCase.reconcile_engine_messages(errors.take(), case.expected_warnings)
			total_engine_errors += int(engine["errors"])
			total_engine_warnings += int(engine["warnings"])
			var engine_failures: PackedStringArray = engine["failures"]
			case.failures.append_array(engine_failures)
			var label := "%s::%s" % [path.get_file().get_basename(), method_name]
			if case.failures.is_empty():
				passed += 1
				print("  PASS  ", label)
			else:
				failed += 1
				print("  FAIL  ", label)
				for failure in case.failures:
					print("          ", failure)
	# A shard prints a DISTINCT line and never the bare one, so that in a sharded run there is exactly one
	# `N passed, M failed` in the output -- the total, printed by the make recipe after it adds the shards up.
	# The orchestrator reads that line and nothing else (lesson 28); several of them would be worse than none.
	# The engine tally goes on its OWN line, never inside the summary the orchestrator reads (lesson 28). The
	# make recipe sums the sharded ones the same way it sums the rest.
	if shard >= 0:
		print("\nSHARD-ENGINE %d/%d: %d errors, %d warnings" % [shard, shards, total_engine_errors, total_engine_warnings])
		print("SHARD %d/%d: %d files, %d passed, %d failed" % [shard, shards, mine.size(), passed, failed])
	else:
		print("\nengine: %d errors, %d warnings" % [total_engine_errors, total_engine_warnings])
		print("%d passed, %d failed" % [passed, failed])
	# A FILTER THAT MATCHES NOTHING IS NOT A PASS. `make test FILTER=typo` printed "0 passed, 0 failed" and
	# exited 0, so a mistyped filter read exactly like a clean run of the tests you meant -- the same shape as
	# `lint` over zero files, and the reason a green filtered run was never evidence of anything.
	if not filter_parts.is_empty() and passed + failed == 0:
		print("\nFILTER MATCHED NO TESTS: nothing contains %s." % [", ".join(filter_parts)])
		print("  This is a failure, not an empty pass: a run of zero tests says nothing about the code.")
		print("  The filter is a SUBSTRING of \"file::method\" (use | for alternatives), not a regex.")
		quit(1)
	quit(1 if failed > 0 else 0)


## Does `label` match any alternative? No alternatives means everything matches.
static func _matches(label: String, parts: PackedStringArray) -> bool:
	if parts.is_empty():
		return true
	for part in parts:
		if label.contains(part):
			return true
	return false


func _discover(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		found.append_array(_discover(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	found.sort()
	return found
