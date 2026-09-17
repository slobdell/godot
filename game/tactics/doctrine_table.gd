class_name DoctrineTable
extends RefCounted
## An element leader's standard operating procedures, as data (doctrine X1/X2): which movement formation and
## which movement technique to use for a task, in this terrain, against this threat, with these vehicles, and
## the numbers its battle drills run on. One file per doctrine in `res://doctrines/doctrine_<name>.json`, with
## a `faction` field; factions differ by table, never by engine (L1, X6).
##
##   DoctrineTable.load_table("standard")          -> {"table": DoctrineTable} or {"error": "..."}
##   DoctrineTable.for_faction("gangs")            -> the faction's table, or the standard one
##   table.select({"task": "move", "threat": "possible", "terrain": "open", "composition": "heavy"})
##       -> {"formation": "wedge", "technique": "traveling_overwatch", "why": "contact is possible ...", "rule": 2}
##   table.spacing("open") / table.drill_number("near_ambush_m") / table.leg("bounding_m")
##
## Rules are tried in order and the first match wins, so a table reads top to bottom like a leader's priorities
## and the same inputs always pick the same row (determinism). Every rule carries its own `why`: that string is
## what the player sees when the element changes shape ("dense cover, contact likely: bounding overwatch").
## The doctrine behind the shapes and the techniques, with citations, is in _agents/doctrine.md.

const DIR := "res://doctrines"
const THREATS := ["none", "possible", "likely", "contact"]
const TERRAINS := ["open", "lanes", "dense"]
const COMPOSITIONS := ["heavy", "balanced", "light", "support"]
const TECHNIQUES := ["traveling", "traveling_overwatch", "bounding_overwatch"]
const WHEN_KEYS := ["task", "threat", "terrain", "composition"]
const RULE_KEYS := ["when", "formation", "technique", "why"]
const TABLE_KEYS := ["name", "faction", "display_name", "summary", "spacing_m", "movement", "legs", "drills", "traits"]

## Every number a drill runs on, with the doctrine-standard value. A table overrides only what it changes.
const DRILL_DEFAULTS := {
	# Which drills this doctrine runs at all (X3).
	"enabled": ["react_to_contact", "near_ambush", "far_ambush", "assault_through", "support_by_fire",
			"break_contact", "herringbone"],
	# Encircle and bait are off unless a table asks for them: they are gang behaviour, not doctrine.
	# How close the pack gets when it rings a target, and how near is too near to keep circling.
	"encircle_m": 70.0,
	"encircle_min_m": 22.0,
	"encircle_min_units": 3.0,
	# How far away an enemy can be and still be worth leading onto the rest of the pack.
	"bait_m": 95.0,
	"bait_min_m": 30.0,
	# How far behind the pack the bait vehicle runs, drawing them onto it.
	"bait_back_m": 45.0,
	# Only something moving at least this fast is worth trying to lure, and this is how long the pack waits
	# to find out whether it took the bait before giving up on it.
	"bait_chaser_mps": 2.0,
	"bait_patience_ticks": 240,
	# A contact closer than this, appearing suddenly, is a NEAR ambush: turn into it and assault through.
	"near_ambush_m": 38.0,
	# How far past the enemy an assault carries before the drill ends.
	"assault_through_m": 26.0,
	# React to contact is the short "deploy and report" step: this many ticks before the leader picks a course.
	"react_ticks": 72,
	# A far ambush's maneuver element swings this far off the line of contact before it turns in.
	"flank_m": 42.0,
	# Break contact when our strength is below this fraction of what we can see...
	"break_contact_ratio": 0.5,
	# ...but never turn our backs on an enemy closer than this (round-3 lesson: disengaging up close gets you shot).
	"disengage_m": 40.0,
	# How far back a break-contact bound goes, and when we call the contact broken.
	"rally_back_m": 55.0,
	"broken_contact_m": 95.0,
	# No drill runs longer than this without being re-decided.
	"timeout_ticks": 900,
	# A drill needs this much of the element still alive to be worth running (else break contact).
	"min_strength": 0.15,
}

## Movement legs and cohesion, in meters (see _agents/doctrine.md "Movement techniques").
const LEG_DEFAULTS := {
	# How far the element advances between decisions under each technique.
	"traveling_m": 45.0,
	"traveling_overwatch_m": 34.0,
	"bounding_m": 22.0,
	# How far the trail element follows behind the lead under traveling overwatch.
	"overwatch_gap_m": 30.0,
	# The element waits for stragglers this far from their slots before advancing the next leg.
	"cohesion_m": 20.0,
	# A bound never goes further than this from the overwatch element: it must be able to support by fire.
	"support_range_m": 85.0,
}

const SPACING_DEFAULTS := {"open": 14.0, "lanes": 11.0, "dense": 8.0}

## Tables already read from disk, by name: loading is pure and the files never change during a match.
static var _cache := {}

