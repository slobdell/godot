extends SceneTree
## Round 22 (brains B1): the SITTING DUCK, from his recording (build/recordings/2026-10-07T12-58-28.jsonl, foundry, seed
## 73429, main 5beb038f): `Rust_Hunters_2`, a Limousine Gunship (pulse cannon, 70 m, effective 55), stood on its post
## at (-6.7, 51.7) from tick 1096 until it died at 1771 (22.5 s, 36 hits, shield 200 + hp 240 = 440 to nothing) while
## `Green_Charlie_1`, a Condemned Lancer (laser, 90 m), lased it from ~86 m (census tick 1396: (-92.4, 52.4)).
## Here: the gunship in its element on a post (`--task=hold`: the leader's hold; `ambush`: the task it really had,
## recorded at tick 841), the Lancer on standing orders at 84 m (inside its own sight of 85 m, as his other crews spotted
## for it in his game), and the gunship's answer to fire it cannot return.
##
##   godot --headless --path . --script res://tests/tactics/duck_probe.gd -- --seed=1 --duck=on|off --side=cpu|his
##         --task=ambush|hold --lancers=1 (2-3: outgunned) --seconds=30 --trace=on
##   --side=his: the gunship's team is the player's and the hold is HIS order (C22.6: it holds, the readout says why).
##   DUCK_PROBE {"seed", "duck", "side", "task", "lancers", "first_hit_s", "moved_s" (first > 2 m off its post; -1 never),
##               "react_s" (moved - first hit), "outcome" (close | cover | fall_back | held | ""), "end_m" (to the
##               nearest Lancer), "in_own_range", "out_of_reach", "covered" (no clear sight line from a living Lancer), "answered" (any of the three),
##               "unhit_s" (seconds since its last hit, at the end), "lost"
##               (shield + hp), "alive", "died_s", "readout", "lancers_lost"}


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
	UnansweredFire.ENABLED = _flag("duck", "on") != "off"
	UnansweredFire.URGENT_ENABLED = _flag("duck-urgent", "on") != "off"  # round 23 (B3): the arm
	var side := _flag("side", "cpu")
	var task_verb := _flag("task", "ambush")
	var trace := _flag("trace", "off") == "on"
	var report := await DuckStage.run(case, seed_value, side, task_verb, int(_flag("lancers", "1")),
			float(_flag("seconds", "30")), trace)
	report["duck"] = "on" if UnansweredFire.ENABLED else "off"
	print("DUCK_PROBE " + JSON.stringify(report))
	case.teardown()
	quit(0)
