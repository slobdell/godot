class_name MatchFxLink
extends Node
## Connects the running Match's weapon events to the effect families (WeaponFx). Visual only: it listens, never calls
## into the rules.
##
## **Live (K2, after combat's CP2):** the match has `weapon_fired(event)` and `projectile_impact(event)`; both go
## straight to WeaponFx, and the old Impact path goes quiet so hits never draw twice.
## **Stub (today's match):** every Tank's `fired(muzzle, direction)` becomes a K2-shaped weapon_fired event, and each
## Impact (Match.show_impact) becomes a projectile_impact attributed to the recent shot whose line passes closest to
## it, with the nearest vehicle as its target. Same shapes, so the effects are written once against the contract.
## Only a simulating match emits Tank.fired; on a networked client the link stays detached and FxWorld keeps the
## legacy tracer-muzzle and Impact effects.

## A stub impact belongs to a recent shot whose line passes within this many meters of it.
const ATTRIBUTION_RADIUS := 3.5
## Stub shots are remembered this long (seconds) for impact attribution: longer than any round's flight.
const RECENT_SHOT_SECONDS := 5.0
const RECENT_SHOTS := 64
## A stub impact's target is the vehicle whose center is within this flat distance.
const TARGET_RADIUS := 3.2
const SEARCH_EVERY := 0.5

## True when the match emits real K2 events.
var live := false
var weapons: WeaponFx

var _match: Node
var _clock := 0.0
var _search_left := 0.0
var _next_stub_id := 1_000_000
## Stub: [{id, model, muzzle, direction, range, time}], oldest first.
var _recent: Array[Dictionary] = []


func _init(weapon_fx: WeaponFx = null) -> void:
	name = "MatchFxLink"
	weapons = weapon_fx


func _process(delta: float) -> void:
	_clock += delta
	if is_attached():
		return
	_search_left -= delta
	if _search_left > 0.0:
		return
	_search_left = SEARCH_EVERY
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return
	var found: Node = scene if scene is Match else scene.get_node_or_null("Match")
	if found != null:
		attach(found)


## True while effects come from a match (live or stubbed).
func is_attached() -> bool:
	return _match != null and is_instance_valid(_match) and not _match.is_queued_for_deletion()


## Follow `game_match`'s weapon events (the FX bench and tests attach explicitly; games are found automatically).
func attach(game_match: Node) -> void:
	detach()
	_match = game_match
	live = game_match.has_signal("weapon_fired") and game_match.has_signal("projectile_impact")
	if live:
		game_match.connect("weapon_fired", _on_weapon_fired)
		game_match.connect("projectile_impact", _on_projectile_impact)
	elif _simulating():
		var tanks := _tanks_root()
		if tanks != null:
			tanks.child_entered_tree.connect(_on_tank_added)
			for tank in tanks.get_children():
				_on_tank_added(tank)
	weapons.resolver = find_unit
	weapons.units = unit_nodes
	# In the stub, the fx.tracer slot knows where each hitscan round ended and draws it; live K2 draws from events.
	weapons.draw_hitscan = live


func detach() -> void:
	if is_attached():
		for connection in get_incoming_connections():
			var source: Object = connection["signal"].get_object()
			if is_instance_valid(source):
				source.disconnect(connection["signal"].get_name(), connection["callable"])
	_match = null
	live = false
	_recent.clear()
	if weapons != null:
		weapons.draw_hitscan = true


## Whether stubbed weapon events are flowing (so FxWorld skips its legacy muzzle flash on new tracers).
func drives_muzzles() -> bool:
	return is_attached() and (live or _simulating())


## A vehicle by name in the attached match, or null.
func find_unit(unit_name: String) -> Node:
	var tanks := _tanks_root()
	return tanks.get_node_or_null(NodePath(unit_name)) if tanks != null and unit_name != "" else null


## Every vehicle node in the attached match (alive or not).
func unit_nodes() -> Array:
	var tanks := _tanks_root()
	return tanks.get_children() if tanks != null else []


