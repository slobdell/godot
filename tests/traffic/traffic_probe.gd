extends SceneTree
## Round 26 (traffic T0): his two crossing cases as a probe (tests/traffic/traffic_stage.gd has the stage and fields).
##
##   godot --headless --fixed-fps 60 --path . --script res://tests/traffic/traffic_probe.gd -- --seed=1
##         --arena=yard_open|terminus --kind=head|cross --which=both|solo_a|solo_b --seconds=120 --side=green --trace=on
##   TRAFFIC_PROBE {"seed", "arena", "kind", "which", "arrived", "friend_stuck_s", "contacts", ...}

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
	BrainSwitches.ensure_parsed()
	TacticsFlags.requested()
	var report := await TrafficStage.run(case, int(_flag("seed", "1")), _flag("arena", "yard_open"),
			_flag("kind", "head"), _flag("which", "both"), float(_flag("seconds", "120")), _flag("side", "green"),
			_flag("trace", "off") == "on")
	report["brains_off"] = _flag("brains-off", "")
	report["nav_off"] = _flag("nav-off", "")
	print("TRAFFIC_PROBE " + JSON.stringify(report))
	print("TRAFFIC_PROBE_DONE")
	case.teardown()
	quit(0)
