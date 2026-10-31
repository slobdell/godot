class_name BlastDoors
extends RefCounted
## Blast doors (mapkit P2, round 47; the lead WANTS them: "can make the game generally more interesting"): gates
## between sections of a map that open and shut on a schedule the announcer calls. THE RULES ONLY, as a pure function
## of the layout and the match seed -- no nodes, no physics -- so a replay reproduces every door, the route's planner
## can ask about any future tick (C47.8: `is_open(id, tick)`), and both sides read the same schedule (C47.9).
## The collider and the "never crush a crew" hold are the arena's (game/arena/arena_doors.gd); the look is his pick.
##
## A layout's `doors`: [{name, group, position [x, z], rotation_deg?, width?, start?, open_s?, shut_s?}]
##   group     doors in one group share ONE schedule. Point symmetry demands a door's mirror be in its group, so a
##             door never opens for one side and not the other (Arena.validate refuses a pair split across groups).
##   width     the opening along the door's local x (m), at least MIN_WIDTH (a lane's widest-hull bar, with room).
##   start     "open" (default) or "shut" at tick 0.
##   open_s / shut_s   how long each state lasts once the cycle starts (default OPEN_S / SHUT_S).
## The first change comes FIRST_MIN_S..FIRST_MAX_S into the match, drawn per group from the seed; after it the
## cycle is fixed, so a player who has seen one cycle can plan on the next.

## The warning before every change (the header light, the caller's countdown): seconds.
const WARN_S := 5.0
const OPEN_S := 40.0
const SHUT_S := 25.0
const FIRST_MIN_S := 45.0
const FIRST_MAX_S := 75.0
## arenas.md *Streets are lanes*: 12.14 m physical for the widest hull; a door is a street.
const MIN_WIDTH := 14.0
const DEFAULT_WIDTH := 14.0
## The slab: thick enough to stop a shell, above the tallest hull (6.18 m).
const DEPTH := 1.6
const HEIGHT := 7.5
const STATES := ["open", "closing", "shut", "opening"]
const EVENT_KINDS := ["warn_close", "shut", "warn_open", "open"]

## id → {name, group, center Vector2, rotation_deg, width, start_open bool, first, open_ticks, shut_ticks}
var _doors := {}
var _ids := PackedStringArray()
var seed_value := 0


## Doors of `layout` (normalized or raw; no `doors` key = none) for a match of `match_seed`.
static func from_layout(layout: Dictionary, match_seed: int) -> BlastDoors:
	var doors := BlastDoors.new()
	doors.seed_value = match_seed
	var firsts := {}
	for entry: Dictionary in layout.get("doors", []):
		var group := String(entry.get("group", entry["name"]))
		if not firsts.has(group):
			firsts[group] = _first_change(match_seed, group)
		doors._add(entry, group, int(firsts[group]))
	return doors


## The tick of a group's first change: deterministic from (seed, group), the same on every peer and every replay.
static func _first_change(match_seed: int, group: String) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("blast_doors/%d/%s" % [match_seed, group])
	return rng.randi_range(SimClock.ticks(FIRST_MIN_S), SimClock.ticks(FIRST_MAX_S))


func _add(entry: Dictionary, group: String, first: int) -> void:
	var id := String(entry["name"])
	_ids.append(id)
	_doors[id] = {
		"name": id, "group": group,
		"center": Vector2(float(entry["position"][0]), float(entry["position"][1])),
		"rotation_deg": float(entry.get("rotation_deg", 0.0)),
		"width": float(entry.get("width", DEFAULT_WIDTH)),
		"start_open": String(entry.get("start", "open")) != "shut",
		"first": first,
		"open_ticks": maxi(1, SimClock.ticks(float(entry.get("open_s", OPEN_S)))),
		"shut_ticks": maxi(1, SimClock.ticks(float(entry.get("shut_s", SHUT_S)))),
	}


func ids() -> PackedStringArray:
	return _ids


func has(id: String) -> bool:
	return _doors.has(id)


func door(id: String) -> Dictionary:
	return _doors[id]


## THE query (C47.8): is door `id` passable at `tick`? Pure; any tick, past or future.
func is_open(id: String, tick: int) -> bool:
	var d: Dictionary = _doors[id]
	var start_open: bool = d["start_open"]
	if tick < int(d["first"]):
		return start_open
	var first_len: int = d["shut_ticks"] if start_open else d["open_ticks"]
	var period: int = int(d["open_ticks"]) + int(d["shut_ticks"])
	var into := (tick - int(d["first"])) % period
	return (not start_open) if into < first_len else start_open


