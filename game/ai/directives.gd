class_name Directives
extends RefCounted
## Directives: the structured data a commander (player UI, CPU commander, or LLM)
## uses to steer autonomous tanks. Never code. Resolved in layers:
##   DEFAULTS → squad directive (+ its role preset) → tank directive (+ its role preset)
## See _agents/tank_brain.md "Directives v1".

const ROLES := ["assault", "anchor", "flanker", "scout", "support"]
const TARGET_PRIORITIES := ["nearest", "weakest", "most_exposed", "threatening_allies"]
const UNIT_KEYS := ["aggression", "caution", "flanking", "cohesion"]

const DEFAULTS := {
	"role": "assault",
	"aggression": 0.6,
	"caution": 0.5,
	"flanking": 0.3,
	"cohesion": 0.4,
	"objective": null,
	"leash": 0.0,
	"target_priority": "nearest",
}

## A role is just a named bundle of weights; explicit keys in the same layer win.
const ROLE_PRESETS := {
	"assault": {"aggression": 0.7, "caution": 0.4, "flanking": 0.3, "cohesion": 0.4},
	"anchor": {"aggression": 0.4, "caution": 0.6, "flanking": 0.0, "cohesion": 0.2, "leash": 15.0},
	"flanker": {"aggression": 0.6, "caution": 0.4, "flanking": 0.9, "cohesion": 0.2},
	"scout": {"aggression": 0.2, "caution": 0.8, "flanking": 0.5, "cohesion": 0.0},
	"support": {"aggression": 0.5, "caution": 0.6, "flanking": 0.1, "cohesion": 0.8},
}


## Merge layers (earliest = most general). Each layer may name a role, whose preset
## applies first, then that layer's explicit values.
static func resolve(layers: Array) -> Dictionary:
	var result := DEFAULTS.duplicate(true)
	for layer in layers:
		if typeof(layer) != TYPE_DICTIONARY:
			continue
		if layer.has("role"):
			result.merge(ROLE_PRESETS[layer["role"]], true)
		result.merge(layer, true)
	return result


## "" if valid, else a human-readable reason. Partial layers are allowed.
static func validate(layer: Variant) -> String:
	if typeof(layer) != TYPE_DICTIONARY:
		return "directive must be an object"
	for key in layer:
		match key:
			"role":
				if not ROLES.has(layer[key]):
					return "role must be one of %s" % [ROLES]
			"aggression", "caution", "flanking", "cohesion":
				if not _is_number(layer[key]) or float(layer[key]) < 0.0 or float(layer[key]) > 1.0:
					return "%s must be a number from 0 to 1" % key
			"leash":
				if not _is_number(layer[key]) or float(layer[key]) < 0.0:
					return "leash must be a number >= 0"
			"target_priority":
				if not TARGET_PRIORITIES.has(layer[key]):
					return "target_priority must be one of %s" % [TARGET_PRIORITIES]
			"objective":
				var objective: Variant = layer[key]
				if objective == null:
					continue
				if typeof(objective) != TYPE_DICTIONARY:
					return "objective must be {right, forward, radius} or null"
				for field in ["right", "forward", "radius"]:
					if not _is_number(objective.get(field)):
						return "objective needs a number '%s'" % field
			_:
				return "unknown directive key '%s'" % key
	return ""


## Team-relative (right, forward) → world position. `forward` points at the enemy
## base, so one doctrine means the same thing for either team.
static func to_world(team: int, right: float, forward: float) -> Vector3:
	var frame := Match.team_frame(team)
	return frame["right"] * right + frame["forward"] * forward


static func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
