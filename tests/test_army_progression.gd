extends TestCase
## Army Y2: the progression profile (C8): award math, unlocks, tiers, migration, and the match report (C3).

const PROFILE := "user://test_army_progression/profile.json"


func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for file_name in DirAccess.get_files_at(PROFILE.get_base_dir()):
		DirAccess.remove_absolute(PROFILE.get_base_dir().path_join(file_name))


func _report(winner: String, seconds := 120.0, green_kills := 0, key := "") -> Dictionary:
	return {"key": key, "winner": winner, "duration_seconds": seconds, "teams": {"green": {"kills": green_kills}, "rust": {"kills": 0}}}


# ---- Award math ---------------------------------------------------------------------------------

func test_winning_pays_more_than_losing_and_losing_still_pays() -> void:
	var win := Progression.credits_for(_report("Green"), "Green")
	var loss := Progression.credits_for(_report("Rust"), "Green")
	var draw := Progression.credits_for(_report("draw"), "Green")
	assert_eq([win["outcome"], loss["outcome"], draw["outcome"]], ["win", "loss", "draw"], "outcomes are read from Green's side")
	assert_true(win["credits"] > draw["credits"] and draw["credits"] > loss["credits"] and loss["credits"] > 0,
			"win > draw > loss > 0: %d %d %d" % [win["credits"], draw["credits"], loss["credits"]])
	assert_eq(Progression.credits_for(_report("Green"), "Rust")["outcome"], "loss", "the same report is a loss for Rust")


func test_kills_and_tier_add_to_the_base() -> void:
	var plain := int(Progression.credits_for(_report("Rust"), "Green")["credits"])
	var fought := Progression.credits_for(_report("Rust", 120.0, 3), "Green")
	assert_eq(int(fought["credits"]), plain + 3 * int(Progression.AWARD["per_kill"]), "each enemy unit destroyed pays")
	var high := int(Progression.credits_for(_report("Green"), "Green", 2)["credits"])
	assert_eq(high, int(Progression.AWARD["win"]) + roundi(Progression.AWARD["win"] * Progression.AWARD["tier_bonus"] * 2), "bigger tiers pay a bigger base")
	var lines: Array = fought["lines"]
	var sum := 0
	for line: Array in lines:
		sum += int(line[1])
	assert_eq(sum, int(fought["credits"]), "the breakdown lines add up to the total shown")


func test_a_forfeit_or_instant_match_pays_nothing() -> void:
	assert_eq(int(Progression.credits_for(_report("Green", 5.0, 4), "Green")["credits"]), 0, "a 5 s match pays nothing")


func test_throwing_matches_is_never_faster_than_trying() -> void:
	# A minimum-length loss with no kills vs a typical 3-minute win with 3 kills: credits per simulated minute.
	var min_seconds := float(Progression.AWARD["min_seconds"])
	var thrown := float(Progression.credits_for(_report("Rust", min_seconds), "Green")["credits"]) / (min_seconds / 60.0)
	var won := float(Progression.credits_for(_report("Green", 180.0, 3), "Green")["credits"]) / 3.0
	assert_true(won > thrown, "a real win earns more per minute (%d) than quitting at the earliest paying moment (%d)" % [won, thrown])


# ---- Profile ------------------------------------------------------------------------------------

func test_award_updates_the_record_saves_and_never_pays_twice() -> void:
	_clean()
	var profile := Progression.new(PROFILE)
	var paid := profile.award(_report("Green", 100.0, 2, "hash@1"))
	assert_true(paid > 0, "a win pays")
	assert_eq(profile.award(_report("Green", 100.0, 2, "hash@1")), 0, "the same match can't be awarded twice (a reload)")
	profile.award(_report("Rust", 100.0, 0, "hash@2"))
	var again := Progression.new(PROFILE)
	assert_eq([again.credits, again.wins, again.losses], [profile.credits, 1, 1], "credits and the record are saved")
	_clean()


func test_unlocks_spend_credits_and_explain_refusals() -> void:
	var catalog := ArmyCatalog.from_game()
	var profile := Progression.new("")
	var locked := catalog.unit_ids().filter(func(id: String) -> bool: return catalog.unlock_tier(id) > 0)
	assert_true(not locked.is_empty(), "setup: some unit needs unlocking")
	var unit_id: String = locked[0]
	var price := Progression.unit_unlock_credits(catalog, unit_id)
	assert_true(not profile.has_unit(catalog, unit_id), "a new player doesn't have it")
	assert_true(profile.unlock_unit(catalog, unit_id).contains("costs %d credits" % price), "no credits: the refusal names the price")
	profile.credits = price + 5
	assert_eq(profile.unlock_unit(catalog, unit_id), "", "with the credits it unlocks")
	assert_eq(profile.credits, 5, "and the price is spent")
	assert_true(profile.catalog_for(catalog, 0).is_unlocked(unit_id), "the army builder's catalog now offers it")
	assert_true(profile.unlock_unit(catalog, unit_id).contains("already"), "unlocking twice is refused")
	for starter in catalog.unit_ids().filter(func(id: String) -> bool: return catalog.unlock_tier(id) == 0):
		assert_true(profile.has_unit(catalog, starter), "starter %s is always unlocked" % starter)


