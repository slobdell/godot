extends TestCase
## Doctrine X1/X2/X6: the doctrine table. The same situation must always pick the same formation and
## technique (determinism), a typo in a table must fail loudly, and the factions must actually differ.


func _table(overrides: Dictionary = {}) -> DoctrineTable:
	var data := {"name": "test", "movement": [
			{"when": {"threat": ["likely"]}, "formation": "wedge", "technique": "bounding_overwatch",
			 "why": "contact likely: bound"},
			{"when": {"task": ["hold"]}, "formation": "herringbone", "technique": "traveling", "why": "halted"},
			{"when": {}, "formation": "column", "technique": "traveling", "why": "nothing out there"}]}
	data.merge(overrides, true)
	var parsed := DoctrineTable.parse(data)
	assert_true(parsed.has("table"), "the test table parses: %s" % parsed.get("error", ""))
	return parsed.get("table")


func test_the_same_situation_always_picks_the_same_formation() -> void:
	var table := _table()
	var inputs := {"task": "move", "threat": "likely", "terrain": "open", "composition": "heavy"}
	var first := table.select(inputs)
	var second := table.select(inputs.duplicate())
	assert_eq(first["formation"], "wedge", "contact likely picks the wedge")
	assert_eq(first["technique"], "bounding_overwatch", "and bounds forward")
	assert_eq(second, first, "the same inputs pick the same row every time")
	assert_true(String(first["why"]).length() > 3, "and the row says why, in words a player can read")


func test_rules_are_tried_in_order_and_the_last_one_catches_everything() -> void:
	var table := _table()
	assert_eq(table.select({"task": "hold", "threat": "likely", "terrain": "open", "composition": "heavy"})["formation"],
			"wedge", "an earlier rule wins over a later one that also matches")
	assert_eq(table.select({"task": "move", "threat": "none", "terrain": "open", "composition": "light"})["formation"],
			"column", "and a situation no rule names falls through to the catch-all")


func test_a_broken_table_says_what_is_wrong() -> void:
	assert_true(String(DoctrineTable.parse({"name": "x", "movement": []}).get("error", "")).contains("movement"),
			"a table with no rules is rejected")
	assert_true(String(DoctrineTable.parse({"name": "x", "movement": [
			{"when": {}, "formation": "square", "technique": "traveling", "why": "no"}]}).get("error", "")).contains("formation"),
			"an unknown formation is rejected by name")
	assert_true(String(DoctrineTable.parse({"name": "x", "movement": [
			{"when": {}, "formation": "wedge", "technique": "sprinting", "why": "no"}]}).get("error", "")).contains("technique"),
			"so is an unknown movement technique")
	assert_true(String(DoctrineTable.parse({"name": "x", "movement": [
			{"when": {"mood": ["angry"]}, "formation": "wedge", "technique": "traveling", "why": "no"},
			{"when": {}, "formation": "wedge", "technique": "traveling", "why": "yes"}]}).get("error", "")).contains("mood"),
			"and an unknown condition, so a typo never silently never-matches")
	assert_true(String(DoctrineTable.parse({"name": "x", "movement": [
			{"when": {"threat": ["likely"]}, "formation": "wedge", "technique": "traveling", "why": "y"}]}).get("error", "")).contains("empty 'when'"),
			"a table with no catch-all is rejected: every situation needs a pick")
	assert_true(String(DoctrineTable.parse({"name": "x", "drills": {"near_ambush_metres": 30}, "movement": [
			{"when": {}, "formation": "wedge", "technique": "traveling", "why": "y"}]}).get("error", "")).contains("near_ambush_metres"),
			"and a misspelled drill number is rejected instead of being ignored")


func test_a_table_only_says_what_it_changes() -> void:
	var table := _table({"drills": {"near_ambush_m": 50.0}, "legs": {"bounding_m": 30.0}})
	assert_near(table.drill_number("near_ambush_m"), 50.0, 0.01, "what the table sets, it gets")
	assert_near(table.drill_number("assault_through_m"), DoctrineTable.DRILL_DEFAULTS["assault_through_m"], 0.01,
			"everything else keeps the doctrine default")
	assert_near(table.leg("bounding_m"), 30.0, 0.01, "legs work the same way")
	assert_near(table.spacing("dense"), DoctrineTable.SPACING_DEFAULTS["dense"], 0.01, "and so does spacing")


