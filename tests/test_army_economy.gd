extends TestCase
## Round 19 (garage, G1): 1000 credits a game for both sides, every vehicle priced and open, the CPU at the same money
## and the same rules. The lead: *"each player is given 1000 credits per game ... Each vehicle has a cost, and they
## allocate so many credits to buy the units they want"* (2026-10-05). Contract C19.2: prices are balance (his), so
## credits are a PRESENTATION of the points (Credits), and the points every CPU army is bought with must not move.
##
## Round 20 (garage, R1; contract C20.1): the scale is anchored on the Road Gangs' scout. The lead: *"for now we will
## assume that an all scout army for the road gangs is 25 vehicles, and all costs and counts can be based on that"*
## (2026-10-06). One credit = 1.75 points for every faction, each price rounded UP to the credit.

## The 21 prices at the round-19 launch (567e1997). C19.2: they move once, on purpose, with the baseline lines
## declared; this table is that tripwire (a price change fails here first, in words).
const PRICES_AT_LAUNCH := {"scout": 110, "tank": 200, "ifv": 150, "artillery": 220, "lancer": 200, "burner": 220,
		"gang_scout": 70, "gang_ifv": 110, "gang_tank": 175, "gang_artillery": 170, "gang_support": 130,
		"law_scout": 140, "law_ifv": 195, "law_tank": 260, "law_artillery": 250, "law_suppressor": 230,
		"syn_scout": 210, "syn_ifv": 300, "syn_tank": 470, "syn_artillery": 380, "syn_lancer": 340}

## Round 20 (R1): the 21 prices the garage shows, in credits (points x 4/7, rounded up). The table he reads.
const CREDITS_R20 := {"scout": 63, "tank": 115, "ifv": 86, "artillery": 126, "lancer": 115, "burner": 126,
		"gang_scout": 40, "gang_ifv": 63, "gang_tank": 100, "gang_artillery": 98, "gang_support": 75,
		"law_scout": 80, "law_ifv": 112, "law_tank": 149, "law_artillery": 143, "law_suppressor": 132,
		"syn_scout": 120, "syn_ifv": 172, "syn_tank": 269, "syn_artillery": 218, "syn_lancer": 195}

## How many scouts 1000 credits buys, per faction (his rule: 25 for the Gangs; the others keep their identity by count).
const ALL_SCOUT_ARMY := {"gangs": 25, "condemned": 15, "law": 12, "syndicate": 8}

## Round 20 (R1): the proof that the skirmish and the baselines' armies are untouched. A digest of `Army.cpu_army` for
## every archetype x seeds 0-19 at the skirmish budget (with its faction) and the plain "cpu" army at the default
## budget, pinned at ae80f557 (where R1 starts; R1 touches neither Army nor Units). A change here is a change to every
## baseline line: it moves only with them, declared.
const CPU_ARMY_DIGEST := "5681a05efe937bd22368c0251bae7ea0"


func test_the_points_every_army_is_bought_with_have_not_moved() -> void:
	for unit_id: String in PRICES_AT_LAUNCH:
		assert_eq(Units.cost_of({"unit": unit_id}), PRICES_AT_LAUNCH[unit_id],
				"%s still costs its launch points (C19.2: a price moves only on purpose)" % unit_id)
	assert_eq(Units.PROFILES.size(), PRICES_AT_LAUNCH.size(), "every unit's price is pinned here")


func test_twenty_five_gangs_scouts_are_exactly_1000_credits() -> void:
	assert_eq(Credits.ANCHOR_UNIT, "gang_scout", "the anchor is the Road Gangs' scout")
	assert_eq(Credits.of_unit(Credits.ANCHOR_UNIT) * Credits.ANCHOR_COUNT, Credits.GAME_CREDITS,
			"25 Gangs scouts are exactly the game's 1000 credits")
	assert_eq(Credits.of_unit("gang_scout"), 40, "the Gangs' scout is 40 CR")
	assert_eq(Credits.POINTS_PER_CREDIT, 1.75, "one credit is 1.75 points")
	assert_eq(Credits.game_points(), 1750, "1000 credits is 1,750 points: 25 x the scout's 70")
	assert_eq(Credits.to_points(Credits.GAME_CREDITS), Units.cost_of({"unit": "gang_scout"}) * 25,
			"the fight's points are exactly the anchor army's")
	assert_eq(Credits.text(40), "40 CR", "credits are written 40 CR")


