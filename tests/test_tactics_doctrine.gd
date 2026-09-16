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
	assert_true(ElementTask.validate({"verb": "hold", "formation": "wedge"}).contains("unknown key"),
			"and so is commanding geometry: the leader picks the formation, not the commander")
