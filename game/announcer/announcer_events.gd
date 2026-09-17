class_name AnnouncerEvents
extends RefCounted
## K5 match events for the announcer: loading and validating timelines (JSON lines).
##
## The contract is tests/announcer/fixtures/README.md. tools/announcer/events.py is the Python twin; both must accept
## and reject the same timelines (tests/announcer/contract_cases.json). JSON numbers parse as floats in Godot, so an
## "integer" here is a float with no fractional part.

const TEAMS := ["green", "rust"]
const UNIT_TYPES := ["scout", "tank", "ifv", "artillery", "lancer", "burner"]
## The fixtures' tick rate (they were recorded at 60 Hz). Live matches use Engine.physics_ticks_per_second instead.
const TICKS_PER_SECOND := 60

## type -> {field: kind}; kinds match events.py.
const REQUIRED := {
	"match_start": {"arena": "str", "budget": "int", "teams": "special"},
	"first_contact": {"team": "team", "unit_id": "id", "unit": "unit", "target_id": "id", "target_unit": "unit"},
	"damage": {"shooter": "id", "shooter_unit": "unit", "victim": "id", "victim_unit": "unit",
			"hull": "ratio", "shield": "ratio", "critical": "bool"},
	"unit_destroyed": {"victim": "id", "victim_unit": "unit", "victim_team": "team", "killer": "str",
			"killer_unit": "str", "killer_team": "str", "friendly": "bool"},
	"friendly_fire": {"shooter": "id", "shooter_unit": "unit", "victim": "id", "victim_unit": "unit",
			"team": "team", "hull": "ratio", "killed": "bool"},
	"close_call": {"unit_id": "id", "unit": "unit", "team": "team", "hull_left": "ratio"},
	"control_changed": {"owner": "owner"},
	"squad_wiped": {"team": "team", "squad": "str"},
	"momentum": {"army_health": "team_map_ratio"},
	"match_end": {"winner": "winner", "reason": "reason", "duration_seconds": "num",
			"units_left": "team_map_int", "kills_by_unit": "special"},
	# L1, from doctrine (2026-09-16): why an element is lining up the way it is, so the booth can explain the
	# tactics instead of the HUD having to. `reason` is the doctrine table's own words - useful as a subtitle and
	# as the demo page's "why", but never spoken, because every spoken word has to have been recorded.
	"element_formation": {"team": "team", "element": "str", "size": "int", "reason": "str",
			"formation": "str", "technique": "str", "changed": "special"},
	"element_drill": {"team": "team", "element": "str", "size": "int", "reason": "str",
			"drill": "str", "formation": "str", "distance": "num", "target": "str"},
}

## Fields that may name a unit that is already gone. A shell outlives the crew that fired it — `Shell` keeps the
## shooter's *name* and `Match` looks it up when the round lands, handling the null — so a vehicle really can be
## killed by something that died first. Everything else stays strict, so a destroyed unit reported as dying twice,
## or being targeted after death, is still a bookkeeping bug. (Diagnosed by the ai stream, 2026-09-16: it went from
## rare to common when brains started firing to suppress, which puts far more rounds in the air.)
const MAY_BE_DEAD := ["shooter", "killer"]

## Fields that name a unit instance, paired with the field naming its type.
const ID_FIELDS := [["unit_id", "unit"], ["shooter", "shooter_unit"], ["victim", "victim_unit"],
		["killer", "killer_unit"], ["target_id", "target_unit"]]


## Parses JSON lines. Returns {"events": Array, "error": String}.
static func parse_jsonl(text: String) -> Dictionary:
	var events: Array = []
	var number := 0
	for line in text.split("\n"):
		number += 1
		if line.strip_edges() == "":
			continue
		var json := JSON.new()
		if json.parse(line) != OK:
			return {"events": events, "error": "line %d: not JSON (%s)" % [number, json.get_error_message()]}
		events.append(json.data)
	return {"events": events, "error": ""}


static func load_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"events": [], "error": "cannot open %s" % path}
	return parse_jsonl(file.get_as_text())


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


static func _is_integer(value: Variant) -> bool:
	return _is_number(value) and float(value) == floorf(float(value))