func test_every_doctrine_table_we_ship_loads_and_covers_every_situation() -> void:
	DoctrineTable.clear_cache()
	var found := 0
	for file_name in DirAccess.get_files_at(DoctrineTable.DIR):
		if not file_name.begins_with("doctrine_") or not file_name.ends_with(".json"):
			continue
		found += 1
		var loaded := DoctrineTable.load_table(file_name.trim_prefix("doctrine_").trim_suffix(".json"))
		assert_true(loaded.has("table"), "%s loads: %s" % [file_name, loaded.get("error", "")])
		if not loaded.has("table"):
			continue
		var table: DoctrineTable = loaded["table"]
		for task in ElementTask.VERBS:
			for threat in DoctrineTable.THREATS:
				for terrain in DoctrineTable.TERRAINS:
					for composition in DoctrineTable.COMPOSITIONS:
						var pick := table.select({"task": task, "threat": threat, "terrain": terrain,
								"composition": composition})
						assert_true(int(pick["rule"]) >= 0, "%s has a rule for %s/%s/%s/%s"
								% [file_name, task, threat, terrain, composition])
	assert_true(found >= 5, "the standard table and one per faction are shipped (found %d)" % found)


## Round 13 (the lead, answer 2: *"Default wedge."*): a plain move with nothing in sight forms a WEDGE in every
## terrain -- dense too: re-measured on the yard, the column stopped first in 5 of 16 paired runs and kept its shape
## better in 0 of 4 cells (squad.md Status, rule pre-registered) -- and the row says so ("wedge (default)"), in the tables his squads actually use (a squad reads its units'
## FACTION table: Condemned and Law; standard for parity). Round 12's S5 measured the wedge settling first in 23 of 32
## paired runs. The Gangs' swarm and the Syndicate's wedge were never a column and are not his squads' default.
func test_a_plain_move_with_nothing_in_sight_is_a_wedge_by_default() -> void:
	DoctrineTable.clear_cache()
	for faction in ["condemned", "law", "standard"]:
		var table := DoctrineTable.for_faction(faction)
		for terrain in DoctrineTable.TERRAINS:
			for composition in DoctrineTable.COMPOSITIONS:
				var pick := table.select({"task": "move", "threat": "none", "terrain": terrain, "composition": composition})
				assert_eq(pick["formation"], "wedge", "%s: a plain move in %s ground (%s) is a wedge"
						% [faction, terrain, composition])
				assert_true(String(pick["why"]).begins_with("wedge (default)"),
						"%s: and the card's reason says it is the default: %s" % [faction, pick["why"]])


func test_the_factions_fight_differently() -> void:
	DoctrineTable.clear_cache()
	var moving := {"task": "move", "threat": "likely", "terrain": "open", "composition": "balanced"}
	var law := DoctrineTable.for_faction("law").select(moving)
	var gangs := DoctrineTable.for_faction("gangs").select(moving)
	var syndicate := DoctrineTable.for_faction("syndicate").select(moving)
	assert_eq(law["technique"], "bounding_overwatch", "the Law advances by bounds")
	assert_eq(gangs["technique"], "traveling", "the gangs never stop to cover each other")
	assert_eq(gangs["formation"], "vee", "they fan out and come at you head on")
	assert_true(syndicate["formation"].begins_with("echelon"), "the Syndicate refuses a flank and keeps the range")
	assert_true(DoctrineTable.for_faction("gangs").drill_number("near_ambush_m")
			> DoctrineTable.for_faction("syndicate").drill_number("near_ambush_m"),
			"a gang charges an ambush from much further out than the Syndicate does")
	assert_true(DoctrineTable.for_faction("condemned").drill_number("break_contact_ratio")
			< DoctrineTable.for_faction("law").drill_number("break_contact_ratio"),
			"the Condemned grind on where the Law would withdraw")
	assert_true(not DoctrineTable.for_faction("gangs").runs_drill("break_contact"),
			"the gangs have no break-contact drill at all")
	assert_eq(DoctrineTable.for_faction("nobody").name, "standard", "an unknown faction falls back to standard doctrine")