func test_tiers_unlock_in_order_and_set_the_budget() -> void:
	var profile := Progression.new("")
	var base := ArmyCatalog.from_game()
	assert_eq(profile.catalog_for(base, 0).budget, Progression.budget_for(0), "tier 0's budget")
	assert_eq(profile.catalog_for(base, 3).budget, Progression.budget_for(0), "a tier you don't own falls back to yours")
	assert_true(profile.unlock_next_tier().contains("credits"), "no credits, no tier")
	profile.credits = 100000
	assert_eq(profile.unlock_next_tier(), "", "the next tier unlocks")
	assert_eq(profile.budget_tier, 1, "tiers go one at a time")
	for i in Progression.BUDGET_TIERS.size():
		profile.unlock_next_tier()
	assert_eq(profile.budget_tier, Progression.BUDGET_TIERS.size() - 1, "up to the top")
	assert_true(profile.unlock_next_tier().contains("biggest"), "and no further")
	var budgets := Progression.BUDGET_TIERS.map(func(t: Dictionary) -> int: return int(t["budget"]))
	for i in range(1, budgets.size()):
		assert_true(budgets[i] > budgets[i - 1], "each tier is a bigger budget")


func test_profiles_migrate_from_anything() -> void:
	var clean := Progression.migrate({"credits": -40, "budget_tier": 99, "wins": "lots", "unlocked_units": ["lancer", 7, "lancer"]})
	assert_eq(clean["credits"], 0, "negative credits clamp")
	assert_eq(clean["budget_tier"], Progression.BUDGET_TIERS.size() - 1, "an impossible tier clamps")
	assert_eq(clean["wins"], 0, "garbage counts become 0")
	assert_eq(clean["unlocked_units"], ["lancer"], "unlocks are deduplicated strings")
	assert_eq(clean["schema"], Progression.SCHEMA, "and it's the current schema")
	for key in ["schema", "credits", "unlocked_units", "budget_tier", "wins", "losses"]:
		assert_true(clean.has(key), "C8 key %s" % key)


func test_an_unreadable_profile_is_kept_aside_not_wiped() -> void:
	_clean()
	var file := FileAccess.open(PROFILE, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	var profile := Progression.new(PROFILE)
	assert_eq(profile.credits, 0, "a fresh profile starts")
	assert_true(profile.load_error.contains(".bad"), "the player is told where the old one went")
	assert_true(FileAccess.file_exists(PROFILE + ".bad"), "and the old file still exists")
	_clean()


# ---- Match report -------------------------------------------------------------------------------

func test_the_report_counts_units_losses_kills_and_the_best_unit() -> void:
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	var army := {"name": "A", "squads": [{"name": "Alpha", "units": [{"unit": "ifv"}, {"unit": "tank"}]}]}
	var enemy := {"name": "B", "squads": [{"name": "Eyes", "units": [{"unit": "scout"}, {"unit": "scout"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, ArmyFormat.to_game_doctrine(army)), "", "setup: green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, ArmyFormat.to_game_doctrine(enemy)), "", "setup: rust loads")
	await wait_physics_frames(2)
	var report := MatchReport.new()
	add_to_tree(report)
	report.watch(game_match)
	report.unit_names = MatchReport.names_for("Green", army)
	var victims := game_match.team_tanks(Match.Team.RUST)
	for victim in victims:
		victim.apply_damage(100000)
		game_match.tank_destroyed.emit(victim, "Green_Alpha_1")
	var built := report.build({"winner": "Green", "reason": "elimination", "sim_seconds": 64.0, "state_hash": "x", "tick": 9}, 1000, 1)
	assert_eq(built["teams"]["green"]["units"], {"ifv": 1, "tank": 1}, "green's units are the army's unit types")
	assert_eq([built["teams"]["rust"]["units_lost"], built["teams"]["rust"]["units_left"]], [2, 0], "rust lost both")
	assert_eq(built["teams"]["green"]["kills_by_unit"], {"ifv": 2}, "kills are credited to the IFV's type")
	assert_eq(built["best_unit"]["name"], "Green_Alpha_1", "the best unit is the one with the kills")
	assert_eq([built["duration_seconds"], built["budget"], built["tier"]], [64.0, 1000, 1], "duration, budget, tier")
	assert_eq(MatchReport.describe_units({"tank": 2, "scout": 1}, ArmyCatalog.from_game()), "2 Tanks, 1 Scout", "a readable composition")
