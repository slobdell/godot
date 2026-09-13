extends SceneTree
## Headless test runner: `make test`.
##
## Discovers res://tests/**/test_*.gd (each extends TestCase), runs every method
## named test_* on a fresh instance, and exits non-zero if anything failed.
## Deliberately tiny and dependency-free; see _agents/verification.md.

const TEST_ROOT := "res://tests"


func _initialize() -> void:
	# Defer so the SceneTree is fully running (physics frames tick) before tests start.
	_run.call_deferred()


func _run() -> void:
	var passed := 0
	var failed := 0
	for path in _discover(TEST_ROOT):
		var script: GDScript = load(path)
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case.tree = self
			await case.call(method_name)
			case.teardown()
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
