extends SceneTree
## Round 23 (brains B0/B1): HIS CASE as a probe (tests/tactics/pace_stage.gd has the stage and the report's fields).
##
##   godot --headless --fixed-fps 60 --path . --script res://tests/tactics/pace_probe.gd -- --seed=1 --arena= (the
##         parade ground's open middle; or yard etc. at the Green spawn) --units=law_tank:law_tank:law_tank:law_tank:law_tank
##         --metres=150 --layout=along|across --shape=line --facing=abreast|goal --seconds=90 --pace=on|off --trace=on
##   PACE_PROBE {"seed", "pace", ..., "formed_m", "formed_s", "rms_m", "lead_speed", "pace_min", "stops", "arrived_s", ...}

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
	var seed_value := int(_flag("seed", "1"))
	ElementPlan.PACE_ENABLED = _flag("pace", "on") != "off"
	ElementPlan.PACE_SPAN_MIN_M = float(_flag("pace-span", str(ElementPlan.PACE_SPAN_MIN_M)))
	var report := await PaceStage.run(case, seed_value, _flag("arena", ""),
			_flag("units", "law_tank:law_tank:law_tank:law_tank:law_tank").split(":"), float(_flag("metres", "150")),
			_flag("layout", "along"), _flag("shape", "line"), float(_flag("seconds", "90")), _flag("facing", "abreast"),
			_flag("trace", "off") == "on")
	report["pace"] = "on" if ElementPlan.PACE_ENABLED else "off"
	print("PACE_PROBE " + JSON.stringify(report))
	print("PACE_PROBE_DONE")
	case.teardown()
	quit(0)
