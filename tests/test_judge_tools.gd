extends TestCase
## Round 30 (sizing, C30.10): the judge tools' own python suite (tools/judge/test_*.py: the stats core, the row readers,
## the inventory, the CP-N table, size.py, sequential.py, aa.py) runs inside `make test`, so `make check` carries it.
##
## It FAILS LOUDLY on every way a suite can read as green without running (the orchestrator's ruling, 2026-10-14):
## no python3 on the box (OS.execute cannot start it), a module import error (unittest exits non-zero), or a suite that
## collected nothing ("Ran 0 tests" is OK to unittest and a lie to us). ~13 s on the laptop, pure python, no Godot run.

const MIN_TESTS := 40  # the suite had 61 at the time of writing; a collection that shrinks past this is a broken import
const CHILD_TIMEOUT_S := 300


func test_the_judge_python_suite_passes() -> void:
	var tools_dir := ProjectSettings.globalize_path("res://tools/judge")
	var out: Array = []
	var code := OS.execute("timeout", [str(CHILD_TIMEOUT_S), "python3", "-m", "unittest", "discover", "-s", tools_dir,
			"-p", "test_*.py"], out, true)
	var text := "\n".join(PackedStringArray(out.map(func(line: Variant) -> String: return str(line))))
	assert_true(code != -1, "python3 (and timeout) could be started: OS.execute returned -1, so the suite NEVER RAN")
	assert_true(code != 124, "the suite finished inside %d s (exit 124 is the timeout)" % CHILD_TIMEOUT_S)
	var ran := _ran_count(text)
	assert_true(ran >= MIN_TESTS, "unittest collected %d tests (need >= %d; 0 means an import failed or the path is wrong): %s" % [
			ran, MIN_TESTS, text.substr(maxi(0, text.length() - 1200))])
	assert_true(code == 0 and (text.contains("\nOK") or text.ends_with("OK")),
			"the judge suite is green (exit %d): %s" % [code, text.substr(maxi(0, text.length() - 1600))])
	print("MEASURE judge_tools: %d python tests, exit %d" % [ran, code])


func _ran_count(text: String) -> int:
	var re := RegEx.new()
	re.compile("Ran (\\d+) tests?")
	var m := re.search(text)
	return int(m.get_string(1)) if m else 0
