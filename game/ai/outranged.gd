class_name Outranged
extends RefCounted
## E10 (R47.48, engage): a crew taking fire from beyond its own reach. One memory per match of which rounds struck which
## crew and where each was fired from: what a crew in the field reads from the rounds themselves (where they come from),
## never a fog cheat on the shooter's identity or health. Fed by the match's own weapon_fired / projectile_impact events,
## in their order, so it is deterministic. `--outranged=off` is the escape (R47.51: ON after Bar E10; D1 and every guard passed,
## D2's reverse half did not, round 48); the memory is built only when the switch is on.

const OUTRANGED_DEFAULT := true
static var ON := _flag()

## A crew counts as outranged after this many damaging hits inside WINDOW_S, each fired from beyond its own weapon's
## range plus MARGIN_M (or by a shooter it cannot see: the same answer for a crew that cannot shoot back).
const HITS := 2
const WINDOW_S := 4.0
const MARGIN_M := 5.0
const HEAVY := 0.15
## Rounds in the air are remembered this long (the slowest round's flight), then forgotten.
const FLIGHT_MEMORY_TICKS := 30 * 10

## projectile id -> {"shooter", "team", "from": Vector3, "tick"}
var _fired := {}
## crew name -> Array of {"tick", "from": Vector3, "shooter", "damage"}, oldest first
var _hits := {}


static func _flag() -> bool:
	for arg in OS.get_cmdline_user_args():
		if String(arg) == "--outranged=on":
			return true
		if String(arg) == "--outranged=off":
			return false
	return OUTRANGED_DEFAULT


## The match's memory (made and connected on first use), or null without a match.
static func of(game_match: Node) -> Outranged:
	if game_match == null:
		return null
	if game_match.has_meta("outranged"):
		return game_match.get_meta("outranged") as Outranged
	var memory := Outranged.new()
	game_match.set_meta("outranged", memory)
	if game_match.has_signal("weapon_fired"):
		game_match.connect("weapon_fired", memory._on_fired)
		game_match.connect("projectile_impact", memory._on_impact)
	return memory


func _on_fired(event: Dictionary) -> void:
	var muzzle: Array = event.get("muzzle", [0.0, 0.0, 0.0])
	note_fired(int(event.get("projectile_id", -1)), String(event.get("shooter", "")),
			Vector3(float(muzzle[0]), float(muzzle[1]), float(muzzle[2])), int(event.get("tick", 0)))


func _on_impact(event: Dictionary) -> void:
	var victims: Array = event.get("victims", [])
	if victims.is_empty() and event.has("target"):
		victims = [{"target": event["target"], "damage": event.get("damage", 0.0)}]
	for victim: Dictionary in victims:
		note_hit(int(event.get("projectile_id", -1)), String(victim.get("target", "")), float(victim.get("damage", 0.0)),
				int(event.get("tick", 0)))


## A round left `shooter`'s gun at `from`.
func note_fired(projectile_id: int, shooter: String, from: Vector3, tick: int) -> void:
	if projectile_id < 0:
		return
	_fired[projectile_id] = {"shooter": shooter, "from": from, "tick": tick}
	# Forget rounds long since landed (ids rise with time; erase while iterating a copy of the keys).
	for id: int in _fired.keys():
		if tick - int(_fired[id]["tick"]) > FLIGHT_MEMORY_TICKS:
			_fired.erase(id)
		else:
			break


## A round struck `victim` for `damage`.
func note_hit(projectile_id: int, victim: String, damage: float, tick: int) -> void:
	if damage <= 0.0 or victim == "" or not _fired.has(projectile_id):
		return
	var fired: Dictionary = _fired[projectile_id]
	if String(fired["shooter"]) == victim:
		return
	var list: Array = _hits.get(victim, [])
	list.append({"tick": tick, "from": fired["from"], "shooter": fired["shooter"], "damage": damage})
	var window := int(WINDOW_S * 30.0)
	while not list.is_empty() and tick - int(list[0]["tick"]) > window:
		list.pop_front()
	_hits[victim] = list


## Whether `crew` (at `position`, its weapon reaching `reach` m) is being shot from beyond its reach now, and from where:
## {} when not, else {"from": the latest such shot's muzzle, "shooter", "hits", "damage", "distance"}. `seen` names the
## shooters it can see (a hidden shooter counts as out of reach: the crew has nothing to answer). With `max_health`, one
## hit that took HEAVY of it is enough (a railgun's round: the second may be the last).
func read(crew: String, position: Vector3, reach: float, tick: int, seen: Dictionary = {}, max_health := 0.0) -> Dictionary:
	var list: Array = _hits.get(crew, [])
	var window := int(WINDOW_S * 30.0)
	var count := 0
	var damage := 0.0
	var latest: Dictionary = {}
	for hit: Dictionary in list:
		if tick - int(hit["tick"]) > window:
			continue
		var from: Vector3 = hit["from"]
		var distance := Vector2(from.x - position.x, from.z - position.z).length()
		if distance <= reach + MARGIN_M and seen.has(String(hit["shooter"])):
			continue
		count += 1
		damage += float(hit["damage"])
		latest = hit
	if count < HITS and not (count > 0 and max_health > 0.0 and damage >= HEAVY * max_health):
		return {}
	var from: Vector3 = latest["from"]
	return {"from": from, "shooter": latest["shooter"], "hits": count, "damage": damage,
			"distance": Vector2(from.x - position.x, from.z - position.z).length()}
