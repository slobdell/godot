class_name Orders
extends RefCounted
## K1 Orders API (control X1; CP1): every unit's current order and its queue, for one match. The simulating peer
## owns it; the player's input, the CPU, the agent bridge, and replays all go through issue(). Brains (ai) execute
## current(unit) and call complete(unit) when it's done. See _agents/workstreams.md "K1" and _agents/tactical_map.md.
##
##   issue(command, team = -1) -> String     "" or why not (UnitCommand shape, names, teams, targets)
##   current(unit_name) -> Dictionary         the active order, {} when idle (read-only: don't edit it)
##   queue(unit_name) -> Array                orders waiting after it (shift)
##   complete(unit_name)                      the executor finished the current order: start the next one
##   signal order_changed(unit_name)          the current order changed (new, completed, stopped); brains react
##                                            within 3 ticks (the response guarantee, tested in both streams)
##
## An order (current or queued) is the command resolved for one unit:
##   {"id": int (same for every unit of one issue), "verb", "units": [the group, sorted], "queue": bool,
##    "formation": what the group uses (GroupFormation.choose: a Formations name, "rows", or "single"),
##    "issued_tick": Match.tick at issue, "started_tick": when it became current,
##    "to"?: [x, z] (the group's destination, clamped into the arena), "target"?: unit name,
##    "slot"?: [right, back] meters in the group's frame (this unit's place in the formation),
##    "source": who asked for it ("player", "element", or ""): the response guarantee is about the player's,
##    "heading"?: [x, z] (the group's direction of travel, and its facing on arrival unless "facing" says otherwise),
##    "facing"?: [x, z] (normalised; from the command. On a MOVE it means ARRIVE ON THIS HEADING - a hull that pivots
##      turns once stopped, a wheeled one plans the arc into its last leg (nav, round 8) - and it is the station's heading),
##    "goal"?: [x, z] (this unit's own destination: to + slot; for follow, see goal_position()),
##    "pace_mps"?: float (the group's slowest member's top speed)}
##   pace_factor(unit_name) -> float           arrive together: the fraction of its top speed a unit drives at now
##   station(unit_name) -> Dictionary          where an idle unit belongs (regroup): {"position": [x, z],
##                                            "heading": [x, z], "units": [its group], "id"}; {} if never ordered
## Deterministic: no clock, no randomness; units are processed in name order.

signal order_changed(unit_name: String)
## Every accepted command, as issued (round 5 reopened: the lead sees order markers "repeating or re-orienting", which
## is a witness to something re-issuing. This is the instrument that counts it: who asked, for what, how often).
signal issued(command: Dictionary)
## A unit's queue changed without its current order changing (a shift-queued waypoint): for waypoint markers.
signal queue_changed(unit_name: String)
## Round 10 (R2): an order for a unit that was dropped as a repeat of the one it is already carrying out. The instrument
## for "I clicked and nothing happened": a drop the player cannot see is the bug the lead hit.
signal deduplicated(unit_name: String, order: Dictionary)

## K1's response guarantee, in wall-clock time (round 5, the orchestrator's ruling ahead of combat's 30 Hz tick): an order
## takes effect within this many milliseconds of the input. A player feels milliseconds, not ticks: "3 ticks" meant 50 ms
## at 60 Hz and would silently have meant 100 ms at 30. At 30 Hz this is exactly 3 ticks, with nothing to spare.
const RESPONSE_MS := 100.0

## A move counts as arrived within this distance of its goal (meters).
const ARRIVE_RADIUS := 3.0
## Two orders count as the same when their destinations are within this far of each other (meters). It is the arrive
## radius: a unit already inside that distance of the new spot is, by K1's own definition, already there — and elements
## recompute their members' slots against a moving anchor every update, so the difference is a metre or two of drift,
## not a new intention.
const SAME_ORDER_M := ARRIVE_RADIUS
## Round 10 (R2): a PLAYER's order is a repeat only when he clicked the same spot again: the clicks within this far of
## each other (not the per-unit slots, which on a moving squad compare equal for clicks metres apart), the same facing,
## the same units. Anything else he does is a new order, always.
const PLAYER_REPEAT_M := 1.0

var game_match: Match
var _current := {}
var _queues := {}
var _next_id := 1
var _stations := {}
## How many units the last issue() left on the order they already had (a repeat): the controls tell the player when
## that was ALL of them, because a click that changed nothing and said nothing reads as a broken game.
var last_dropped := 0


