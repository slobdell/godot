extends TestCase
## Round 22 (army, A1; contract C22.1): the army doubles. The lead: *"the armies I can create with tanks are too small
## ... Maybe that means allowing more squads, you had said formations are based in groups of 5"*, and shown the table,
## *"yeah double it sounds good."* (2026-10-07). Squads stay FIVE (Formations.MAX_MEMBERS, brains' invariant); one credit
## stays 1.75 points and the Gangs' scout stays 40 CR (C20.1).
##
## A4 (C22.3, the orchestrator's number, 2026-10-07): the VEHICLE cap went back to 25 (five squads of five: nothing above
## 25 a side holds his laptop's frame bar) while the MONEY stayed 2000 credits. So a tank army still doubles (13 Law
## tanks, 7 Syndicate) and only an all-scout army meets the cap (25 Rat Rods, 1000 CR left). The cap is ONE constant,
## Units.MAX_SQUADS (flip it back to 10 and ten squads / 50 vehicles return); the money is its own, Credits.GAME_CREDITS.

## The cap that is built: five squads (A4). 10 was round 22's first build.
const BUILT_SQUADS := 5

## What 2000 credits buys of each faction's scout and tank under the 25 cap (the launch table, A4's numbers).
const AT_2000 := {"gangs": {"gang_scout": 25, "gang_tank": 20}, "law": {"law_scout": 25, "law_tank": 13},
		"syndicate": {"syn_scout": 16, "syn_tank": 7}, "condemned": {"scout": 25, "tank": 17}}


func test_the_cap_is_one_constant_and_the_money_is_its_own() -> void:
	assert_eq(Units.MAX_SQUADS, BUILT_SQUADS, "five squads, in ONE place (C22.1, A4: Units.MAX_SQUADS)")
	assert_eq(ArmyCatalog.MAX_SQUADS, Units.MAX_SQUADS, "the garage reads it")
	assert_eq(Doctrine.PLAYER_MAX_SQUADS, Units.MAX_SQUADS, "the loader's player cap reads it")
	assert_eq(SquadConsolidation.MAX_SQUADS, Units.MAX_SQUADS, "the skirmish's fold reads it")
	assert_true(ControlGroups.MAX_GROUPS >= Units.MAX_SQUADS, "every squad has a number key")
	assert_eq(ArmyCatalog.MAX_SQUAD_SIZE, 5, "squads stay five")
	assert_eq(ArmyCatalog.MAX_SQUAD_SIZE, Formations.MAX_MEMBERS, "a squad is what a formation holds (brains' invariant)")
	assert_eq(ArmyCatalog.MAX_UNITS, BUILT_SQUADS * 5, "25 vehicles")
	assert_eq(GarageOpponent.UNIT_CAP, ArmyCatalog.MAX_UNITS, "the opponent's cap is his")
	assert_eq(Credits.GAME_CREDITS, 2000, "2000 credits")
	assert_eq(Credits.game_points(), 3500, "2000 credits are 3,500 points")
	assert_eq(Credits.ANCHOR_COUNT * Credits.ANCHOR_PRICE, Credits.GAME_CREDITS,
			"the anchor rule: an all-scout Gangs army of 50 would spend the money exactly")
	assert_eq(Credits.of_unit(Credits.ANCHOR_UNIT), Credits.ANCHOR_PRICE, "the anchor's price is still its credits")
	assert_eq(Credits.ANCHOR_PRICE, 40, "the Gangs' scout stays 40 CR (C20.1)")
	assert_true(Doctrine.MAX_UNITS >= ArmyCatalog.MAX_UNITS, "the spawn grid holds a full army (%d slots)" % Doctrine.MAX_UNITS)
	assert_true(Doctrine.MAX_SQUADS >= ArmyCatalog.MAX_SQUADS, "the loader takes every squad (%d)" % Doctrine.MAX_SQUADS)


func test_the_game_catalog_offers_the_cap_and_two_thousand_credits() -> void:
	for faction: String in Units.FACTIONS:
		var catalog := ArmyCatalog.for_game(faction)
		assert_eq(catalog.max_squads, ArmyCatalog.MAX_SQUADS, "%s: five squads" % faction)
		assert_eq(catalog.max_squad_size, 5, "%s: of five" % faction)
		assert_eq(catalog.max_units, ArmyCatalog.MAX_UNITS, "%s: 25 vehicles" % faction)
		assert_eq(catalog.budget, Credits.GAME_CREDITS, "%s: 2000 credits" % faction)
		assert_eq(catalog.budget_points(), Credits.game_points(), "%s: fought at 3,500 points" % faction)


