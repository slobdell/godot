extends SceneTree
## Round 27 (brains B0, C27.3): one run of ApproachStage (his attack from a drawn side), for `make approach-series`.
##
##   godot --headless --path . --script res://tests/tactics/approach_probe.gd -- --seed=1 --approach=east|none
##         --seconds=60 --trace=on [--lab-start-tick=N]
##   APPROACH_PROBE {"seed", "approach", "in_s", "reach_s", "reach_off_deg", "closest_m", "killed_s", "alive", "start_tick"}


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	var case := TestCase.new()
	case.tree = self
	var approach: Variant = null if _flag("approach", "east") == "none" else ApproachStage.FROM_EAST
	var report := await ApproachStage.run(case, int(_flag("seed", "1")), float(_flag("seconds", "60")), approach,
			_flag("trace", "off") == "on", _flag("arena", "yard_open"), _flag("immortal", "off") == "on", _flag("quiet", "off") == "on", _flag("live", "off") == "on")
	report["start_tick"] = int(_flag("lab-start-tick", str(TacticsLab.START_TICK)))
	print("APPROACH_PROBE " + JSON.stringify(report))
	case.teardown()
	quit(0)
