extends TestCase
## Round 19 (garage, G1): 1000 credits a game for both sides, every vehicle priced and open, the CPU at the same money
## and the same rules. The lead: *"each player is given 1000 credits per game ... Each vehicle has a cost, and they
## allocate so many credits to buy the units they want"* (2026-10-05). Contract C19.2: prices are balance (his), so
## credits are a PRESENTATION of the points (Credits), and the points every CPU army is bought with must not move.

## The 21 prices at the round-19 launch (567e1997). C19.2: they move once, on purpose, with the baseline lines
## declared; this table is that tripwire (a price change fails here first, in words).
const PRICES_AT_LAUNCH := {"scout": 110, "tank": 200, "ifv": 150, "artillery": 220, "lancer": 200, "burner": 220,
		"gang_scout": 70, "gang_ifv": 110, "gang_tank": 175, "gang_artillery": 170, "gang_support": 130,
		"law_scout": 140, "law_ifv": 195, "law_tank": 260, "law_artillery": 250, "law_suppressor": 230,
		"syn_scout": 210, "syn_ifv": 300, "syn_tank": 470, "syn_artillery": 380, "syn_lancer": 340}


func test_the_points_every_army_is_bought_with_have_not_moved() -> void:
	for unit_id: String in PRICES_AT_LAUNCH:
		assert_eq(Units.cost_of({"unit": unit_id}), PRICES_AT_LAUNCH[unit_id],
				"%s still costs its launch points (C19.2: a price moves only on purpose)" % unit_id)
	assert_eq(Units.PROFILES.size(), PRICES_AT_LAUNCH.size(), "every unit's price is pinned here")


func test_a_credit_is_exactly_five_points_for_every_vehicle() -> void:
	for unit_id: String in Units.PROFILES:
		var points := Units.cost_of({"unit": unit_id})
		assert_eq(points % Credits.POINTS_PER_CREDIT, 0, "%s's %d points are a whole number of credits" % [unit_id, points])
		assert_eq(Credits.to_points(Credits.of_unit(unit_id)), points, "%s: credits back to points is exact" % unit_id)
	assert_eq(Credits.game_points(), 5000, "1000 credits is 5,000 points: about the army a skirmish fields (5,200)")
	assert_eq(Credits.text(40), "40 CR", "credits are written 40 CR")


func test_credit_prices_keep_the_order_of_the_points() -> void:
	var ids: Array = Units.PROFILES.keys()
	for a: String in ids:
		for b: String in ids:
			if Units.cost_of({"unit": a}) < Units.cost_of({"unit": b}):
				assert_true(Credits.of_unit(a) < Credits.of_unit(b), "%s stays cheaper than %s in credits" % [a, b])


func test_a_new_player_sees_1000_credits_and_every_vehicle_of_every_faction() -> void:
	for faction: String in Units.FACTIONS:
		var catalog := ArmyCatalog.for_game(faction)
		assert_eq(catalog.budget, 1000, "%s: the game's money is 1000 credits" % faction)
		assert_eq(catalog.budget_points(), Credits.game_points(), "%s: fought at 5,000 points" % faction)
		assert_eq(catalog.faction, faction, "the catalog knows its faction")
		var roster := Units.roster(faction)
		assert_eq(catalog.unit_ids().size(), roster.size(), "%s: the whole roster is offered" % faction)
		for unit_id: String in roster:
			assert_true(catalog.is_unlocked(unit_id), "%s: the %s is open from the first game" % [faction, unit_id])
			assert_eq(catalog.unit_cost(unit_id), Credits.of_unit(unit_id), "%s's card price is its credits" % unit_id)
		var draft := ArmyDraft.new(catalog)
		var cheapest: String = catalog.unit_ids()[0]
		assert_eq(draft.add_unit(0, cheapest), "", "%s: the first tap buys" % faction)


