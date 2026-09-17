extends TestCase
## Doctrine, for the announcer (the lead, 2026-09-16): every decision an element takes is published as
## structured data, in the K5 event shape, so the booth can say *why* a squad is lining up the way it is
## without doctrine writing a word of commentary.

const TICKS := Element.UPDATE_TICKS


func _element(lab: TacticsLab, names: Array) -> Element:
	return lab.element(names, "Alpha")


func test_a_shape_change_is_published_with_the_reason_the_table_gave() -> void:
	var lab := TacticsLab.create(self, 41)
	var names: Array = []
	for i in 4:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				Vector3(TacticsScenarios.LANE_X, 0.0, 40.0 + i * 10.0), 0.0).name))
	var reports: Array = []
	lab.elements.element_reported.connect(func(event: Dictionary) -> void: reports.append(event))
	var alpha := _element(lab, names)
	await lab.start()
	alpha.assign({"verb": "move", "to": [TacticsScenarios.LANE_X, -20.0]})
	for tick in TICKS * 4:
		await lab.step()
	assert_true(not reports.is_empty(), "moving out publishes at least one decision")
	var event: Dictionary = reports[0]
	assert_eq(String(event["type"]), "element_formation", "a shape change is an element_formation event")
	assert_eq(String(event["team"]), "green", "it says whose element it is")
	assert_eq(String(event["element"]), "Alpha", "and which one")
	assert_eq(int(event["size"]), 4, "and how many vehicles are in it")
	assert_true(TacticsFormation.NAMES.has(String(event["formation"])), "the shape is a real formation")
	assert_true(DoctrineTable.TECHNIQUES.has(String(event["technique"])), "so is the movement technique")
	assert_true(String(event["reason"]).length() > 3,
			"and it carries the table's own reason, to be quoted: '%s'" % event["reason"])
	assert_true(not String(event["reason"]).ends_with("."),
			"the reason is a phrase to slot into a sentence, not a sentence")
	lab.dispose()


func test_a_battle_drill_is_published_with_what_set_it_off() -> void:
	var lab := TacticsLab.create(self, 43)
	var names: Array = []
	for i in 3:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				Vector3(TacticsScenarios.LANE_X, 0.0, 30.0 + i * 10.0), 0.0).name))
	var reports: Array = []
	lab.elements.element_reported.connect(func(event: Dictionary) -> void: reports.append(event))
	var alpha := _element(lab, names)
	await lab.start()
	alpha.assign({"verb": "move", "to": [TacticsScenarios.LANE_X, -40.0]})
	var sprung := false
	for tick in SimClock.TICK_RATE * 16:
		await lab.step()
		if not sprung and lab.center_of(names).z < 12.0:
			sprung = true
			lab.gun(Match.Team.RUST, "Rust_Ambush_1",
					Vector3(TacticsScenarios.LANE_X + 22.0, 0.0, lab.center_of(names).z - 4.0), -PI * 0.5)
	var drills: Array = reports.filter(func(event: Dictionary) -> bool:
		return String(event["type"]) == "element_drill" and String(event["drill"]) != "")
	assert_true(not drills.is_empty(), "being ambushed publishes a drill (got %d reports)" % reports.size())
	if drills.is_empty():
		lab.dispose()
		return
	var event: Dictionary = drills[0]
	assert_true(Drills.NAMES.has(String(event["drill"])), "the drill is a real one: %s" % event["drill"])
	for report: Dictionary in reports:
		if String(report["type"]) == "element_drill":
			assert_true(String(report["drill"]) != "",
					"element_drill always means a drill STARTED; coming off one is a shape change")
	assert_true(float(event["distance"]) > 0.0,
			"it says how far off the trigger was, for the call (%s m)" % event["distance"])
	assert_true(String(event["target"]) != "", "and what set it off")
	assert_true(String(event["reason"]).length() > 3, "with the drill's reason: '%s'" % event["reason"])
	lab.dispose()


func test_the_same_decision_is_not_announced_twice() -> void:
	var lab := TacticsLab.create(self, 47)
	var names: Array = []
	for i in 3:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				Vector3(TacticsScenarios.LANE_X, 0.0, 20.0 + i * 10.0), 0.0).name))
	var reports: Array = []
	lab.elements.element_reported.connect(func(event: Dictionary) -> void: reports.append(event))
	var alpha := _element(lab, names)
	await lab.start()
	alpha.assign({"verb": "move", "to": [TacticsScenarios.LANE_X, 0.0]})
	for tick in SimClock.TICK_RATE * 8:
		await lab.step()
	var seen := {}
	for event: Dictionary in reports:
		var key := "%s|%s|%s" % [event["type"], event.get("formation", ""), event.get("technique", "")]
		assert_true(not seen.has(key) or String(event["type"]) == "element_drill",
				"the booth is told '%s' once, not every tick (%d reports)" % [key, reports.size()])
		seen[key] = true
	assert_true(reports.size() < 10, "a quiet move is a handful of calls, not a stream (%d)" % reports.size())
	lab.dispose()


