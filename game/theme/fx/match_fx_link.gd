class_name MatchFxLink
extends Node
## Connects the running Match's events to the effects. Visual only: it listens, never calls into the rules.
##
## **Live (K2, combat's CP2):** on the simulating peer, `Match.weapon_fired` and `Match.projectile_impact` go straight to
## WeaponFx, `Match.unit_destroyed` blows up the dead (with its wreck's place, facing, and size), and the old Impact path
## goes quiet so hits never draw twice. A match without `unit_destroyed` falls back to each vehicle's `died` signal.
## **Not simulating** (a networked client, where the rules don't run and no events arrive): the link attaches for
## lookups only and FxWorld keeps the legacy effects (a muzzle flash on each new tracer, Impact's explosion).

const SEARCH_EVERY := 0.5

## True when the attached match is simulating and emits K2 events.
var live := false
var weapons: WeaponFx

var _match: Node
var _search_left := 0.0


func _init(weapon_fx: WeaponFx = null) -> void:
	name = "MatchFxLink"
	weapons = weapon_fx


func _process(delta: float) -> void:
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


## The match effects follow, or null.
func attached_match() -> Node:
	return _match if is_attached() else null


func is_attached() -> bool:
	return _match != null and is_instance_valid(_match) and not _match.is_queued_for_deletion()


## Follow `game_match`'s events (the FX bench and tests attach explicitly; games are found automatically).
func attach(game_match: Node) -> void:
	detach()
	_match = game_match
	live = game_match.has_signal("weapon_fired") and game_match.has_signal("projectile_impact") and _simulating()
	if live:
		game_match.connect("weapon_fired", _on_weapon_fired)
		game_match.connect("projectile_impact", _on_projectile_impact)
		if game_match.has_signal("unit_destroyed"):
			game_match.connect("unit_destroyed", _on_unit_destroyed)
		else:
			var tanks := _tanks_root()
			if tanks != null:
				tanks.child_entered_tree.connect(_on_tank_added)
				for tank in tanks.get_children():
					_on_tank_added(tank)
	if game_match.has_signal("finished"):
		game_match.connect("finished", _on_finished)
	weapons.resolver = find_unit
	weapons.units = unit_nodes


func detach() -> void:
	if is_attached():
		for connection in get_incoming_connections():
			var source: Object = connection["signal"].get_object()
			if is_instance_valid(source):
				source.disconnect(connection["signal"].get_name(), connection["callable"])
	_match = null
	live = false


## A vehicle by name in the attached match, or null.
func find_unit(unit_name: String) -> Node:
	var tanks := _tanks_root()
	return tanks.get_node_or_null(NodePath(unit_name)) if tanks != null and unit_name != "" else null


## Every vehicle node in the attached match (alive or not).
func unit_nodes() -> Array:
	var tanks := _tanks_root()
	return tanks.get_children() if tanks != null else []


func _on_weapon_fired(event: Dictionary) -> void:
	weapons.fired(event)


func _on_projectile_impact(event: Dictionary) -> void:
	weapons.impact(event)


func _on_unit_destroyed(event: Dictionary) -> void:
	weapons.destroyed(event)


func _on_tank_added(node: Node) -> void:
	if node.has_signal("died") and not node.is_connected("died", _on_tank_died):
		node.connect("died", _on_tank_died.bind(node))


func _on_tank_died(tank: Node) -> void:
	if tank is Node3D:
		weapons.unit_destroyed(tank)


func _on_finished(result: Dictionary) -> void:
	var fx := get_parent() as FxWorld
	if fx != null:
		fx.kill_cam.on_finished(result, _match)


func _simulating() -> bool:
	var simulate: Variant = _match.get("simulate")
	return simulate == null or bool(simulate)


func _tanks_root() -> Node:
	if not is_attached():
		return null
	return _match.get("tanks") as Node if _match.get("tanks") is Node else _match.get_node_or_null("Tanks")
