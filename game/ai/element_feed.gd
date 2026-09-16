class_name ElementFeed
extends RefCounted
## How brains read their element's doctrine: contract L1 in _agents/workstreams.md (doctrine's `Elements`, reachable
## as `Match.elements`). The element's leader decides WHAT the element does and issues per-unit K1 orders (OrderFeed);
## this feed carries the read-only part a brain needs to execute that well: my slot, my sector of fire, and the
## formation, movement technique and battle drill in force (round-4 ai X1, _agents/unit_ai.md "Executing doctrine").
##
## Duck-typed on purpose: ai builds against the contract before checkpoint CP1 lands, so nothing here names
## doctrine's classes. The source is `Match.elements` when that field exists and is set, else an object attached with
## attach() (scenarios before CP1, tools). It needs `of(unit_name) -> Object | null`; each element needs
## `state() -> Dictionary` and, ideally, signal `element_changed(id)`.
##
## state() is contract L1's `{formation, technique, drill, reason, slots}`. `slots` is read as
## unit name -> `{position, facing?, role?}` (also accepted: a bare position per unit, or an array parallel to
## `members`). Anything missing simply isn't used, so a leaner `Elements` still works: a brain with no slot behaves
## exactly as it did before elements existed.
##
## context() is normalized for brains into
##   {"id": String, "leader": String, "is_leader": bool,
##    "formation": String, "technique": "traveling" | "traveling_overwatch" | "bounding_overwatch",
##    "drill": String ("" = none), "task": String ("" = none),
##    "slot": Vector3 | null      my post in world meters (doctrine resolves the formation geometry, not the brain),
##    "facing": Vector3 | null    my sector of fire, a flat unit vector,
##    "role": "" | "bound" | "overwatch" | "base_of_fire" | "maneuver",
##    "members": PackedStringArray (sorted), "key": String}
## `key` changes exactly when something a brain must react to changed, so a brain notices the leader's call even if
## the source has no signal.

const TECHNIQUES := ["traveling", "traveling_overwatch", "bounding_overwatch"]
const DRILLS := ["react_to_contact", "near_ambush", "far_ambush", "break_contact", "support_by_fire", "assault_through"]
const TASKS := ["move", "attack", "screen", "support_by_fire", "hold"]
## Roles a brain executes differently. "bound" moves (it is the one being covered), "overwatch" and "base_of_fire"
## stay and shoot, "maneuver" is the element moving under someone else's fire.
const ROLES := ["bound", "overwatch", "base_of_fire", "maneuver"]
## Half-width of a sector of fire when the element doesn't give one: wide enough to fight in, narrow enough that a
## formation still covers all round. As a cosine, precomputed — decisions must not run trig (_agents/determinism.md).
const SECTOR_DEG := 60.0
const SECTOR_COS := 0.5


static func source(game_match: Object) -> Object:
	if game_match == null:
		return null
	if "elements" in game_match:
		var field: Variant = game_match.get("elements")
		if field is Object and is_instance_valid(field):
			return field
	if game_match.has_meta("elements"):
		var attached: Variant = game_match.get_meta("elements")
		if attached is Object and is_instance_valid(attached):
			return attached
	return null


## Use `elements` for this match's brains when the match has no `elements` field yet (before CP1).
static func attach(game_match: Object, elements: Object) -> void:
	game_match.set_meta("elements", elements)


## The element object this unit belongs to, or null.
static func element_of(elements: Object, unit_name: String) -> Object:
	if elements == null or not elements.has_method("of"):
		return null
	var element: Variant = elements.call("of", unit_name)
	if element is Object and is_instance_valid(element):
		return element
	return null


## This unit's element context (see the header), or {} when it has no element.
static func context(elements: Object, unit_name: String) -> Dictionary:
	return normalize(element_of(elements, unit_name), unit_name)