## Impact (Match.show_impact) reports a hit. Returns true if the link handled it (stub) or deliberately ignored it
## (live K2 impacts draw instead); false means nobody drives effects, so the caller draws the legacy explosion.
func stub_impact(position: Vector3, big: bool) -> bool:
	if live:
		return true
	if not drives_muzzles():
		return false
	var shot := _attribute(position)
	var direction: Vector3 = shot["direction"] if not shot.is_empty() else Vector3.DOWN
	var event := K2Events.impact_event(_tick(), int(shot.get("id", -1)), position, -direction,
			_nearest_unit(position), big)
	if not shot.is_empty():
		event["fire_model"] = shot["model"]
		if shot["model"] != "arc":
			_recent.erase(shot)
	weapons.impact(event)
	return true


## The fx.tracer slot reports a round-2 hitscan round from `from` to `to`. Returns false when no match drives effects.
func stub_hitscan(from: Vector3, to: Vector3) -> bool:
	if live or not drives_muzzles():
		return false
	var shooter := _nearest_unit(from, 4.0)
	var unit := find_unit(shooter)
	var weapon: Dictionary = unit.get("weapon") if unit != null and unit.get("weapon") is Dictionary else {}
	var reach := float(weapon.get("range", 45.0))
	var target := _nearest_unit(to, TARGET_RADIUS, shooter)
	weapons.hitscan(from, to, shooter, target, target == "" and from.distance_to(to) < reach - 0.5)
	return true


func _on_weapon_fired(event: Dictionary) -> void:
	weapons.fired(event)


func _on_projectile_impact(event: Dictionary) -> void:
	weapons.impact(event)


func _on_tank_added(node: Node) -> void:
	if node.has_signal("fired") and not node.is_connected("fired", _on_tank_fired):
		node.connect("fired", _on_tank_fired.bind(node))


func _on_tank_fired(muzzle: Vector3, direction: Vector3, tank: Node) -> void:
	var weapon: Dictionary = tank.get("weapon") if tank.get("weapon") is Dictionary else {}
	var event := K2Events.fired_event(_tick(), String(tank.name), String(tank.get("weapon_id")), weapon,
			muzzle, direction, _next_stub_id)
	if event["fire_model"] == "":
		return
	_recent.append({"id": _next_stub_id, "model": event["fire_model"], "muzzle": muzzle, "direction": direction,
			"range": float(weapon.get("range", 80.0)), "time": _clock})
	_next_stub_id += 1
	while _recent.size() > RECENT_SHOTS or (not _recent.is_empty() and _clock - float(_recent[0]["time"]) > RECENT_SHOT_SECONDS):
		_recent.pop_front()
	weapons.fired(event)


## The recent shot whose (flat) line passes closest to `position`, within ATTRIBUTION_RADIUS and its range; newest wins ties.
func _attribute(position: Vector3) -> Dictionary:
	var best := {}
	var best_distance := ATTRIBUTION_RADIUS
	for i in range(_recent.size() - 1, -1, -1):
		var shot: Dictionary = _recent[i]
		var muzzle: Vector3 = shot["muzzle"]
		var flat_direction := Vector2((shot["direction"] as Vector3).x, (shot["direction"] as Vector3).z)
		if flat_direction.length() < 0.01:
			continue
		flat_direction = flat_direction.normalized()
		var offset := Vector2(position.x - muzzle.x, position.z - muzzle.z)
		var along := offset.dot(flat_direction)
		if along < -1.0 or along > float(shot["range"]) + 10.0:
			continue
		var across := absf(offset.cross(flat_direction))
		if shot["model"] == "arc":
			across = 0.0 if along > 0.0 else ATTRIBUTION_RADIUS  # lobbed rounds scatter along their line
		if across < best_distance:
			best_distance = across
			best = shot
	return best


func _nearest_unit(position: Vector3, radius := TARGET_RADIUS, exclude := "") -> String:
	var tanks := _tanks_root()
	if tanks == null:
		return ""
	var best := ""
	var best_distance := radius
	for node in tanks.get_children():
		var unit := node as Node3D
		if unit == null or String(unit.name) == exclude:
			continue
		var distance := Vector2(unit.global_position.x - position.x, unit.global_position.z - position.z).length()
		if distance < best_distance:
			best_distance = distance
			best = String(unit.name)
	return best


func _simulating() -> bool:
	var simulate: Variant = _match.get("simulate")
	return simulate == null or bool(simulate)


func _tick() -> int:
	var tick: Variant = _match.get("tick")
	return int(tick) if tick != null else 0


func _tanks_root() -> Node:
	if not is_attached():
		return null
	return _match.get("tanks") as Node if _match.get("tanks") is Node else _match.get_node_or_null("Tanks")
