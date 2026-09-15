extends TestCase
## Army builder Y1 (model): the catalog v2 view, ArmyDraft rules, army JSON v2 saves and round-1 migration,
## presets that adapt to unlocks, army codes v2, and composition advice.

const TEST_DIR := "user://test_army_draft/"


## A small catalog v2 in the C1 shape, independent of the game's numbers.
func _catalog(budget := 1000) -> ArmyCatalog:
	var units := {
		"scout": {"display_name": "Scout", "role": "scout", "cost": 100, "unlock_tier": 0, "weapon": "machine_gun",
				"mount": "fixed", "max_health": 100, "sight_radius": 110.0, "good_vs": ["artillery"], "weak_vs": ["ifv"]},
		"ifv": {"display_name": "IFV", "role": "ifv", "cost": 150, "unlock_tier": 0, "weapon": "autocannon",
				"mount": "turret", "max_health": 200, "sight_radius": 80.0, "good_vs": ["scout"], "weak_vs": ["tank"]},
		"tank": {"display_name": "Tank", "role": "tank", "cost": 200, "unlock_tier": 0, "weapon": "cannon",
				"mount": "turret", "max_health": 300, "sight_radius": 75.0, "good_vs": ["ifv"], "weak_vs": ["scout"]},
		"artillery": {"display_name": "Artillery", "role": "artillery", "cost": 220, "unlock_tier": 1, "weapon": "mortar",
				"mount": "turret", "max_health": 200, "sight_radius": 60.0, "good_vs": ["tank"], "weak_vs": ["scout"]},
	}
	var weapons := {"machine_gun": {"range": 45.0, "damage": 4.0}, "autocannon": {"display_name": "30 mm autocannon"},
			"cannon": {"range": 70.0, "damage": 34.0, "reload": 2.5}, "mortar": {"range": 160.0}}
	return ArmyCatalog.new(units, weapons, budget)


func _starters_only(catalog: ArmyCatalog) -> ArmyCatalog:
	return catalog.with_budget(catalog.budget, ["scout", "ifv", "tank"])


# ---- Catalog ------------------------------------------------------------------------------------

func test_the_game_catalog_is_v2_shaped_with_c2_limits() -> void:
	var catalog := ArmyCatalog.from_game()
	assert_true(ArmyCatalog.is_v2(catalog.units), "the army builder always sees catalog v2 (the stub until checkpoint 1)")
	for unit_id in catalog.unit_ids():
		var profile := catalog.unit(unit_id)
		for key in ["display_name", "role", "blurb", "cost", "unlock_tier", "weapon", "mount", "good_vs", "weak_vs"]:
			assert_true(profile.has(key), "%s has C1 key %s" % [unit_id, key])
		assert_true(not catalog.weapon(unit_id).is_empty(), "%s's weapon %s has a profile to show" % [unit_id, catalog.weapon_id(unit_id)])
	assert_true(catalog.max_squads <= 5 and catalog.max_squad_size <= 5, "C2: at most 5 squads of 5")
	assert_true(catalog.is_game, "the game catalog runs armies past the game's loader")


func test_units_list_starters_first_then_by_cost() -> void:
	assert_eq(_catalog().unit_ids(), ["scout", "ifv", "tank", "artillery"], "starters by cost, then the tier-1 unit")


func test_matchup_text_reads_like_a_sentence() -> void:
	var catalog := _catalog()
	assert_eq(catalog.matchup_text("scout", true), "Good vs Artillery", "good vs uses role names")
	assert_eq(catalog.matchup_text("scout", false), "Weak vs IFV", "IFV keeps its capitals")


# ---- Draft rules --------------------------------------------------------------------------------

func test_buying_refuses_with_reasons_a_player_can_act_on() -> void:
	var draft := ArmyDraft.new(_starters_only(_catalog(450)))
	assert_eq(draft.add_unit(0, "tank"), "", "a tank fits the budget")
	assert_eq(draft.add_unit(0, "tank"), "", "so does a second")
	assert_true(draft.add_unit(0, "tank").contains("Not enough budget"), "a third doesn't, and says why")
	assert_true(draft.add_unit(0, "artillery").contains("locked"), "a locked unit can't be bought")
	assert_true(draft.add_unit(0, "hovercraft").contains("Unknown"), "nor an unknown one")
	assert_eq(draft.remaining_budget(), 50, "the budget tracks what was bought")


