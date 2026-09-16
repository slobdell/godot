class_name TacticsLab
extends RefCounted
## A deterministic laboratory for elements (doctrine X3/X4): the real arena and Match, an element of brain
## tanks under a doctrine table, an enemy laid out by hand, then N physics ticks with per-tick sampling.
## Used by the drill scenarios (`make tactics-drills`), the formation measurements (`make tactics-measure`)
## and the quick subset in `make test` (tests/test_tactics_scenarios.gd).
##
##   var lab := TacticsLab.create(case, 7)
##   var alpha := lab.element([...], "Alpha", table)
##   alpha.assign({"verb": "move", "to": [0, -60]})
##   await lab.start()
##   for tick in 60 * 20: await lab.step()
##
## Everything here is seeded and ordered by unit name: two runs of the same scenario are identical.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")

var case: TestCase
var arena: Node3D
var game_match: Match
var elements: Elements
var orders: Object
## Per element id: the drills it ran, in order, with the tick each started.
var drill_log := {}


static func create(test: TestCase, seed_value := 7, arena_name := "") -> TacticsLab:
	var lab := TacticsLab.new()
	lab.case = test
	var arena_node := ARENA.instantiate() as Node3D
	if arena_name != "":
		arena_node.set("layout_name", arena_name)
	lab.arena = test.add_to_tree(arena_node)
	lab.game_match = test.add_to_tree(MATCH.instantiate())
	lab.game_match.seed_spawns(seed_value, 0.0)
	lab.game_match.elimination = true
	lab.orders = _orders_for(lab.game_match)
	lab.elements = Elements.install(lab.game_match, lab.orders)
	lab.elements.element_changed.connect(lab._on_element_changed)
	return lab


## An autonomous vehicle with a brain (it executes K1 orders and does its own micro).
func unit(team: int, unit_name: String, position: Vector3, yaw: float, unit_id := "tank") -> Tank:
	var tank := game_match.add_brain_tank(team, "Doctrine", unit_id, [], unit_name)
	tank.global_position = position
	tank.rotation.y = yaw
	return tank


## A vehicle on standing orders: by default it sits still and shoots anything it sees (an ambush party).
func gun(team: int, unit_name: String, position: Vector3, yaw: float, unit_id := "tank") -> Tank:
	var tank := game_match.spawn_tank(unit_name, 0, team, unit_id)
	tank.global_position = position
	tank.rotation.y = yaw
	var controller := OrderController.new()
	controller.name = "Orders_" + unit_name
	controller.tank = tank
	controller.tanks_root = game_match.tanks
	game_match.brains.add_child(controller)
	controller.set_orders({"type": "stop"}, {"type": "fire_at_will"})
	return tank


## Form an element of already-spawned units under `table` (default: the standard doctrine).
func element(unit_names: Array, element_name: String, table: DoctrineTable = null) -> Element:
	return elements.form(unit_names, element_name, table if table != null else _standard())


## A doctrine table built in code: `{"formation": "line", "technique": "traveling"}` plus any overrides.
static func table_of(formation: String, technique: String, overrides: Dictionary = {}) -> DoctrineTable:
	var data := {"name": "lab", "movement": [{"when": {}, "formation": formation, "technique": technique,
			"why": "lab: %s, %s" % [formation, technique]}]}
	data.merge(overrides, true)
	var parsed := DoctrineTable.parse(data)
	if parsed.has("error"):
		push_error("lab table: %s" % parsed["error"])
	return parsed.get("table")


func start() -> void:
	for i in 12:
		await case.tree.physics_frame
		if not game_match.tanks.get_children().is_empty() and Pathing.is_ready(game_match.tanks.get_child(0)):
			break


func step() -> void:
	await case.tree.physics_frame


## Total hull + shield still standing in `unit_names`.
func strength(unit_names: Array) -> float:
	var total := 0.0
	for unit_name: Variant in unit_names:
		var tank := tank_of(String(unit_name))
		if tank != null and tank.is_alive():
			total += float(tank.health) + tank.shield
	return total


## How much of an element is still alive, 0..1 of what it started with.
func survival(unit_names: Array, started: float) -> float:
	return strength(unit_names) / maxf(started, 1.0)


func alive(unit_names: Array) -> int:
	var count := 0
	for unit_name: Variant in unit_names:
		var tank := tank_of(String(unit_name))
		if tank != null and tank.is_alive():
			count += 1
	return count


func center_of(unit_names: Array) -> Vector3:
	var center := Vector3.ZERO
	var count := 0
	for unit_name: Variant in unit_names:
		var tank := tank_of(String(unit_name))
		if tank != null and tank.is_alive():
			center += Vector3(tank.global_position.x, 0.0, tank.global_position.z)
			count += 1
	return center / float(maxi(count, 1))


## The widest distance between two living members: how strung out or bunched an element is.
func spread_of(unit_names: Array) -> float:
	var positions: Array = []
	for unit_name: Variant in unit_names:
		var tank := tank_of(String(unit_name))
		if tank != null and tank.is_alive():
			positions.append(tank.global_position)
	var widest := 0.0
	for i in positions.size():
		for j in range(i + 1, positions.size()):
			widest = maxf(widest, (positions[i] as Vector3).distance_to(positions[j]))
	return widest


## How many of `unit_names` are standing still right now (an overwatch element is "set").
func standing(unit_names: Array, threshold := 1.0) -> int:
	var count := 0
	for unit_name: Variant in unit_names:
		var tank := tank_of(String(unit_name))
		if tank != null and tank.is_alive() and tank.estimated_velocity.length() <= threshold:
			count += 1
	return count


func tank_of(unit_name: String) -> Tank:
	return game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank


## Drills this element has run, in order ("react_to_contact", "near_ambush", ...).
func drills_of(element: Element) -> PackedStringArray:
	var names: PackedStringArray = []
	for entry: Array in drill_log.get(element.id, []):
		names.append(String(entry[0]))
	return names


func ran_drill(element: Element, drill: String) -> bool:
	return drills_of(element).has(drill)


## The tick a drill first started, or -1.
func drill_tick(element: Element, drill: String) -> int:
	for entry: Array in drill_log.get(element.id, []):
		if String(entry[0]) == drill:
			return int(entry[1])
	return -1


func dispose() -> void:
	for node: Node in [game_match, arena]:
		if is_instance_valid(node):
			node.free()


func _on_element_changed(id: int) -> void:
	var element: Element = elements.get_element(id)
	if element == null or element.drill == "":
		return
	var log: Array = drill_log.get_or_add(id, [])
	if log.is_empty() or String(log[-1][0]) != element.drill:
		log.append([element.drill, game_match.tick])


func _standard() -> DoctrineTable:
	var loaded := DoctrineTable.load_table("standard")
	if loaded.has("error"):
		push_error(loaded["error"])
		return TacticsLab.table_of("wedge", "traveling")
	return loaded["table"]


static func _orders_for(game_match: Match) -> Object:
	var existing := OrderFeed.source(game_match)
	if existing != null:
		return existing
	var orders := Orders.new(game_match)
	Orders.attach(game_match, orders)
	return orders