## Contract M4: how far inside the wall's inner face a hull may be sent. The old square clamp was the wall (120) minus
## this, Match.DRIVABLE_LIMIT = 116, so on a square arena `clamp_to_arena` is exactly the old clamp.
const WALL_CLEARANCE_M := 4.0
## Contract M4: the nearest place a hull can be sent, for any arena shape - arena's nearest-boundary clamp (control's
## choice: clicking past the wall puts the unit against the wall nearest the click) WALL_CLEARANCE_M inside the wall,
## then out of water and pits by arena's own Arena.clamp_into. Replaces clampf(..., DRIVABLE_LIMIT), which on a hexagon
## admits points 164 m out on the diagonal. No layout (a bare test world): the old square clamp.
static func clamp_to_arena(point: Vector3) -> Vector3:
	var data: Dictionary = Arena.active
	if data.is_empty():
		return Vector3(clampf(point.x, -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT), point.y,
				clampf(point.z, -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT))
	var kind := String((data.get("shape", {}) as Dictionary).get("kind", ArenaShape.DEFAULT_KIND))
	var bound := float(data.get("half_size", Match.ARENA_HALF_SIZE))
	# The polygon inset by the clearance is the same regular polygon scaled by 1 - clearance / apothem, so clamp to that
	# copy. NOT ArenaShape.clamp_into's `margin`: near a corner it projects onto the corner and pushes along one edge's
	# normal, leaving the point on the neighbouring edge with no clearance ((130, 130) -> (116, 120) on the square), and
	# clamping again returns the same point.
	var sides := ArenaShape.sides(kind)
	var apothem := ArenaShape.circumradius(kind, bound) * cos(PI / float(sides))
	var inset := bound * maxf(1.0 - WALL_CLEARANCE_M / maxf(apothem, 0.001), 0.0)
	var flat := ArenaShape.clamp_into(kind, inset, Vector2(point.x, point.z))
	return Arena.clamp_into(Vector3(flat.x, point.y, flat.y), data)


func _init(p_match: Match = null) -> void:
	game_match = p_match


## The Orders of a match: `Match.orders` once combat adds the field (K1), else the one attach() stored.
## RESPONSE_MS as whole physics ticks at the current tick rate (6 at 60 Hz, 3 at 30 Hz).
static func response_ticks() -> int:
	return floori(RESPONSE_MS * Engine.physics_ticks_per_second / 1000.0 + 0.0001)


static func of(p_match: Match) -> Orders:
	if p_match == null:
		return null
	var field: Variant = p_match.get("orders")
	if field is Orders:
		return field
	return p_match.get_meta("orders") as Orders if p_match.has_meta("orders") else null


## Make `orders` reachable through Orders.of(match) (sets Match.orders when the field exists).
static func attach(p_match: Match, orders: Orders) -> void:
	orders.game_match = p_match
	if "orders" in p_match:
		p_match.set("orders", orders)
	else:
		p_match.set_meta("orders", orders)


func issue(command: Variant, team: int = -1) -> String:
	var error := UnitCommand.validate(command)
	if error != "":
		return error
	var names: Array = (command["units"] as Array).map(func(unit: Variant) -> String: return String(unit))
	names.sort()
	var group_team := -1
	for unit_name: String in names:
		var tank := _tank(unit_name)
		if tank == null:
			return "no unit named %s" % unit_name
		if not tank.is_alive():
			return "%s is destroyed" % unit_name
		if group_team >= 0 and tank.team != group_team:
			return "one command can't order units from both teams"
		group_team = tank.team
	if team >= 0 and group_team != team:
		return "those units belong to the other team"
	var verb: String = command["verb"]
	var target: Tank = null
	if command.has("target"):
		target = _tank(String(command["target"]))
		if target == null:
			return "no unit named %s" % command["target"]
		if not target.is_alive():
			return "%s is already destroyed" % command["target"]
		if verb == "attack" and target.team == group_team:
			return "attack needs an enemy target (%s is a friend)" % command["target"]
		if verb == "follow":
			names.erase(String(command["target"]))
			if names.is_empty():
				return "a unit can't follow itself"
	var queued: bool = command.get("queue", false) and verb != "stop"
	var id := _next_id
	_next_id += 1
	var base := {"id": id, "verb": verb, "units": names, "queue": queued,
			"formation": String(command.get("formation", UnitCommand.AUTO)), "issued_tick": _tick(),
			"source": String(command.get("source", ""))}
	if command.has("to"):
		var to := Orders.clamp_to_arena(Vector3(float(command["to"][0]), 0.0, float(command["to"][1])))
		base["to"] = [to.x, to.z]
	if target != null:
		base["target"] = String(target.name)
	if command.has("facing"):
		base["facing"] = command["facing"]
	if command.has("slot"):
		base["slot"] = [float(command["slot"][0]), float(command["slot"][1])]
	if command.has("task"):
		base["task"] = int(command["task"])
	var per_unit := _resolve_group(base, names, queued)
	last_dropped = 0
	for unit_name: String in names:
		var order: Dictionary = per_unit[unit_name]
		if queued and not (_current.get(unit_name, {}) as Dictionary).is_empty():
			(_queues.get_or_add(unit_name, []) as Array).append(order)
			queue_changed.emit(unit_name)
			continue
		if _same_order(_current.get(unit_name, {}), order):
			last_dropped += 1
			deduplicated.emit(unit_name, order)
			continue  # already doing exactly this: restarting it would reset its path and fire a fresh marker and cue
		_queues.erase(unit_name)
		_start(unit_name, order)
	issued.emit(command)
	return ""