func test_the_price_table() -> void:
	var lines: PackedStringArray = []
	for unit_id: String in CREDITS_R20:
		var points := Units.cost_of({"unit": unit_id})
		var credits := Credits.of_unit(unit_id)
		assert_eq(credits, CREDITS_R20[unit_id], "%s (%d points) is %d CR" % [unit_id, points, CREDITS_R20[unit_id]])
		lines.append("%s %d pts = %d CR (%.2f)" % [unit_id, points, credits, float(points) / Credits.POINTS_PER_CREDIT])
	assert_eq(CREDITS_R20.size(), Units.PROFILES.size(), "every unit's credit price is in the table")
	print("MEASURE r20_prices: %s" % " | ".join(lines))


func test_a_price_is_its_points_rounded_up_to_the_credit() -> void:
	for unit_id: String in Units.PROFILES:
		var points := Units.cost_of({"unit": unit_id})
		var credits := Credits.of_unit(unit_id)
		# credits x 7/4 >= points (never undercharges) and (credits - 1) x 7/4 < points (by less than one credit).
		assert_true(credits * 7 >= points * 4, "%s: %d CR covers its %d points" % [unit_id, credits, points])
		assert_true((credits - 1) * 7 < points * 4, "%s: %d CR is rounded up by less than a credit" % [unit_id, credits])
		assert_true(Credits.to_points(credits) >= points, "%s: its credits back in points cover it" % unit_id)


func test_an_all_scout_army_at_1000_credits() -> void:
	for faction: String in ALL_SCOUT_ARMY:
		var scout := ""
		for unit_id: String in Units.roster(faction):
			if String(Units.PROFILES[unit_id]["role"]) == "scout":
				scout = unit_id
		var count := mini(Credits.GAME_CREDITS / Credits.of_unit(scout), ArmyCatalog.MAX_SQUADS * ArmyCatalog.MAX_SQUAD_SIZE)
		assert_eq(count, ALL_SCOUT_ARMY[faction], "%s: an all-scout army at 1000 CR is %d %ss" % [faction,
				ALL_SCOUT_ARMY[faction], scout])
		# And the garage lets him buy exactly that many, one tap each.
		var draft := ArmyDraft.new(ArmyCatalog.for_game(faction))
		var bought := 0
		for i in 30:
			var squad := draft.squad_with_room(0)
			if squad < 0 or draft.add_unit(squad, scout) != "":
				break
			bought += 1
		assert_eq(bought, count, "%s: the garage buys %d scouts" % [faction, count])
		if faction == "gangs":
			assert_eq(draft.remaining_budget(), 0, "the Gangs' 25 scouts spend every credit")
			assert_eq(draft.squads().size(), 5, "in five squads of five")
		else:
			assert_true(draft.remaining_budget() < Credits.of_unit(scout), "%s: the credits run out first" % faction)


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
		assert_eq(catalog.budget_points(), Credits.game_points(), "%s: fought at 1,750 points" % faction)
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
			assert_true(points <= Credits.to_points(draft.total_cost()), "%s: the fight is charged no more than the credits shown" % faction)
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
	assert_true(error.contains("269 CR"), "a refused buy names the price in credits: %s" % error)
	assert_true(error.contains("CR left"), "and what is left in credits: %s" % error)


