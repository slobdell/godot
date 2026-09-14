class_name Progression
extends RefCounted
## The player's progress (contract C8): credits earned by playing, unit types and budget tiers bought with
## them, and a win/loss record, in `user://profile.json`. Local only until online play brings accounts.
##
## Pillars (game_design.md "Progression"): credits come only from playing, never money. Unlocks add OPTIONS,
## not power: units are sidegrades, and both sides of a match fight at the same budget tier. Losing still
## earns a little, but less than playing well, so throwing matches is never the fastest way to unlock.
## The numbers and the reasoning behind them: _agents/balance.md, "Economy".
##
## Profile JSON: {"schema", "credits", "unlocked_units": [ids], "budget_tier", "wins", "losses", "draws",
##                "last_award": "<match key>", "completed_challenges": [ids]}

const SCHEMA := 1
const DEFAULT_PATH := "user://profile.json"

## Budget tiers: buy the next one with credits (each needs the one before). `budget` is what BOTH sides
## spend in a match at that tier.
const BUDGET_TIERS := [
	{"tier": 0, "budget": 800, "unlock_credits": 0, "name": "Scrapyard"},
	{"tier": 1, "budget": 1200, "unlock_credits": 400, "name": "Pit"},
	{"tier": 2, "budget": 1700, "unlock_credits": 900, "name": "Arena"},
	{"tier": 3, "budget": 2400, "unlock_credits": 1600, "name": "Colosseum"},
	{"tier": 4, "budget": 3200, "unlock_credits": 2500, "name": "Grand Circus"},
]
## Credits to unlock a unit type, by its catalog `unlock_tier` (0 = a starter, always unlocked).
## A unit can be unlocked at any time: the player chooses between a new unit and a bigger budget.
const UNIT_UNLOCK_CREDITS := {1: 300, 2: 600, 3: 1000, 4: 1500}

## What a match pays (credits_for): a base by outcome, plus a bonus per enemy unit destroyed, with the base
## raised for bigger tiers (longer matches). Matches shorter than min_seconds pay nothing (a quit or a forfeit).
## A loss pays little on its own (most of a loss's credits come from the damage done), so throwing matches
## is never the fastest way to earn (a test holds this).
const AWARD := {"win": 100, "draw": 30, "loss": 10, "per_kill": 6, "tier_bonus": 0.25, "min_seconds": 60.0}

signal changed

## "" = in memory only (tests and automated runs never touch the player's profile).
var path: String
var credits := 0
var unlocked_units: Array[String] = []
var budget_tier := 0
var wins := 0
var losses := 0
var draws := 0
## The last match that paid out, so a result is never awarded twice.
var last_award := ""
## Challenge missions won at least once (Challenges): their reward pays once.
var completed_challenges: Array[String] = []
## Set when the file on disk couldn't be read (it was moved aside to <path>.bad).
var load_error := ""


func _init(p_path := DEFAULT_PATH) -> void:
	path = p_path
	if path != "" and FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		var json := JSON.new()
		var data: Variant = json.data if file != null and json.parse(file.get_as_text()) == OK else null
		if file != null:
			file.close()
		if typeof(data) == TYPE_DICTIONARY:
			apply(migrate(data))
		else:
			# Never silently wipe progress: keep the unreadable file for a human to look at.
			load_error = "Your profile couldn't be read; it was saved as %s.bad and a new one started." % path.get_file()
			DirAccess.rename_absolute(path, path + ".bad")


## Any profile dictionary (older schema, hand-edited, missing keys) → a valid current one.
static func migrate(data: Dictionary) -> Dictionary:
	var clean := {"schema": SCHEMA, "credits": maxi(0, _int(data.get("credits"))),
			"budget_tier": clampi(_int(data.get("budget_tier")), 0, BUDGET_TIERS.size() - 1),
			"wins": maxi(0, _int(data.get("wins"))), "losses": maxi(0, _int(data.get("losses"))),
			"draws": maxi(0, _int(data.get("draws"))), "last_award": String(data.get("last_award", "")),
			"unlocked_units": [], "completed_challenges": []}
	var units: Variant = data.get("unlocked_units", [])
	for unit_id: Variant in (units if typeof(units) == TYPE_ARRAY else []):
		if typeof(unit_id) == TYPE_STRING and not clean["unlocked_units"].has(unit_id):
			clean["unlocked_units"].append(unit_id)
	var completed: Variant = data.get("completed_challenges", [])
	for challenge_id: Variant in (completed if typeof(completed) == TYPE_ARRAY else []):
		if typeof(challenge_id) == TYPE_STRING and not clean["completed_challenges"].has(challenge_id):
			clean["completed_challenges"].append(challenge_id)
	return clean


static func _int(value: Variant) -> int:
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0


func apply(data: Dictionary) -> void:
	credits = data["credits"]
	budget_tier = data["budget_tier"]
	wins = data["wins"]
	losses = data["losses"]
	draws = data["draws"]
	last_award = data["last_award"]
	unlocked_units.clear()
	for unit_id: String in data["unlocked_units"]:
		unlocked_units.append(unit_id)
	completed_challenges.clear()
	for challenge_id: String in data["completed_challenges"]:
		completed_challenges.append(challenge_id)


func to_dict() -> Dictionary:
	return {"schema": SCHEMA, "credits": credits, "unlocked_units": unlocked_units.duplicate(), "budget_tier": budget_tier,
			"wins": wins, "losses": losses, "draws": draws, "last_award": last_award,
			"completed_challenges": completed_challenges.duplicate()}


