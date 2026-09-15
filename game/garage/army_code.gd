class_name ArmyCode
extends RefCounted
## Shareable army codes: a short, URL-safe string that carries a whole army, so players can trade
## builds in chat or a link (web: index.html?garage&army=CODE).
##
## Format: "TS2" + 8 hex digits (checksum of the rest, so a truncated or mistyped paste is refused
## before decoding) + base64url(deflate(JSON of the COMPACT form)). Compact form (army JSON v2):
##   {"n": name, "s": [squad…]}
##   squad: {"n": name, "f": formation, "r": role, "h": 1 if holding, "d": other directive keys,
##           "u": [unit id, or {"u": unit id, "p": paint without #, "r": role} when it has extras]}
## Round-1 "TS1" codes (loadouts: "t" lists with weapons per hardpoint) still decode; weapons are dropped
## and a laser unit becomes a Lancer (ArmyFormat.migrate).
## Decoding never trusts the code: the result goes through ArmyDraft.from_doctrine, and callers show
## draft.problems() like any other army.

const PREFIX := "TS2"
const LEGACY_PREFIXES := ["TS1"]
## A code can't inflate into more than this (defends against zip bombs).
const MAX_JSON_BYTES := 16384
const MAX_CODE_LENGTH := 4096


static func encode(draft: ArmyDraft) -> String:
	var squads := []
	for squad: Dictionary in draft.squads():
		var directive: Dictionary = squad.get("directive", {}) if typeof(squad.get("directive")) == TYPE_DICTIONARY else {}
		var compact := {"n": squad.get("name", ""), "u": []}
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
		for entry: Dictionary in squad.get("units", []):
			var unit := {"u": String(entry.get("unit", ""))}
			if entry.has("paint"):
				unit["p"] = String(entry["paint"]).trim_prefix("#")
			if typeof(entry.get("directive")) == TYPE_DICTIONARY and entry["directive"].has("role"):
				unit["r"] = entry["directive"]["role"]
			compact["u"].append(unit["u"] if unit.size() == 1 else unit)
		squads.append(compact)
	return _wrap(PREFIX, JSON.stringify({"n": draft.army.get("name", ""), "s": squads}))


static func _wrap(prefix: String, json: String) -> String:
	var packed := json.to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	var body := Marshalls.raw_to_base64(packed).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")
	return prefix + _checksum(body) + body


static func _checksum(body: String) -> String:
	return "%08x" % (body.hash() & 0xffffffff)


## Returns {"draft": ArmyDraft} or {"error": String}. The draft may still have problems (budget, locked units…).
static func decode(code: String, catalog: ArmyCatalog) -> Dictionary:
	code = code.strip_edges()
	var prefix := code.substr(0, 3)
	if prefix != PREFIX and not LEGACY_PREFIXES.has(prefix):
		return {"error": "Not an army code (they start with %s)." % PREFIX}
	if code.length() > MAX_CODE_LENGTH:
		return {"error": "That army code is too long."}
	var body := code.substr(prefix.length() + 8)
	if code.length() <= prefix.length() + 8 or code.substr(prefix.length(), 8) != _checksum(body):
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
		var list_key := "u" if prefix == PREFIX else "t"
		if typeof(compact) != TYPE_DICTIONARY or typeof(compact.get(list_key)) != TYPE_ARRAY:
			return {"error": "That army code is damaged."}
		var directive: Dictionary = compact.get("d", {}).duplicate() if typeof(compact.get("d")) == TYPE_DICTIONARY else {}
		if compact.has("r"):
			directive["role"] = String(compact["r"])
		var squad := {"name": String(compact.get("n", "")), "units": []}
		if compact.has("f"):
			squad["formation"] = String(compact["f"])
		if not directive.is_empty():
			squad["directive"] = directive
		if compact.get("h", 0):
			squad["verb"] = "hold"
		for unit: Variant in compact[list_key]:
			if typeof(unit) == TYPE_STRING:
				unit = {"u": unit}
			if typeof(unit) != TYPE_DICTIONARY:
				return {"error": "That army code is damaged."}
			var entry := {"unit": String(unit.get("u", ""))}
			# TS1 units carried weapons per hardpoint ("w"); migrate() turns a laser into a Lancer.
			if typeof(unit.get("w")) == TYPE_ARRAY:
				entry["weapons"] = {}
				for i in (unit["w"] as Array).size():
					entry["weapons"]["hardpoint_%d" % i] = String(unit["w"][i])
			if unit.has("p"):
				entry["paint"] = "#" + String(unit["p"])
			if unit.has("r"):
				entry["directive"] = {"role": String(unit["r"])}
			squad["units"].append(entry)
		squads.append(squad)
	return {"draft": ArmyDraft.from_doctrine(catalog, {"name": String(data.get("n", "Shared army")), "squads": squads})}
