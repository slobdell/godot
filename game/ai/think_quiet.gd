class_name ThinkQuiet
extends RefCounted
## Round 25 (pace P1/P2, C24.7, C25.1): the SMARTER quiet. Round 24's quiet was "in reach of an enemy, but not in the
## shooting" (TankBrain._engaged() false: no shot fired, no hit taken, no round on its way for 2 s). Slowing every such
## crew to 2 Hz broke his bridge (a crew 4 s at the canal rim) and the pursuit (range opened on an 18 m/s target), and
## 3.33 Hz broke fights from cover (lesson 281). This read narrows "quiet" to a crew that is doing nothing a fast
## decision would change: why_not() names the first reason it is NOT quiet, "" when it is.
##
## Simulation state only (C24.7): the crew's own order, choice and movement, the team's shared contact table and the
## arena's terrain. Never the camera, the selection or the machine: both sides read the same rule and the match hashes
## the same everywhere.

## A NEW order (verb or target changed) or an element call waiting is a crew about to change what it does: it keeps the
## fight rate for FRESH_ORDER_TICKS after it. Not the order's issued_tick (an element's leader re-issues its members'
## orders on every re-plan, so that stamp is always fresh), and not the goal sliding with a travelling formation
## (ORDER_MOVED_M = 0: the census marked 78 % of quiet crew-ticks "fresh" with an 8 m slide; an order that changes
## already wakes the crew at once through order_changed).
const FRESH_ORDER_TICKS := SimClock.TICK_RATE * 2
const ORDER_MOVED_M := 0.0
## Which fresh-order guard why_not applies: "order", "intent" or "" (none, the pre-registered rule: the census found
## 92 % of the order changes quiet crews see are element focus retargets, every one already waking the crew for an
## immediate think; either guard kept under 40 % of the quiet crew-ticks quiet). `--quiet-guard=` on any run.
static var ORDER_GUARD := _flag_text("--quiet-guard=", "")