func current(unit_name: String) -> Dictionary:
	if not _alive(unit_name):
		return {}
	return _current.get(unit_name, {})


func queue(unit_name: String) -> Array:
	if not _alive(unit_name):
		return []
	return _queues.get(unit_name, [])


func is_idle(unit_name: String) -> bool:
	return current(unit_name).is_empty()


## The current order is done (arrived, target destroyed, stop carried out): start the next queued one, or go idle.
func complete(unit_name: String) -> void:
	if not _current.has(unit_name):
		return
	var waiting: Array = _queues.get(unit_name, [])
	if waiting.is_empty():
		_remember_station(unit_name, _current[unit_name])
		_queues.erase(unit_name)
		_current.erase(unit_name)
		order_changed.emit(unit_name)
		return
	_start(unit_name, waiting.pop_front())


## Units with an active order or a queue, sorted (for executors and waypoint markers).
func ordered_units() -> Array[String]:
	var result: Array[String] = []
	for unit_name: String in _current:
		if _alive(unit_name):
			result.append(unit_name)
	result.sort()
	return result


## Where `unit_name` should be right now for its current order: its goal, or for follow its place behind the
## target (target position + slot in the target's frame). null when the order has no place (attack, stop).
func goal_position(unit_name: String) -> Variant:
	var order := current(unit_name)
	return Orders.goal_of(order, game_match)


static func goal_of(order: Dictionary, p_match: Match) -> Variant:
	if order.is_empty():
		return null
	if order["verb"] == "follow":
		var target := p_match.tanks.get_node_or_null(NodePath(String(order["target"]))) as Tank if p_match != null else null
		if target == null or not target.is_alive():
			return null
		var forward := -target.global_basis.z
		var slot: Array = order.get("slot", [0.0, 10.0])
		return Formations.to_world(Vector3(target.global_position.x, 0.0, target.global_position.z), forward,
				Vector2(slot[0], slot[1]))
	if order.has("goal"):
		return Vector3(float(order["goal"][0]), 0.0, float(order["goal"][1]))
	return null


func station(unit_name: String) -> Dictionary:
	if not _alive(unit_name):
		return {}
	return _stations.get(unit_name, {})


func pace_factor(unit_name: String) -> float:
	var order := current(unit_name)
	var tank := _tank(unit_name)
	if tank == null or not order.has("goal") or (order["units"] as Array).size() <= 1:
		return 1.0
	var group_eta := 0.0
	for member: String in order["units"]:
		var member_order := current(member)
		var member_tank := _tank(member)
		if member_tank == null or member_order.get("id", -1) != order["id"] or member_tank.max_forward_speed <= 0.0:
			continue
		var goal: Vector3 = Orders.goal_of(member_order, game_match)
		group_eta = maxf(group_eta, _flat_distance(member_tank.global_position, goal) / member_tank.max_forward_speed)
	var own_goal: Vector3 = Orders.goal_of(order, game_match)
	return GroupFormation.pace(_flat_distance(tank.global_position, own_goal), tank.max_forward_speed, group_eta)


