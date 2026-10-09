extends SceneTree
## Round 24 (stretch c): what one ElementFeed.context costs, both arms interleaved in ONE process (the build box's load
## swings a 50 v 50 run's ticks by 2x, which no n = 1 pair survives). A five-crew element moving in formation on the
## yard; every call is a cache MISS (the element's stamp is moved first), as a think between two element updates is.
##   godot --headless --path . --script res://tests/tactics/feed_bench.gd -- --rounds=20 --calls=500
##   FEED_BENCH {"off_us", "on_us", "ratio", ...}

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
	var lab := TacticsLab.create(case, 3, "yard")
	var names: Array = []
	for i in 5:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_F_%d" % (i + 1), Vector3(-24.0 + 8.0 * i, 0.0, 60.0), PI, "law_tank").name))
	await lab.start()
	var element := lab.elements.form(names, "Alpha")
	element.assign({"verb": "move", "to": [0.0, -40.0], "drills": false})
	for tick in 90:
		await lab.step()
	var rounds := int(_flag("rounds", "20"))
	var calls := int(_flag("calls", "500"))
	var totals := {"off": 0, "on": 0}
	for r in rounds:
		for arm: String in (["off", "on"] if r % 2 == 0 else ["on", "off"]):
			ElementFeed.FEED_CACHE = arm == "on"
			var started := Time.get_ticks_usec()
			for c in calls:
				element._state_stamp += 1
				ElementFeed.context(lab.elements, String(names[c % names.size()]), "move")
			totals[arm] += Time.get_ticks_usec() - started
	# The parts: the full state() and the lean view alone (a miss each time).
	var parts := {"state": 0, "view": 0, "per_crew_with_shared": 0}
	var view := element._feed_view()
	for r in rounds:
		var t0 := Time.get_ticks_usec()
		for c in calls:
			element.state()
		parts["state"] += Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		for c in calls:
			element._feed_view()
		parts["view"] += Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		ElementFeed.FEED_CACHE = true
		var shared := ElementFeed._shared(element)
		for c in calls:
			ElementFeed._normalize(element, String(names[c % names.size()]), "move", shared)
		parts["per_crew_with_shared"] += Time.get_ticks_usec() - t0
	var n := float(rounds * calls)
	for key: String in parts:
		print("FEED_PART %s %.2f us" % [key, float(parts[key]) / n])
	var off_us: float = float(totals["off"]) / n
	var on_us: float = float(totals["on"]) / n
	print("FEED_BENCH " + JSON.stringify({"off_us": snappedf(off_us, 0.01), "on_us": snappedf(on_us, 0.01),
			"ratio": snappedf(on_us / off_us, 0.001), "calls_per_arm": int(n), "host": OS.get_environment("HOSTNAME")}))
	lab.dispose()
	case.teardown()
	quit(0)
