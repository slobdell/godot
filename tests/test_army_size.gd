extends TestCase
## Round 22 (army, A1; contract C22.1): the army doubles. The lead: *"the armies I can create with tanks are too small
## ... Maybe that means allowing more squads, you had said formations are based in groups of 5"*, and shown the table,
## *"yeah double it sounds good."* (2026-10-07). Ten squads of five, 50 vehicles, 2000 credits; squads stay FIVE
## (Formations.MAX_MEMBERS, brains' invariant); one credit stays 1.75 points and the Gangs' scout stays 40 CR (C20.1).
##
## Each number lives in ONE place: Units.MAX_SQUADS (the cap: C22.3 may set it to 8 or 6 from his laptop's frame),
## and everything else derives from it: the unit cap (squads x five), the money (the cap's worth of Gangs scouts), the
## CPU opponent's purchase. The tests below read the constants, so the cap moves in one commit (A4).

## His squads, his vehicles, his money, at the cap that is built (10 / 50 / 2000; A4 moves only MAX_SQUADS).
const BUILT_SQUADS := 10

## How many of each faction's tank and scout the money buys (the launch table, game_design.md *Round 22 direction*).
const AT_2000 := {"gangs": {"gang_scout": 50, "gang_tank": 20}, "law": {"law_scout": 25, "law_tank": 13},
		"syndicate": {"syn_scout": 16, "syn_tank": 7}, "condemned": {"scout": 31, "tank": 17}}


func test_ten_squads_of_five_and_two_thousand_credits() -> void:
	assert_eq(Units.MAX_SQUADS, BUILT_SQUADS, "ten squads, in ONE place (C22.1: Units.MAX_SQUADS)")
	assert_eq(ArmyCatalog.MAX_SQUADS, Units.MAX_SQUADS, "the garage reads it")
	assert_eq(Doctrine.PLAYER_MAX_SQUADS, Units.MAX_SQUADS, "the loader's player cap reads it")
	assert_eq(ArmyCatalog.MAX_SQUAD_SIZE, 5, "squads stay five")
	assert_eq(ArmyCatalog.MAX_SQUAD_SIZE, Formations.MAX_MEMBERS, "a squad is what a formation holds (brains' invariant)")
	assert_eq(ArmyCatalog.MAX_UNITS, 50, "50 vehicles")
	assert_eq(GarageOpponent.UNIT_CAP, ArmyCatalog.MAX_UNITS, "the opponent's cap is his")
	assert_eq(Credits.GAME_CREDITS, 2000, "2000 credits")
	assert_eq(Credits.game_points(), 3500, "2000 credits are 3,500 points")
	assert_eq(Credits.ANCHOR_COUNT, ArmyCatalog.MAX_UNITS, "his rule: a full army of Gangs scouts is the money")
	assert_eq(Credits.of_unit(Credits.ANCHOR_UNIT), Credits.ANCHOR_PRICE, "the anchor's price is still its credits")
	assert_eq(Credits.ANCHOR_PRICE, 40, "the Gangs' scout stays 40 CR (C20.1)")
	assert_true(Doctrine.MAX_UNITS >= ArmyCatalog.MAX_UNITS, "the spawn grid holds a full army (%d slots)" % Doctrine.MAX_UNITS)
	assert_true(Doctrine.MAX_SQUADS >= ArmyCatalog.MAX_SQUADS, "the loader takes ten squads (%d)" % Doctrine.MAX_SQUADS)


func test_the_game_catalog_offers_ten_squads_and_two_thousand_credits() -> void:
	for faction: String in Units.FACTIONS:
		var catalog := ArmyCatalog.for_game(faction)
		assert_eq(catalog.max_squads, ArmyCatalog.MAX_SQUADS, "%s: ten squads" % faction)
		assert_eq(catalog.max_squad_size, 5, "%s: of five" % faction)
		assert_eq(catalog.max_units, ArmyCatalog.MAX_UNITS, "%s: 50 vehicles" % faction)
		assert_eq(catalog.budget, Credits.GAME_CREDITS, "%s: 2000 credits" % faction)
		assert_eq(catalog.budget_points(), Credits.game_points(), "%s: fought at 3,500 points" % faction)


func test_fifty_gangs_scouts_are_exactly_two_thousand_credits() -> void:
	var draft := ArmyDraft.new(ArmyCatalog.for_game("gangs"))
	var bought := _buy_all(draft, "gang_scout")
	assert_eq(bought, 50, "50 Rat Rods, one tap each")
	assert_eq(draft.remaining_budget(), 0, "spend every credit")
	assert_eq(draft.squads().size(), ArmyCatalog.MAX_SQUADS, "in ten squads")
	for squad: Dictionary in draft.squads():
		assert_eq((squad["units"] as Array).size(), 5, "of five")