## True when a unit at `position` has reached a move-like order's goal.
static func reached(order: Dictionary, position: Vector3) -> bool:
	if not order.has("goal"):
		return false
	return Vector2(position.x - float(order["goal"][0]), position.z - float(order["goal"][1])).length() <= ARRIVE_RADIUS


# ---- Internals ----------------------------------------------------------------------------------------------

func _start(unit_name: String, order: Dictionary) -> void:
	var started := order.duplicate()
	started["started_tick"] = _tick()
	_current[unit_name] = started
	order_changed.emit(unit_name)


## One order per unit: slots, goals, heading, and pace for group verbs.
func _resolve_group(base: Dictionary, names: Array, queued: bool) -> Dictionary:
	var result := {}
	var verb: String = base["verb"]
	var tanks: Array[Tank] = []
	for unit_name: String in names:
		tanks.append(_tank(unit_name))
	var pace := INF
	for tank in tanks:
		pace = minf(pace, tank.max_forward_speed)
	# Where the group starts from: its centroid now, or where its last queued order leaves it.
	var start := Vector3.ZERO
	var forward := Vector3.ZERO
	for i in tanks.size():
		var from: Variant = _last_destination(names[i]) if queued else null
		start += from if from != null else Vector3(tanks[i].global_position.x, 0.0, tanks[i].global_position.z)
		forward += -tanks[i].global_basis.z
	start /= tanks.size()
	forward = Vector3(forward.x, 0.0, forward.z)
	forward = forward.normalized() if forward.length_squared() > 1e-6 else Vector3.FORWARD

	var slots := {}
	var heading := forward
	var layout := forward  # the frame the slots are laid in: the travel, or a drawn facing (round 10)
	var anchor: Variant = null
	var formation := GroupFormation.choose(tanks, String(base["formation"]), verb)
	if verb in ["move", "attack_move"] or (verb == "hold" and base.has("to")):
		anchor = Vector3(float(base["to"][0]), 0.0, float(base["to"][1]))
		var travel: Vector3 = anchor - start
		if travel.length() > 2.0:
			heading = travel.normalized()
		# Round 10 (control item 5a, decided 2026-09-20): a DRAWN facing orients the formation across that heading - an
		# emplacement faces its threat, so a line dragged east stands north-south with its front to the east. Without
		# one, the shape lies along the direction of travel, as it always has. `heading` itself stays the travel.
		layout = heading
		if base.has("facing"):
			var drawn := Vector3(float(base["facing"][0]), 0.0, float(base["facing"][1]))
			if drawn.length() > 0.001:
				layout = drawn.normalized()
		slots = GroupFormation.slots(tanks, formation, layout, anchor, verb)
	elif verb == "follow":
		slots = GroupFormation.follow_slots(tanks)
		formation = "rows" if tanks.size() > 1 else "single"
		# Round 7 (K1): an element's follower names its own place in the leader's frame.
		if base.has("slot") and names.size() == 1:
			slots = {names[0]: Vector2(float(base["slot"][0]), float(base["slot"][1]))}
	var facing: Array = []
	if base.has("facing"):
		var direction := Vector2(float(base["facing"][0]), float(base["facing"][1])).normalized()
		facing = [direction.x, direction.y]
	for i in tanks.size():
		var unit_name: String = names[i]
		var order := base.duplicate()
		order["formation"] = formation
		if not facing.is_empty():
			order["facing"] = facing.duplicate()
		if slots.has(unit_name):
			var slot: Vector2 = slots[unit_name]
			order["slot"] = [slot.x, slot.y]
		if anchor != null:
			var goal := Formations.to_world(anchor, layout, slots[unit_name])
			goal = Orders.clamp_to_arena(goal)
			order["goal"] = [goal.x, goal.z]
			order["heading"] = [heading.x, heading.z]
		elif verb == "hold":
			order["goal"] = [tanks[i].global_position.x, tanks[i].global_position.z]
			order["heading"] = [(-tanks[i].global_basis.z).x, (-tanks[i].global_basis.z).z]
		if tanks.size() > 1 and verb in ["move", "attack_move", "follow"]:
			order["pace_mps"] = pace
		result[unit_name] = order
	return result


