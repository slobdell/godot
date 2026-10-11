extends TestCase
## Round 25 (native N6, contract C25.6; his pick 2026-10-10: "20 now, C++ continues"): the army cap follows the render
## preset. The laptop preset fields Units.LAPTOP_SQUADS (4) squads, 20 a side; every other preset Units.MAX_SQUADS (5),
## which stays the ceiling. One test per rule. The preset is switched here through RenderLevers' own activation and put
## back after each test, so the rest of the suite (headless = desktop) never sees the laptop's cap.

var _saved := {}
## Five squad names of five families (SquadConsolidation folds "Spears2" into "Spears").
const NAMES: Array[String] = ["Alpha", "Bravo", "Charlie", "Delta", "Echo"]


func _laptop() -> void:
	_saved = {"on": RenderLevers._on.duplicate(), "read": RenderLevers._read, "preset": RenderLevers._preset,
			"source": RenderLevers.source}
	RenderLevers._activate(RenderLevers.PRESETS["laptop"], "laptop", "test")


func _restore() -> void:
	RenderLevers._on = _saved["on"]
	RenderLevers._read = _saved["read"]
	RenderLevers._preset = _saved["preset"]
	RenderLevers.source = _saved["source"]


## Five squads of five, named apart (a saved garage army at the desktop cap).
static func _five_squads(unit_id: String) -> Dictionary:
	var squads: Array = []
	for index in Units.MAX_SQUADS:
		var units: Array = []
		for _i in 5:
			units.append({"unit": unit_id})
		squads.append({"name": NAMES[index], "units": units})
	return {"name": "Five", "squads": squads}


static func _vehicles(doctrine: Dictionary) -> int:
	var count := 0
	for squad: Dictionary in doctrine.get("squads", []):
		count += (squad.get("units", []) as Array).size()
	return count


func test_the_rule_by_preset() -> void:
	assert_eq(Units.squads_for_preset("laptop"), 4, "the laptop preset: four squads")
	assert_eq(Units.squads_for_preset("desktop"), Units.MAX_SQUADS, "desktop: the ceiling")
	assert_eq(Units.squads_for_preset("custom"), Units.MAX_SQUADS, "an explicit lever list: the ceiling")
	assert_true(Units.LAPTOP_SQUADS < Units.MAX_SQUADS, "the laptop's cap sits under the compile-time ceiling")


func test_headless_is_desktop_so_baselines_do_not_move() -> void:
	assert_eq(RenderLevers.preset(), "desktop", "a headless run is desktop")
	assert_eq(Units.max_squads(), Units.MAX_SQUADS, "five squads headless")
	assert_eq(Units.max_units(), Units.MAX_SQUADS * Formations.MAX_MEMBERS, "25 vehicles headless")
	assert_eq(ArmyCatalog.for_game("law").max_squads, Units.MAX_SQUADS, "the garage headless: five")


func test_laptop_reads_four_squads_twenty_vehicles() -> void:
	_laptop()
	var squads := Units.max_squads()
	var units := Units.max_units()
	_restore()
	assert_eq(squads, 4, "four squads on the laptop preset")
	assert_eq(units, 20, "twenty vehicles on the laptop preset")
	assert_eq(Units.max_squads(), Units.MAX_SQUADS, "restored: the next match reads the preset again")


func test_the_garage_shows_the_cap_the_match_uses() -> void:
	_laptop()
	var catalog := ArmyCatalog.for_game("gangs")
	var game := ArmyCatalog.from_game()
	_restore()
	assert_eq(catalog.max_squads, 4, "the garage offers four squads on the laptop")
	assert_eq(catalog.max_units, 20, "and twenty vehicles")
	assert_eq(game.max_squads, 4, "from_game too")
	assert_eq(catalog.budget, Credits.GAME_CREDITS, "credits stay as they are")
	assert_eq(ArmyCatalog.for_game("gangs").budget, Credits.GAME_CREDITS, "the same money on the desktop")