var name := ""
var faction := "condemned"
var display_name := ""
var summary := ""
var movement: Array = []
var spacing_m: Dictionary = SPACING_DEFAULTS.duplicate()
var legs: Dictionary = LEG_DEFAULTS.duplicate()
var drills: Dictionary = DRILL_DEFAULTS.duplicate()
var traits: Dictionary = {}


static func path_for(table_name: String) -> String:
	# Round-5 X3: the tactics ladder names variant tables by path (tests/tactics/variants/).
	if table_name.begins_with("res://"):
		return table_name
	return "%s/doctrine_%s.json" % [DIR, table_name]


## {"table": DoctrineTable} or {"error": String}. Cached by name.
static func load_table(table_name: String) -> Dictionary:
	if _cache.has(table_name):
		return {"table": _cache[table_name]}
	var path := path_for(table_name)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "cannot open doctrine table %s: %s" % [path, error_string(FileAccess.get_open_error())]}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null:
		return {"error": "%s is not valid JSON" % path}
	var parsed := parse(data)
	if parsed.has("error"):
		return {"error": "%s: %s" % [path.get_file(), parsed["error"]]}
	_cache[table_name] = parsed["table"]
	return parsed


## The table a faction fights by: doctrine_<faction>.json when it exists, else the standard one.
static func for_faction(faction_id: String) -> DoctrineTable:
	if faction_id != "" and FileAccess.file_exists(path_for(faction_id)):
		var loaded := load_table(faction_id)
		if loaded.has("table"):
			return loaded["table"]
		push_error(loaded["error"])
	var standard := load_table("standard")
	if standard.has("error"):
		push_error(standard["error"])
		return DoctrineTable.new()
	return standard["table"]


## Round-5 X3: `base` with changes, for ladder variants of a faction's own table:
## `drop` drills taken out of `drills.enabled`, and `commander` set as `traits.commander` ("" = unchanged).
## Cached by name, base, drop and commander.
static func variant_of(base: DoctrineTable, drop: PackedStringArray, commander: String) -> DoctrineTable:
	var key := "variant|%s|%s|%s" % [base.name, ",".join(drop), commander]
	if _cache.has(key):
		return _cache[key]
	var table: DoctrineTable = base.duplicate_table()
	var enabled: Array = (table.drills.get("enabled", DRILL_DEFAULTS["enabled"]) as Array).duplicate()
	for drill in drop:
		enabled.erase(drill)
	table.drills["enabled"] = enabled
	if commander != "":
		table.traits["commander"] = commander
	table.name = "%s%s%s" % [base.name, "".join(Array(drop).map(func(d: String) -> String: return "-" + d)),
			"+" + commander if commander != "" else ""]
	_cache[key] = table
	return table


func duplicate_table() -> DoctrineTable:
	var copy := DoctrineTable.new()
	for property: Dictionary in get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = get(property["name"])
			copy.set(property["name"], value.duplicate(true) if value is Dictionary or value is Array else value)
	return copy


## Forget cached tables (tests that write their own files).
static func clear_cache() -> void:
	_cache.clear()


