class_name Doctrine
extends RefCounted
## A doctrine is a whole team plan as data: squads, each tank's weapon, and
## directives. Match runner experiments load them from res://doctrines/*.json;
## a squad-command UI or an LLM will produce the same shape.
##
## {
##   "name": "Pincer",
##   "squads": [
##     {"name": "Anvil", "directive": {"role": "anchor", "objective": {"right": 0, "forward": -10, "radius": 10}},
##      "tanks": [{"weapon": "cannon"}, {"weapon": "cannon", "directive": {"caution": 0.8}}]},
##   Per tank (the Loadout fields contract, directive set 2): "unit" (Units.PROFILES id, default
##   "tank"), "weapon" (main hardpoint) or "weapons" {hardpoint: weapon}, "components" [ids],
##   "paint" "#rrggbb". See Units.validate_loadout.
##     ...
##   ]
## }
## Optional per squad: "formation" (see Formations.NAMES) and "verb": "hold", which starts the
## squad formed up and waiting for tactical-map orders; "spacing" in meters.

## 2026-09-15 (directive set 2): armies grow to ~20 units once cheap vehicles exist (the lead). A squad
## still holds at most Formations.MAX_MEMBERS (5), so 4 squads.
const MAX_SQUADS := 4
const MAX_TANKS := 20


## Returns {"doctrine": Dictionary} or {"error": String}.
static func load_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "cannot open doctrine %s: %s" % [path, error_string(FileAccess.get_open_error())]}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null:
		return {"error": "doctrine %s is not valid JSON" % path}
	return parse(data)


static func parse(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {"error": "doctrine must be an object"}
	if typeof(data.get("name")) != TYPE_STRING:
		return {"error": "doctrine needs a string 'name'"}
	var squads: Variant = data.get("squads")
	if typeof(squads) != TYPE_ARRAY or squads.is_empty() or squads.size() > MAX_SQUADS:
		return {"error": "doctrine needs 1 to %d squads" % MAX_SQUADS}
	var total_tanks := 0
	var names := {}
	for squad in squads:
		if typeof(squad) != TYPE_DICTIONARY or typeof(squad.get("name")) != TYPE_STRING:
			return {"error": "every squad needs a string 'name'"}
		if names.has(squad["name"]):
			return {"error": "duplicate squad name '%s'" % squad["name"]}
		names[squad["name"]] = true
		if not String(squad["name"]).is_valid_ascii_identifier():
			return {"error": "squad name '%s' must be letters, digits, underscores" % squad["name"]}
		if squad.has("directive"):
			var error := Directives.validate(squad["directive"])
			if error != "":
				return {"error": "squad %s: %s" % [squad["name"], error]}
		if squad.has("formation") and not Formations.NAMES.has(squad["formation"]):
			return {"error": "squad %s: formation must be one of %s" % [squad["name"], Formations.NAMES]}
		if squad.has("verb") and not ["hold"].has(squad["verb"]):
			return {"error": "squad %s: a doctrine may only start a squad with verb 'hold' (others need a destination)" % squad["name"]}
		var tanks: Variant = squad.get("tanks")
		if typeof(tanks) != TYPE_ARRAY or tanks.is_empty():
			return {"error": "squad %s needs at least one tank" % squad["name"]}
		if tanks.size() > Formations.MAX_MEMBERS:
			return {"error": "squad %s has %d tanks; a squad holds at most %d" % [squad["name"], tanks.size(), Formations.MAX_MEMBERS]}
		for tank in tanks:
			if typeof(tank) != TYPE_DICTIONARY:
				return {"error": "squad %s: tanks must be objects" % squad["name"]}
			var loadout_error := Units.validate_loadout(tank)
			if loadout_error != "":
				return {"error": "squad %s: %s" % [squad["name"], loadout_error]}
			if tank.has("directive"):
				var error := Directives.validate(tank["directive"])
				if error != "":
					return {"error": "squad %s tank: %s" % [squad["name"], error]}
			total_tanks += 1
	if total_tanks > MAX_TANKS:
		return {"error": "doctrine has %d tanks; the limit is %d" % [total_tanks, MAX_TANKS]}
	return {"doctrine": data}
