class_name AiScenario
extends RefCounted
## A deterministic mini-battle for behavior scenarios (_agents/unit_ai.md "Testing"): the real arena and
## Match, brain tanks and scripted tanks placed by hand, then N physics ticks with a per-tick sampler.
##
##   var s := AiScenario.create(self)            # self: the TestCase (adds nodes it frees afterwards)
##   var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-20, 0, -12), 0.0)
##   var gun := s.shooter(Match.Team.RUST, "Rust_Gun_1", Vector3(-40, 0, -65), PI)
##   await s.start()
##   for tick in SimClock.TICK_RATE * 10:
##       await s.step()
##       ...sample...
##
## Scenarios live in tests/ai_scenarios/scenario_*.gd (`make ai-scenarios`, faster than real time); a quick
## subset runs in `make test` through tests/test_ai_scenarios.gd.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")

var case: TestCase
var arena: Node3D
var game_match: Match
## Tank name -> ticks at which it fired, in order.
var shots := {}


static func create(test: TestCase, seed_value := 1) -> AiScenario:
	var scenario := AiScenario.new()
	scenario.case = test
	scenario.arena = test.add_to_tree(ARENA.instantiate())
	scenario.game_match = test.add_to_tree(MATCH.instantiate())
	scenario.game_match.seed_spawns(seed_value, 0.0)
	scenario.game_match.elimination = true  # destroyed stays destroyed: no respawn timers mid-scenario
	return scenario


## An autonomous brain tank, placed at `position` facing `yaw` (0 = north, −Z).
func brain_tank(team: int, tank_name: String, position: Vector3, yaw: float, directive := {},
		unit := "tank", weapon := "", squad := "Solo") -> Tank:
	var tank := game_match.add_brain_tank(team, squad, unit_for(unit, weapon), [directive], tank_name)
	_place(tank, position, yaw)
	return tank


## A tank on standing orders (OrderController): by default it stays put and shoots anything it sees.
func shooter(team: int, tank_name: String, position: Vector3, yaw: float, move := {"type": "stop"},
		weapon_order := {"type": "fire_at_will"}, unit := "tank", weapon := "") -> Tank:
	var tank := game_match.spawn_tank(tank_name, 0, team, unit_for(unit, weapon))
	_place(tank, position, yaw)
	var controller := OrderController.new()
	controller.name = "Orders_" + tank_name
	controller.tank = tank
	controller.tanks_root = game_match.tanks
	game_match.brains.add_child(controller)
	controller.set_orders(move, weapon_order)
	return tank


## A tank that never moves or shoots (a target).
func dummy(team: int, tank_name: String, position: Vector3, yaw: float, unit := "tank") -> Tank:
	return shooter(team, tank_name, position, yaw, {"type": "stop"}, {"type": "hold_fire"}, unit)


## Catalog v2 (rules R1): a unit type carries one fixed weapon. `weapon` (optional) picks the unit type that fires it,
## preferring `unit` when that unit's weapon matches.
static func unit_for(unit: String, weapon: String) -> String:
	if weapon == "" or String(Units.PROFILES.get(unit, {}).get("weapon", "")) == weapon:
		return unit
	for id: String in Units.PROFILES:
		if String(Units.PROFILES[id].get("weapon", "")) == weapon:
			return id
	push_error("no unit type fires %s" % weapon)
	return unit


## Can't be destroyed during the scenario (still takes hits, so its shield breaks and it counts damage).
static func make_durable(tank: Tank) -> void:
	tank.max_health = 1_000_000
	tank.health = 1_000_000


## Put brain tanks into one runtime Squad so squad orders (Match.command_squad) reach them.
func form_squad(team: int, squad_name: String, members: Array) -> Squad:
	var roster: PackedStringArray = []
	for tank: Tank in members:
		roster.append(String(tank.name))
	var squad := Squad.new(squad_name, team, roster)
	game_match.squads[Match._squad_key(team, squad_name)] = squad
	return squad


## K1 orders for this match's brains (OrderFeed): the match's own, else control's `Orders` (after CP1), else a
## StubOrders with the contract's shape. Issue with `orders().issue({"units": [name], "verb": "move", "to": [x, z]})`.
func orders() -> Object:
	var existing := OrderFeed.source(game_match)
	if existing != null:
		return existing
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry["class"] == "Orders":
			var script: GDScript = load(entry["path"])
			var real: Object = script.new(game_match)
			OrderFeed.attach(game_match, real)
			return real
	var stub := StubOrders.new(game_match)
	OrderFeed.attach(game_match, stub)
	return stub


## L1 elements for this match's brains, staged by hand: a StubElements the scenario drives itself
## (`elements().form([name, ...], "Alpha")`, then `bound()` / `support_by_fire()` / `halt()`). These scenarios test how
## a brain EXECUTES a leader's call, so the call is staged rather than decided — doctrine owns who decides.
## `real_elements()` is the other half: the same reading against doctrine's own `Elements`.
func elements() -> StubElements:
	var existing := ElementFeed.source(game_match)
	if existing is StubElements:
		return existing
	var stub := StubElements.new(game_match, orders())
	ElementFeed.attach(game_match, stub)
	return stub


## Doctrine's real `Elements` (CP1), installed on this match and wired to its K1 Orders: for checking that ElementFeed
## reads what doctrine actually publishes.
func real_elements() -> Elements:
	return Elements.install(game_match, orders())


func brain_of(tank: Tank) -> TankBrain:
	return game_match.brains.get_node_or_null("Brain_" + tank.name) as TankBrain


func controller_of(tank: Tank) -> OrderController:
	var brain := brain_of(tank)
	if brain != null:
		return brain
	return game_match.brains.get_node_or_null("Orders_" + tank.name) as OrderController


## Wait for the navigation mesh (a few ticks) so brains path around obstacles from the start. Then drive
## the battle tick by tick: `for tick in SimClock.TICK_RATE * 10: await s.step()` and sample state in the loop body.
## (Loops, not callbacks: GDScript lambdas capture local variables by value, so a sampler lambda can't
## count into the test's locals.)
func start() -> void:
	for i in 10:
		await case.tree.physics_frame
		if not game_match.tanks.get_children().is_empty() and Pathing.is_ready(game_match.tanks.get_child(0)):
			break


## Free this scenario's arena and match now (to run a second scenario in the same test; otherwise the
## TestCase frees them afterwards). Two live arenas would share one physics world.
func dispose() -> void:
	for node: Node in [game_match, arena]:
		if is_instance_valid(node):
			node.free()


## One physics tick.
func step() -> void:
	await case.tree.physics_frame


## True if `viewer` has an unobstructed sight line to `target` (world geometry only).
static func sees(viewer: Tank, target: Tank) -> bool:
	return Perception.has_line_of_sight(viewer, target)


func shots_by(tank: Tank) -> int:
	return (shots.get(String(tank.name), []) as Array).size()


func _place(tank: Tank, position: Vector3, yaw: float) -> void:
	tank.global_position = position
	tank.rotation.y = yaw
	var ticks: Array = []
	shots[String(tank.name)] = ticks
	tank.fired.connect(func(_muzzle: Vector3, _direction: Vector3) -> void: ticks.append(game_match.tick))
