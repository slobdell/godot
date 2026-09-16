extends SceneTree
## Behavior scenario runner: `make ai-scenarios` (FILTER=substring). Runs every test_* method in
## res://tests/ai_scenarios/scenario_*.gd, under --fixed-fps 60 so battles run faster than real time.
##
## A scenario script lists behaviors that aren't built yet in `const PENDING := ["test_..."]`. A pending
## scenario is EXPECTED to fail (it prints PENDING and the reason); if it passes, the run fails with
## "UNEXPECTED PASS" so the behavior gets promoted (removed from PENDING, maybe added to the quick subset
## in tests/test_ai_scenarios.gd). Engine errors fail a scenario, like tests/run_tests.gd.

const ROOT := "res://tests/ai_scenarios"


class ErrorCollector extends Logger:
	var messages: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		messages.append("%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var taken := messages
		messages = PackedStringArray()
		_mutex.unlock()
		return taken


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var errors := ErrorCollector.new()
	OS.add_logger(errors)
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
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			var label := "%s::%s" % [file.get_basename(), method_name]
			if not method_name.begins_with("test_") or (filter != "" and not label.contains(filter)):
				continue
			var case: TestCase = script.new()
			case.tree = self
			errors.take()
			var started := Time.get_ticks_msec()
			await case.call(method_name)
			case.teardown()
			for message in errors.take():
				case.failures.append("engine error: " + message)
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
	print("\nscenarios: %d passed, %d failed, %d pending, %d unexpectedly passing" % [counts["passed"], counts["failed"],
			counts["pending"], counts["unexpected"]])
	quit(1 if counts["failed"] + counts["unexpected"] > 0 else 0)
