extends SceneTree
## `make tactics-drills` and `make tactics-measure` (doctrine X3/X4): run the battle-drill scenarios and the
## formation measurements headless and faster than real time, print one line each, and write
## build/tactics/measurements.json. The numbers go into _agents/doctrine.md "Measurements".
##
##   --drills     every drill fires on its trigger (exit 1 if one never does)
##   --measure    doctrinal shape vs. the naive one, under identical conditions
##   --filter=x   only scenarios whose name contains x
##   --idle-face=on|off  TankBrain.IDLE_FACE_NO_PIVOT for the run (round 13, S6)
##   --mutate=bait_any|gangs_no_bait|gangs_encircle  round 14's three mutation runs as flags (round 15, P4): each must
##                turn the gang-pack / bait-chase assertions red (bait without the follower rule; the gangs' table
##                without bait; the gangs' table with encircle)

const OUT := "res://build/tactics"

var case: TestCase
var failures: PackedStringArray = []
var results := {}
var mutate := ""


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
		# Round 13 (squad Q2): the S6 arm, so the drills can be compared with a no-pivot scout's idle face on and off.
		# Round 15 (squad P4): the far-ambush turn-in as it was before (the mutation arm).
		if arg.begins_with("--mutate="):
			mutate = arg.trim_prefix("--mutate=")
			if mutate == "bait_any":
				Drills.BAIT_NEEDS_FOLLOWER = false
		if arg == "--flank-turn-in=distance":
			ElementPlan.FLANK_TURN_IN_BY_BEARING = false
		if arg == "--bait-return=off":
			ElementPlan.BAIT_RETURN = false
		if arg.begins_with("--idle-face="):
			TankBrain.IDLE_FACE_NO_PIVOT = arg.trim_prefix("--idle-face=") == "on"
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
	if _wanted("gang_pack", filter):
		# The same vehicles, the same enemy, the same seed: only the doctrine differs.
		_begin()
		var pack: Dictionary = await TacticsScenarios.gang_pack(case, _gangs())
		_record("gang_pack_gangs", pack)
		_begin()
		var loose: Dictionary = await TacticsScenarios.gang_pack(case, "gangs-no-encircle")
		_record("gang_pack_swarm_only", loose)
		_begin()
		var drilled: Dictionary = await TacticsScenarios.gang_pack(case, "standard")
		_record("gang_pack_standard", drilled)
		# Round 14 (squad Q1): these two assertions were stale from the commit that wrote them (9247ef48, red there on
		# builder0 and at every commit since). The SAME commit measured encircle and switched it off in every shipped
		# table (enemy survival 0.66 with it, 0.19 without), and made bait require a contact that FOLLOWS (its first
		# version lost three of four vehicles luring two dug-in guns). Against these two guns the gangs' design is to
		# fight, not to lure or circle, so that is what is asserted; bait is asserted where it belongs, in bait_chase.
		# "More sides than a standard element" is dropped, not loosened: the same commit found a standard element
		# covers as many arcs by fighting, and the comparison flipped 4-8 arcs across commits on one seed (a coin).
		var pack_drills: Array = pack["drills"]
		_expect(pack, "drills", "against dug-in guns the pack does not lure (a lure needs something that follows)",
				not pack_drills.has("bait"))
		_expect(pack, "drills", "nor circle (encircle is in no shipped table)", not pack_drills.has("encircle"))
		_expect(pack, "drills", "it fights them instead", pack_drills.has("react_to_contact"))
		_expect(pack, "arcs_covered", "and comes at them from more than one side",
				int(pack["arcs_covered"]) >= 3)
	if _wanted("bait_chase", filter):
		# Bait only means anything against something that follows, so measure it against one that does.
		_begin()
		var lured: Dictionary = await TacticsScenarios.gang_pack(case, _gangs(), 26.0, true)
		_record("bait_chase_gangs", lured)
		_begin()
		var straight: Dictionary = await TacticsScenarios.gang_pack(case, "gangs-no-bait", 26.0, true)
		_record("bait_chase_no_bait", straight)
		# Round 14 (squad Q1): the positive half of the gangs' lure, never asserted until now. Only that it FIRES
		# against something that follows, and that the control arm really lacks it -- not that it wins: what the
		# lure is worth is a balance question (C12.6), and on one seed it is reported, not judged.
		_expect(lured, "drills", "against a contact that follows, the gangs send a lure", (lured["drills"] as Array).has("bait"))
		_expect(straight, "drills", "and without the drill they do not", not (straight["drills"] as Array).has("bait"))
	if _wanted("herringbone", filter):
		_begin()
		var halt: Dictionary = await TacticsScenarios.herringbone(case)
		_record("herringbone", halt)
		_expect(halt, "formation", "halted in all-round security",
				["herringbone", "coil"].has(String(halt["formation"])))
		_expect(halt, "left/right", "watching both flanks", int(halt["left"]) > 0 and int(halt["right"]) > 0)
		_expect(halt, "coverage", "with most of the circle covered", float(halt["coverage"]) > 0.8)


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


## The gangs' table, or its mutation (round 15, P4: `--mutate=gangs_no_bait|gangs_encircle`).
func _gangs() -> String:
	return {"gangs_no_bait": "gangs-no-bait", "gangs_encircle": "gangs+encircle"}.get(mutate, "gangs")


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
