extends SceneTree
## Round 33 (native): one test method in a fresh process (tests/native/fresh_stage.gd says why).
##   godot --headless --fixed-fps 30 --path . --script res://tests/native/fresh_stage_child.gd -- --case=res://tests/test_native_yield.gd --stage=test_the_give_way_in_the_sumps
##   FRESH_STAGE {"failures": [...]}
## The method runs as the runner runs it: a fresh instance, `tree` set, awaited, then the sealed `_teardown()`. The
## engine's messages are reconciled with the case's expectations and the runner's allowlist, as the runner does.

const RUNNER := preload("res://tests/run_tests.gd")


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return ""


func _run() -> void:
	FreshStage.in_child = true
	var errors = RUNNER.ErrorCollector.new()
	OS.add_logger(errors)
	var failures: PackedStringArray = []
	var script: GDScript = load(_flag("case"))
	var stage := _flag("stage")
	var case: TestCase = script.new() if script != null else null
	if case == null or not case.has_method(stage):
		failures.append("no stage %s in %s" % [stage, _flag("case")])
	else:
		case.tree = self
		errors.take()
		await case.call(stage)
		await case._teardown()
		var engine: Dictionary = TestCase.reconcile_engine_messages(errors.take(), case.expected_warnings,
				case.expected_errors, _allowlist())
		failures.append_array(case.failures)
		failures.append_array(engine["failures"] as PackedStringArray)
	print(FreshStage.MARK + JSON.stringify({"failures": failures}))
	quit(0)


func _allowlist() -> PackedStringArray:
	var patterns: PackedStringArray = []
	var file := FileAccess.open(RUNNER.ALLOWLIST, FileAccess.READ)
	if file == null:
		return patterns
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line != "" and not line.begins_with("#"):
			patterns.append(line)
	return patterns
