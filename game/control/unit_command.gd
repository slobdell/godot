class_name UnitCommand
extends RefCounted
## K1 (control X1): one order for one or more units, as plain data. The player's mouse and keyboard, the CPU, the
## agent bridge, replays, and a future LLM commander all speak it. See _agents/workstreams.md "K1 Orders API" and
## _agents/tactical_map.md (the controls doc).
##
##   {"units": ["Green_Alpha_1", ...],      who (one team; Orders.issue checks them against the match)
##    "verb": "move" | "attack" | "attack_move" | "follow" | "hold" | "stop",
##    "to": [x, z],                          world meters: required for move and attack_move; hold here (optional)
##    "target": "Rust_Bravo_2",              required for attack (an enemy) and follow (another unit)
##    "queue": false,                        shift: run after the unit's current orders (stop is never queued)
##    "formation": "auto" | Formations.NAMES} how a group arranges itself (default auto: by role and situation)
##
## Validation here is structural (types, required keys, no unknown keys, so a typo from a script or an LLM fails
## loudly); Orders.issue then checks names, teams, and targets against the match.

const VERBS := ["move", "attack", "attack_move", "follow", "hold", "stop"]
const NEEDS_TO := ["move", "attack_move"]
const NEEDS_TARGET := ["attack", "follow"]
const KEYS := ["units", "verb", "to", "target", "queue", "formation"]
const AUTO := "auto"
## A selection bigger than this is almost certainly a bug in the caller (two full armies are 50 units).
const MAX_UNITS := 64


## "" if `command` is a well-formed UnitCommand, else a human-readable reason.
static func validate(command: Variant) -> String:
	if typeof(command) != TYPE_DICTIONARY:
		return "command must be an object"
	for key in command:
		if not KEYS.has(key):
			return "unknown key '%s' (allowed: %s)" % [key, ", ".join(KEYS)]
	var units: Variant = command.get("units")
	if typeof(units) != TYPE_ARRAY or (units as Array).is_empty() or (units as Array).size() > MAX_UNITS:
		return "'units' must be a list of 1 to %d unit names" % MAX_UNITS
	var seen := {}
	for unit in units:
		if typeof(unit) != TYPE_STRING and typeof(unit) != TYPE_STRING_NAME:
			return "'units' must be a list of unit names"
		if seen.has(String(unit)):
			return "%s is listed twice in 'units'" % unit
		seen[String(unit)] = true
	var verb: Variant = command.get("verb")
	if not VERBS.has(verb):
		return "'verb' must be one of %s" % ", ".join(VERBS)
	if command.has("to"):
		var pair: Variant = command["to"]
		if typeof(pair) != TYPE_ARRAY or (pair as Array).size() != 2 or not _finite(pair[0]) or not _finite(pair[1]):
			return "'to' must be [x, z] in meters"
	elif NEEDS_TO.has(verb):
		return "'%s' needs a destination 'to'" % verb
	if command.has("target"):
		if typeof(command["target"]) != TYPE_STRING and typeof(command["target"]) != TYPE_STRING_NAME:
			return "'target' must be a unit name"
	elif NEEDS_TARGET.has(verb):
		return "'%s' needs a 'target' unit" % verb
	if command.has("queue") and typeof(command["queue"]) != TYPE_BOOL:
		return "'queue' must be true or false"
	if command.has("formation"):
		var formation: Variant = command["formation"]
		if formation != AUTO and not Formations.NAMES.has(formation):
			return "'formation' must be auto or one of %s" % ", ".join(Formations.NAMES)
	return ""


## A command from parts: make(["Green_Alpha_1"], "move", {"to": [0, 20], "queue": true}).
static func make(units: Array, verb: String, extra: Dictionary = {}) -> Dictionary:
	var command := {"units": units.map(func(unit: Variant) -> String: return String(unit)), "verb": verb}
	command.merge(extra)
	return command


## A few plain words for acknowledgements and logs ("3 units: attack-move").
static func describe(command: Dictionary) -> String:
	var count := (command.get("units", []) as Array).size()
	var who := String(command["units"][0]) if count == 1 else "%d units" % count
	var words: String = {"move": "move", "attack": "attack", "attack_move": "attack-move", "follow": "follow",
			"hold": "hold position", "stop": "stop"}.get(command.get("verb", ""), "?")
	if command.has("target"):
		words += " " + String(command["target"])
	if command.get("queue", false) and command.get("verb") != "stop":
		words += " (queued)"
	return "%s: %s" % [who, words]


static func _finite(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