## "" when value is of kind, else what was expected.
static func kind_error(value: Variant, kind: String) -> String:
	match kind:
		"int":
			return "" if _is_integer(value) else "an integer"
		"num":
			return "" if _is_number(value) and float(value) >= 0.0 else "a non-negative number"
		"str":
			return "" if typeof(value) == TYPE_STRING else "a string"
		"id":
			return "" if typeof(value) == TYPE_STRING and value != "" else "a non-empty id"
		"bool":
			return "" if typeof(value) == TYPE_BOOL else "true or false"
		"team":
			return "" if typeof(value) == TYPE_STRING and value in TEAMS else "green or rust"
		"owner":
			return "" if typeof(value) == TYPE_STRING and value in TEAMS + ["neutral"] else "green, rust, or neutral"
		"winner":
			return "" if typeof(value) == TYPE_STRING and value in TEAMS + ["draw"] else "green, rust, or draw"
		"reason":
			return "" if typeof(value) == TYPE_STRING and value in ["elimination", "control", "time"] \
					else "elimination, control, or time"
		"unit":
			return "" if typeof(value) == TYPE_STRING and value in UNIT_TYPES else "a unit type"
		"ratio":
			return "" if _is_number(value) and float(value) >= 0.0 and float(value) <= 1.0 else "a ratio 0..1"
		"team_map_ratio", "team_map_int":
			if typeof(value) != TYPE_DICTIONARY or value.size() != 2 or not value.has("green") or not value.has("rust"):
				return "an object with exactly green and rust"
			var inner := "ratio" if kind == "team_map_ratio" else "int"
			for team in TEAMS:
				if kind_error(value[team], inner) != "":
					return "green and rust as %s" % inner
	return ""


## Problems with one event on its own.
static func validate_event(event: Variant, index: int = 0) -> PackedStringArray:
	var where := "event %d" % index
	var problems := PackedStringArray()
	if typeof(event) != TYPE_DICTIONARY:
		problems.append("%s: not a JSON object" % where)
		return problems
	for pair in [["tick", "int"], ["t", "num"], ["type", "str"]]:
		if not event.has(pair[0]):
			problems.append("%s: missing %s" % [where, pair[0]])
		elif kind_error(event[pair[0]], pair[1]) != "":
			problems.append("%s: %s must be %s" % [where, pair[0], kind_error(event[pair[0]], pair[1])])
	if not problems.is_empty():
		return problems
	if float(event["tick"]) < 0.0:
		problems.append("%s: tick must be >= 0" % where)
	var type: String = event["type"]
	if not REQUIRED.has(type):
		problems.append("%s: unknown type '%s'" % [where, type])
		return problems
	where = "event %d (%s)" % [index, type]
	var fields: Dictionary = REQUIRED[type]
	for field in fields:
		if not event.has(field):
			problems.append("%s: missing %s" % [where, field])
		elif fields[field] != "special" and kind_error(event[field], fields[field]) != "":
			problems.append("%s: %s must be %s" % [where, field, kind_error(event[field], fields[field])])
	if not problems.is_empty():
		return problems
	match type:
		"match_start":
			problems.append_array(_check_teams(event["teams"], where))
		"match_end":
			problems.append_array(_check_kills(event["kills_by_unit"], where))
		"unit_destroyed":
			var hazard: bool = event["killer"] == ""
			if hazard and (event["killer_unit"] != "" or event["killer_team"] != ""):
				problems.append("%s: a hazard kill has empty killer, killer_unit, and killer_team" % where)
			if not hazard and (kind_error(event["killer_unit"], "unit") != "" or kind_error(event["killer_team"], "team") != ""):
				problems.append("%s: killer_unit and killer_team must name a unit type and team" % where)
			if not hazard and bool(event["friendly"]) != (event["killer_team"] == event["victim_team"]):
				problems.append("%s: friendly must be true exactly when killer_team == victim_team" % where)
	return problems


