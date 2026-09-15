extends TestCase
## Feel X5: order and selection feedback. Control's K1 Orders decide when orders happen; feel draws the ground markers
## (move, attack, attack-move, follow, hold, stop), the waypoint trail for queued orders, the pulse on newly selected
## units, and the short acknowledgement sounds. Only the local player's orders show; everything is pooled.

const FAKE_ORDERS := """extends RefCounted
signal order_changed(unit_name: String)
signal queue_changed(unit_name: String)
var current_orders := {}
var queues := {}
func current(unit_name: String) -> Dictionary:
	return current_orders.get(unit_name, {})
func queue(unit_name: String) -> Array:
	return queues.get(unit_name, [])
"""
const FAKE_CONTROLS := """extends Node
var team := 0
var selection := Picked.new()
class Picked:
	var units: Array[String] = []
"""


func _setup() -> Dictionary:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	game_match.elimination = true
	fx.link.attach(game_match)
	var script := GDScript.new()
	script.source_code = FAKE_ORDERS
	script.reload()
	var orders: RefCounted = script.new()
	var controls_script := GDScript.new()
	controls_script.source_code = FAKE_CONTROLS
	controls_script.reload()
	var controls: Node = add_to_tree(controls_script.new())
	fx.order_feedback.attach(orders, game_match, controls)
	var green: Array[Tank] = []
	for i in 3:
		green.append(game_match.spawn_tank("G%d" % i, 0, Match.Team.GREEN, "tank"))
	var rust := game_match.spawn_tank("R0", 0, Match.Team.RUST, "tank")
	return {"fx": fx, "match": game_match, "orders": orders, "controls": controls, "green": green, "rust": rust}


func _order(orders: RefCounted, units: Array, id: int, verb: String, extra := {}) -> void:
	for unit_name: String in units:
		var order := {"id": id, "verb": verb, "units": units, "queue": false}
		order.merge(extra)
		orders.current_orders[unit_name] = order
		orders.order_changed.emit(unit_name)


func test_a_group_move_shows_one_marker_and_one_acknowledgement() -> void:
	var s := await _ready_setup()
	var fx: FxWorld = s["fx"]
	var before := fx.order_feedback.markers_started
	_order(s["orders"], ["G0", "G1", "G2"], 1, "move", {"to": [10.0, -20.0]})
	fx.order_feedback.update(fx.now)
	assert_eq(fx.order_feedback.markers_started - before, 1, "three units ordered together get one move marker")
	assert_eq(fx.order_feedback.last_marker_kind, "move", "a move marker")
	assert_near(fx.order_feedback.last_marker_position.x, 10.0, 0.01, "at the destination (x)")
	assert_near(fx.order_feedback.last_marker_position.z, -20.0, 0.01, "at the destination (z)")
	assert_eq(fx.order_feedback.last_acks, PackedStringArray(["ui_ack_move"]), "and one acknowledgement sound")


func test_attack_marks_the_target_and_sounds_different() -> void:
	var s := await _ready_setup()
	var fx: FxWorld = s["fx"]
	var rust: Tank = s["rust"]
	rust.global_position = Vector3(30, 0, 5)
	_order(s["orders"], ["G0", "G1"], 2, "attack", {"target": "R0"})
	fx.order_feedback.update(fx.now)
	assert_eq(fx.order_feedback.last_marker_kind, "attack", "an attack marker")
	assert_near(fx.order_feedback.last_marker_position.x, 30.0, 0.01, "on the target")
	assert_eq(fx.order_feedback.last_acks, PackedStringArray(["ui_ack_attack"]), "with the attack acknowledgement")


func test_every_verb_has_its_own_marker() -> void:
	for verb in ["move", "attack", "attack_move", "follow", "hold", "stop"]:
		assert_true(OrderFeedback.KINDS.has(verb), "%s has a ground marker" % verb)