func test_the_cpu_fights_at_the_same_money_and_the_same_rules() -> void:
	var sizes := {}
	for faction: String in Units.FACTIONS:
		for seed_value in 12:
			var built := GarageOpponent.build("cpu", faction, seed_value)
			assert_true(built.has("doctrine"), "%s seed %d builds: %s" % [faction, seed_value, built.get("error", "")])
			var doctrine: Dictionary = built["doctrine"]
			var entries := Doctrine.entries(doctrine)
			var credits := 0
			for item: Dictionary in entries:
				credits += Credits.of_unit(String(item["entry"]["unit"]))
			var cost := Units.army_cost(doctrine)
			assert_true(credits <= Credits.GAME_CREDITS, "%s seed %d spends at most 1000 credits (%d)" % [faction, seed_value, credits])
			assert_true(cost <= Credits.game_points(), "%s seed %d fits the fight's 1,750 points (%d)" % [faction, seed_value, cost])
			assert_eq(int(doctrine["cost"]), cost, "the doctrine's cost is in points, as the loader reads it")
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
				cheapest = minf(cheapest, float(Credits.of_unit(unit_id)))
			assert_true(entries.size() == 25 or Credits.GAME_CREDITS - credits < cheapest,
					"%s seed %d spends all it can (%d CR, %d vehicles)" % [faction, seed_value, credits, entries.size()])
			sizes["%s/%d" % [faction, seed_value]] = "%d:%d" % [entries.size(), credits]
		assert_eq(GarageOpponent.build("cpu", faction, 7), GarageOpponent.build("cpu", faction, 7),
				"%s: the same seed is the same army (REMATCH meets it again)" % faction)
	print("MEASURE r20_cpu_armies (vehicles:credits): %s" % sizes)
	var named: Dictionary = GarageOpponent.build("cpu:law_cordon", "law", 3)["doctrine"]
	assert_eq(named["archetype"], "law_cordon", "a named archetype of the faction is that archetype")
	var foreign: Dictionary = GarageOpponent.build("cpu:siege", "law", 3)["doctrine"]
	assert_true(Army.archetypes_for("law").has(foreign["archetype"]), "another faction's archetype falls back to this one's")
	assert_true(GarageOpponent.build("cpu", "wardens", 1).has("error"), "an unknown faction is an error, not an army")


func test_the_skirmish_armies_are_untouched() -> void:
	# The baselines and series buy at Units.BASELINE_BUDGET with Army.cpu_army; the garage never goes near them. Pinned
	# sizes at seed 3 (567e1997): a change here is a change to every baseline line.
	var sizes := {}
	for faction: String in Units.FACTIONS:
		sizes[faction] = Doctrine.entries(Army.cpu_army("cpu", 3, Units.BASELINE_BUDGET, faction)).size()
	assert_eq(Units.BASELINE_BUDGET, 5200, "the skirmish budget is still 5,200 points")
	assert_eq(sizes, {"condemned": 27, "gangs": 44, "law": 24, "syndicate": 17}, "the skirmish armies' sizes at seed 3")
	print("MEASURE skirmish_sizes seed 3 at %d: %s" % [Units.BASELINE_BUDGET, sizes])


func test_every_archetype_and_seed_buys_the_army_it_bought_before() -> void:
	var parts: PackedStringArray = []
	var count := 0
	for archetype: String in Army.ARCHETYPES:
		var faction := String(Army.ARCHETYPES[archetype].get("faction", Units.DEFAULT_FACTION))
		for seed_value in 20:
			parts.append(JSON.stringify(Army.cpu_army("cpu:" + archetype, seed_value, Units.BASELINE_BUDGET, faction), "", true))
			count += 1
	for seed_value in 20:
		parts.append(JSON.stringify(Army.cpu_army("cpu", seed_value), "", true))
		count += 1
	var digest := "\n".join(parts).md5_text()
	print("MEASURE r20_cpu_army_digest %d armies (%d archetypes x 20 seeds + 20 plain): %s" % [count,
			Army.ARCHETYPES.size(), digest])
	assert_eq(digest, CPU_ARMY_DIGEST, "Army.cpu_army builds the same armies as before R1 (the baselines' input)")