static func _check_teams(teams: Variant, where: String) -> PackedStringArray:
	var problems := PackedStringArray()
	if typeof(teams) != TYPE_ARRAY or teams.size() != 2:
		problems.append("%s: teams must be a list of two teams" % where)
		return problems
	var seen: Array = []
	for team in teams:
		if typeof(team) != TYPE_DICTIONARY or kind_error(team.get("team"), "team") != "" \
				or typeof(team.get("faction")) != TYPE_STRING or typeof(team.get("units")) != TYPE_ARRAY or team["units"].is_empty():
			problems.append("%s: each team needs team, faction, and a non-empty units list" % where)
			continue
		seen.append(team["team"])
		for unit in team["units"]:
			if typeof(unit) != TYPE_DICTIONARY or kind_error(unit.get("id"), "id") != "" or kind_error(unit.get("unit"), "unit") != "":
				problems.append("%s: each unit needs an id and a unit type" % where)
	seen.sort()
	if problems.is_empty() and seen != TEAMS:
		problems.append("%s: teams must be green and rust" % where)
	return problems


static func _check_kills(kills: Variant, where: String) -> PackedStringArray:
	var problems := PackedStringArray()
	if typeof(kills) != TYPE_DICTIONARY or kills.size() != 2 or not kills.has("green") or not kills.has("rust"):
		problems.append("%s: kills_by_unit must have green and rust" % where)
		return problems
	for team in TEAMS:
		if typeof(kills[team]) != TYPE_DICTIONARY:
			problems.append("%s: kills_by_unit.%s maps unit types to integers" % [where, team])
			continue
		for unit in kills[team]:
			if kind_error(unit, "unit") != "" or kind_error(kills[team][unit], "int") != "":
				problems.append("%s: kills_by_unit.%s maps unit types to integers" % [where, team])
				break
	return problems


## Problems with a whole match: every event, plus ordering and references. Empty means valid.
static func validate_timeline(events: Array) -> PackedStringArray:
	var problems := PackedStringArray()
	for index in events.size():
		problems.append_array(validate_event(events[index], index))
	if not problems.is_empty():
		return problems
	if events.is_empty():
		problems.append("timeline is empty")
		return problems
	if events[0]["type"] != "match_start":
		problems.append("the first event must be match_start")
	if events[-1]["type"] != "match_end":
		problems.append("the last event must be match_end")
	var counts := {}
	for event in events:
		counts[event["type"]] = counts.get(event["type"], 0) + 1
	for once in ["match_start", "match_end"]:
		if counts.get(once, 0) != 1:
			problems.append("exactly one %s (found %d)" % [once, counts.get(once, 0)])
	if counts.get("first_contact", 0) > 1:
		problems.append("first_contact happens at most once")
	if not problems.is_empty():
		return problems
	var team_of := {}
	var type_of := {}
	for team in events[0]["teams"]:
		for unit in team["units"]:
			if team_of.has(unit["id"]):
				problems.append("match_start: unit id %s listed twice" % unit["id"])
			team_of[unit["id"]] = team["team"]
			type_of[unit["id"]] = unit["unit"]
	var dead := {}
	var last_tick := 0.0
	var last_t := 0.0
	for index in events.size():
		var event: Dictionary = events[index]
		var where := "event %d (%s)" % [index, event["type"]]
		if float(event["tick"]) < last_tick or float(event["t"]) < last_t:
			problems.append("%s: tick and t must not decrease" % where)
		last_tick = float(event["tick"])
		last_t = float(event["t"])
		if event["type"] == "match_start":
			continue
		for pair in ID_FIELDS:
			var unit_id: String = str(event.get(pair[0], ""))
			if unit_id == "":
				continue
			if not team_of.has(unit_id):
				problems.append("%s: %s %s is not in match_start" % [where, pair[0], unit_id])
			elif event.has(pair[1]) and event[pair[1]] != type_of[unit_id]:
				problems.append("%s: %s is a %s, not a %s" % [where, unit_id, type_of[unit_id], event[pair[1]]])
			elif dead.has(unit_id) and not pair[0] in MAY_BE_DEAD:
				problems.append("%s: %s %s was already destroyed" % [where, pair[0], unit_id])
		if event["type"] == "unit_destroyed":
			if team_of.has(event["victim"]) and team_of[event["victim"]] != event["victim_team"]:
				problems.append("%s: %s is on %s" % [where, event["victim"], team_of[event["victim"]]])
			dead[event["victim"]] = true
	return problems