func test_squads_hold_five_and_armies_five_squads() -> void:
	var draft := ArmyDraft.new(_catalog(100000))
	for i in 5:
		assert_eq(draft.add_unit(0, "scout"), "", "unit %d fits Alpha" % (i + 1))
	assert_true(draft.add_unit(0, "scout").contains("full"), "a sixth doesn't")
	assert_eq(draft.squad_with_room(0), 1, "the next squad with room is a new Bravo")
	while draft.squads().size() < 5:
		draft.add_squad()
	assert_true(draft.add_squad().contains("at most 5"), "a sixth squad is refused")
	assert_eq(draft.move_unit(0, 0, 1), "", "a unit moves to another squad")
	assert_eq([draft.units_of(0).size(), draft.units_of(1).size()], [4, 1], "and leaves its old one")


func test_problems_name_what_to_fix() -> void:
	var draft := ArmyDraft.new(_catalog(1000))
	assert_true("  ".join(draft.problems()).contains("Buy a unit"), "an empty army says to buy something")
	draft.add_unit(0, "tank")
	draft.add_squad()
	draft.add_squad()
	assert_true("  ".join(draft.problems()).contains("Charlie is empty"), "an empty squad is named: %s" % [draft.problems()])
	draft.remove_squad(2)
	draft.remove_squad(1)
	draft.units_of(0).append({"unit": "artillery"})
	var locked := ArmyDraft.new(_starters_only(_catalog()), draft.army)
	assert_true("  ".join(locked.problems()).contains("Artillery is locked"), "an army with a locked unit can't fight: %s" % [locked.problems()])
	assert_true(draft.problems().is_empty(), "with everything unlocked it's ready: %s" % [draft.problems()])
	draft.catalog.budget = 300
	assert_true("  ".join(draft.problems()).contains("Over budget by 120"), "over budget says by how much")


func test_saves_are_army_json_v2() -> void:
	var draft := ArmyDraft.new(_catalog())
	draft.add_unit(0, "tank")
	draft.set_paint(0, 0, "#c8a02a")
	draft.tier = 2
	var doctrine := draft.to_doctrine()
	assert_eq(doctrine["squads"][0]["units"], [{"unit": "tank", "paint": "#c8a02a"}], "units are just ids (and paint)")
	assert_true(not doctrine["squads"][0].has("tanks"), "no v1 tanks list")
	assert_eq(doctrine["garage"], {"schema": 2, "budget": 1000, "cost": 200, "tier": 2}, "the builder's summary rides along")
	var saved := ArmyStore.save(doctrine, "v2", TEST_DIR)
	var again := ArmyDraft.from_doctrine(draft.catalog, ArmyStore.read(saved["path"])["doctrine"])
	assert_eq(again.army, draft.army, "a saved army loads back unchanged")
	assert_eq(again.tier, 2, "with its tier")
	ArmyStore.remove("v2", TEST_DIR)


func test_a_ready_game_army_loads_into_a_real_match() -> void:
	var catalog := ArmyCatalog.from_game()
	var draft := ArmyPresets.build("scout_screen", catalog)
	assert_true(draft.is_ready(), "the preset passes the game's loader: %s" % [draft.problems()])
	var parsed := Doctrine.parse(ArmyFormat.to_game_doctrine(draft.to_doctrine()))
	assert_true(parsed.has("doctrine"), "the game's loader reads what FIGHT hands it: %s" % parsed.get("error", ""))
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, parsed["doctrine"]), "", "the match fields it")
	await wait_physics_frames(2)
	assert_eq(game_match.team_tanks(Match.Team.GREEN).size(), draft.unit_count(), "one vehicle per unit bought")


# ---- Migration ----------------------------------------------------------------------------------