func test_twenty_five_rat_rods_fill_the_cap_and_a_26th_is_refused() -> void:
	var draft := ArmyDraft.new(ArmyCatalog.for_game("gangs"))
	assert_eq(_buy_all(draft, "gang_scout"), 25, "25 Rat Rods, one tap each")
	assert_eq(draft.squads().size(), ArmyCatalog.MAX_SQUADS, "in five squads")
	for squad: Dictionary in draft.squads():
		assert_eq((squad["units"] as Array).size(), 5, "of five")
	assert_eq(draft.remaining_budget(), 1000, "1000 CR left: the cap, not the money, stops an all-scout army")
	assert_true(draft.add_unit(0, "gang_scout") != "" and draft.squad_with_room(0) < 0, "a 26th is refused: no squad has room")
	assert_eq(draft.unit_count(), 25, "still 25")
	assert_true(GarageScreen.full_line(draft).contains("1000 CR left can't be spent"),
			"the line says the money left can't be spent: %s" % GarageScreen.full_line(draft))


func test_a_tank_army_still_doubles() -> void:
	var law := ArmyDraft.new(ArmyCatalog.for_game("law"))
	assert_eq(_buy_all(law, "law_tank"), 13, "13 Law tanks (6 at round 20's 1000 CR)")
	var syndicate := ArmyDraft.new(ArmyCatalog.for_game("syndicate"))
	assert_eq(_buy_all(syndicate, "syn_tank"), 7, "7 Syndicate tanks (3 at 1000 CR)")


func test_the_table_at_two_thousand() -> void:
	var lines: PackedStringArray = []
	for faction: String in AT_2000:
		for unit_id: String in AT_2000[faction]:
			var expected: int = AT_2000[faction][unit_id]
			assert_eq(mini(Credits.GAME_CREDITS / Credits.of_unit(unit_id), ArmyCatalog.MAX_UNITS), expected,
					"%s: 2000 CR buys %d %s under the cap" % [faction, expected, unit_id])
			var draft := ArmyDraft.new(ArmyCatalog.for_game(faction))
			assert_eq(_buy_all(draft, unit_id), expected, "%s: the garage buys %d %s" % [faction, expected, unit_id])
			lines.append("%s %d" % [unit_id, expected])
	print("MEASURE r22_table at %d CR, cap %d: %s" % [Credits.GAME_CREDITS, ArmyCatalog.MAX_UNITS, ", ".join(lines)])


func test_the_opponent_buys_two_thousand_under_the_cap() -> void:
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
			assert_true(entries.size() <= ArmyCatalog.MAX_UNITS, "%s seed %d: at most 25 vehicles" % [faction, seed_value])
			assert_true((doctrine["squads"] as Array).size() <= ArmyCatalog.MAX_SQUADS, "%s: at most five squads" % faction)
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


func test_his_squads_reach_the_field_as_he_built_them() -> void:
	# SkirmishMode folds the player's army (SquadConsolidation.for_player) before it spawns, at the garage's cap (C22.1).
	var draft := ArmyDraft.new(ArmyCatalog.for_game("gangs"))
	_buy_all(draft, "gang_scout")
	var folded := SquadConsolidation.for_player(ArmyFormat.to_game_doctrine(draft.to_doctrine()))
	assert_eq((folded["squads"] as Array).size(), ArmyCatalog.MAX_SQUADS, "five squads in, five squads on the field")
	assert_eq(Doctrine.entries(folded).size(), ArmyCatalog.MAX_UNITS, "every vehicle")


func _buy_all(draft: ArmyDraft, unit_id: String) -> int:
	var bought := 0
	for i in ArmyCatalog.MAX_UNITS + 10:
		var squad := draft.squad_with_room(0)
		if squad < 0 or draft.add_unit(squad, unit_id) != "":
			break
		bought += 1
	return bought


func test_a_full_army_fits_its_share_code() -> void:
	# Stretch (b): the share line's code for a full army stays far inside ArmyCode.MAX_CODE_LENGTH and opens whole.
	for faction: String in Units.FACTIONS:
		var catalog := ArmyCatalog.for_game(faction)
		var full := ArmyDraft.new(catalog)
		var cheapest: String = catalog.unit_ids()[0]
		for unit_id in catalog.unit_ids():
			if catalog.unit_cost(unit_id) < catalog.unit_cost(cheapest):
				cheapest = unit_id
		_buy_all(full, cheapest)
		for draft: ArmyDraft in [full, GarageSuggest.draft(catalog)]:
			var code := ArmyCode.encode(draft)
			assert_true(code.length() * 4 <= ArmyCode.MAX_CODE_LENGTH, "%s: %d vehicles in %d characters (a quarter of %d)" % [
					faction, draft.unit_count(), code.length(), ArmyCode.MAX_CODE_LENGTH])
			var opened := ArmyCode.decode(code, catalog)
			assert_true(opened.has("draft"), "%s: the code opens: %s" % [faction, opened.get("error", "")])
			if opened.has("draft"):
				assert_eq((opened["draft"] as ArmyDraft).unit_count(), draft.unit_count(), "%s: every vehicle" % faction)
				assert_eq((opened["draft"] as ArmyDraft).squads().size(), draft.squads().size(), "%s: every squad" % faction)