static func normalize(element: Object, unit_name: String) -> Dictionary:
	if element == null or not element.has_method("state"):
		return {}
	var raw: Variant = element.call("state")
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var state: Dictionary = raw
	var members := _members(state, element)
	var leader := String(state.get("leader", element.get("leader") if "leader" in element else ""))
	var technique := String(state.get("technique", ""))
	var drill := String(state.get("drill", ""))
	var task := String(state.get("task", state.get("verb", "")))
	var mine := _slot_of(state, unit_name, members)
	var context := {
		"id": String(state.get("id", element.get("id") if "id" in element else "")),
		"leader": leader,
		"is_leader": leader != "" and leader == unit_name,
		"formation": String(state.get("formation", "")),
		"technique": technique if TECHNIQUES.has(technique) else "",
		"drill": drill if DRILLS.has(drill) else "",
		"task": task if TASKS.has(task) else "",
		"slot": OrderFeed.point(mine.get("position")),
		"facing": _direction(mine.get("facing")),
		"role": _role(mine, state, unit_name, technique, drill, task),
		"members": members,
	}
	context["key"] = "%s|%s|%s|%s|%s|%s" % [context["id"], context["technique"], context["drill"], context["task"],
			context["role"], context["slot"]]
	return context


## True when a brain must re-decide: the element's call changed (a bound halted, a drill started, my role flipped).
static func changed(before: Dictionary, after: Dictionary) -> bool:
	return String(before.get("key", "")) != String(after.get("key", ""))


## Is this unit one of the ones holding still and shooting so someone else can move?
static func is_firing_base(context: Dictionary) -> bool:
	return ["overwatch", "base_of_fire"].has(String(context.get("role", "")))


## Is `point` inside my sector of fire (or do I not have one)? `half_width_cos` is a cosine, not an angle.
static func in_sector(context: Dictionary, from: Vector3, point: Vector3, half_width_cos := SECTOR_COS) -> bool:
	var facing: Variant = context.get("facing")
	if facing == null:
		return true
	var to_point := Vector3(point.x - from.x, 0.0, point.z - from.z)
	if to_point.length_squared() < 1.0:
		return true
	return to_point.normalized().dot(facing) >= half_width_cos


static func _members(state: Dictionary, element: Object) -> PackedStringArray:
	var raw: Variant = state.get("members")
	if raw == null and "members" in element:
		raw = element.get("members")
	if raw == null:
		raw = (state.get("slots") as Dictionary).keys() if typeof(state.get("slots")) == TYPE_DICTIONARY else []
	var names: PackedStringArray = []
	for value: Variant in Array(raw):
		names.append(String(value))
	names.sort()  # determinism: brains iterate members in one order whatever the source's insertion order was
	return names


## This unit's entry in `slots`: {"position", "facing"?, "role"?}. Accepts a dictionary per unit, a bare position per
## unit, or an array parallel to `members`.
static func _slot_of(state: Dictionary, unit_name: String, members: PackedStringArray) -> Dictionary:
	var slots: Variant = state.get("slots")
	var mine: Variant = null
	if typeof(slots) == TYPE_DICTIONARY:
		mine = (slots as Dictionary).get(unit_name)
	elif typeof(slots) == TYPE_ARRAY:
		var index := Array(members).find(unit_name)
		if index >= 0 and index < (slots as Array).size():
			mine = (slots as Array)[index]
	if typeof(mine) == TYPE_DICTIONARY:
		return mine
	if mine != null and OrderFeed.point(mine) != null:
		return {"position": mine}
	return {}


## My role, from the slot when doctrine names it, else derived from the technique and the drill in force.
static func _role(mine: Dictionary, state: Dictionary, unit_name: String, technique: String, drill: String,
		task: String) -> String:
	var named := String(mine.get("role", ""))
	if ROLES.has(named):
		return named
	# Doctrine may instead name the element half that is moving; everyone else is covering it.
	var moving := _names(state.get("moving", state.get("bounding", state.get("maneuver"))))
	if not moving.is_empty():
		var i_move := moving.has(unit_name)
		if drill == "support_by_fire" or task == "support_by_fire":
			return "maneuver" if i_move else "base_of_fire"
		return "bound" if i_move else "overwatch"
	if drill == "support_by_fire" or task == "support_by_fire":
		return "base_of_fire"
	# Nothing said who is moving and who is covering: no role, and the brain behaves as it did before elements.
	return ""


static func _names(raw: Variant) -> PackedStringArray:
	var names: PackedStringArray = []
	if raw == null or typeof(raw) not in [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY]:
		return names
	for value: Variant in Array(raw):
		names.append(String(value))
	return names


## A flat unit vector from a direction or a [x, z] pair; null when there's nothing usable.
static func _direction(value: Variant) -> Variant:
	var point: Variant = OrderFeed.point(value)
	if point == null:
		return null
	var flat: Vector3 = point
	if flat.length_squared() < 0.0001:
		return null
	return flat.normalized()
