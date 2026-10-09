extends SceneTree
## Round 24 (brains R2): his three-squad move as a probe (tests/tactics/body_stage.gd).
##   godot --headless --fixed-fps 60 --path . --script res://tests/tactics/body_probe.gd -- --seed=1 --body=on|off --side=green|rust --seconds=90
##   BODY_PROBE {"seed", "side", "body", "alone_s", "widest_gap_m", "Sirens": {"choice", "arrived_s"}, ..., "arrived_s"}

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	Element.BODY_ENABLED = _flag("body", "on") != "off"
	var report := await BodyStage.run(case, int(_flag("seed", "1")), float(_flag("seconds", "90")), _flag("side", "green") in ["rust", "cpu-rust"], _flag("side", "green").begins_with("cpu"))
	print("BODY_PROBE " + JSON.stringify(report))
	case.teardown()
	quit(0)
