extends TestCase
## Round 34 (planner, C34.6): a rematch in ONE process plays out exactly as the first match. Replays and the relay-only
## network both need a match to replay; ArmyLoop's REMATCH reloads main.tscn in the same process. It did not: Traffic's
## solve stagger read the engine's physics frame mod 6, a counter that never resets, so a rematch started at another
## phase and branched (builder0, 918ede503: 12 of 12 rematches; references/round34/planner/rematch/diagnosis.md).
##
## A child process (the suite's own phase is whatever ran before) runs the sim-baseline match through main.tscn twice
## (tests/planner/rematch_probe.gd), the rematch started 1 frame past a multiple of 60 frames after the first, so a
## decision keyed to the engine's frame counter with any period dividing 60 sees another phase. Every tank's pose,
## velocities and command are compared every tick through TICKS. Without the fix it fails at tick ~250.

const TICKS := 600
const CHILD_TIMEOUT_S := "300"


func test_a_rematch_in_one_process_plays_out_the_same() -> void:
	var out: Array = []
	var code := OS.execute("timeout", [CHILD_TIMEOUT_S, OS.get_executable_path(), "--headless", "--fixed-fps",
			str(SimClock.TICK_RATE), "--path", ProjectSettings.globalize_path("res://"), "--script",
			"res://tests/planner/rematch_probe.gd", "--", "--match", "--elimination",
			"--green-doctrine=res://doctrines/sim_baseline_green.json", "--rust-doctrine=res://doctrines/sim_baseline_rust.json",
			"--time-limit=40", "--seed=3", "--rematch-runs=2", "--rematch-ticks=%d" % TICKS, "--rematch-phase=1",
			"--rematch-detail=on"], out, true)
	var text := "\n".join(PackedStringArray(out.map(func(line: Variant) -> String: return str(line))))
	assert_true(code == 0, "the rematch child finished inside %ss (exit %d)" % [CHILD_TIMEOUT_S, code])
	var runs: Array = []
	for line in text.split("\n"):
		if line.begins_with("REMATCH "):
			var parsed: Variant = JSON.parse_string(line.trim_prefix("REMATCH "))
			if parsed is Dictionary:
				runs.append(parsed)
	assert_eq(runs.size(), 2, "both matches reported: %s" % text.substr(0, 600))
	if runs.size() != 2:
		return
	print("MEASURE rematch: %s" % JSON.stringify(runs))
	assert_eq(int(runs[1]["first_diff_tick"]), -1, "the rematch replays the first match tick for tick through %d (it parted at %s: %s)"
			% [TICKS, runs[1]["first_diff_tick"], _units(text)])
	assert_eq(String(runs[1]["hash_at_T"]), String(runs[0]["hash_at_T"]), "and the state hashes agree at tick %d" % TICKS)


static func _units(text: String) -> String:
	var lines: Array = []
	for line in text.split("\n"):
		if line.begins_with("REMATCH_UNIT"):
			lines.append(line.substr(0, 300))
	return " | ".join(lines)
