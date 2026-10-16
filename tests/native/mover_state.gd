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
## Round 27 (E5b): the native execute's own bookkeeping (the stale bits): not drive state.
const NATIVE_MEMBERS: Array[String] = ["native_stale"]
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


## {member: value} for the instance, {"static:" + name: value} for the script's statics, and for an object member
## that drive mutates through its own methods (the station PID), {"<member>.<its member>": value}.
static func capture(mover: Movement) -> Dictionary:
	var state := {}
	for prop: Dictionary in mover.get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var name: String = prop["name"]
		if NATIVE_MEMBERS.has(name):
			continue
		if OBJECT_MEMBERS.has(name):
			# The object itself goes back on restore ("@": never compared: a PID made fresh in each arm is two objects
			# with one state); what is compared is whether there is one, and (below) the station PID's own members.
			state["@" + name] = mover.get(name)
			state[name + "?"] = mover.get(name) != null
		else:
			state[name] = _copy(mover.get(name))
	for name in static_names():
		state["static:" + name] = _copy(mover.get(name))
	var station: Object = mover._station
	if station != null:
		for prop: Dictionary in station.get_property_list():
			if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				state["_station." + String(prop["name"])] = _copy(station.get(prop["name"]))
	return state


static func restore(mover: Movement, state: Dictionary) -> void:
	for key: String in state:
		if key.begins_with("_station.") or key.ends_with("?"):
			continue
		if key.begins_with("@"):
			mover.set(key.trim_prefix("@"), state[key])
			continue
		mover.set(key.trim_prefix("static:"), _copy(state[key]))
	var station: Object = mover._station
	if station != null:
		for key: String in state:
			if key.begins_with("_station."):
				station.set(key.trim_prefix("_station."), _copy(state[key]))
	# Round 27 (E5b): restoring writes the members (new containers): a door into the C++-owned state.
	mover.native_stale |= Movement.STALE_ALL


## The keys whose values differ (`==` on Variants: bit-exact for floats and vectors), with both values, or "".
static func diff(a: Dictionary, b: Dictionary) -> String:
	var out: Array[String] = []
	for key: String in a:
		if key.begins_with("@"):
			continue
		if not b.has(key) or typeof(a[key]) != typeof(b[key]) or a[key] != b[key]:
			out.append("%s: %s v %s" % [key, var_to_str(a[key]).left(80), var_to_str(b.get(key)).left(80)])
	for key: String in b:
		if not a.has(key) and not key.begins_with("@"):
			out.append("%s: missing v %s" % [key, var_to_str(b[key]).left(80)])
	return "; ".join(out)


## The capture without the shared statics (so "did this drive change ANOTHER mover" is not every static counter).
static func own(state: Dictionary) -> Dictionary:
	var out := {}
	for key: String in state:
		if not key.begins_with("static:") and not key.begins_with("@"):
			out[key] = state[key]
	return out


static func command(cmd: TankCommand) -> Array:
	return [cmd.throttle, cmd.turn, cmd.aim_point, cmd.fire]


# ---- Round 31 (planner CP-P1): the world a drive can change besides the movers -- the lattice planner's seam -------
# PlannerSeam's static table (crews, queue, retries, counters, the live search session) changes when a held crew's
# drive runs; a twin must start both arms from the same seam and compare what each left. Loaded by path (absent on a
# tree without the planner: {} and no compare).
const PLANNER_SEAM := "res://game/ai/planner/planner_seam.gd"


static func _seam() -> Script:
	return load(PLANNER_SEAM) if ResourceLoader.exists(PLANNER_SEAM) else null


## The seam's snapshot ("@snap", restorable) and its comparable form ("cmp"), or {} without a seam or with it OFF.
static func world_capture() -> Dictionary:
	var seam := _seam()
	if seam == null or not bool(seam.call("on")):
		return {}
	var snap: Dictionary = seam.call("capture")
	var crews := {}
	for name: String in snap["crews"]:
		var crew: Object = snap["crews"][name]
		var row := {}
		for prop: Dictionary in crew.get_property_list():
			if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var key := String(prop["name"])
			var value: Variant = crew.get(key)
			if key == "executor":
				row[key] = _executor_row(value)
			elif key == "req":
				row[key] = _req_row(value)
			else:
				row[key] = _copy(value)
		crews[name] = row
	return {"@snap": snap, "cmp": {"crews": crews, "queue": snap["queue"], "retry": snap["retry"],
			"counters": snap["counters"], "last_refusal": snap["last_refusal"]}}


static func _executor_row(executor: Object) -> Variant:
	if executor == null:
		return null
	var state: Dictionary = executor.call("to_state")
	var row := {}
	for key: String in state:
		if key == "tank":
			continue  # the hull itself (one object both arms)
		var value: Variant = state[key]
		row[key] = (value as Object).get("legs") if key == "plan" and value != null else _copy(value)
	return row


static func _req_row(req: Object) -> Variant:
	if req == null:
		return null
	var row: Dictionary = req.call("to_native")
	var world: Dictionary = (row.get("world", {}) as Dictionary).duplicate()
	world.erase("nav")  # NativeBridge.nav: one object both arms
	row["world"] = world
	return row


static func world_restore(world: Dictionary) -> void:
	if world.is_empty():
		return
	_seam().call("restore", world["@snap"])


static func world_diff(a: Dictionary, b: Dictionary) -> String:
	if a.is_empty() and b.is_empty():
		return ""
	var ca: Dictionary = a.get("cmp", {})
	var cb: Dictionary = b.get("cmp", {})
	for key: String in ca:
		if not cb.has(key) or typeof(ca[key]) != typeof(cb[key]) or ca[key] != cb[key]:
			return "PlannerSeam.%s: %s v %s" % [key, var_to_str(ca[key]).left(200), var_to_str(cb.get(key)).left(200)]
	return "" if ca.size() == cb.size() else "PlannerSeam: %s v %s" % [ca.keys(), cb.keys()]
