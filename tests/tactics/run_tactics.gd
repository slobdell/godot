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
		_begin()
		var near: Dictionary = await TacticsScenarios.near_ambush(case)
		_record("near_ambush", near)
		_expect(near, "drills", "near ambush", (near["drills"] as Array).has("near_ambush"))
		_expect(near, "drills", "assault through", (near["drills"] as Array).has("assault_through"))
		_expect(near, "through_tick", "the element drove through the ambush", int(near["through_tick"]) > 0)
	if _wanted("far_ambush", filter):
		_begin()
		var far: Dictionary = await TacticsScenarios.far_ambush(case)
		_record("far_ambush", far)
		_expect(far, "drills", "react to contact", (far["drills"] as Array).has("react_to_contact"))
		_expect(far, "drills", "far ambush", (far["drills"] as Array).has("far_ambush"))
		_expect(far, "off_axis_m", "one half went round them", float(far["widest_lateral"]) > 20.0)
		_expect(far, "held_the_line_m", "while the base of fire held the line of contact",
				float(far["held_the_line_m"]) < 12.0)
	if _wanted("bounding", filter):
		_begin()
		var bound: Dictionary = await TacticsScenarios.bounding(case)
		_record("bounding", bound)
		_expect(bound, "set_fraction", "one element was set while the other moved",
				float(bound["set_fraction"]) > 0.3)
		_expect(bound, "advanced_m", "and the element still got forward", float(bound["advanced_m"]) > 20.0)
	if _wanted("break_contact", filter):
		_begin()
		var away: Dictionary = await TacticsScenarios.break_contact(case)
		_record("break_contact", away)
		_expect(away, "drills", "break contact", (away["drills"] as Array).has("break_contact"))
	if _wanted("herringbone", filter):
		_begin()
		var halt: Dictionary = await TacticsScenarios.herringbone(case)
		_record("herringbone", halt)
		_expect(halt, "formation", "halted in a herringbone", String(halt["formation"]) == "herringbone")
		_expect(halt, "left/right", "watching both flanks", int(halt["left"]) > 0 and int(halt["right"]) > 0)


func _measure(filter: String) -> void:
	if _wanted("formation", filter):
		for trial in [["wedge", 14.0, "tank"], ["line", 14.0, "tank"], ["column", 14.0, "tank"],
				["wedge", 3.0, "tank"], ["wedge", 14.0, "artillery"], ["wedge", 3.0, "artillery"]]:
			_begin()
			var seconds := 20.0 if String(trial[2]) == "tank" else 30.0
			var values: Dictionary = await TacticsScenarios.formation_trial(case, String(trial[0]),
					float(trial[1]), seconds, String(trial[2]))
			_record("formation_%s_%dm_vs_%s" % [trial[0], int(trial[1]), trial[2]], values)
	if _wanted("technique", filter):
		for technique in ["traveling", "traveling_overwatch", "bounding_overwatch"]:
			_begin()
			var values: Dictionary = await TacticsScenarios.technique_trial(case, String(technique))
			_record("technique_%s" % technique, values)
	if _wanted("halt", filter):
		for formation in ["herringbone", "column"]:
			_begin()
			var values: Dictionary = await TacticsScenarios.halt_trial(case, String(formation))
			_record("halt_%s" % formation, values)


## A fresh TestCase per scenario (it owns and frees the nodes the scenario adds).
func _begin() -> void:
	if case != null:
		case.teardown()
	case = TestCase.new()
	case.tree = self


func _record(label: String, values: Dictionary) -> void:
	case.teardown()
	results[label] = values
	print("TACTICS %s %s" % [label, JSON.stringify(values)])


func _expect(values: Dictionary, key: String, what: String, ok: bool) -> void:
	if not ok:
		failures.append("%s: %s (%s)" % [what, JSON.stringify(values.get(key)), key])


static func _wanted(label: String, filter: String) -> bool:
	return filter == "" or label.contains(filter)