func test_round_one_saves_migrate_to_fixed_units() -> void:
	var v1 := {"name": "Old Army", "garage": {"schema": 1, "budget": 1000, "cost": 900}, "squads": [
		{"name": "Alpha", "formation": "wedge", "directive": {"role": "anchor"}, "verb": "hold", "tanks": [
			{"unit": "tank", "weapon": "cannon", "weapons": {"main": "cannon"}, "components": ["ammo_rack"], "paint": "#3a8fd0"},
			{"unit": "tank", "weapon": "laser", "weapons": {"main": "laser"}, "components": ["heat_sink"]},
			{"unit": "hovercraft", "weapon": "cannon"}]},
		{"name": "Bravo", "tanks": [{"weapon": "cannon", "directive": {"role": "scout"}}]}]}
	var catalog := ArmyCatalog.from_game()
	var draft := ArmyDraft.from_doctrine(catalog, v1)
	assert_eq(draft.units_of(0), [{"unit": "tank", "paint": "#3a8fd0"}, {"unit": "lancer"}], "weapons and components go; a laser tank is a Lancer; unknown units drop")
	assert_eq(draft.units_of(1), [{"unit": "tank", "directive": {"role": "scout"}}], "a hand-written tank keeps its directive")
	assert_eq(draft.squad(0)["formation"], "wedge", "squad settings survive")
	assert_true("  ".join(draft.notes).contains("Weapons and components are gone"), "the player is told why their loadouts changed")
	assert_true("  ".join(draft.notes).contains("hovercraft"), "and what was removed")
	assert_true(not ArmyFormat.is_v1(draft.to_doctrine()), "it saves as v2")


func test_every_shipped_doctrine_opens_in_the_builder() -> void:
	var catalog := ArmyCatalog.from_game()
	for file_name in DirAccess.get_files_at("res://doctrines/"):
		if not file_name.ends_with(".json"):
			continue
		var loaded := ArmyStore.read("res://doctrines/" + file_name)
		assert_true(loaded.has("doctrine"), "%s reads" % file_name)
		var draft := ArmyDraft.from_doctrine(catalog, loaded["doctrine"])
		assert_true(draft.unit_count() > 0, "%s keeps its units (%d)" % [file_name, draft.unit_count()])


# ---- Presets ------------------------------------------------------------------------------------

func test_presets_are_legal_spend_the_budget_and_use_only_unlocked_units() -> void:
	for budget in [800, 1700, 3200]:
		var catalog := _starters_only(ArmyCatalog.from_game().with_budget(budget))
		var cheapest := 1000000
		for unit_id in catalog.unit_ids():
			if catalog.is_unlocked(unit_id):
				cheapest = mini(cheapest, catalog.unit_cost(unit_id))
		for preset in ArmyPresets.ids():
			var draft := ArmyPresets.build(preset, catalog)
			assert_true(draft.problems(false).is_empty(), "%s at %d is legal: %s" % [preset, budget, draft.problems(false)])
			assert_true(draft.remaining_budget() < cheapest or draft.unit_count() == catalog.max_units,
					"%s at %d spends the budget (%d left, %d units)" % [preset, budget, draft.remaining_budget(), draft.unit_count()])
			for unit_id: String in draft.counts_by_unit():
				assert_true(catalog.is_unlocked(unit_id), "%s uses only unlocked units (not %s)" % [preset, unit_id])


func test_a_preset_uses_its_signature_unit_once_unlocked() -> void:
	var catalog := ArmyCatalog.from_game().with_budget(1700)
	assert_true(ArmyPresets.build("siege_line", catalog).counts_by_unit().has("artillery"), "Siege Line fields artillery when it's unlocked")
	assert_true(not ArmyPresets.build("siege_line", _starters_only(catalog)).counts_by_unit().has("artillery"), "and falls back without it")
	assert_eq(ArmyPresets.missing_units("siege_line", _starters_only(catalog)), ["artillery"], "the menu can say Siege Line needs artillery")
	assert_eq(ArmyPresets.missing_units("siege_line", catalog), [], "and nothing once it's unlocked")
	assert_eq(ArmyPresets.build("scout_screen", catalog).army, ArmyPresets.build("scout_screen", catalog).army, "presets are deterministic")


# ---- Codes --------------------------------------------------------------------------------------

func test_codes_round_trip_every_preset() -> void:
	var catalog := ArmyCatalog.from_game().with_budget(3200)
	for preset in ArmyPresets.ids():
		var draft := ArmyPresets.build(preset, catalog)
		draft.set_paint(0, 0, "#d04a8c")
		var code := ArmyCode.encode(draft)
		var decoded := ArmyCode.decode(code, catalog)
		assert_true(decoded.has("draft"), "%s decodes: %s" % [preset, decoded.get("error", "")])
		if decoded.has("draft"):
			assert_eq((decoded["draft"] as ArmyDraft).army, draft.army, "%s survives the round trip" % preset)
		assert_true(code.begins_with("TS2") and code.length() < 400, "%s's code is v2 and short (%d chars)" % [preset, code.length()])
		assert_true(code.is_valid_filename() and not code.contains("+") and not code.contains("/") and not code.contains("="),
				"codes are URL- and filename-safe: %s" % code)


