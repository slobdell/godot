extends TestCase
## Round-5 X3 (ai): the tactics ladder's two pieces. TacticsFlags puts a side under doctrine (elements and an
## ElementCommander, optionally another doctrine table) without the match runner knowing, and TacticsLedger charges
## the fight to what each unit was doing: a drill, a shape, or just its brain.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func teardown() -> void:
	TacticsFlags.reset()
	super()


func test_activities_are_named_the_way_the_ladder_reports_them() -> void:
	assert_eq(TacticsLedger.activity_of(null), "brain", "a unit with no element is fighting on its brain alone")


func test_a_side_run_by_doctrine_fills_the_ledger() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	game_match.seed_spawns(7, 0.0)
	game_match.elimination = true
	for side in 2:
		var loaded := Doctrine.load_file("res://doctrines/%s.json" % ["combined_arms", "anvil_hammer"][side])
		assert_true(not loaded.has("error"), "army loads")
		assert_eq(game_match.load_doctrine(side, loaded["doctrine"]), "", "army spawns")
	await wait_physics_frames(TacticsFlags.SETTLE_TICKS)
	var installed := TacticsFlags.install(game_match, ["", "gangs"], true)
	var elements: Elements = installed["elements"]
	assert_eq((installed["commanders"] as Array).size(), 2, "both sides get an element commander")
	assert_true(not elements.of_team(Match.Team.GREEN).is_empty() and not elements.of_team(Match.Team.RUST).is_empty(),
			"both sides are formed into elements")
	var gang_table: DoctrineTable = DoctrineTable.load_table("gangs")["table"]
	for element: Element in elements.of_team(Match.Team.RUST):
		assert_true(element.table == gang_table, "rust's elements fight by the table the flag named (%s)" % element.element_name)
	await wait_physics_frames(60 * 45)
	var report: Dictionary = (installed["ledger"] as TacticsLedger).report()
	print("MEASURE tactics_ledger %s" % JSON.stringify(report))
	for side_name in ["green", "rust"]:
		var rows: Dictionary = report[side_name]
		var seconds := 0.0
		var elemental := 0.0
		for activity: String in rows:
			seconds += float(rows[activity]["seconds"])
			if activity != "brain":
				elemental += float(rows[activity]["seconds"])
		assert_true(seconds > 100.0, "%s: unit-seconds are counted (%.0f)" % [side_name, seconds])
		assert_true(elemental > seconds * 0.5, "%s: most of its time is under doctrine (%.0f of %.0f)" % [side_name, elemental, seconds])
	var dealt := 0.0
	for side_name in ["green", "rust"]:
		for activity: String in report[side_name]:
			dealt += float(report[side_name][activity]["dealt"])
	assert_true(dealt > 0.0, "the fight's damage is charged to activities (%.0f)" % dealt)