func test_a_task_is_checked_before_it_is_accepted() -> void:
	assert_eq(ElementTask.validate({"verb": "move", "to": [10, 20]}), "", "a move with a destination is fine")
	assert_true(ElementTask.validate({"verb": "move"}).contains("needs a destination"), "a move without one is not")
	assert_true(ElementTask.validate({"verb": "attack"}).contains("needs a 'target'"), "an attack needs an enemy")
	assert_true(ElementTask.validate({"verb": "charge", "to": [0, 0]}).contains("verb"), "unknown verbs are refused")
	# REPLACED round 11 (the lead, 2026-09-25: *"they're still not really forming up when I give them a formation to
	# use"*). This used to assert that a task may NOT name a formation — "the leader picks the formation, not the
	# commander" — which was his own 2026-09-16 ruling read strictly. The cost, unwritten until he hit it: the only
	# way to command a shape was the DIRECT path, which dissolves the element, so choosing a shape threw away the
	# leader entirely. A task may now carry one; AUTO (the default, and every CPU task) still leaves the leader to
	# decide, so the ruling stands where it was aimed.
	assert_eq(ElementTask.validate({"verb": "hold", "formation": "wedge"}), "",
			"a task MAY name the shape the commander chose")
	assert_true(ElementTask.validate({"verb": "hold", "formation": "banana"}).contains("formation"),
			"but not a shape that does not exist")


## Round 14 (squad Q3): the tactics ladder's variant tables (tests/tactics/variants/) are ABLATIONS of the standard
## table, and an ablation is only read against its control if it differs from it in exactly the thing its label names.
## Round 13 changed the live table's plain move to the wedge and left these copies on the old `dense -> column` row, so
## every variant quietly carried a second change. A variant may differ from `doctrine_standard.json` only in its
## name, its summary, the drills it enables and its traits (the commander); everything else -- the movement rows,
## spacing, legs -- is the live table's, so the next change to the live table fails here instead of forking them.
const VARIANT_DIR := "res://tests/tactics/variants"
const VARIANT_MAY_DIFFER := ["name", "summary", "drills", "traits"]


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Where two tables' rows part, in one line: a full-table dump in a failure message is unreadable.
func _first_difference(got: Variant, want: Variant) -> String:
	if not (got is Array and want is Array):
		return ""
	for index in maxi((got as Array).size(), (want as Array).size()):
		var a: Variant = (got as Array)[index] if index < (got as Array).size() else null
		var b: Variant = (want as Array)[index] if index < (want as Array).size() else null
		if JSON.stringify(a, "", true) != JSON.stringify(b, "", true):
			return "; row %d is %s, the live table's is %s" % [index, JSON.stringify(a, "", true), JSON.stringify(b, "", true)]
	return ""


func test_a_ladder_variant_differs_from_the_standard_table_only_in_what_it_names() -> void:
	var live := _json("%s/doctrine_standard.json" % DoctrineTable.DIR)
	assert_true(not live.is_empty(), "the standard table reads")
	var found := 0
	for file_name in DirAccess.get_files_at(VARIANT_DIR):
		if not file_name.ends_with(".json"):
			continue
		found += 1
		var variant := _json(VARIANT_DIR.path_join(file_name))
		assert_true(not variant.is_empty(), "%s reads" % file_name)
		var keys: Array = live.keys()
		for key in variant.keys():
			if not keys.has(key):
				keys.append(key)
		for key in keys:
			if VARIANT_MAY_DIFFER.has(key):
				continue
			assert_true(JSON.stringify(variant.get(key), "", true) == JSON.stringify(live.get(key), "", true),
					"%s: `%s` is the live standard table's (a variant changes only %s)%s"
					% [file_name, key, ", ".join(VARIANT_MAY_DIFFER), _first_difference(variant.get(key), live.get(key))])
		var loaded := DoctrineTable.load_table("%s/%s" % [VARIANT_DIR, file_name])
		assert_true(loaded.has("table"), "%s loads: %s" % [file_name, loaded.get("error", "")])
		if loaded.has("table"):
			var pick: Dictionary = (loaded["table"] as DoctrineTable).select(
					{"task": "move", "threat": "none", "terrain": "dense", "composition": "balanced"})
			assert_eq(pick["formation"], "wedge", "%s: a plain move in dense ground is the live default" % file_name)
	assert_true(found >= 4, "the four ladder variants are here (found %d)" % found)
