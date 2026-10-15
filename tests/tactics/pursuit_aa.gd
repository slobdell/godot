extends SceneTree
## Round 31 (brains B5c-v5, C31.6): the pursuit test's OWN margin over seeds. `test_tactics_pursuit`'s stage exactly (its
## `_pursue`, five gang scouts on a spotter at `--speed`), at `--seed`, with each crew's start moved `--nudge` metres
## (0 = the test as written; the A/A's second arm moves every start 0.25 m: a change that should decide nothing, as
## B5c-v4's `near` changed two crews' opening seats). Both arms run with every brains switch as the tree has it.
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/tactics/pursuit_aa.gd -- --speed=8 --seed=1 --nudge=0
##   PURSUIT_AA {"speed", "seed", "nudge", "pass", "closing_worst_m", "closing_margin_m", "reversal_worst_deg",
##               "reversal_margin_deg", "let_go_at", "lived_s", "killed_by", "closing_at", "reversal_at"}

const PURSUIT := preload("res://tests/test_tactics_pursuit.gd")


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	BrainSwitches.ensure_parsed()
	var test = PURSUIT.new()
	test.tree = self
	var speed := float(_flag("speed", "8"))
	var seed_value := int(_flag("seed", "3"))
	var nudge := float(_flag("nudge", "0"))
	# The test's own durations: 30 s at 8 m/s, 25 s at 18 m/s.
	var seconds := 30.0 if speed < 12.0 else 25.0
	var result: Dictionary = await test._pursue(speed, seconds, seed_value, 70.0, "gang_scout", nudge)
	var closing := float(result["closing_worst_m"])
	var reversal := float(result["reversal_worst_deg"])
	var report := {"speed": speed, "seed": seed_value, "nudge": nudge,
			"pass": closing <= PURSUIT.CLOSING_SLACK_M and String(result["let_go_at"]) == ""
					and reversal <= PURSUIT.REVERSAL_DEG,
			"closing_worst_m": closing, "closing_margin_m": snappedf(PURSUIT.CLOSING_SLACK_M - closing, 0.1),
			"reversal_worst_deg": reversal, "reversal_margin_deg": snappedf(PURSUIT.REVERSAL_DEG - reversal, 1.0),
			"let_go_at": result["let_go_at"], "lived_s": result["lived_s"], "killed_by": result["killed_by"],
			"closing_at": result["closing_at"], "reversal_at": result["reversal_at"]}
	print("PURSUIT_AA " + JSON.stringify(report))
	quit(0)
