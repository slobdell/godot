extends SceneTree
## Headless test runner: `make test`.
##
## Discovers res://tests/**/test_*.gd (each extends TestCase), runs every method
## named test_* on a fresh instance, and exits non-zero if anything failed.
## Deliberately tiny and dependency-free; see _agents/verification.md.
##
## A script error aborts the test function WITHOUT recording an assertion
## failure, which once let a crashing test print PASS. So every engine/script
## error logged while a test runs also fails that test.

const TEST_ROOT := "res://tests"


## Collects every error the engine logs (script errors, push_error, failed checks).
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
	# Defer so the SceneTree is fully running (physics frames tick) before tests start.
	_run.call_deferred()


func _run() -> void:
	var errors := ErrorCollector.new()
	OS.add_logger(errors)
	var passed := 0
	var failed := 0
	# `make test FILTER=bot` passes --filter=bot: run only tests whose "file::method" contains it.
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	for path in _discover(TEST_ROOT):
		var script: GDScript = load(path)
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			if filter != "" and not ("%s::%s" % [path.get_file().get_basename(), method_name]).contains(filter):
				continue
			var case: TestCase = script.new()
			case.tree = self
			errors.take()
			await case.call(method_name)
			case.teardown()
			for message in errors.take():
				case.failures.append("engine error: " + message)
			var label := "%s::%s" % [path.get_file().get_basename(), method_name]
			if case.failures.is_empty():
				passed += 1
				print("  PASS  ", label)
			else:
				failed += 1
				print("  FAIL  ", label)
				for failure in case.failures:
					print("          ", failure)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


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
