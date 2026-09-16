extends SceneTree
## `make tactics-drills` and `make tactics-measure` (doctrine X3/X4): run the battle-drill scenarios and the
## formation measurements headless and faster than real time, print one line each, and write
## build/tactics/measurements.json. The numbers go into _agents/doctrine.md "Measurements".
##
##   --drills     every drill fires on its trigger (exit 1 if one never does)
##   --measure    doctrinal shape vs. the naive one, under identical conditions
##   --filter=x   only scenarios whose name contains x

const OUT := "res://build/tactics"

var case: TestCase
var failures: PackedStringArray = []
var results := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var want_drills := args.has("--drills") or not args.has("--measure")
	var want_measure := args.has("--measure")
	var filter := ""
	for arg in args:
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if want_drills:
		await _drills(filter)
	if want_measure:
		await _measure(filter)
	var file := FileAccess.open("%s/measurements.json" % OUT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(results, "  "))
	for failure in failures:
		print("TACTICS_FAIL ", failure)
	print("TACTICS_DONE failures=", failures.size())
	quit(1 if not failures.is_empty() else 0)


func _drills(filter: String) -> void:
	if _wanted("near_ambush", filter):
		var near := await _scenario("near_ambush", TacticsScenarios.near_ambush(case))
		_expect(near, "drills", "near ambush", (near["drills"] as Array).has("near_ambush"))
		_expect(near, "drills", "assault through", (near["drills"] as Array).has("assault_through"))
		_expect(near, "through_tick", "the element drove through the ambush", int(near["through_tick"]) > 0)
	if _wanted("far_ambush", filter):
		var far := await _scenario("far_ambush", TacticsScenarios.far_ambush(case))
		_expect(far, "drills", "react to contact", (far["drills"] as Array).has("react_to_contact"))
		_expect(far, "drills", "far ambush", (far["drills"] as Array).has("far_ambush"))
		_expect(far, "widest_lateral", "someone maneuvered wide of the guns", float(far["widest_lateral"]) > 25.0)
	if _wanted("bounding", filter):
		var bound := await _scenario("bounding", TacticsScenarios.bounding(case))
		_expect(bound, "set_fraction", "one element was set while the other moved",
				float(bound["set_fraction"]) > 0.3)
		_expect(bound, "advanced_m", "and the element still got forward", float(bound["advanced_m"]) > 20.0)
	if _wanted("break_contact", filter):
		var away := await _scenario("break_contact", TacticsScenarios.break_contact(case))
		_expect(away, "drills", "break contact", (away["drills"] as Array).has("break_contact"))
	if _wanted("herringbone", filter):
		var halt := await _scenario("herringbone", TacticsScenarios.herringbone(case))
		_expect(halt, "formation", "halted in a herringbone", String(halt["formation"]) == "herringbone")
		_expect(halt, "left/right", "watching both flanks", int(halt["left"]) > 0 and int(halt["right"]) > 0)


func _measure(filter: String) -> void:
	if _wanted("formation", filter):
		for trial in [["wedge", 14.0, "tank"], ["line", 14.0, "tank"], ["column", 14.0, "tank"],
				["wedge", 3.0, "tank"], ["wedge", 14.0, "artillery"], ["wedge", 3.0, "artillery"]]:
			var label := "formation_%s_%dm_vs_%s" % [trial[0], int(trial[1]), trial[2]]
			await _scenario(label, TacticsScenarios.formation_trial(case, String(trial[0]), float(trial[1]),
					20.0 if String(trial[2]) == "tank" else 30.0, String(trial[2])))
	if _wanted("technique", filter):
		for technique in ["traveling", "traveling_overwatch", "bounding_overwatch"]:
			await _scenario("technique_%s" % technique, TacticsScenarios.technique_trial(case, technique))
	if _wanted("halt", filter):
		for formation in ["herringbone", "column"]:
			await _scenario("halt_%s" % formation, TacticsScenarios.halt_trial(case, formation))


func _scenario(label: String, result: Variant) -> Dictionary:
	case = TestCase.new()
	case.tree = self
	var values: Dictionary = await result
	case.teardown()
	results[label] = values
	print("TACTICS %s %s" % [label, JSON.stringify(values)])
	return values


func _expect(values: Dictionary, key: String, what: String, ok: bool) -> void:
	if not ok:
		failures.append("%s: %s (%s)" % [what, JSON.stringify(values.get(key)), key])


static func _wanted(label: String, filter: String) -> bool:
	return filter == "" or label.contains(filter)
