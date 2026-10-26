extends TestCase
## B7 (round 42, balance; C42.5): the CPU counter-lineup. When the opposing army's cost is mostly tanks
## (Army.COUNTER_TANK_SHARE), a plain "cpu" deal fields its faction's artillery-heavy lineup instead of its roll.
## OFF behind --cpu-counter until Bar B7 passes; with it OFF nothing changes.

const SEEDS := [1, 2, 3, 7, 11, 42, 99, 123, 777, 8501, 9901, 31337]


func teardown() -> void:
	Army.set_counter(Army.COUNTER_DEFAULT)
	super()


func _mono(faction: String) -> Dictionary:
	return Army.load_army("cpu:mono_tank", 1, Units.BASELINE_BUDGET, faction)["doctrine"]


func test_tank_share_reads_cost() -> void:
	Army.set_counter(true)
	assert_eq(Army.tank_share({}), 0.0, "an empty army has no tanks")
	for faction: String in Units.FACTIONS:
		assert_eq(Army.tank_share(_mono(faction)), 1.0, "%s mono_tank is all tanks" % faction)
		var siege := Army.load_army("cpu:" + String(Army.COUNTER_ARCHETYPES[faction]), 1, Units.BASELINE_BUDGET, faction)
		assert_true(Army.tank_share(siege["doctrine"]) < 0.3, "%s's counter lineup is not tank-heavy" % faction)


func test_no_rolled_deal_is_tank_heavy() -> void:
	Army.set_counter(true)
	# The threshold sits above every army the CPU itself deals, so CPU v CPU (the demo, a seeded "cpu" opponent) never
	# counters: the switch changes a fight only when someone brings a tank rush.
	for faction: String in Units.FACTIONS:
		for budget: int in [Units.BASELINE_BUDGET, Units.DEFAULT_BUDGET]:
			for archetype: String in Army.archetypes_for(faction):
				for seed_value: int in SEEDS:
					var army := Army.cpu_army("cpu:" + archetype, seed_value, budget, faction)
					assert_true(Army.tank_share(army) < Army.COUNTER_TANK_SHARE, "%s %s s%d budget %d deals %.2f tanks" % [
							faction, archetype, seed_value, budget, Army.tank_share(army)])
	for seed_value: int in SEEDS:
		var plain := Army.cpu_army("cpu", seed_value)
		assert_true(Army.tank_share(plain) < Army.COUNTER_TANK_SHARE, "the plain cpu deal s%d" % seed_value)


func test_a_cpu_meets_a_tank_rush_with_its_artillery_lineup() -> void:
	Army.set_counter(true)
	for faction: String in Units.FACTIONS:
		var dealt := Army.load_army("cpu", 9901, Units.BASELINE_BUDGET, faction, _mono(faction))
		assert_true(not dealt.has("error"), "%s counter deal loads: %s" % [faction, dealt.get("error", "")])
		assert_eq(String(dealt["doctrine"].get("archetype")), String(Army.COUNTER_ARCHETYPES[faction]),
				"%s fields its artillery-heavy lineup against all tanks" % faction)
		var artillery := 0
		for item: Dictionary in Doctrine.entries(dealt["doctrine"]):
			if Units.role_of(String(item["entry"]["unit"])) == "artillery":
				artillery += 1
		assert_true(artillery >= 2, "%s brings artillery (%d)" % [faction, artillery])
		assert_true(Doctrine.entries(dealt["doctrine"]).size() <= Army.MAX_ARMY_UNITS, "%s within the unit cap" % faction)
		assert_true(Units.army_cost(dealt["doctrine"]) <= Units.BASELINE_BUDGET, "%s within the budget" % faction)


func test_off_named_or_mixed_opponents_change_nothing() -> void:
	Army.set_counter(true)
	for faction: String in Units.FACTIONS:
		var rolled := Army.load_army("cpu", 9901, Units.BASELINE_BUDGET, faction)
		var mixed: Dictionary = Army.load_army("cpu", 9902, Units.BASELINE_BUDGET, faction)["doctrine"]
		assert_eq(Army.load_army("cpu", 9901, Units.BASELINE_BUDGET, faction, mixed), rolled,
				"%s: a mixed opponent leaves the roll as it was" % faction)
		var named := Army.load_army("cpu:" + String(Army.archetypes_for(faction)[0]), 9901, Units.BASELINE_BUDGET, faction)
		assert_eq(Army.load_army("cpu:" + String(Army.archetypes_for(faction)[0]), 9901, Units.BASELINE_BUDGET, faction,
				_mono(faction)), named, "%s: a named archetype is never swapped" % faction)
		Army.set_counter(false)
		assert_eq(Army.load_army("cpu", 9901, Units.BASELINE_BUDGET, faction, _mono(faction)), rolled,
				"%s: OFF, a tank rush meets the roll" % faction)
		Army.set_counter(true)


