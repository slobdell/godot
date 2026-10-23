class_name MatchEnd
extends RefCounted
## Round 38 (feedback F1/F2): what the end of a match says, in his words. Pure; EndCard draws it.
##
## He played on after a match ended on the rings (round 37: the end at 195.4 s, his later clicks still answered "move"): the old
## end was a bare VICTORY / DEFEAT label, no reason, over a fight that kept going. This names who won and WHY (the rings, a
## wipe-out, the clock) and builds the next match's flags.

## "win", "loss" or "draw" from `team`'s side (-1 = nobody commands: never a win or a loss).
static func outcome(result: Dictionary, team: int) -> String:
	var winner := String(result.get("winner", "draw"))
	if winner == "draw" or team < 0:
		return "draw" if winner == "draw" else "decided"
	return "win" if winner == Match.TEAM_NAMES[team] else "loss"


static func headline(result: Dictionary, team: int, spectated: bool, factions: Dictionary) -> String:
	var winner := String(result.get("winner", "draw"))
	if winner == "draw":
		return "DRAW"
	if not spectated and team >= 0:
		return "VICTORY" if outcome(result, team) == "win" else "DEFEAT"
	return "%s WIN" % _name(Match.TEAM_NAMES.find(winner), -1, factions).to_upper()


## Why it ended, from `team`'s side ("you"), or naming both factions when nobody commands (team -1).
static func reason_line(result: Dictionary, team: int, factions: Dictionary) -> String:
	var reason := String(result.get("reason", ""))
	var winner_team := Match.TEAM_NAMES.find(String(result.get("winner", "draw")))
	var control: Variant = result.get("control")
	var left: Dictionary = result.get("units_left", {}) if result.get("units_left") is Dictionary else {}
	match reason:
		"control":
			var points := _points(control, winner_team)
			return "%s held the rings: %d points to %d" % [_name(winner_team, team, factions, true), points[0], points[1]]
		"elimination":
			var loser := 1 - winner_team if winner_team >= 0 else -1
			var kept := int(left.get(String(Match.TEAM_NAMES[winner_team]).to_lower(), 0)) if winner_team >= 0 else 0
			var wiped := "Your last vehicle was destroyed" if loser == team and team >= 0 \
					else ("Every enemy vehicle destroyed" if team >= 0 else "Every %s vehicle destroyed" % _bare(loser, factions))
			if winner_team < 0:
				return "Both sides destroyed"
			return "%s. %s kept %d" % [wiped, _name(winner_team, team, factions, true), kept]
		"time_limit":
			if control is Dictionary:
				if winner_team < 0:
					return "Time's up, level at the rings: %d points each" % int((control as Dictionary).get("green", 0))
				var points := _points(control, winner_team)
				return "Time's up: %s led at the rings, %d points to %d" % [_name(winner_team, team, factions), points[0], points[1]]
			if winner_team < 0:
				return "Time's up: level"
			return "Time's up: %s destroyed more" % _name(winner_team, team, factions)
		"score_limit":
			return "%s reached the kill limit" % _name(winner_team, team, factions, true) if winner_team >= 0 else "The kill limit"
	return ""


## What was left on the field: "Vehicles left: you 2, enemy 5" (or both factions when nobody commands).
static func score_line(result: Dictionary, team: int, factions: Dictionary = {}) -> String:
	var left: Dictionary = result.get("units_left", {}) if result.get("units_left") is Dictionary else {}
	if left.is_empty():
		return ""
	var green := int(left.get("green", 0))
	var rust := int(left.get("rust", 0))
	if team < 0:
		return "Vehicles left: %s %d, %s %d" % [_bare(Match.Team.GREEN, factions), green, _bare(Match.Team.RUST, factions), rust]
	var mine := green if team == Match.Team.GREEN else rust
	var theirs := rust if team == Match.Team.GREEN else green
	return "Vehicles left: you %d, enemy %d" % [mine, theirs]


## The next match: "again" keeps his factions and map with a new seed; "factions" opens the faction menu.
static func next_flags(flags: LaunchFlags, choice: String, new_seed: int) -> LaunchFlags:
	var next := LaunchFlags.new()
	next.values = flags.values.duplicate() if flags != null else {}
	next.values["seed"] = str(new_seed)
	if choice == "factions":
		next.values.erase("no-pick-faction")
		next.values.erase("player-faction")
		next.values.erase("enemy-faction")
		next.values["pick-faction"] = ""
	return next


## [the winner's points, the other side's] from a control dictionary.
static func _points(control: Variant, winner_team: int) -> Array[int]:
	if not control is Dictionary or winner_team < 0:
		return [0, 0]
	var board := control as Dictionary
	var mine := int(board.get(String(Match.TEAM_NAMES[winner_team]).to_lower(), 0))
	var theirs := int(board.get(String(Match.TEAM_NAMES[1 - winner_team]).to_lower(), 0))
	return [mine, theirs]


## "You"/"you" for his side, else the faction ("The Syndicate"), else the team name.
static func _name(side: int, team: int, factions: Dictionary, capital := false) -> String:
	if side >= 0 and side == team:
		return "You" if capital else "you"
	if side < 0:
		return "Nobody"
	var faction := String(factions.get(side, ""))
	return String(Units.FACTION_NAMES.get(faction, Match.TEAM_NAMES[side]))


## The faction without its article, for "Every Syndicate vehicle" ("Road Gangs", "Law").
static func _bare(side: int, factions: Dictionary) -> String:
	var full := _name(side, -1, factions)
	return full.trim_prefix("The ")
