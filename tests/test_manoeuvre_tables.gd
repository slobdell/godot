extends TestCase
## Round 32 (R32.7): manoeuvre's own python table tests (tests/manoeuvre/test_*.py) run inside `make test`, so `make
## check` carries them. Today that is pinned_table.py's STUCK reading restarting on a new goal (the s303 Green_S0_4
## case). Fails loudly the ways test_judge_tools.gd does: no python3, an import error, or nothing collected.

const MIN_TESTS := 4
const CHILD_TIMEOUT_S := 120


func test_the_manoeuvre_table_suite_passes() -> void:
	var dir := ProjectSettings.globalize_path("res://tests/manoeuvre")
	var out: Array = []
	var code := OS.execute("timeout", [str(CHILD_TIMEOUT_S), "python3", "-m", "unittest", "discover", "-s", dir,
			"-p", "test_*.py"], out, true)
	var text := "\n".join(PackedStringArray(out.map(func(line: Variant) -> String: return str(line))))
	assert_true(code != -1, "python3 (and timeout) could be started: OS.execute returned -1, so the suite NEVER RAN")
	assert_true(code != 124, "the suite finished inside %d s (exit 124 is the timeout)" % CHILD_TIMEOUT_S)
	var ran := _ran_count(text)
	assert_true(ran >= MIN_TESTS, "unittest collected %d tests (need >= %d): %s" % [ran, MIN_TESTS, text.substr(maxi(0, text.length() - 1200))])
	assert_true(code == 0 and (text.contains("\nOK") or text.ends_with("OK")),
			"the manoeuvre table suite is green (exit %d): %s" % [code, text.substr(maxi(0, text.length() - 1600))])
	print("MEASURE manoeuvre_tables: %d python tests, exit %d" % [ran, code])


func _ran_count(text: String) -> int:
	var re := RegEx.new()
	re.compile("Ran (\\d+) tests?")
	var m := re.search(text)
	return int(m.get_string(1)) if m else 0