func test_finished_orders_and_the_enemy_s_orders_show_nothing() -> void:
	var s := await _ready_setup()
	var fx: FxWorld = s["fx"]
	var orders: RefCounted = s["orders"]
	_order(orders, ["G0"], 3, "move", {"to": [0.0, 0.0]})
	fx.order_feedback.update(fx.now)
	var before := fx.order_feedback.markers_started
	orders.current_orders.erase("G0")
	orders.order_changed.emit("G0")
	_order(orders, ["R0"], 4, "move", {"to": [5.0, 5.0]})
	fx.order_feedback.update(fx.now)
	assert_eq(fx.order_feedback.markers_started, before, "a completed order and a CPU order draw no marker")
	assert_true(fx.order_feedback.last_acks.is_empty(), "and play no acknowledgement")


func test_queued_orders_draw_a_waypoint_trail_for_selected_units() -> void:
	var s := await _ready_setup()
	var fx: FxWorld = s["fx"]
	var orders: RefCounted = s["orders"]
	var controls: Node = s["controls"]
	var green: Array = s["green"]
	(green[0] as Tank).global_position = Vector3(0, 0, 0)
	_order(orders, ["G0"], 5, "move", {"to": [0.0, -20.0], "goal": [0.0, -20.0]})
	orders.queues["G0"] = [{"id": 6, "verb": "move", "units": ["G0"], "queue": true, "to": [20.0, -20.0], "goal": [20.0, -20.0]}]
	orders.queue_changed.emit("G0")
	fx.order_feedback.update(fx.now)
	assert_eq(fx.order_feedback.last_marker_kind, "waypoint", "a shift-queued order drops a waypoint marker")
	var markers := fx.order_feedback.markers_started
	orders.queues["G0"].append({"id": 7, "verb": "move", "units": ["G0"], "queue": true, "to": [30.0, 0.0], "goal": [30.0, 0.0]})
	orders.queues["G0"].append({"id": 8, "verb": "move", "units": ["G0"], "queue": true, "to": [30.0, 20.0], "goal": [30.0, 20.0]})
	orders.queue_changed.emit("G0")
	fx.order_feedback.update(fx.now)
	assert_eq(fx.order_feedback.markers_started - markers, 2, "two waypoints queued at once get two markers")
	assert_eq(fx.order_feedback.trail_dots(), 0, "no trail while the unit isn't selected")
	controls.selection.units.assign(["G0"])
	fx.order_feedback.update(fx.now + 0.1)
	assert_true(fx.order_feedback.trail_dots() >= 10, "selected: a dotted trail runs unit → goal → waypoint (%d dots)" % fx.order_feedback.trail_dots())
	orders.queues["G0"] = []
	orders.current_orders.erase("G0")
	fx.order_feedback.update(fx.now + 0.2)
	assert_eq(fx.order_feedback.trail_dots(), 0, "the trail is gone when nothing is queued")


func test_newly_selected_units_pulse_once_with_one_blip() -> void:
	var s := await _ready_setup()
	var fx: FxWorld = s["fx"]
	var controls: Node = s["controls"]
	controls.selection.units.assign(["G0", "G1"])
	var before := fx.order_feedback.markers_started
	fx.order_feedback.update(fx.now)
	assert_eq(fx.order_feedback.markers_started - before, 2, "two newly selected units, two pulses")
	assert_eq(fx.order_feedback.last_acks, PackedStringArray(["ui_select"]), "one selection blip")
	fx.order_feedback.update(fx.now + 0.1)
	assert_true(fx.order_feedback.last_acks.is_empty(), "units that stay selected don't pulse again")


func test_order_feedback_adds_no_nodes() -> void:
	var s := await _ready_setup()
	var fx: FxWorld = s["fx"]
	var nodes := fx.order_feedback.get_child_count()
	for i in 50:
		_order(s["orders"], ["G0", "G1"], 100 + i, "attack_move", {"to": [float(i), 0.0]})
		fx.order_feedback.update(fx.now + i * 0.05)
	assert_eq(fx.order_feedback.get_child_count(), nodes, "fifty orders reuse the pooled markers")


func _ready_setup() -> Dictionary:
	var s := _setup()
	await wait_physics_frames(1)
	return s