func test_bad_codes_are_refused_politely() -> void:
	var catalog := ArmyCatalog.from_game()
	var code := ArmyCode.encode(GarageScreen.starter_army(catalog))
	assert_true(ArmyCode.decode("hello", catalog)["error"].contains("Not an army code"), "garbage")
	assert_true(ArmyCode.decode(code.substr(0, code.length() - 5), catalog)["error"].contains("damaged"), "a truncated paste")
	assert_true(ArmyCode.decode("TS2" + "x".repeat(5000), catalog)["error"].contains("too long"), "an absurd paste")


func test_round_one_codes_still_decode() -> void:
	# A TS1 code made by round 1's garage: one tank with a cannon, one with a laser, in Alpha.
	var compact := {"n": "Legacy", "s": [{"n": "Alpha", "f": "wedge", "h": 1, "t": [{"u": "tank", "w": ["cannon"]},
			{"u": "tank", "w": ["laser"], "c": ["heat_sink"]}]}]}
	var code := ArmyCode._wrap("TS1", JSON.stringify(compact))
	var decoded := ArmyCode.decode(code, ArmyCatalog.from_game())
	assert_true(decoded.has("draft"), "a TS1 code decodes: %s" % decoded.get("error", ""))
	if decoded.has("draft"):
		assert_eq((decoded["draft"] as ArmyDraft).units_of(0), [{"unit": "tank"}, {"unit": "lancer"}], "into fixed units")


# ---- Advice -------------------------------------------------------------------------------------

func test_advice_names_an_uncovered_weakness_and_its_counter() -> void:
	var draft := ArmyDraft.new(_starters_only(_catalog(1000)))
	draft.add_unit(0, "tank")
	draft.add_unit(0, "tank")
	var hints := "  ".join(GarageAdvice.composition_hints(draft))
	assert_true(hints.contains("Tanks are weak vs scouts") and hints.contains("add an IFV"), "all tanks: scouts are the danger, IFVs the fix: %s" % hints)
	draft.add_unit(0, "ifv")
	hints = "  ".join(GarageAdvice.composition_hints(draft))
	assert_true(not hints.contains("weak vs scouts"), "an IFV covers it: %s" % hints)
	assert_true(hints.contains("IFV is weak vs tanks and nothing here counters them."),
			"with artillery locked nothing unlocked counters tanks, so no fix is suggested: %s" % hints)


func test_compare_table_marks_the_best_values() -> void:
	var table := GarageAdvice.unit_table(_catalog())
	var cost_column: int = table["headers"].find("Cost")
	assert_true(table["best"][0][cost_column], "the scout is cheapest")
	var hull_column: int = table["headers"].find("Hull")
	assert_true(table["best"][2][hull_column], "the tank is toughest")
	assert_eq(table["rows"][0][table["headers"].find("Weak vs")], "IFV", "matchups are in the table")


func test_the_matchup_grid_shows_intent_and_prefers_measured_rates() -> void:
	var catalog := _catalog()
	var grid := GarageAdvice.matchup_grid(catalog)
	var scout: int = grid["units"].find("scout")
	var ifv: int = grid["units"].find("ifv")
	var artillery: int = grid["units"].find("artillery")
	assert_eq(grid["rows"][scout][artillery], {"text": "beats", "tone": "good"}, "a scout is built to beat artillery")
	assert_eq(grid["rows"][scout][ifv], {"text": "loses", "tone": "bad"}, "and to lose to IFVs")
	assert_eq(grid["rows"][scout][scout]["text"], "-", "no mirror matchups")
	var measured := GarageAdvice.matchup_grid(catalog, {"scout": {"ifv": 0.55}})
	assert_eq(measured["rows"][scout][ifv], {"text": "55%", "tone": "even"}, "a measured rate wins over intent (and 55% is close to even)")
	assert_true(measured["measured"], "and the view says it's measured")

