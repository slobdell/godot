extends SceneTree
## Round 25 (brains F0): HIS CROSSING as a probe (tests/tactics/crossing_stage.gd has the stage and the fields).
##
##   godot --headless --fixed-fps 60 --path . --script res://tests/tactics/crossing_probe.gd -- --seed=1 --arena=crossing
##         --formation=wedge|column --side=green|rust --seconds=90 --unit=law_tank --trace=on
##   CROSSING_PROBE {"seed", "arena", "formation", "crossed", "crossed_s", "point_passes", "seat_passes", ...}

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
	TacticsFlags.requested()  # parse the tactics arms (--seat-nearest=off) before the first seating
	var report := await CrossingStage.run(case, int(_flag("seed", "1")), _flag("arena", "crossing"),
			_flag("formation", "wedge"), _flag("side", "green"), float(_flag("seconds", "90")),
			_flag("unit", "law_tank"), _flag("trace", "off") == "on",
			_flag("drills", "off") == "on")
	report["brains_off"] = _flag("brains-off", "")
	report["arm"] = _flag("arm", "")
	print("CROSSING_PROBE " + JSON.stringify(report))
	print("CROSSING_PROBE_DONE")
	case.teardown()
	quit(0)
