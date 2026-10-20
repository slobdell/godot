extends SceneTree
## Round 36 (orders O1): the herringbone-across-a-lane lab stage (tests/control/herringbone_lane_stage.gd), one run a process.
##   godot --headless --fixed-fps 60 --path . --script res://tests/control/herringbone_lane_probe.gd -- --lead=0 --seconds=40 [--deploy-pass=on]
##   HERRINGBONE_LAB {"lead_m", "pass", "step", "sirens_s", "hunters2_s", "deployed_s", "held_s", "held_worst_s", "pass_waits"}

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
	print("NATIVE %s | switch %s" % [NativeBridge.describe(), "on" if BrainSwitches.native else "off"])
	var report := await HerringboneLaneStage.run(case, float(_flag("seconds", "40")), float(_flag("lead", "0")), float(_flag("goal-dx", "0")), float(_flag("goal-dz", "0")))
	print("HERRINGBONE_LAB " + JSON.stringify(report))
	case.teardown()
	quit(0)
