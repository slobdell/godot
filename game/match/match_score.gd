class_name MatchScore
extends RefCounted
## Round 19 (board, S1; contract C19.4): the pure parts of the score snapshot, so the board, the arena screens and the
## results screen name sides and zones the same way. `Match.score_snapshot()` builds the snapshot; this file only
## names things. Nothing here reads or changes the simulation.

## What the one central zone is called on the board: "centre" only where a map has one (the older arenas).
const CENTRE_LABEL := "the centre"
const _COMPASS := {"west": "east", "east": "west", "north": "south", "south": "north"}


## The board's name for a zone. The map's own name, except that the generator calls a mirrored zone "<name> (far)",
## which on the Terminus puts "the west ring (far)" in the EAST: the compass word is swapped instead ("the east ring"),
## the way the lead already drives the mirrored streets by their real names (tools/make_arenas.py:202). A mirror with
## no compass word is "the far <name>"; a name that already says "far" keeps the map's word. Pure.
static func zone_label(name: String, all_names: Array) -> String:
	if name == "control point" and all_names.size() <= 1:
		return CENTRE_LABEL
	if not name.ends_with(" (far)"):
		return name
	var base := name.trim_suffix(" (far)")
	var words := base.split(" ")
	for i in words.size():
		var word := words[i].to_lower()
		if _COMPASS.has(word):
			words[i] = _COMPASS[word]
			var swapped := " ".join(words)
			return name if all_names.has(swapped) else swapped
	if base.contains("far"):
		return name
	return "the far " + base.trim_prefix("the ") if base.begins_with("the ") else "the far " + base


## Screen names for the two sides: short faction names ("CONDEMNED", "LAW"), or a neutral HOME / AWAY when a faction
## can't be read or both sides field the same one (a test build; never a colour; the round-5 rule). Pure.
static func side_names(faction_a: String, faction_b: String) -> Array:
	if faction_a == "" or faction_b == "" or faction_a == faction_b:
		return ["HOME", "AWAY"]
	return [short_faction(faction_a), short_faction(faction_b)]


static func short_faction(faction: String) -> String:
	var name := String(Units.FACTION_NAMES.get(faction, faction))
	return name.trim_prefix("The ").to_upper()


## The faction `team` fields in `game_match`: the most common among its vehicles ("" when none can be read).
static func fielded_faction(game_match: Node, team: int) -> String:
	var tanks: Variant = game_match.get("tanks")
	if not (tanks is Node):
		return ""
	var counts := {}
	for tank in (tanks as Node).get_children():
		if tank.get("team") == null or int(tank.get("team")) != team or tank.get("unit_id") == null:
			continue
		var faction := Units.faction_of(String(tank.get("unit_id")))
		if faction != "":
			counts[faction] = int(counts.get(faction, 0)) + 1
	var best := ""
	for faction in counts:
		if best == "" or int(counts[faction]) > int(counts[best]):
			best = faction
	return best


## Who leads: on points while control decides the match; ties (and matches without control) go to the credits
## destroyed, then the kills. -1 when level. Display only: `Match.result()` is the rules.
static func leader(sides: Array, control: bool) -> int:
	for key in (["points", "points_destroyed", "kills"] if control else ["points_destroyed", "kills"]):
		var a := int(sides[0][key])
		var b := int(sides[1][key])
		if a != b:
			return 0 if a > b else 1
	return -1