func test_a_saved_five_squad_army_keeps_its_first_four_and_says_so() -> void:
	_laptop()
	var catalog := ArmyCatalog.for_game("gangs")
	var draft := ArmyDraft.from_doctrine(catalog, _five_squads(Units.roster("gangs")[0]))
	_restore()
	assert_eq(draft.squads().size(), 4, "four squads kept")
	assert_eq(String(draft.squads()[0]["name"]), "Alpha", "the FIRST squads, in order")
	assert_eq(String(draft.squads()[3]["name"]), "Delta", "the fifth is the one left out")
	assert_eq(draft.unit_count(), 20, "twenty vehicles")
	var said := false
	for note in draft.notes:
		said = said or (note.contains("4 squads") and note.contains("first 4"))
	assert_true(said, "a note says so: %s" % [draft.notes])
	assert_true(draft.problems(false).is_empty() or not "\n".join(draft.problems(false)).contains("Too many squads"),
			"the kept army is not 'too many squads'")


func test_the_desktop_keeps_a_five_squad_army_whole() -> void:
	var draft := ArmyDraft.from_doctrine(ArmyCatalog.for_game("gangs"), _five_squads(Units.roster("gangs")[0]))
	assert_eq(draft.squads().size(), 5, "five squads on the desktop")
	assert_eq(draft.unit_count(), 25, "25 vehicles")
	for note in draft.notes:
		assert_true(not note.contains("squads: kept"), "no cap note on the desktop")


func test_the_cpu_opponent_is_capped_the_same_way() -> void:
	for faction: String in Units.FACTIONS:
		for seed_value in [1, 7, 92721]:
			var desktop := GarageOpponent.build("cpu", faction, seed_value)
			_laptop()
			var laptop := GarageOpponent.build("cpu", faction, seed_value)
			_restore()
			if desktop.has("error") or laptop.has("error"):
				assert_true(desktop.has("error") == laptop.has("error"), "%s: the same error both ways" % faction)
				continue
			var d: Dictionary = desktop["doctrine"]
			var l: Dictionary = laptop["doctrine"]
			assert_true((l["squads"] as Array).size() <= 4, "%s/%d: at most four CPU squads on the laptop" % [faction, seed_value])
			assert_true(_vehicles(l) <= 20, "%s/%d: at most 20 CPU vehicles on the laptop (%d)" % [faction, seed_value, _vehicles(l)])
			assert_true((d["squads"] as Array).size() <= Units.MAX_SQUADS and _vehicles(d) <= 25,
					"%s/%d: the desktop's CPU is unchanged in size" % [faction, seed_value])
			assert_eq(_vehicles(l), mini(20, _vehicles(d)), "%s/%d: the same purchase, cut at the cap" % [faction, seed_value])


func test_the_players_fold_reads_the_cap() -> void:
	var army := _five_squads(Units.roster("law")[0])
	assert_eq((SquadConsolidation.for_player(army)["squads"] as Array).size(), 5, "five squads on the desktop")
	_laptop()
	var folded := SquadConsolidation.for_player(army)
	_restore()
	assert_eq((folded["squads"] as Array).size(), 4, "folded into four on the laptop")


static func _counts(doctrine: Dictionary) -> Dictionary:
	var counts := {}
	for squad: Dictionary in doctrine.get("squads", []):
		for entry: Dictionary in squad.get("units", []):
			var role := String(Units.PROFILES[String(entry["unit"])].get("role", entry["unit"]))
			counts[role] = int(counts.get(role, 0)) + 1
	return counts


func test_a_laptop_cap_cpu_army_keeps_its_role_mix() -> void:
	# The orchestrator's condition (C25.6): the CPU buys the same archetype order and stops at 20, so each role's share
	# is the desktop army's share of 20, within one vehicle and a half (the purchase cycles through the order).
	for faction: String in [""] + Array(Units.FACTIONS):
		for seed_value in [1, 7, 4242, 92721]:
			var budget := Units.BASELINE_BUDGET if faction != "" else Units.DEFAULT_BUDGET
			var desktop := Army.cpu_army("cpu", seed_value, budget, faction)
			_laptop()
			var laptop := Army.cpu_army("cpu", seed_value, budget, faction)
			_restore()
			var d_total := _vehicles(desktop)
			var l_total := _vehicles(laptop)
			assert_eq(l_total, mini(20, d_total), "%s/%d: the laptop buys to 20 (desktop %d)" % [faction, seed_value, d_total])
			var d := _counts(desktop)
			var l := _counts(laptop)
			for role: String in d:
				var expected := float(d[role]) * float(l_total) / float(d_total)
				assert_true(absf(float(l.get(role, 0)) - expected) <= 1.5, "%s/%d %s: %d on the laptop, %.1f proportional (desktop %d of %d)"
						% [faction, seed_value, role, int(l.get(role, 0)), expected, int(d[role]), d_total])