## {"table": DoctrineTable} or {"error": String}: strict, so a typo in a doctrine file is loud.
static func parse(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {"error": "a doctrine table must be an object"}
	for key in data:
		if not TABLE_KEYS.has(key):
			return {"error": "unknown key '%s' (allowed: %s)" % [key, ", ".join(TABLE_KEYS)]}
	if typeof(data.get("name")) != TYPE_STRING:
		return {"error": "a doctrine table needs a string 'name'"}
	var table := DoctrineTable.new()
	table.name = data["name"]
	table.faction = String(data.get("faction", "condemned"))
	table.display_name = String(data.get("display_name", table.name))
	table.summary = String(data.get("summary", ""))
	table.traits = data.get("traits", {})
	var rules: Variant = data.get("movement")
	if typeof(rules) != TYPE_ARRAY or (rules as Array).is_empty():
		return {"error": "'movement' must be a non-empty list of rules"}
	var catch_all := false
	for i in (rules as Array).size():
		var rule: Variant = rules[i]
		if typeof(rule) != TYPE_DICTIONARY:
			return {"error": "movement rule %d must be an object" % i}
		for key in (rule as Dictionary):
			if not RULE_KEYS.has(key):
				return {"error": "movement rule %d: unknown key '%s' (allowed: %s)" % [i, key, ", ".join(RULE_KEYS)]}
		if not TacticsFormation.NAMES.has(rule.get("formation")):
			return {"error": "movement rule %d: 'formation' must be one of %s" % [i, ", ".join(TacticsFormation.NAMES)]}
		if not TECHNIQUES.has(rule.get("technique")):
			return {"error": "movement rule %d: 'technique' must be one of %s" % [i, ", ".join(TECHNIQUES)]}
		if typeof(rule.get("why")) != TYPE_STRING or String(rule["why"]).is_empty():
			return {"error": "movement rule %d needs a 'why' the player can read" % i}
		var when: Variant = rule.get("when", {})
		if typeof(when) != TYPE_DICTIONARY:
			return {"error": "movement rule %d: 'when' must be an object" % i}
		for key in (when as Dictionary):
			if not WHEN_KEYS.has(key):
				return {"error": "movement rule %d: unknown condition '%s' (allowed: %s)" % [i, key, ", ".join(WHEN_KEYS)]}
			var allowed: Array = {"task": ElementTask.VERBS, "threat": THREATS, "terrain": TERRAINS,
					"composition": COMPOSITIONS}[key]
			var values: Variant = when[key]
			if typeof(values) != TYPE_ARRAY or (values as Array).is_empty():
				return {"error": "movement rule %d: '%s' must be a non-empty list" % [i, key]}
			for value in (values as Array):
				if not allowed.has(value):
					return {"error": "movement rule %d: '%s' must be one of %s" % [i, key, ", ".join(allowed)]}
		if (when as Dictionary).is_empty():
			catch_all = true
		table.movement.append(rule)
	if not catch_all:
		return {"error": "a doctrine table's last rule must have an empty 'when': every situation needs a pick"}
	var numbers := _merge_numbers(data.get("spacing_m", {}), SPACING_DEFAULTS, "spacing_m")
	if numbers.has("error"):
		return numbers
	table.spacing_m = numbers["values"]
	numbers = _merge_numbers(data.get("legs", {}), LEG_DEFAULTS, "legs")
	if numbers.has("error"):
		return numbers
	table.legs = numbers["values"]
	var drill_values: Variant = data.get("drills", {})
	if typeof(drill_values) != TYPE_DICTIONARY:
		return {"error": "'drills' must be an object"}
	var merged := DRILL_DEFAULTS.duplicate(true)
	for key in (drill_values as Dictionary):
		if not DRILL_DEFAULTS.has(key):
			return {"error": "drills: unknown setting '%s' (allowed: %s)" % [key, ", ".join(DRILL_DEFAULTS.keys())]}
		if key == "enabled":
			var enabled: Variant = drill_values[key]
			if typeof(enabled) != TYPE_ARRAY:
				return {"error": "drills.enabled must be a list of drill names"}
			for drill in (enabled as Array):
				if not Drills.NAMES.has(drill):
					return {"error": "drills.enabled: unknown drill '%s' (allowed: %s)" % [drill,
							", ".join(Drills.NAMES)]}
			merged["enabled"] = Array(enabled)
			continue
		if not _is_number(drill_values[key]):
			return {"error": "drills.%s must be a number" % key}
		merged[key] = float(drill_values[key]) if typeof(DRILL_DEFAULTS[key]) == TYPE_FLOAT else int(drill_values[key])
	table.drills = merged
	return {"table": table}


## The formation and technique for this situation, with the reason the player reads.
## inputs: {"task": verb, "threat": THREATS, "terrain": TERRAINS, "composition": COMPOSITIONS}.
func select(inputs: Dictionary) -> Dictionary:
	for i in movement.size():
		var rule: Dictionary = movement[i]
		if _matches(rule.get("when", {}), inputs):
			return {"formation": String(rule["formation"]), "technique": String(rule["technique"]),
					"why": String(rule["why"]), "rule": i}
	return {"formation": TacticsFormation.DEFAULT, "technique": "traveling_overwatch",
			"why": "no rule matched", "rule": -1}


func spacing(terrain: String) -> float:
	return float(spacing_m.get(terrain, SPACING_DEFAULTS.get(terrain, TacticsFormation.DEFAULT_SPACING)))


func leg(key: String) -> float:
	return float(legs.get(key, LEG_DEFAULTS.get(key, 30.0)))


func drill_number(key: String) -> float:
	return float(drills.get(key, DRILL_DEFAULTS.get(key, 0.0)))


func drill_ticks(key: String) -> int:
	return int(drills.get(key, DRILL_DEFAULTS.get(key, 0)))


func runs_drill(drill: String) -> bool:
	return (drills.get("enabled", DRILL_DEFAULTS["enabled"]) as Array).has(drill)


static func _matches(when: Dictionary, inputs: Dictionary) -> bool:
	for key in when:
		if not (when[key] as Array).has(inputs.get(key)):
			return false
	return true


static func _merge_numbers(values: Variant, defaults: Dictionary, label: String) -> Dictionary:
	if typeof(values) != TYPE_DICTIONARY:
		return {"error": "'%s' must be an object" % label}
	var merged := defaults.duplicate()
	for key in (values as Dictionary):
		if not defaults.has(key):
			return {"error": "%s: unknown setting '%s' (allowed: %s)" % [label, key, ", ".join(defaults.keys())]}
		if not _is_number(values[key]):
			return {"error": "%s.%s must be a number" % [label, key]}
		merged[key] = float(values[key])
	return {"values": merged}


static func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
