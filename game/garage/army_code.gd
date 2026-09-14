class_name ArmyCode
extends RefCounted
## Shareable army codes: a short, URL-safe string that carries a whole army, so players can trade
## builds in chat or a link (web: index.html?garage&army=CODE). Stretch goal of the garage stream.
##
## Format: "TS1" + 8 hex digits (checksum of the rest, so a truncated or mistyped paste is refused
## before decoding) + base64url(deflate(JSON of the COMPACT form)). Compact form, per army:
##   {"n": name, "s": [squad…]}
##   squad: {"n": name, "f": formation, "r": role, "h": 1 if holding, "d": other directive keys (all but n optional),
##           "t": [unit…]}
##   unit:  {"u": unit id, "w": [weapon per hardpoint, in the catalog's hardpoint order],
##           "c": [components] (optional), "p": paint (optional), "r": role (optional)}
## Decoding needs the catalog (hardpoint order), and never trusts the code: the result goes through
## Loadout.from_doctrine, and callers show loadout.problems() like any other army.

const PREFIX := "TS1"
## A code can't inflate into more than this (defends against zip bombs).
const MAX_JSON_BYTES := 16384
const MAX_CODE_LENGTH := 4096


static func encode(loadout: Loadout) -> String:
	var squads := []
	for squad in loadout.squads():
		var directive: Dictionary = squad.get("directive", {}) if typeof(squad.get("directive")) == TYPE_DICTIONARY else {}
		var compact := {"n": squad.get("name", ""), "t": []}
		if squad.has("formation"):
			compact["f"] = squad["formation"]
		if directive.has("role"):
			compact["r"] = directive["role"]
		if squad.get("verb") == "hold":
			compact["h"] = 1
		var extras := directive.duplicate()
		extras.erase("role")
		if not extras.is_empty():
			compact["d"] = extras
		for tank: Dictionary in squad.get("tanks", []):
			var unit := {"u": tank.get("unit", ""), "w": []}
			for hardpoint in loadout.catalog.hardpoints(String(tank.get("unit", ""))):
				unit["w"].append(tank.get("weapons", {}).get(hardpoint["id"], ""))
			if not tank.get("components", []).is_empty():
				unit["c"] = tank["components"]
			if tank.has("paint"):
				unit["p"] = String(tank["paint"]).trim_prefix("#")
			if typeof(tank.get("directive")) == TYPE_DICTIONARY and tank["directive"].has("role"):
				unit["r"] = tank["directive"]["role"]
			compact["t"].append(unit)
		squads.append(compact)
	var json := JSON.stringify({"n": loadout.army.get("name", ""), "s": squads})
	var packed := json.to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	var body := Marshalls.raw_to_base64(packed).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")
	return PREFIX + _checksum(body) + body


static func _checksum(body: String) -> String:
	return "%08x" % (body.hash() & 0xffffffff)


## Returns {"loadout": Loadout} or {"error": String}. The loadout may still have problems (budget…).
static func decode(code: String, catalog: GarageCatalog) -> Dictionary:
	code = code.strip_edges()
	if not code.begins_with(PREFIX):
		return {"error": "Not an army code (they start with %s)." % PREFIX}
	if code.length() > MAX_CODE_LENGTH:
		return {"error": "That army code is too long."}
	var body := code.substr(PREFIX.length() + 8)
	if code.length() <= PREFIX.length() + 8 or code.substr(PREFIX.length(), 8) != _checksum(body):
		return {"error": "That army code is damaged or incomplete."}
	body = body.replace("-", "+").replace("_", "/")
	while body.length() % 4 != 0:
		body += "="
	var packed := Marshalls.base64_to_raw(body)
	if packed.is_empty():
		return {"error": "That army code is damaged."}
	var raw := packed.decompress_dynamic(MAX_JSON_BYTES, FileAccess.COMPRESSION_DEFLATE)
	var data: Variant = JSON.parse_string(raw.get_string_from_utf8()) if not raw.is_empty() else null
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("s")) != TYPE_ARRAY:
		return {"error": "That army code is damaged."}
	var squads := []
	for compact: Variant in data["s"]:
		if typeof(compact) != TYPE_DICTIONARY or typeof(compact.get("t")) != TYPE_ARRAY:
			return {"error": "That army code is damaged."}
		var directive: Dictionary = compact.get("d", {}).duplicate() if typeof(compact.get("d")) == TYPE_DICTIONARY else {}
		if compact.has("r"):
			directive["role"] = String(compact["r"])
		var squad := {"name": String(compact.get("n", "")), "tanks": []}
		if compact.has("f"):
			squad["formation"] = String(compact["f"])
		if not directive.is_empty():
			squad["directive"] = directive
		if compact.get("h", 0):
			squad["verb"] = "hold"
		for unit: Variant in compact["t"]:
			if typeof(unit) != TYPE_DICTIONARY:
				return {"error": "That army code is damaged."}
			var unit_id := String(unit.get("u", ""))
			var weapons := {}
			var hardpoints := catalog.hardpoints(unit_id)
			var mounted: Array = unit.get("w", []) if typeof(unit.get("w")) == TYPE_ARRAY else []
			for i in mini(hardpoints.size(), mounted.size()):
				if String(mounted[i]) != "":
					weapons[String(hardpoints[i]["id"])] = String(mounted[i])
			var tank := {"unit": unit_id, "weapons": weapons,
					"components": (unit.get("c", []) as Array).map(func(c: Variant) -> String: return String(c)) if typeof(unit.get("c")) == TYPE_ARRAY else []}
			if unit.has("p"):
				tank["paint"] = "#" + String(unit["p"])
			if unit.has("r"):
				tank["directive"] = {"role": String(unit["r"])}
			squad["tanks"].append(tank)
		squads.append(squad)
	return {"loadout": Loadout.from_doctrine(catalog, {"name": String(data.get("n", "Shared army")), "squads": squads})}