## The first tick AFTER `tick` at which `is_open` changes.
func next_change(id: String, tick: int) -> int:
	var d: Dictionary = _doors[id]
	var first := int(d["first"])
	if tick < first:
		return first
	var start_open: bool = d["start_open"]
	var first_len: int = d["shut_ticks"] if start_open else d["open_ticks"]
	var period: int = int(d["open_ticks"]) + int(d["shut_ticks"])
	var cycle_start := first + ((tick - first) / period) * period
	var into := tick - cycle_start
	return cycle_start + first_len if into < first_len else cycle_start + period


## "open", "closing" (open, shutting within WARN_S), "shut", "opening" (shut, opening within WARN_S).
func state(id: String, tick: int) -> String:
	var open := is_open(id, tick)
	var soon := next_change(id, tick) - tick <= SimClock.ticks(WARN_S)
	if open:
		return "closing" if soon else "open"
	return "opening" if soon else "shut"


## Every scheduled event with from_tick < tick <= to_tick, sorted by tick then door: {tick, door, group, kind}.
## kind: warn_close (WARN_S before it shuts), shut, warn_open, open.
func events_between(from_tick: int, to_tick: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var warn := SimClock.ticks(WARN_S)
	for id in _ids:
		var change := next_change(id, from_tick - warn)
		while change - warn <= to_tick:
			var opening := not is_open(id, change - 1)
			var warn_tick := change - warn
			if warn_tick > from_tick and warn_tick <= to_tick and warn_tick > 0:
				out.append({"tick": warn_tick, "door": id, "group": _doors[id]["group"], "kind": "warn_open" if opening else "warn_close"})
			if change > from_tick and change <= to_tick:
				out.append({"tick": change, "door": id, "group": _doors[id]["group"], "kind": "open" if opening else "shut"})
			change = next_change(id, change)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["tick"]) < int(b["tick"]) or (int(a["tick"]) == int(b["tick"]) and String(a["door"]) < String(b["door"])))
	return out


## The slab's footprint as the arena builds it: size (x = width, y = HEIGHT, z = DEPTH), centre and rotation.
func slab_size(id: String) -> Vector3:
	return Vector3(float(_doors[id]["width"]), HEIGHT, DEPTH)


## Is the ground point `point` within `margin` of door `id`'s slab footprint (the swept box a closing door needs)?
func in_doorway(id: String, point: Vector2, margin := 0.0) -> bool:
	var d: Dictionary = _doors[id]
	return ArenaKit.distance_to_footprint(point, d["center"], slab_size(id), float(d["rotation_deg"])) <= margin


## Arena.validate's door rules, as an error string ("" when fine): names unique, widths, start keys, and every door's
## 180-degree mirror present IN ITS GROUP (fairness: both sides meet the same schedule).
static func validate_doors(doors: Variant, tolerance: float) -> String:
	if not doors is Array:
		return "doors must be an array"
	var names := {}
	for entry: Variant in doors:
		if not entry is Dictionary or not entry.has("name") or not entry.has("position"):
			return "a door needs a name and a position"
		var name := String(entry["name"])
		if names.has(name):
			return "door %s is declared twice" % name
		names[name] = true
		if float(entry.get("width", DEFAULT_WIDTH)) < MIN_WIDTH:
			return "door %s is %.1f m wide; a door is a street and needs %.1f m" % [name, float(entry["width"]), MIN_WIDTH]
		if not String(entry.get("start", "open")) in ["open", "shut"]:
			return "door %s: start must be open or shut" % name
		for key in ["open_s", "shut_s"]:
			if entry.has(key) and float(entry[key]) <= WARN_S:
				return "door %s: %s must be longer than the %.0f s warning" % [name, key, WARN_S]
	for entry: Dictionary in doors:
		var p := Vector2(float(entry["position"][0]), float(entry["position"][1]))
		var group := String(entry.get("group", entry["name"]))
		var rot := fposmod(float(entry.get("rotation_deg", 0.0)), 180.0)  # a slab is symmetric about its own centre
		var mirrored := false
		for other: Dictionary in doors:
			var q := Vector2(float(other["position"][0]), float(other["position"][1]))
			if q.distance_to(-p) > tolerance or String(other.get("group", other["name"])) != group:
				continue
			var other_rot := fposmod(float(other.get("rotation_deg", 0.0)), 180.0)
			var diff := absf(rot - other_rot)
			if minf(diff, 180.0 - diff) <= tolerance and float(other.get("width", DEFAULT_WIDTH)) == float(entry.get("width", DEFAULT_WIDTH)):
				mirrored = true
				break
		if not mirrored:
			return "door %s has no mirror at (%.2f, %.2f) in group %s: both sides must meet the same doors" % [entry["name"], -p.x, -p.y, group]
	return ""
