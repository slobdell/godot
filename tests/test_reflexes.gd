extends TestCase
## Reflexes fire on the simulating peer's real state, once, and re-arm when the condition clears.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Array:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Commanded", 0, Match.Team.GREEN)
	tank.global_position = Vector3(-48, 0, 20)
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	return [game_match, tank, orders]


func test_retreat_below_hp_fires_once_and_rearms() -> void:
	var setup: Array = _setup()
	var tank: Tank = setup[1]
	var orders: OrderController = setup[2]
	orders.set_orders({"type": "stop"}, null, [{"type": "retreat_below_hp", "hp": 40, "x": -48, "z": 50}])
	await wait_physics_frames(2)
	assert_eq(orders.move_order["type"], "stop", "healthy: the reflex stays quiet")
	tank.apply_damage(70)
	await wait_physics_frames(2)
	assert_eq(orders.move_order["type"], "move_to", "below 40 HP the tank retreats")
	assert_eq(orders.move_order.get("reverse"), true, "backing away by default, front armor forward")
	assert_eq(orders.events.size(), 1, "and the event is logged for the commander")
	orders.set_orders({"type": "stop"}, null)
	await wait_physics_frames(5)
	assert_eq(orders.move_order["type"], "stop", "a new order overrides it; it doesn't re-fire while still hurt")
	tank.respawn(tank.global_position, 0.0)
	await wait_physics_frames(2)
	tank.apply_damage(70)
	await wait_physics_frames(2)
	assert_eq(orders.move_order["type"], "move_to", "after healing (respawn) it re-arms and fires again")


func test_halt_on_contact_stops_an_advance() -> void:
	var setup: Array = _setup()
	var game_match: Match = setup[0]
	var orders: OrderController = setup[2]
	var enemy := game_match.spawn_tank("Enemy", 0, Match.Team.RUST)
	enemy.global_position = Vector3(-48, 0, -40)  # far up the open lane, out of range but in sight
	orders.set_orders({"type": "move_to", "x": -48, "z": -30}, {"type": "hold_fire"}, [{"type": "halt_on_contact"}])
	await wait_physics_frames(3)
	assert_eq(orders.move_order["type"], "stop", "an enemy in sight halts the advance")
	assert_true(orders.events.size() == 1 and orders.events[0].contains("Enemy"), "the event names who was seen")
