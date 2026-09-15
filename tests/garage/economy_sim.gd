extends SceneTree
## Army Y5 (`make economy-sim`): simulated players earning credits with the real Progression numbers
## (awards, tier budgets, unlock prices) and the game's catalog, to measure time-to-unlock. Not a test.
## Prints a markdown table (for _agents/balance.md, "Economy") and ECONOMY_SIM lines.
##   -- --players=N (default 400)   -- --seed=N (default 1)
##
## Model (assumptions stated so they can be argued with):
##   - Both armies spend the tier budget; units per side ≈ budget / the average starter cost.
##   - A win destroys ~90% of the enemy army, a loss ~35%, a draw ~60% (each with ±20% noise).
##   - Match length (minutes) = 2.5 + 0.9 × tier, ±25%: bigger armies fight longer.
##   - Players always fight at their highest tier, and spend credits greedily on the cheapest remaining
##     unlock (a unit type or the next tier).
##   - Draws happen 5% of the time; win rate p is fixed per simulated player (0.35 / 0.5 / 0.65).

const WIN_RATES := [0.35, 0.5, 0.65]
const KILL_SHARE := {"win": 0.9, "loss": 0.35, "draw": 0.6}


func _initialize() -> void:
	var players := 400
	var seed_value := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="):
			players = arg.trim_prefix("--players=").to_int()
		elif arg.begins_with("--seed="):
			seed_value = arg.trim_prefix("--seed=").to_int()
	var catalog := ArmyCatalog.from_game()
	var starter_cost := 0.0
	var starters := 0
	for unit_id in catalog.unit_ids():
		if catalog.unlock_tier(unit_id) == 0:
			starter_cost += catalog.unit_cost(unit_id)
			starters += 1
	starter_cost /= maxi(starters, 1)
	var milestones := ["first unlock", "every unit", "tier 1", "tier 2", "tier 3", "top tier", "everything"]
	print("| Win rate | " + " | ".join(milestones) + " |")
	print("|---|" + "---|".repeat(milestones.size()))
	for p: float in WIN_RATES:
		var totals := {}
		for m: String in milestones:
			totals[m] = [0.0, 0.0]  # matches, minutes
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value * 7919 + int(p * 100)
		for _i in players:
			var reached := _simulate(catalog, starter_cost, p, rng)
			for m: String in milestones:
				totals[m][0] += reached[m][0]
				totals[m][1] += reached[m][1]
		var cells: PackedStringArray = []
		for m: String in milestones:
			cells.append("%.0f (%.1f h)" % [totals[m][0] / players, totals[m][1] / players / 60.0])
		print("| %d%% | %s |" % [roundi(p * 100), " | ".join(cells)])
		print("ECONOMY_SIM p=%.2f everything_matches=%.0f everything_hours=%.1f" % [p, totals["everything"][0] / players, totals["everything"][1] / players / 60.0])
	var per_match: PackedStringArray = []
	for tier in Progression.BUDGET_TIERS.size():
		var units := Progression.budget_for(tier) / starter_cost
		var win := int(Progression.credits_for({"winner": "Green", "duration_seconds": 600.0, "teams": {"green": {"kills": roundi(units * KILL_SHARE["win"])}}}, "Green", tier)["credits"])
		var loss := int(Progression.credits_for({"winner": "Rust", "duration_seconds": 600.0, "teams": {"green": {"kills": roundi(units * KILL_SHARE["loss"])}}}, "Green", tier)["credits"])
		per_match.append("tier %d (%d, ~%.0f units): win %d, loss %d" % [tier, Progression.budget_for(tier), units, win, loss])
	print("\nTypical match pay: " + "; ".join(per_match))
	quit(0)


## {milestone: [matches, minutes]} for one player.
func _simulate(catalog: ArmyCatalog, starter_cost: float, p: float, rng: RandomNumberGenerator) -> Dictionary:
	var profile := Progression.new("")
	var reached := {}
	var matches := 0
	var minutes := 0.0
	var locked_units := catalog.unit_ids().filter(func(id: String) -> bool: return catalog.unlock_tier(id) > 0)
	while matches < 10000:
		var tier := profile.budget_tier
		var roll := rng.randf()
		var winner := "draw" if roll < 0.05 else ("Green" if roll < 0.05 + p * 0.95 else "Rust")
		var outcome := "draw" if winner == "draw" else ("win" if winner == "Green" else "loss")
		var units := Progression.budget_for(tier) / starter_cost
		var kills := roundi(units * KILL_SHARE[outcome] * rng.randf_range(0.8, 1.2))
		var length := (2.5 + 0.9 * tier) * rng.randf_range(0.75, 1.25)
		matches += 1
		minutes += length
		profile.award({"key": str(matches), "winner": winner, "duration_seconds": length * 60.0, "teams": {"green": {"kills": kills}}}, "Green", tier)
		# Spend greedily on the cheapest remaining unlock.
		var bought := true
		while bought:
			bought = false
			var options := []
			for unit_id: String in locked_units:
				if not profile.has_unit(catalog, unit_id):
					options.append([Progression.unit_unlock_credits(catalog, unit_id), unit_id])
			if not profile.next_tier().is_empty():
				options.append([int(profile.next_tier()["unlock_credits"]), "tier"])
			if options.is_empty():
				break
			options.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			if profile.credits >= int(options[0][0]):
				var error := profile.unlock_next_tier() if options[0][1] == "tier" else profile.unlock_unit(catalog, options[0][1])
				bought = error == ""
				if bought and not reached.has("first unlock"):
					reached["first unlock"] = [matches, minutes]
		if not reached.has("every unit") and locked_units.all(func(id: String) -> bool: return profile.has_unit(catalog, id)):
			reached["every unit"] = [matches, minutes]
		for t in range(1, Progression.BUDGET_TIERS.size()):
			var key := "top tier" if t == Progression.BUDGET_TIERS.size() - 1 else "tier %d" % t
			if profile.budget_tier >= t and not reached.has(key):
				reached[key] = [matches, minutes]
		if reached.has("every unit") and reached.has("top tier"):
			reached["everything"] = [matches, minutes]
			break
	return reached
