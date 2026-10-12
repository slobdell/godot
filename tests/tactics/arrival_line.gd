class_name ArrivalLine
extends RefCounted
## Round 27 (brains B1, C27.5, lesson 293): THE ARRIVE LINE COUNTS EVERY CREW. An element's own "arrived" (and every
## series that read it) was true on round 26's Sumps cell with a crew 19-26 m off its slot: the element's flow had
## finished, its crews had not. This line is the measuring one: the squad has arrived when EVERY LIVING CREW is within
## its radius of its OWN slot, held for HOLD_S. A crew's radius is the order's arrive radius (TankBrain.ORDER_ARRIVE,
## 3.5 m) or its hull's settle radius (Movement.settle_radius: a car cannot settle tighter), whichever is larger.
## The element's own `arrived` is left as it is (the leader's flow reads it); only the measurement changes.
##
##   var line := ArrivalLine.new()
##   each tick: line.sample(now_tick, [{"name", "unit", "position", "slot"}, ...])   (living crews only)
##   line.arrived_tick   -1 until the line holds; then the tick its HOLD_S window started

const HOLD_S := 1.0

var arrived_tick := -1
## The tick the current unbroken "every crew in" window started (-1: not in).
var _since := -1
## The worst crew of the latest sample: {"name", "off_m", "radius_m"} (for the report: who kept the squad out).
var worst := {}


## The radius a crew of `unit_id` counts as on its slot within.
static func radius_of(unit_id: String) -> float:
	return maxf(TankBrain.ORDER_ARRIVE, Movement.settle_radius(unit_id))


## Whether every crew in `crews` ({"unit", "position", "slot"}) is within its radius of its own slot. A crew with no
## slot is not on it. Empty = false (a squad with nobody left has not arrived anywhere). Pure.
static func all_in(crews: Array) -> bool:
	if crews.is_empty():
		return false
	for crew: Dictionary in crews:
		if not _in(crew):
			return false
	return true


static func _in(crew: Dictionary) -> bool:
	var slot: Variant = crew.get("slot")
	if not (slot is Vector3):
		return false
	return _off(crew) <= radius_of(String(crew.get("unit", "")))


static func _off(crew: Dictionary) -> float:
	var at: Vector3 = crew["position"]
	var slot: Vector3 = crew["slot"]
	return Vector2(at.x - slot.x, at.z - slot.z).length()


## Feed one tick. Returns true once the line has held (and stays true: an arrival is the first time it held).
func sample(tick: int, crews: Array) -> bool:
	worst = {}
	for crew: Dictionary in crews:
		var off := _off(crew) if crew.get("slot") is Vector3 else INF
		if worst.is_empty() or off > float(worst["off_m"]):
			worst = {"name": String(crew.get("name", "")), "off_m": off, "radius_m": radius_of(String(crew.get("unit", "")))}
	if arrived_tick >= 0:
		return true
	if all_in(crews):
		if _since < 0:
			_since = tick
		if tick - _since >= int(HOLD_S * SimClock.TICK_RATE):
			arrived_tick = _since
			return true
	else:
		_since = -1
	return false
