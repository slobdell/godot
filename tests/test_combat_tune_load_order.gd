extends TestCase
## Round 9: **a tune knob must reach the predicate, and the case that broke is only reachable in a fresh process.**
##
## `apply_tuning` used to write statics on four other classes. A write to another class's static at class-load time
## is undone by that class's own initialiser whenever the load order puts it second -- so the knob parsed, returned
## `""`, printed nothing, and did nothing. It cost this round a knob A/B, an exoneration, a "second cause" that
## never existed, and (feel, on builder0) a timing bench whose census walked 90 -> 77 while the freeze it had
## requested was off in 13 of 13 phases.
##
## Two assertions here, and they fail differently on purpose. Neither stands in for the other.

const PROBE := "res://tests/probes/tune_load_order.gd"
## A child that hangs must fail this test by name rather than stall the whole shard.
const CHILD_TIMEOUT_S := "120"


## Runs the probe in a FRESH process with the environment set explicitly -- `env TUNE=...` for the treatment,
## `env -u TUNE` for the control -- rather than trusting inheritance in either direction, so this suite's own
## `TUNE` (set or not) cannot reach the child and let it pass for the wrong reason.
func _probe(spec: String) -> String:
	var args: Array = [CHILD_TIMEOUT_S, "env"]
	if spec.is_empty():
		args.append_array(["-u", "TUNE"])
	else:
		args.append("TUNE=%s" % spec)
	args.append_array([OS.get_executable_path(), "--headless", "--path",
			ProjectSettings.globalize_path("res://"), "-s", PROBE])
	var out: Array = []
	var code := OS.execute("timeout", args, out, true)
	var text := "\n".join(PackedStringArray(out.map(func(line: Variant) -> String: return str(line))))
	assert_true(code != 124, "the probe child finished inside %ss (exit %d)" % [CHILD_TIMEOUT_S, code])
	for line in text.split("\n"):
		if line.begins_with("TUNE_PROBE "):
			return line.strip_edges()
	assert_true(false, "the probe printed its line (exit %d): %s" % [code, text.substr(0, 400)])
	return ""


## (2) THE LOAD-ORDER CASE, in a fresh process — the one that actually broke, and the one no test method can reach.
## This is the afternoon's hand-run `tune_order_probe.gd` promoted from a scratch file to a test.
func test_a_knob_set_in_the_environment_reaches_the_predicate_in_a_fresh_process() -> void:
	var treated := _probe("match.no_damage=1")
	var control := _probe("")
	print("MEASURE tune_load_order treatment: %s" % treated)
	print("MEASURE tune_load_order control:   %s" % control)
	# ⚠ THE ARMS MUST DIFFER BEFORE EITHER VALUE IS READ. A single child printing `true` is the exact pattern that
	# fooled everyone for a day: it is equally what a working knob and a knob nobody selected would print, if the
	# default happened to be true. A pair that prints true and false is the arm proof; one line is a hope.
	assert_true(treated != control, "the two arms DIFFER (%s vs %s)" % [treated, control])
	# ...and the child saw the environment THIS test set, not one it inherited.
	assert_true(treated.contains("saw TUNE='match.no_damage=1'"), "the treated child saw its own TUNE: %s" % treated)
	assert_true(control.contains("saw TUNE=''"), "the control child saw none: %s" % control)
	# Only now the values, read through the same call `Tank.take_hit` gates on.
	assert_true(treated.contains("no_damage_on=true"), "the knob reaches the predicate: %s" % treated)
	assert_true(control.contains("no_damage_on=false"), "and is absent without it: %s" % control)


## (1) THE DEFERRAL, NOT THE ORDERING — named for what it is. `_ensure_env_tuning()` applying at first read rather
## than in `_static_init` is the structural property the fix rests on, and this asserts it directly so that a
## refactor which re-inlines the application fails here instead of silently reinstating the bug. It does NOT
## reproduce the load order; only the child above does.
func test_the_env_spec_is_applied_at_first_read_and_only_once() -> void:
	var was_spec: String = Units._env_spec
	var was_applied: bool = Units._env_applied
	var had := Units.tuning.has("no_damage")
	Units.tuning.erase("no_damage")
	Units._env_spec = "match.no_damage=1"
	Units._env_applied = false
	assert_true(not Units.tuning.has("no_damage"), "setup: the knob is absent before anything reads a tune")
	assert_true(Armor.no_damage_on(), "reading the predicate APPLIES the pending spec")
	assert_true(Units.tuning.has("no_damage"), "and it landed in Units' own dictionary, not a foreign static")
	# Once only: a second read must not re-apply, or a test that erased a knob would have it restored under it.
	Units.tuning.erase("no_damage")
	assert_true(not Armor.no_damage_on(), "a second read does not re-apply (the guard is set before applying)")
	Units._env_spec = was_spec
	Units._env_applied = was_applied
	if not had:
		Units.tuning.erase("no_damage")
