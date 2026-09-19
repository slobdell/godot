class_name ElementTask
extends RefCounted
## What the player (or the CPU) asks an element to do: contract L1's task, as plain data. The commander says
## WHAT and WHERE; the element's leader decides the formation, the movement technique and the drills
## (_agents/doctrine.md). Nobody commands geometry.
##
##   {"verb": "move" | "attack" | "screen" | "support_by_fire" | "ambush" | "hold",
##    "to": [x, z],        world meters: required for move, screen, support_by_fire and ambush; optional for hold
##    "target": "Rust_1",  an enemy unit: required for attack, optional for support_by_fire
##    "facing": [x, z],    optional: which way the element faces when it gets there (a plain move or a hold); the
##                         screen, support-by-fire and ambush tasks face their point by their own geometry
##    "drills": false}     optional (default true): false = a plain move. The element travels formed up and its crews
##                         shoot what they meet, but the leader runs NO contact drill (no react to contact, no flank,
##                         no assault): the player said where, not how to fight (round 6, X4: right-click to a squad)
##
## What each verb means to the leader (_agents/doctrine.md "Tasks"):
##   move             get there as a formed element; fight only what stops you (react to contact)
##   attack           close with that enemy (or where it was last seen) and destroy it
##   screen           occupy a line across that point, observe, report, fight only what comes to you
##   support_by_fire  take a firing position covering that point (or target) and suppress from it; don't advance
##   ambush           (round 6, X7) take positions covering that point (the kill zone), HOLD FIRE, and open up all at
##                    once when an enemy enters it or the element is found (Drills: "ambush", then "spring_ambush")
##   hold             stay here, all-round security (herringbone at a halt)

const VERBS := ["move", "attack", "screen", "support_by_fire", "ambush", "hold"]
const NEEDS_TO := ["move", "screen", "support_by_fire", "ambush"]
const NEEDS_TARGET := ["attack"]
const KEYS := ["verb", "to", "target", "drills", "facing"]


## "" when `task` is well formed, else a human-readable reason (a typo from a script or an LLM fails loudly).
static func validate(task: Variant) -> String:
	if typeof(task) != TYPE_DICTIONARY:
		return "a task must be an object"
	for key in task:
		if not KEYS.has(key):
			return "unknown key '%s' (allowed: %s)" % [key, ", ".join(KEYS)]
	var verb: Variant = task.get("verb")
	if not VERBS.has(verb):
		return "'verb' must be one of %s" % ", ".join(VERBS)
	if task.has("to"):
		var pair: Variant = task["to"]
		if typeof(pair) != TYPE_ARRAY or (pair as Array).size() != 2 or not _finite(pair[0]) or not _finite(pair[1]):
			return "'to' must be [x, z] in meters"
	elif NEEDS_TO.has(verb):
		return "'%s' needs a destination 'to'" % verb
	if task.has("target"):
		if typeof(task["target"]) != TYPE_STRING and typeof(task["target"]) != TYPE_STRING_NAME:
			return "'target' must be a unit name"
	elif NEEDS_TARGET.has(verb):
		return "'%s' needs a 'target' unit" % verb
	if task.has("facing"):
		var facing: Variant = task["facing"]
		if typeof(facing) != TYPE_ARRAY or (facing as Array).size() != 2 or not _finite(facing[0]) or not _finite(facing[1]) \
				or Vector2(float(facing[0]), float(facing[1])).length() < 1e-6:
			return "'facing' must be a non-zero [x, z] direction"
	if task.has("drills") and typeof(task["drills"]) != TYPE_BOOL:
		return "'drills' must be true or false"
	return ""


## Whether the leader may run contact drills on this task (false for a plain move).
static func runs_drills(task: Dictionary) -> bool:
	return bool(task.get("drills", true))


## The task's `facing` as a flat unit direction, or null.
static func facing(task: Dictionary) -> Variant:
	if not task.has("facing"):
		return null
	return Vector3(float(task["facing"][0]), 0.0, float(task["facing"][1])).normalized()


static func make(verb: String, extra: Dictionary = {}) -> Dictionary:
	var task := {"verb": verb}
	task.merge(extra)
	return task


## The task's point in the world, or null (attack without a known destination, hold where we stand).
static func destination(task: Dictionary) -> Variant:
	if not task.has("to"):
		return null
	return Vector3(float(task["to"][0]), 0.0, float(task["to"][1]))


## A few plain words for the HUD and logs.
static func describe(task: Dictionary) -> String:
	var verb := String(task.get("verb", ""))
	var words: String = {"move": "move", "attack": "attack", "screen": "screen",
			"support_by_fire": "support by fire", "ambush": "ambush", "hold": "hold"}.get(verb, "?")
	if task.has("target"):
		words += " " + String(task["target"])
	elif task.has("to"):
		words += " (%d, %d)" % [int(task["to"][0]), int(task["to"][1])]
	return words


static func _finite(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