func test_an_element_with_no_orders_says_nothing() -> void:
	var element := Element.new(1, "Alpha", Match.Team.GREEN, PackedStringArray(["Green_A_1"]))
	element.changed_fields = PackedStringArray(["formation"])
	element.formation = "herringbone"
	assert_eq(ElementReport.of(element), {}, "a parked element with no task is not news")
	element.task = {"verb": "move", "to": [0, 0]}
	assert_true(not ElementReport.of(element).is_empty(), "the same change once it has a job is")


func test_the_publisher_can_be_found_without_naming_it() -> void:
	# Audio's MatchEventAdapter cannot name the Elements class — it doesn't exist on their branch until the
	# checkpoint merges, and a file that names it would not compile. So it finds the publisher by group.
	var lab := TacticsLab.create(self, 59)
	lab.unit(Match.Team.GREEN, "Green_A_1", Vector3(TacticsScenarios.LANE_X, 0.0, 20.0), 0.0)
	await lab.start()
	var found := tree.get_nodes_in_group(Elements.GROUP)
	assert_true(found.has(lab.elements), "the match's Elements is in the '%s' group" % Elements.GROUP)
	assert_true((found[0] as Node).has_signal("element_reported"),
			"and it is recognisable by the signal a listener connects to")
	lab.dispose()


func test_every_value_the_booth_has_to_speak_is_from_a_closed_set() -> void:
	# FROZEN by agreement with audio (2026-09-16). The announcer records every word in advance, so each value
	# below is 8-16 recordings across the lines that name it — and the failure mode is silent: a value with
	# no clip doesn't error, it just makes those lines ineligible and the booth says something blander
	# instead. So adding a shape or a drill to a shipped table is not a free edit.
	#
	# To add one: ask audio first, then change this list in the same commit as the table. `encircle`/`ring`
	# and `echelon_left` are deliberately absent — they exist in the engine but no shipped table selects
	# them, and nothing should be recorded for a shape nobody uses.
	var spoken_formations := ["coil", "column", "echelon_right", "herringbone", "line", "swarm", "vee", "wedge"]
	var spoken_techniques := ["bounding_overwatch", "traveling", "traveling_overwatch"]
	# break_contact left the shipped tables in round 5 (ai, ladder evidence in doctrine.md): its recorded lines stay
	# valid but unused; audio was told.
	var spoken_drills := ["assault_through", "bait", "far_ambush", "herringbone",
			"near_ambush", "react_to_contact", "support_by_fire"]
	DoctrineTable.clear_cache()
	var formations := {}
	var techniques := {}
	var drills := {}
	for file_name in DirAccess.get_files_at(DoctrineTable.DIR):
		if not file_name.begins_with("doctrine_") or not file_name.ends_with(".json"):
			continue
		var table: DoctrineTable = DoctrineTable.load_table(
				file_name.trim_prefix("doctrine_").trim_suffix(".json")).get("table")
		for rule: Dictionary in table.movement:
			formations[rule["formation"]] = true
			techniques[rule["technique"]] = true
		for drill in table.drills.get("enabled", []):
			drills[drill] = true
	var found_formations: Array = formations.keys()
	var found_techniques: Array = techniques.keys()
	var found_drills: Array = drills.keys()
	found_formations.sort()
	found_techniques.sort()
	found_drills.sort()
	assert_eq(found_formations, spoken_formations, _frozen("formation", found_formations, spoken_formations))
	assert_eq(found_techniques, spoken_techniques, _frozen("technique", found_techniques, spoken_techniques))
	assert_eq(found_drills, spoken_drills, _frozen("drill", found_drills, spoken_drills))


## The message a future tuner reads when a table starts using something the booth cannot say.
func _frozen(field: String, found: Array, recorded: Array) -> String:
	var added: Array = found.filter(func(value: Variant) -> bool: return not recorded.has(value))
	var dropped: Array = recorded.filter(func(value: Variant) -> bool: return not found.has(value))
	var what := "added %s" % [added] if not added.is_empty() else "stopped using %s" % [dropped]
	return ("the shipped tables %s: the booth's %s values are frozen (audio, 2026-09-16). Every new value is "
			+ "8-16 recordings, and an unrecorded one fails silently — the lines naming it just go quiet. "
			+ "Get audio's sign-off, then update this list in the same commit as the table") % [what, field]


func test_doctrine_publishes_values_not_commentary() -> void:
	# The words are audio's job. If doctrine ever starts writing sentences, this test should fail.
	var element := Element.new(1, "Alpha", Match.Team.RUST, PackedStringArray(["Rust_A_1"]))
	element.task = {"verb": "move", "to": [0, 0]}
	element.formation = "wedge"
	element.technique = "bounding_overwatch"
	element.reason = "contact likely: bound forward"
	element.strength = 3
	element.changed_fields = PackedStringArray(["formation"])
	var event := ElementReport.of(element)
	assert_eq(String(event["type"]), "element_formation", "a formation change reports as one")
	assert_eq(String(event["team"]), "rust", "teams are named the way K5 names them")
	assert_eq(Array(event["changed"]), ["formation"], "and it says exactly what moved")
	element.changed_fields = PackedStringArray(["reason"])
	assert_eq(ElementReport.of(element), {},
			"the same shape for a slightly different reason is not worth a sentence")
	element.changed_fields = PackedStringArray(["leader", "roster"])
	assert_eq(ElementReport.of(element), {}, "nor is a leader change: the HUD wants it, the booth doesn't")