func test_load_pair_sees_the_other_side_whichever_loads_first() -> void:
	Army.set_counter(true)
	for mono_team: int in [Match.Team.GREEN, Match.Team.RUST]:
		var other := Match.Team.RUST if mono_team == Match.Team.GREEN else Match.Team.GREEN
		var lineups := {mono_team: "cpu:mono_tank", other: "cpu"}
		var factions := {Match.Team.GREEN: "law", Match.Team.RUST: "law"}
		var armies := Army.load_pair(lineups, factions, 9903, Units.BASELINE_BUDGET)
		assert_eq(String(armies[other]["doctrine"]["archetype"]), "law_barrage", "the CPU on %d counters" % other)
		assert_eq(Army.tank_share(armies[mono_team]["doctrine"]), 1.0, "the tank rush is as named")
	# Two plain CPUs: nobody rolls a tank rush, so the pair is exactly the two rolls (the demo, unchanged).
	var plain := Army.load_pair({Match.Team.GREEN: "cpu", Match.Team.RUST: "cpu"},
			{Match.Team.GREEN: "gangs", Match.Team.RUST: "law"}, 4242, Units.BASELINE_BUDGET)
	assert_eq(plain[Match.Team.GREEN], Army.load_army("cpu", 4242, Units.BASELINE_BUDGET, "gangs"), "green's roll")
	assert_eq(plain[Match.Team.RUST], Army.load_army("cpu", 4242, Units.BASELINE_BUDGET, "law"), "rust's roll")


func test_the_garage_opponent_counters_his_tank_draft() -> void:
	Army.set_counter(true)
	for faction: String in Units.FACTIONS:
		var tanks := {"squads": [{"name": "Guns", "units": [{"unit": Array(Units.roster(faction)).filter(
				func(u: String) -> bool: return Units.role_of(u) == "tank")[0]}]}]}
		var built := GarageOpponent.build("cpu", faction, 9904, Credits.GAME_CREDITS, tanks)
		assert_true(not built.has("error"), "%s garage counter builds: %s" % [faction, built.get("error", "")])
		assert_eq(String(built["doctrine"]["archetype"]), String(Army.COUNTER_ARCHETYPES[faction]),
				"%s garage CPU brings artillery" % faction)
		Army.set_counter(false)
		assert_eq(GarageOpponent.build("cpu", faction, 9904, Credits.GAME_CREDITS, tanks),
				GarageOpponent.build("cpu", faction, 9904), "%s OFF: the garage deal is today's" % faction)
		Army.set_counter(true)
		assert_eq(GarageOpponent.build("cpu", faction, 9904, Credits.GAME_CREDITS, {}), GarageOpponent.build("cpu", faction, 9904),
				"%s: no draft known, today's deal" % faction)


func test_the_garage_suggests_artillery_to_a_tank_draft() -> void:
	Army.set_counter(true)
	var draft := ArmyDraft.new(ArmyCatalog.from_game(100000))
	for i in 4:
		draft.add_unit(0, "tank")
	assert_true(Array(GarageAdvice.composition_hints(draft)).has(GarageAdvice.TANK_RUSH_HINT), "all tanks: the line shows")
	assert_eq(GarageAdvice.composition_hints(draft)[0], GarageAdvice.TANK_RUSH_HINT, "and comes first")
	var mixed := ArmyDraft.new(ArmyCatalog.from_game(100000))
	for unit_id: String in ["tank", "artillery", "scout", "ifv"]:
		mixed.add_unit(0, unit_id)
	assert_true(not Array(GarageAdvice.composition_hints(mixed)).has(GarageAdvice.TANK_RUSH_HINT), "a mixed draft: no line")


func test_off_the_pair_is_each_side_loaded_alone() -> void:
	Army.set_counter(false)
	for lineups: Dictionary in [{Match.Team.GREEN: "cpu:mono_tank", Match.Team.RUST: "cpu"},
			{Match.Team.GREEN: "cpu", Match.Team.RUST: "cpu:mono_tank"}, {Match.Team.GREEN: "cpu", Match.Team.RUST: "cpu"},
			{Match.Team.GREEN: "player_default", Match.Team.RUST: "cpu"}]:
		var factions := {Match.Team.GREEN: "", Match.Team.RUST: ""} if lineups[Match.Team.GREEN] == "player_default" \
				else {Match.Team.GREEN: "syndicate", Match.Team.RUST: "gangs"}
		var budget := Units.DEFAULT_BUDGET if lineups[Match.Team.GREEN] == "player_default" else Units.BASELINE_BUDGET
		var pair := Army.load_pair(lineups, factions, 5150, budget)
		for team: int in lineups:
			assert_eq(pair[team], Army.load_army(String(lineups[team]), 5150, budget, String(factions[team])),
					"OFF: %s on %d is exactly today's load" % [lineups[team], team])