func test_the_desktop_cpu_army_is_unchanged() -> void:
	var past := 0
	for faction: String in [""] + Array(Units.FACTIONS):
		var budget := Units.BASELINE_BUDGET if faction != "" else Units.DEFAULT_BUDGET
		var once := Army.cpu_army("cpu", 92721, budget, faction)
		assert_eq(once, Army.cpu_army("cpu", 92721, budget, faction), "%s: deterministic" % faction)
		assert_true(_vehicles(once) <= Army.MAX_ARMY_UNITS, "%s: the desktop's own cap" % faction)
		past += 1 if _vehicles(once) > 20 else 0
	assert_true(past > 0, "some desktop faction army is past the laptop's 20, so the cap is exercised")


func test_the_skirmish_cap_folds_then_trims() -> void:
	# A plain skirmish's faction army bought at the DESKTOP size: many five-vehicle squads and more than 20 vehicles.
	for faction: String in Units.FACTIONS:
		var big := Army.cpu_army("cpu", 7, Units.BASELINE_BUDGET, faction)
		if _vehicles(big) <= 20:
			continue
		var before := _counts(big)
		var capped := SkirmishMode.capped(big, 4)
		# At most four: the fold joins families (Spears2 into Spears) and splits only a squad past SquadConsolidation.SPLIT_OVER.
		assert_true((capped["squads"] as Array).size() <= 4, "%s: at most four squads (%d in, %d out)" % [faction,
				(big["squads"] as Array).size(), (capped["squads"] as Array).size()])
		assert_eq(_vehicles(capped), 20, "%s: twenty vehicles" % faction)
		assert_true(_vehicles(big) > 20, "%s: the input is not changed" % faction)
		var after := _counts(capped)
		for role: String in before:
			assert_true(after.has(role), "%s: %s keeps a vehicle (%s -> %s)" % [faction, role, before, after])
	var small := {"name": "Small", "squads": [{"name": "A", "units": [{"unit": Units.roster("law")[0]}]}]}
	assert_eq(SkirmishMode.capped(small, 4), small, "an army under the cap is unchanged")
	var five := _five_squads(Units.roster("law")[0])
	var five_capped := SkirmishMode.capped(five, 4)
	assert_eq((five_capped["squads"] as Array).size(), 4, "five squads in, four out")
	assert_eq(String(five_capped["squads"][3]["name"]), "Delta", "the FIRST four, like the garage")
	assert_eq(_vehicles(five_capped), 20, "and twenty vehicles")


func test_squad_cap_flag_pins_the_cap_for_measurements() -> void:
	var flags := LaunchFlags.new()
	assert_eq(SkirmishMode.squad_cap_for(flags), Units.max_squads(), "no flag: this machine's cap")
	flags.values["squad-cap"] = "5"
	_laptop()
	var pinned := SkirmishMode.squad_cap_for(flags)
	flags.values["squad-cap"] = "machine"
	var machine := SkirmishMode.squad_cap_for(flags)
	flags.values["squad-cap"] = "9"
	var clamped := SkirmishMode.squad_cap_for(flags)
	_restore()
	assert_eq(pinned, 5, "--squad-cap=5 means 25 a side on the laptop preset (C24.7's instrument)")
	assert_eq(machine, 4, "--squad-cap=machine: the laptop's own four")
	assert_eq(clamped, Units.MAX_SQUADS, "never past the ceiling")


func test_the_planning_hint_names_the_cap() -> void:
	assert_eq(SkirmishMode.planning_hint(5), "PLANNING: select (click, drag, 1-5) and right-click to order; Space starts",
			"the desktop's line is unchanged")
	assert_true(SkirmishMode.planning_hint(4).contains("1-4)"), "the laptop's names keys 1-4")
