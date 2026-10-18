class_name FreshStage
extends RefCounted
## Round 33 (native, main de6d3266 red on builder2): a twin stage with path floors runs in its OWN fresh Godot process,
## as brains' f8cf6476 runs test_tactics_body's arms. In one process a stage reads by what ran before it: the Sumps'
## parked refusals were 129 run alone, 47 in builder0's check, 6 and then 0 in builder2's 16 shards, and foundry's latch
## 0 there (every twin 0 mismatches each time). What a match leaves behind (the physics server's bodies, statics a new
## match does not clear) branches the run. In a fresh child, with `--fixed-fps`, the counts are a function of the stage
## alone, so its floors can be counts again.
##
## A test opts in with its first line: `if FreshStage.parent(self, "test_name"): return`. In the runner's process
## that runs the child and stops there. In the child (tests/native/fresh_stage_child.gd) `in_child` is true, so the
## same method runs its body. The child's failures (asserts, engine messages, the leak guard) come back as this test's
## failures, and its printed lines are printed here, so the log keeps the stage's counts.

const CHILD := "res://tests/native/fresh_stage_child.gd"
const CHILD_TIMEOUT_S := "1500"
const MARK := "FRESH_STAGE "
static var in_child := false


## True when the stage ran in a child (the caller returns); false inside the child (the caller runs its body).
static func parent(case: TestCase, method: String) -> bool:
	if in_child:
		return false
	var out: Array = []
	var started := Time.get_ticks_msec()
	var code := OS.execute("timeout", [CHILD_TIMEOUT_S, OS.get_executable_path(), "--headless", "--fixed-fps",
			str(SimClock.TICK_RATE), "--path", ProjectSettings.globalize_path("res://"), "--script", CHILD, "--",
			"--case=%s" % String(case.get_script().resource_path), "--stage=%s" % method], out, true)
	var text := "\n".join(PackedStringArray(out.map(func(line: Variant) -> String: return str(line))))
	var report: Variant = null
	for line in text.split("\n"):
		if line.begins_with(MARK):
			report = JSON.parse_string(line.trim_prefix(MARK))
		elif line.strip_edges() != "":
			print(line)
	print("fresh stage %s: child exit %d in %.1f s" % [method, code, (Time.get_ticks_msec() - started) / 1000.0])
	if not report is Dictionary:
		case.failures.append("the fresh %s child printed no report (exit %d; timeout %s s): %s" % [method, code,
				CHILD_TIMEOUT_S, text.right(600)])
		return true
	for failure: String in (report as Dictionary).get("failures", []):
		case.failures.append("(fresh process) " + failure)
	if code != 0:
		case.failures.append("the fresh %s child exited %d" % [method, code])
	return true