func test_the_table_at_two_thousand() -> void:
	var lines: PackedStringArray = []
	for faction: String in AT_2000:
		for unit_id: String in AT_2000[faction]:
			var expected: int = AT_2000[faction][unit_id]
			assert_eq(mini(Credits.GAME_CREDITS / Credits.of_unit(unit_id), ArmyCatalog.MAX_UNITS), expected,
					"%s: 2000 CR buys %d %s" % [faction, expected, unit_id])
			var draft := ArmyDraft.new(ArmyCatalog.for_game(faction))
			assert_eq(_buy_all(draft, unit_id), expected, "%s: the garage buys %d %s" % [faction, expected, unit_id])
			lines.append("%s %d" % [unit_id, expected])
	print("MEASURE r22_table at %d CR: %s" % [Credits.GAME_CREDITS, ", ".join(lines)])


func test_the_opponent_buys_two_thousand_in_ten_squads_of_five() -> void:
	for faction: String in Units.FACTIONS:
		for seed_value in 12:
			var built := GarageOpponent.build("cpu", faction, seed_value)
			assert_true(built.has("doctrine"), "%s seed %d builds: %s" % [faction, seed_value, built.get("error", "")])
			var doctrine: Dictionary = built["doctrine"]
			var entries := Doctrine.entries(doctrine)
			var credits := 0
			for item: Dictionary in entries:
				credits += Credits.of_unit(String(item["entry"]["unit"]))
			assert_true(credits <= Credits.GAME_CREDITS, "%s seed %d: at most 2000 CR (%d)" % [faction, seed_value, credits])
			assert_true(entries.size() <= ArmyCatalog.MAX_UNITS, "%s seed %d: at most 50 vehicles" % [faction, seed_value])
			assert_true((doctrine["squads"] as Array).size() <= ArmyCatalog.MAX_SQUADS, "%s: at most ten squads" % faction)
			var lone := ""
			for squad: Dictionary in doctrine["squads"]:
				assert_true((squad["units"] as Array).size() <= 5, "%s: squads of at most five" % faction)
				if (squad["units"] as Array).size() == 1:
					lone = String(squad["name"])
			# A3: a vehicle alone is a squad only when every other squad is full (a lone tank is a weak element).
			if lone != "" and (doctrine["squads"] as Array).size() > 1:
				var others_full := true
				for squad: Dictionary in doctrine["squads"]:
					if String(squad["name"]) != lone and (squad["units"] as Array).size() < ArmyCatalog.MAX_SQUAD_SIZE:
						others_full = false
				assert_true(others_full, "%s seed %d: %s is a squad of one while another has room" % [faction, seed_value, lone])
			# It spends what it can: less than its cheapest vehicle is left, or the cap is reached.
			var cheapest := INF
			for unit_id: String in Army.ARCHETYPES[doctrine["archetype"]]["units"]:
				cheapest = minf(cheapest, float(Credits.of_unit(unit_id)))
			assert_true(entries.size() == ArmyCatalog.MAX_UNITS or Credits.GAME_CREDITS - credits < cheapest,
					"%s seed %d spends all it can (%d CR)" % [faction, seed_value, credits])
			# More than the old cap's money: the army really doubled (> 1000 CR spent on every seed).
			assert_true(credits > Credits.GAME_CREDITS / 2, "%s seed %d spends more than half (%d)" % [faction, seed_value, credits])


func test_his_ten_squads_reach_the_field_as_ten() -> void:
	# SkirmishMode folds the player's army (SquadConsolidation.for_player) before it spawns: at the old five, a garage
	# army of ten squads came out as five. The fold reads the garage's cap (C22.1).
	assert_eq(SquadConsolidation.MAX_SQUADS, ArmyCatalog.MAX_SQUADS, "the player's fold keeps his ten squads")
	var draft := ArmyDraft.new(ArmyCatalog.for_game("gangs"))
	_buy_all(draft, "gang_scout")
	var doctrine := ArmyFormat.to_game_doctrine(draft.to_doctrine())
	var folded := SquadConsolidation.for_player(doctrine)
	assert_eq((folded["squads"] as Array).size(), ArmyCatalog.MAX_SQUADS, "ten squads in, ten squads on the field")
	assert_eq(Doctrine.entries(folded).size(), 50, "every vehicle")


func _buy_all(draft: ArmyDraft, unit_id: String) -> int:
	var bought := 0
	for i in ArmyCatalog.MAX_UNITS + 10:
		var squad := draft.squad_with_room(0)
		if squad < 0 or draft.add_unit(squad, unit_id) != "":
			break
		bought += 1
	return bought