func save() -> String:
	changed.emit()
	if path == "":
		return ""
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "can't save your profile: %s" % error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify(to_dict(), "  ", false))
	file.close()
	return ""


# ---- Tiers and unlocks ----------------------------------------------------------------------------

static func tier_info(tier: int) -> Dictionary:
	return BUDGET_TIERS[clampi(tier, 0, BUDGET_TIERS.size() - 1)]


static func budget_for(tier: int) -> int:
	return int(tier_info(tier)["budget"])


## "Pit (1,200)"
static func tier_label(tier: int) -> String:
	return "%s (%s)" % [tier_info(tier)["name"], _thousands(budget_for(tier))]


static func unit_unlock_credits(catalog: ArmyCatalog, unit_id: String) -> int:
	var tier := catalog.unlock_tier(unit_id)
	if tier <= 0:
		return 0
	return int(UNIT_UNLOCK_CREDITS.get(tier, UNIT_UNLOCK_CREDITS[UNIT_UNLOCK_CREDITS.keys().max()]))


## Starter units (unlock_tier 0) plus the ones bought, in catalog order.
func unlocked_in(catalog: ArmyCatalog) -> Array[String]:
	var result: Array[String] = []
	for unit_id in catalog.unit_ids():
		if catalog.unlock_tier(unit_id) <= 0 or unlocked_units.has(unit_id):
			result.append(unit_id)
	return result


## The catalog at `tier`'s budget with this player's unlocks (the army builder's view).
func catalog_for(base: ArmyCatalog, tier: int) -> ArmyCatalog:
	return base.with_budget(budget_for(mini(tier, budget_tier)), unlocked_in(base))


func has_unit(catalog: ArmyCatalog, unit_id: String) -> bool:
	return unlocked_in(catalog).has(unit_id)


## "" or why not. Spends credits and saves on success.
func unlock_unit(catalog: ArmyCatalog, unit_id: String) -> String:
	if not catalog.has_unit(unit_id):
		return "Unknown unit %s." % unit_id
	if has_unit(catalog, unit_id):
		return "The %s is already unlocked." % catalog.display_name(unit_id)
	var price := unit_unlock_credits(catalog, unit_id)
	if credits < price:
		return "The %s costs %d credits; you have %d." % [catalog.display_name(unit_id), price, credits]
	credits -= price
	unlocked_units.append(unit_id)
	return save()


## The next tier to buy, or {} at the top.
func next_tier() -> Dictionary:
	return BUDGET_TIERS[budget_tier + 1] if budget_tier + 1 < BUDGET_TIERS.size() else {}


func unlock_next_tier() -> String:
	var next := next_tier()
	if next.is_empty():
		return "You have the biggest budget tier."
	if credits < int(next["unlock_credits"]):
		return "%s costs %d credits; you have %d." % [next["name"], next["unlock_credits"], credits]
	credits -= int(next["unlock_credits"])
	budget_tier = int(next["tier"])
	return save()


# ---- Earning ---------------------------------------------------------------------------------------

## What a match pays `team` ("Green"/"Rust"), without changing anything:
## {"credits": int, "outcome": "win"|"loss"|"draw", "lines": [[label, credits]]}.
## `report` is a MatchReport (C3 fields: winner, duration_seconds, teams.<team>.kills).
static func credits_for(report: Dictionary, team: String, tier := 0) -> Dictionary:
	var winner := String(report.get("winner", "draw"))
	var outcome := "draw" if winner == "draw" else ("win" if winner == team else "loss")
	var lines := []
	if float(report.get("duration_seconds", 0.0)) < float(AWARD["min_seconds"]):
		return {"credits": 0, "outcome": outcome, "lines": [["Match too short to pay", 0]]}
	var base := int(AWARD[outcome])
	lines.append([{"win": "Victory", "loss": "Defeat", "draw": "Draw"}[outcome], base])
	var tier_extra := roundi(base * float(AWARD["tier_bonus"]) * clampi(tier, 0, BUDGET_TIERS.size() - 1))
	if tier_extra > 0:
		lines.append(["%s tier bonus" % tier_info(tier)["name"], tier_extra])
	var kills := int(report.get("teams", {}).get(team.to_lower(), {}).get("kills", 0))
	if kills > 0:
		lines.append(["%d enemy unit%s destroyed" % [kills, "" if kills == 1 else "s"], kills * int(AWARD["per_kill"])])
	var total := 0
	for line: Array in lines:
		total += int(line[1])
	return {"credits": total, "outcome": outcome, "lines": lines}


## Award a finished match to `team` (C8): adds the credits and the win/loss, saves, and returns the
## credits. A report with the same `key` as the last award pays nothing (a reload can't double-pay).
func award(report: Dictionary, team := "Green", tier := 0) -> int:
	var key := String(report.get("key", ""))
	if key != "" and key == last_award:
		return 0
	var paid := credits_for(report, team, tier)
	credits += int(paid["credits"])
	match String(paid["outcome"]):
		"win":
			wins += 1
		"loss":
			losses += 1
		_:
			draws += 1
	last_award = key
	save()
	return int(paid["credits"])


## A challenge mission was won: the first win pays `reward` once; returns the credits paid (0 on a replay).
func complete_challenge(challenge_id: String, reward: int) -> int:
	if completed_challenges.has(challenge_id):
		return 0
	completed_challenges.append(challenge_id)
	credits += reward
	save()
	return reward


static func _thousands(value: int) -> String:
	var text := str(value)
	return text if value < 1000 else "%s,%s" % [text.substr(0, text.length() - 3), text.substr(text.length() - 3)]