static func _flag_text(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return fallback
## Fighting from cover is a timing game (peek on the enemy's reload, back in after the shot): the options that are
## in it, or going for it, keep the fight rate.
const COVER_OPTIONS := ["COVER_FIRE", "TAKE_COVER"]
## The crew's own target (its order's, else its choice's) opening the range at this speed or more (m/s, flat, relative):
## a chase (round 24's 2 Hz opened 6.9 m on an 18 m/s runner). Not a contact merely closing: in the opening clash both
## armies close at 10-20 m/s, so "closing fast" marked 97 % of the quiet crew-ticks (pace census, foundry, headless),
## and round 24's quiet 2 Hz passed all 44 fight scenarios, the closing fights among them.
const FAST_MS := 3.0
## Arm S2 (2026-10-10, after S failed the cover-by-a-wall line at every timing: the tank fighting from behind the
## wall holds ENGAGE between shots, read quiet 2 s after its shot, and stopped ducking back): a crew a known enemy gun
## is laid on (its turret within ~20 degrees of this crew, TankBrain.COS_WATCHING, and this crew inside its reach + 5 m)
## is in a timing fight whether it fired lately or not. `--quiet-watched=1`; off = arm S.
static var WATCHED := _flag_text("--quiet-watched=", "0") == "1"
## Within this many metres of water, a pit or a bridge deck (the arena's carved terrain), a crew keeps the fight rate:
## the bridge's rim and mouth is where a late steering decision puts a crew in the river or against a rail.
const WATER_M := 20.0

## Per-arena cache of the carved terrain's rectangles grown by WATER_M ([] for a dry map: one lookup, nothing else).
static var _wet_boxes: Array = []
static var _wet_for: Dictionary = {}
## Per brain (instance id): [verb, target, goal, tick the order last changed]. Reset with the match.
static var _orders: Dictionary = {}
static var _orders_match := 0


## "" when this crew is quiet by the smarter rule, else the first reason it is not: "order", "cover", "giveway",
## "fast", "water". Asked only of a crew round 24's rule already calls quiet (in reach, not in the shooting).
static func why_not(brain: TankBrain) -> String:
	var reasons := reasons_for(brain, true)
	return "" if reasons.is_empty() else reasons[0]


## Every reason this crew is not quiet, in why_not's order (`first_only`: stop at the first). The census reads them
## all, so the share a rule costs on its own can be read off one run.
static func reasons_for(brain: TankBrain, first_only := false) -> PackedStringArray:
	var out := PackedStringArray()
	var game_match := brain.game_match
	if first_only and ORDER_GUARD == "":
		return _rest(brain, out, true)
	var dirty := brain._order_dirty or brain._element_dirty
	var record := _order_record(brain)
	# Two guards, both read so the census can price each (ORDER_GUARD picks the one the rule uses): "order" = the
	# verb or target changed (an element's move/attack-move flip counts), "intent" = a new target or destination.
	var by_task := dirty or game_match.tick - int(record[3]) < FRESH_ORDER_TICKS
	var by_intent := dirty or game_match.tick - int(record[4]) < FRESH_ORDER_TICKS
	if first_only:
		if (by_task if ORDER_GUARD == "order" else by_intent if ORDER_GUARD == "intent" else false):
			out.append(ORDER_GUARD)
			return out
	else:
		if by_task:
			out.append("order")
		if by_intent:
			out.append("intent")
	return _rest(brain, out, first_only)


## The reasons after the order guards (cover, give-way, a running target, water), appended to `out`.
static func _rest(brain: TankBrain, out: PackedStringArray, first_only: bool) -> PackedStringArray:
	if COVER_OPTIONS.has(String(brain.choice.get("option", ""))):
		out.append("cover")
		if first_only:
			return out
	var movement := brain.movement
	if movement != null and (movement.yield_to != "" or movement._give_way_left > 0):
		out.append("giveway")
		if first_only:
			return out
	var tank := brain.tank
	var me := tank.global_position
	if _target_running(brain, me):
		out.append("fast")
		if first_only:
			return out
	if (WATCHED or not first_only) and _watched(brain, me):
		out.append("watched")
		if first_only:
			return out
	if near_water(me):
		out.append("water")
	return out


## The tick this brain's order last CHANGED (verb or target; ORDER_MOVED_M > 0 adds the goal moving that far);
## an order seen for the first time has no known change (the read starts mid-match). -1 << 30 when none was seen.
static func order_changed_tick(brain: TankBrain) -> int:
	return _order_record(brain)[3]


## The tick this brain's order INTENT last changed: a new target, an order given or cleared, or the destination moved
## more than INTENT_MOVED_M from where it was at the last intent change. Not an element flipping its crews between
## move and attack-move on the same leg, and not a slot sliding a few metres with a travelling formation.
static func intent_changed_tick(brain: TankBrain) -> int:
	return _order_record(brain)[4]


const INTENT_MOVED_M := 25.0
## Census only (`census_changes`): order changes by kind, read by tests/pace/census.py.
static var census_changes := false


## [verb, target, goal at the last intent change, task change tick, intent change tick], updated on every read.
static func _order_record(brain: TankBrain) -> Array:
	var game_match := brain.game_match
	if _orders_match != game_match.get_instance_id():
		_orders_match = game_match.get_instance_id()
		_orders = {}
	var order := brain.order
	var verb := String(order.get("verb", ""))
	var target := String(order.get("target", ""))
	var goal: Variant = order.get("goal")
	var id := brain.get_instance_id()
	var last: Array = _orders.get(id, [])
	if last.is_empty():
		last = [verb, target, goal, -(1 << 30), -(1 << 30)]
		_orders[id] = last
		return last
	var drift := 0.0
	if goal is Vector3 and last[2] is Vector3:
		drift = (goal as Vector3).distance_to(last[2])
	var task: bool = verb != last[0] or target != last[1] or (ORDER_MOVED_M > 0.0 and drift > ORDER_MOVED_M)
	var intent: bool = target != last[1] or (verb == "") != (String(last[0]) == "") or drift > INTENT_MOVED_M \
			or (goal is Vector3) != (last[2] is Vector3)
	if task and census_changes:
		var kind := "target" if target != last[1] else ("goal" if intent else "flip")
		TankBrain.lod_ticks["ochg." + kind] = int(TankBrain.lod_ticks.get("ochg." + kind, 0)) + 1
	if task:
		last[0] = verb
		last[1] = target
		last[3] = game_match.tick
	if intent:
		last[2] = goal
		last[4] = game_match.tick
	return last


## Whether `point` is within WATER_M of water, a pit or a bridge deck on the live arena.
static func near_water(point: Vector3, data: Dictionary = Arena.active) -> bool:
	if not is_same(_wet_for, data):
		_wet_for = data
		_wet_boxes = _boxes(data)
	for box: PackedFloat32Array in _wet_boxes:
		if point.x > box[0] and point.x < box[2] and point.z > box[1] and point.z < box[3]:
			return true
	return false


static func _boxes(data: Dictionary) -> Array:
	var out: Array = []
	for entry: Dictionary in data.get("terrain", []):
		var kind := String(entry["kind"])
		if not ArenaTerrain.carves(kind) and not ArenaTerrain.is_deck(kind):
			continue
		var box := ArenaTerrain.bounds(entry)
		out.append(PackedFloat32Array([box[0] - WATER_M, box[1] - WATER_M, box[2] + WATER_M, box[3] + WATER_M]))
	return out


## Whether this crew's target (its order's, else its choice's) is known and opening the range at FAST_MS or more.
static func _target_running(brain: TankBrain, me: Vector3) -> bool:
	var target := String(brain.order.get("target", ""))
	if target == "":
		target = String(brain.choice.get("target", ""))
	if target == "":
		return false
	var known: Variant = AiTickCache.contact_prototypes(brain.game_match, brain.tank.team).get(target)
	if known == null:
		return false
	var offset: Vector3 = known["position"] - me
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.1:
		return false
	var relative: Vector3 = known["velocity"] - brain.tank.estimated_velocity
	return (relative.x * offset.x + relative.z * offset.z) / distance >= FAST_MS


## Whether a known enemy gun is laid on this crew: its turret within COS_WATCHING of the line to it, and it inside that
## gun's reach + 5 m (TankBrain's watching_me, read from the team's contact table).
static func _watched(brain: TankBrain, me: Vector3) -> bool:
	for known: Dictionary in AiTickCache.contact_prototypes(brain.game_match, brain.tank.team).values():
		var offset: Vector3 = me - known["position"]
		offset.y = 0.0
		if offset.length() > float(known["weapon_range"]) + 5.0:
			continue
		if TankBrain.points_at(known["turret_forward"], offset, TankBrain.COS_WATCHING):
			return true
	return false
