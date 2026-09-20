class_name StubElements
extends RefCounted
## A minimal stand-in for doctrine's L1 `Elements` (_agents/workstreams.md), so ai's execution tests run before
## checkpoint CP1. It holds the contract's shape — form / of / assign / state / element_changed — and resolves slots
## with the geometry we already have (`Formations`), but it is deliberately dumb: it has no doctrine table and picks
## no drills. Scenarios stage the leader's call themselves (`set_technique`, `bound`, `support_by_fire`, `halt`),
## which is the point: we are testing how a brain *executes* a call, not who makes it.
##
## AiScenario.elements() uses doctrine's real class instead once it exists, so the same scenarios then test the real
## thing. Slots are published in the richest shape ElementFeed reads (unit -> {position, facing, role}); doctrine may
## ship less and the feed degrades.

signal element_changed(id: String)

var game_match: Match
var orders: Object = null
var _elements: Array[StubElement] = []
var _by_unit := {}


func _init(p_match: Match = null, p_orders: Object = null) -> void:
	game_match = p_match
	orders = p_orders


## L1: gather `units` (names) into an element led by the first one.
func form(units: Array, element_name: String) -> StubElement:
	var element := StubElement.new()
	element.id = element_name
	element.owner = weakref(self)
	element.game_match = game_match
	for unit: Variant in units:
		element.members.append(String(unit))
		_by_unit[String(unit)] = element
	element.members.sort()
	element.leader = String(units[0]) if not units.is_empty() else ""
	_elements.append(element)
	return element


func of(unit_name: String) -> StubElement:
	return _by_unit.get(unit_name)


func all() -> Array[StubElement]:
	return _elements


func changed(id: String) -> void:
	element_changed.emit(id)


class StubElement extends RefCounted:
	var id := ""
	## Weak: the manager holds every element, so a strong link back would leak them both ("resources still in use").
	var owner: WeakRef = null
	var game_match: Match = null
	var leader := ""
	var members: PackedStringArray = []
	var formation := "wedge"
	var technique := "traveling"
	var drill := ""
	var task := ""
	var reason := "stub"
	## Anchor and heading the formation is laid out from (the leader's spot unless a task set one).
	var anchor := Vector3.ZERO
	var heading := Vector3.FORWARD
	var spacing := Formations.DEFAULT_SPACING

	## X1 (round 9): the pitch this element's slots are laid at, Vector2(across the heading, along it) — the spacing
	## above raised to what the members' own hulls fit in. The real `Element` computes it from its plan; the stub
	## derives it from the same function, so a scenario reading `element.pitch` gets the same number either way and
	## `TankBrain.slot_leash` is fed the same value the real element would feed it.
	##
	## It is a PROPERTY and not a field because the stub's members and spacing are set by the scenario after `form`,
	## and a field captured at construction would be stale for every scenario that stages its element in two steps.
	var pitch: Vector2:
		get:
			return TacticsFormation.pitch(_members_for_pitch(), spacing)
	## Unit names currently moving (bounding, or the assaulting half of a support-by-fire); everyone else covers them.
	var moving: PackedStringArray = []
	## Sector of fire per unit (a flat direction), when the scenario wants a specific one.
	var sectors := {}

	## L1: {"verb": "move" | "attack" | "screen" | "support_by_fire" | "hold", "to"?, "target"?}.
	func assign(t: Dictionary) -> String:
		task = String(t.get("verb", ""))
		if not ElementFeed.TASKS.has(task):
			return "verb must be one of %s" % [ElementFeed.TASKS]
		var to: Variant = OrderFeed.point(t.get("to"))
		if to != null:
			var here := _leader_position()
			var across: Vector3 = (to as Vector3) - here
			if across.length_squared() > 1.0:
				heading = across.normalized()
			anchor = to
		_publish()
		return ""

	## The leader's call: this half moves, the rest covers it from where they stand.
	func bound(units: Array) -> void:
		technique = "bounding_overwatch"
		moving = PackedStringArray(units.map(func(u: Variant) -> String: return String(u)))
		_publish()

	## The leader's call: `units` assault, everyone else is the base of fire.
	func support_by_fire(units: Array) -> void:
		drill = "support_by_fire"
		moving = PackedStringArray(units.map(func(u: Variant) -> String: return String(u)))
		_publish()

	## The leader's call to stop: nobody is moving any more.
	func halt() -> void:
		moving = PackedStringArray()
		_publish()

	func set_technique(value: String) -> void:
		technique = value
		_publish()

	func set_drill(value: String) -> void:
		drill = value
		_publish()

	## L1 read-only state, in the richest shape ElementFeed reads.
	func state() -> Dictionary:
		return {"id": id, "leader": leader, "members": members, "formation": formation, "technique": technique,
				"drill": drill, "task": task, "reason": reason, "moving": moving, "slots": _slots(),
				# X1: brains read the pitch through ElementFeed to size a slot's leash, so the stub publishes it too —
				# a stub that omits it makes the leash read as the old flat constant and the scenario would measure a
				# behaviour the real element does not have.
				"pitch": [pitch.x, pitch.y]}


	## The member data `TacticsFormation.pitch` needs: a unit id per member, read from the match when there is one.
	## A member whose tank is gone contributes no hull, which is the same answer the real element gives.
	func _members_for_pitch() -> Array:
		var result: Array = []
		for unit_name in members:
			var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank \
					if game_match != null and game_match.tanks != null else null
			if tank != null:
				result.append({"name": String(unit_name), "unit": tank.unit_id})
		return result

	func _slots() -> Dictionary:
		var order := members.duplicate()
		var lead_index := Array(order).find(leader)
		if lead_index > 0:
			order.remove_at(lead_index)
			order.insert(0, leader)
		var base := anchor if anchor != Vector3.ZERO else _leader_position()
		var offsets := Formations.offsets(_geometry(), order.size(), spacing)
		var slots := {}
		for i in order.size():
			var unit := String(order[i])
			var offset: Vector2 = offsets[i] if i < offsets.size() else Vector2.ZERO
			var facing: Vector3 = sectors.get(unit, Formations.facing(_geometry(), heading, offset))
			slots[unit] = {"position": Formations.to_world(base, heading, offset), "facing": facing,
					"role": _role_of(unit)}
		return slots

	## L1's formations over the geometry we have: a herringbone (all-round security on a halt) is our coil.
	func _geometry() -> String:
		return "coil" if formation == "herringbone" else formation

	## Who does what right now. A halt (nobody moving) leaves a bounding element all in overwatch — that IS the
	## leader's call, and the point of the scenario: the rush ends before any new order arrives.
	func _role_of(unit: String) -> String:
		var i_move := Array(moving).has(unit)
		if drill == "support_by_fire":
			return "maneuver" if i_move else "base_of_fire"
		if technique == "bounding_overwatch":
			return "bound" if i_move else "overwatch"
		return ""

	func _leader_position() -> Vector3:
		if game_match == null or leader == "":
			return anchor
		var tank := AiTickCache.tanks_by_name(game_match).get(leader) as Tank
		return tank.global_position if tank != null else anchor

	func _publish() -> void:
		var manager: StubElements = owner.get_ref() if owner != null else null
		if manager != null:
			manager.changed(id)
