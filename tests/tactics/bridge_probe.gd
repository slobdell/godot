extends SceneTree
## Round 24 (brains R0/R1): HIS BRIDGE CASE as a probe (tests/tactics/bridge_stage.gd has the stage and the fields).
##
##   godot --headless --fixed-fps 60 --path . --script res://tests/tactics/bridge_probe.gd -- --seed=1 --arena=locks
##         --units=law_tank:law_tank:law_tank:law_tank --side=green|rust --guns=3 --gun=syn_lancer --seconds=90 --trace=on --wet-ground=on|off
##   BRIDGE_PROBE {"seed", "arena", "side", "rim_s", "rim_total_s", "rim_crews", "wet_hops", "crossed", ...}

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
	SlotGround.WET_ENABLED = _flag("wet-ground", "on") != "off"
	var report := await BridgeStage.run(case, int(_flag("seed", "1")), _flag("arena", "locks"),
			_flag("units", "law_tank:law_tank:law_tank:law_tank").split(":"), _flag("side", "green"),
			int(_flag("guns", "3")), _flag("gun", "syn_lancer"), float(_flag("seconds", "90")), _flag("trace", "off") == "on")
	report["brains_off"] = _flag("brains-off", "")
	report["wet_ground"] = "on" if SlotGround.WET_ENABLED else "off"
	report["wet_hops_cut"] = TankBrain.wet_hops_cut
	print("BRIDGE_PROBE " + JSON.stringify(report))
	print("BRIDGE_PROBE_DONE")
	case.teardown()
	quit(0)
