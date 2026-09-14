class_name Doctrine
extends RefCounted
## A doctrine is a whole army as data: squads of units, with directives. Doctrine files
## (res://doctrines/*.json), garage saves, CPU armies, and a future LLM commander all produce this shape.
## Army JSON v2 (contract C2 in _agents/workstreams.md; owned by the rules stream):
##
## {
##   "name": "Pincer",
##   "squads": [
##     {"name": "Anvil", "formation": "wedge", "directive": {"role": "anchor"},
##      "units": [{"unit": "tank"}, {"unit": "ifv", "paint": "#c8a02a", "directive": {"caution": 0.8}}]},
##     ...
##   ]
## }
## Per unit: "unit" (a Units.PROFILES id, required), optional "paint" "#rrggbb" and "directive".
## Optional per squad: "formation" (see Formations.NAMES) and "verb": "hold", which starts the squad formed
## up and waiting for orders; "spacing" in meters. At most MAX_SQUADS squads of MAX_SQUAD_UNITS units.
## v1 keys ("tanks", "weapon", "weapons", "components") are rejected with a message saying what changed.
## Budgets are checked by the caller (Army.check_budget), which knows the match's budget.

const VERSION := 2
## The lead (2026-09-15): "a player can have up to some finite number of squads (say 5)."
const MAX_SQUADS := 5
const MAX_SQUAD_UNITS := Formations.MAX_MEMBERS
const MAX_UNITS := MAX_SQUADS * MAX_SQUAD_UNITS


## Returns {"doctrine": Dictionary} or {"error": String}.
static func load_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "cannot open doctrine %s: %s" % [path, error_string(FileAccess.get_open_error())]}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null:
		return {"error": "doctrine %s is not valid JSON" % path}
	var parsed := parse(data)
	if parsed.has("error"):
		parsed["error"] = "%s: %s" % [path.get_file(), parsed["error"]]
	return parsed


static func parse(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {"error": "doctrine must be an object"}
	if typeof(data.get("name")) != TYPE_STRING:
		return {"error": "doctrine needs a string 'name'"}
	var squads: Variant = data.get("squads")
	if typeof(squads) != TYPE_ARRAY or squads.is_empty() or squads.size() > MAX_SQUADS:
		return {"error": "an army needs 1 to %d squads" % MAX_SQUADS}
	var names := {}
	for squad in squads:
		if typeof(squad) != TYPE_DICTIONARY or typeof(squad.get("name")) != TYPE_STRING:
			return {"error": "every squad needs a string 'name'"}
		if names.has(squad["name"]):
			return {"error": "duplicate squad name '%s'" % squad["name"]}
		names[squad["name"]] = true
		if not String(squad["name"]).is_valid_ascii_identifier():
			return {"error": "squad name '%s' must be letters, digits, underscores" % squad["name"]}
		if squad.has("tanks"):
			return {"error": "squad %s uses the v1 key 'tanks': army JSON v2 lists 'units' ([{\"unit\": \"tank\"}, ...])" % squad["name"]}
		if squad.has("directive"):
			var error := Directives.validate(squad["directive"])
			if error != "":
				return {"error": "squad %s: %s" % [squad["name"], error]}
		if squad.has("formation") and not Formations.NAMES.has(squad["formation"]):
			return {"error": "squad %s: formation must be one of %s" % [squad["name"], Formations.NAMES]}
		if squad.has("verb") and not ["hold"].has(squad["verb"]):
			return {"error": "squad %s: a doctrine may only start a squad with verb 'hold' (others need a destination)" % squad["name"]}
		var units: Variant = squad.get("units")
		if typeof(units) != TYPE_ARRAY or units.is_empty():
			return {"error": "squad %s needs at least one unit in 'units'" % squad["name"]}
		if units.size() > MAX_SQUAD_UNITS:
			return {"error": "squad %s has %d units; a squad holds at most %d" % [squad["name"], units.size(), MAX_SQUAD_UNITS]}
		for entry in units:
			if typeof(entry) != TYPE_DICTIONARY:
				return {"error": "squad %s: units must be objects like {\"unit\": \"tank\"}" % squad["name"]}
			var entry_error := Units.validate_entry(entry)
			if entry_error != "":
				return {"error": "squad %s: %s" % [squad["name"], entry_error]}
			if entry.has("directive"):
				var error := Directives.validate(entry["directive"])
				if error != "":
					return {"error": "squad %s unit: %s" % [squad["name"], error]}
	return {"doctrine": data}


## Every unit entry in squad order: [{"squad": name, "entry": {...}}].
static func entries(doctrine: Dictionary) -> Array:
	var result: Array = []
	for squad in doctrine.get("squads", []):
		for entry in squad.get("units", []):
			result.append({"squad": squad.get("name", ""), "entry": entry})
	return result