## Whether a unit is already carrying out exactly this order (same verb, same place, same target). Round 5: elements
## re-issued their members' orders every update, ~36 a second across an army; each re-issue restarted the order and the
## feedback system drew a marker and played a cue for it ("blue dots ... repeating ... beeping", and the frame rate with
## it). An order identical to the one in progress is a no-op, whoever sends it.
static func _same_order(current: Dictionary, order: Dictionary) -> bool:
	if current.is_empty() or String(current.get("verb", "")) != String(order.get("verb", "")):
		return false
	if String(current.get("target", "")) != String(order.get("target", "")):
		return false
	# Round 10 (R2, squad's ask): an order under a new element task is new, whatever it says - the task changed.
	if int(current.get("task", -1)) != int(order.get("task", -1)):
		return false
	# Round 10 (R2, the lead: "I was trying to right click to move them in a different direction and they didnt
	# respond"): the player's order pre-empts everything. It compares the CLICK, not this unit's slot: two clicks
	# metres apart on a moving squad resolve to slots within SAME_ORDER_M of each other, and the old rule dropped the
	# second. Only the same click again (same spot within PLAYER_REPEAT_M, same facing, same units) is a repeat, and an
	# order that takes a unit off someone else's (an element's) is never one.
	if String(order.get("source", "")) == "player":
		if String(current.get("source", "")) != "player" or current.get("units", []) != order.get("units", []):
			return false
		if not _same_facing(current.get("facing", []), order.get("facing", [])):
			return false
		var clicked: Array = current.get("to", [])
		var again: Array = order.get("to", [])
		if clicked.size() != again.size():
			return false
		return clicked.is_empty() or Vector2(float(clicked[0]) - float(again[0]), float(clicked[1]) - float(again[1])).length() <= PLAYER_REPEAT_M
	# Everyone else (an element re-issuing its members' moves): the same place within SAME_ORDER_M is the same order.
	# Facing is not compared here - a leader's heading drifts as the element turns, and a new order every few degrees
	# is the re-issue churn round 8 spent a day removing. (Round 9's player-facing rule is inside the player branch.)
	var a: Array = current.get("goal", current.get("to", []))
	var b: Array = order.get("goal", order.get("to", []))
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(float(a[i]) - float(b[i])) > SAME_ORDER_M:
			return false
	return true


## Two arrival headings (each [x, z], or empty for "no particular heading") that mean the same thing. Present and
## absent never match: dropping a facing is as much a change as adding one.
const SAME_FACING_DOT := 0.996  # about 5 degrees

static func _same_facing(a: Array, b: Array) -> bool:
	if a.size() != 2 or b.size() != 2:
		return a.size() == b.size()
	var one := Vector2(float(a[0]), float(a[1]))
	var two := Vector2(float(b[0]), float(b[1]))
	if one.length() < 0.001 or two.length() < 0.001:
		return one.length() < 0.001 and two.length() < 0.001
	return one.normalized().dot(two.normalized()) >= SAME_FACING_DOT


## The destination a unit's queue ends at (for chaining shift-queued waypoints), or null.
func _last_destination(unit_name: String) -> Variant:
	var chain: Array = [_current.get(unit_name, {})] + (_queues.get(unit_name, []) as Array)
	for i in range(chain.size() - 1, -1, -1):
		var order: Dictionary = chain[i]
		if order.has("goal"):
			return Vector3(float(order["goal"][0]), 0.0, float(order["goal"][1]))
	return null


## Where a unit that just finished its orders belongs: its slot for orders with a goal (so a pushed or distracted unit
## returns to its group), else where it stopped.
func _remember_station(unit_name: String, order: Dictionary) -> void:
	var tank := _tank(unit_name)
	var position: Array = order.get("goal", [])
	var heading: Array = order.get("facing", order.get("heading", []))
	if tank != null:
		if position.is_empty():
			position = [tank.global_position.x, tank.global_position.z]
		if heading.is_empty():
			heading = [(-tank.global_basis.z).x, (-tank.global_basis.z).z]
	if position.is_empty():
		return
	_stations[unit_name] = {"position": position, "heading": heading, "units": order["units"], "id": order["id"]}


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _tank(unit_name: String) -> Tank:
	if game_match == null or game_match.tanks == null:
		return null
	return game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank


## Dead units drop their orders (lazily, so no signal wiring per spawned tank).
func _alive(unit_name: String) -> bool:
	if not _current.has(unit_name) and not _queues.has(unit_name) and not _stations.has(unit_name):
		return true
	var tank := _tank(unit_name)
	if tank != null and tank.is_alive():
		return true
	_current.erase(unit_name)
	_queues.erase(unit_name)
	_stations.erase(unit_name)
	return false


func _tick() -> int:
	return game_match.tick if game_match != null else 0