func test_the_credits_left_are_exact_to_the_credit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	for faction: String in Units.FACTIONS:
		var catalog := ArmyCatalog.for_game(faction)
		var ids := catalog.unit_ids()
		for trial in 20:
			var draft := ArmyDraft.new(catalog)
			for i in 40:
				var squad := draft.squad_with_room(rng.randi_range(0, 4))
				if squad < 0:
					break
				draft.add_unit(squad, ids[rng.randi_range(0, ids.size() - 1)])
			var shown := 0
			for squad_data: Dictionary in draft.squads():
				for entry: Dictionary in squad_data["units"]:
					shown += catalog.unit_cost(String(entry["unit"]))
			assert_eq(draft.total_cost(), shown, "the meter is the sum of the cards' prices")
			assert_eq(draft.remaining_budget(), 1000 - shown, "what is left is 1000 minus what was bought")
			assert_true(draft.remaining_budget() >= 0, "buying never overdraws")
			var points := Units.army_cost(ArmyFormat.to_game_doctrine(draft.to_doctrine()))
			assert_eq(points, Credits.to_points(draft.total_cost()), "%s: the fight is charged exactly the credits shown" % faction)
			assert_true(points <= catalog.budget_points(), "and fits the fight's budget")


func test_refusals_speak_in_credits() -> void:
	var catalog := ArmyCatalog.for_game("syndicate")
	var draft := ArmyDraft.new(catalog)
	var error := ""
	for i in 30:
		var squad := draft.squad_with_room(0)
		if squad < 0:
			break
		error = draft.add_unit(squad, "syn_tank")
		if error != "":
			break
	assert_true(error.contains("94 CR"), "a refused buy names the price in credits: %s" % error)
	assert_true(error.contains("CR left"), "and what is left in credits: %s" % error)


func test_the_cpu_fights_at_the_same_money_and_the_same_rules() -> void:
	for faction: String in Units.FACTIONS:
		for seed_value in 12:
			var built := GarageOpponent.build("cpu", faction, seed_value)
			assert_true(built.has("doctrine"), "%s seed %d builds: %s" % [faction, seed_value, built.get("error", "")])
			var doctrine: Dictionary = built["doctrine"]
			var entries := Doctrine.entries(doctrine)
			var cost := Units.army_cost(doctrine)
			assert_true(cost <= Credits.game_points(), "%s seed %d fits 1000 credits (%d points)" % [faction, seed_value, cost])
			assert_true(entries.size() <= 25, "%s seed %d fields at most 25 vehicles, as he can (%d)" % [faction, seed_value,
					entries.size()])
			assert_true((doctrine["squads"] as Array).size() <= 5, "%s: at most five squads" % faction)
			for squad: Dictionary in doctrine["squads"]:
				assert_true((squad["units"] as Array).size() <= 5, "%s: squads of at most five" % faction)
				assert_true(not squad.has("formation"), "a CPU squad steers by objectives, never a bare formation (trip-up 53)")
			for item: Dictionary in entries:
				assert_eq(Units.faction_of(String(item["entry"]["unit"])), faction, "%s buys only its own vehicles" % faction)
			# It spends what it can: the cap, or less than its cheapest vehicle left over.
			var cheapest := INF
			for unit_id: String in Army.ARCHETYPES[doctrine["archetype"]]["units"]:
				cheapest = minf(cheapest, float(Units.cost_of({"unit": unit_id})))
			assert_true(entries.size() == 25 or Credits.game_points() - cost < cheapest,
					"%s seed %d spends all it can (%d points, %d vehicles)" % [faction, seed_value, cost, entries.size()])
		assert_eq(GarageOpponent.build("cpu", faction, 7), GarageOpponent.build("cpu", faction, 7),
				"%s: the same seed is the same army (REMATCH meets it again)" % faction)
	var named: Dictionary = GarageOpponent.build("cpu:law_cordon", "law", 3)["doctrine"]
	assert_eq(named["archetype"], "law_cordon", "a named archetype of the faction is that archetype")
	var foreign: Dictionary = GarageOpponent.build("cpu:siege", "law", 3)["doctrine"]
	assert_true(Army.archetypes_for("law").has(foreign["archetype"]), "another faction's archetype falls back to this one's")
	assert_true(GarageOpponent.build("cpu", "wardens", 1).has("error"), "an unknown faction is an error, not an army")


func test_the_skirmish_armies_are_untouched() -> void:
	# The baselines and series buy at Units.BASELINE_BUDGET with Army.cpu_army; G1 never goes near them. Pinned sizes
	# at seed 3 (567e1997): a change here is a change to every baseline line.
	var sizes := {}
	for faction: String in Units.FACTIONS:
		sizes[faction] = Doctrine.entries(Army.cpu_army("cpu", 3, Units.BASELINE_BUDGET, faction)).size()
	assert_eq(Units.BASELINE_BUDGET, 5200, "the skirmish budget is still 5,200 points")
	print("MEASURE skirmish_sizes seed 3 at %d: %s" % [Units.BASELINE_BUDGET, sizes])
