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

## A fresh order (or an element call) is a crew about to move: it keeps the fight rate this long after the order.
const FRESH_ORDER_TICKS := SimClock.TICK_RATE * 2
## Fighting from cover is a timing game (peek on the enemy's reload, back in after the shot): the options that are
## in it, or going for it, keep the fight rate.
const COVER_OPTIONS := ["COVER_FIRE", "TAKE_COVER"]
## A contact this fast (m/s, flat) within LOD_RADIUS makes the crew a chaser or the chased: it keeps the fight rate.
const FAST_MS := 8.0
## Within this many metres of water, a pit or a bridge deck (the arena's carved terrain), a crew keeps the fight rate:
## the bridge's rim and mouth is where a late steering decision puts a crew in the river or against a rail.
const WATER_M := 20.0

## Per-arena cache of the carved terrain's rectangles grown by WATER_M ([] for a dry map: one lookup, nothing else).
static var _wet_boxes: Array = []
static var _wet_for: Dictionary = {}


## "" when this crew is quiet by the smarter rule, else the first reason it is not: "order", "cover", "giveway",
## "fast", "water". Asked only of a crew round 24's rule already calls quiet (in reach, not in the shooting).
static func why_not(brain: TankBrain) -> String:
	var game_match := brain.game_match
	if brain._order_dirty or brain._element_dirty:
		return "order"
	if not brain.order.is_empty() and game_match.tick - int(brain.order.get("issued_tick", -FRESH_ORDER_TICKS)) < FRESH_ORDER_TICKS:
		return "order"
	if COVER_OPTIONS.has(String(brain.choice.get("option", ""))):
		return "cover"
	var movement := brain.movement
	if movement != null and (movement.yield_to != "" or movement._give_way_left > 0):
		return "giveway"
	var tank := brain.tank
	var me := tank.global_position
	for known: Dictionary in AiTickCache.contact_prototypes(game_match, tank.team).values():
		var velocity: Vector3 = known["velocity"]
		if Vector2(velocity.x, velocity.z).length() >= FAST_MS \
				and me.distance_to(known["position"]) <= TankBrain.LOD_RADIUS:
			return "fast"
	if near_water(me):
		return "water"
	return ""


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
