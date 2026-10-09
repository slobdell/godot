class_name MoverState
extends RefCounted
## Round 24 (native, N3c's proof harness): everything a Movement's drive can change, as one comparable value, so a
## port is asked "from the SAME state, does the native drive leave the SAME state and command as the live GDScript?".
## The instance's script members (deep-copied: routes, k-turn legs, Dictionaries), the script's static counters (read
## from movement.gd's own `static var` lines, so a counter brains adds is compared without editing this file), and the
## command. `restore` puts a snapshot back (members and statics) so the second arm starts where the first did.

const SOURCE := "res://game/ai/movement.gd"
## Statics that are configuration or caches, not state a drive changes (and the registry, which holds objects).
const SKIP_STATICS: Array[String] = ["_registry", "_off", "_off_parsed", "avoidance_on", "station_on", "yield_log",
		"kturn_log", "leg_print", "reverse_log", "_bake_radius"]
## Members that hold objects (compared by identity, never deep-copied).
const OBJECT_MEMBERS: Array[String] = ["ctl", "contact", "_station"]

static var _statics: PackedStringArray = []


static func static_names() -> PackedStringArray:
	if _statics.is_empty():
		var regex := RegEx.create_from_string("(?m)^static var ([A-Za-z_][A-Za-z0-9_]*)")
		for found in regex.search_all(FileAccess.get_file_as_string(SOURCE)):
			var name := found.get_string(1)
			if not SKIP_STATICS.has(name):
				_statics.append(name)
	return _statics


static func _copy(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value


## {member: value} for the instance, {"static:" + name: value} for the script's statics.
static func capture(mover: Movement) -> Dictionary:
	var state := {}
	for prop: Dictionary in mover.get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var name: String = prop["name"]
		state[name] = mover.get(name) if OBJECT_MEMBERS.has(name) else _copy(mover.get(name))
	for name in static_names():
		state["static:" + name] = _copy(mover.get(name))
	return state


static func restore(mover: Movement, state: Dictionary) -> void:
	for key: String in state:
		var name := key.trim_prefix("static:")
		mover.set(name, state[key] if OBJECT_MEMBERS.has(name) else _copy(state[key]))


## The keys whose values differ (`==` on Variants: bit-exact for floats and vectors), with both values, or "".
static func diff(a: Dictionary, b: Dictionary) -> String:
	var out: Array[String] = []
	for key: String in a:
		if not b.has(key) or typeof(a[key]) != typeof(b[key]) or a[key] != b[key]:
			out.append("%s: %s v %s" % [key, var_to_str(a[key]).left(80), var_to_str(b.get(key)).left(80)])
	for key: String in b:
		if not a.has(key):
			out.append("%s: missing v %s" % [key, var_to_str(b[key]).left(80)])
	return "; ".join(out)


static func command(cmd: TankCommand) -> Array:
	return [cmd.throttle, cmd.turn, cmd.aim_point, cmd.fire]
