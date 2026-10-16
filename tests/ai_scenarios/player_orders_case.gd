extends TestCase
## The lead, 2026-09-17: *"I start the game by selecting squad 1, having them go somewhere, select squad 2, move them,
## and I do that for all squads. And in just that simple action, the units do not re-arrange as intended."*
##
## His exact sequence, reproduced: three squads on the player's team, each given one move order in turn, then left
## alone. For every unit this reports where it was sent, where it got to, and — after it has been standing there a
## while — whether it stayed. That separates the three things it could be: never moved, moved then drifted back
## toward its spawn (the suspect: ai's "the player's units hold until ordered" post), or moved but never formed up.
## Round 31 (C31.9 / R31.9): the stage of test_ai_player_orders*.gd (split by time); no tests of its own.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## How long each squad gets to make its move before the next order goes out, and how long everything is then left alone.
const MOVE_SECONDS := 10
## The lead orders squad after squad without waiting: this is the gap between his clicks.
const CLICK_GAP_SECONDS := 1
const SETTLE_SECONDS := 15
## A unit counts as "there" within this of the spot it was sent to (formation slots spread a squad out).
const ARRIVED_M := 14.0
## ...and as "drifted" if it moves this far after everything has stopped being ordered.
const DRIFT_M := 6.0
## ...and as "on its slot" within this of the place K1 gave it inside the formation.
const SLOT_M := 6.0

var _match: Match
var _orders: Orders
var _given := {}


func _setup(squad_count := 3, per_squad := 3) -> Dictionary:
	add_to_tree(ARENA.instantiate())
	_match = add_to_tree(MATCH.instantiate())
	_match.seed_spawns(3, 0.0)
	_match.set_meta("player_team", Match.Team.GREEN)
	_orders = Orders.new(_match)
	Orders.attach(_match, _orders)
	var squads := {}
	for i in squad_count:
		squads[["Alpha", "Bravo", "Charlie", "Delta", "Echo"][i]] = []
	var index := 0
	for squad_name: String in squads:
		for i in per_squad:
			var tank := _match.add_brain_tank(Match.Team.GREEN, squad_name, "tank", [{}],
					"Green_%s_%d" % [squad_name, i + 1])
			tank.global_position = Vector3(-90.0 + index * 6.0, 0.0, 95.0)
			tank.rotation.y = PI
			index += 1
			(squads[squad_name] as Array).append(String(tank.name))
	# An enemy far away, so the world is a real match without anything shooting at the player yet.
	var enemy := _match.add_brain_tank(Match.Team.RUST, "Enemy", "tank", [{}], "Rust_A_1")
	enemy.global_position = Vector3(0.0, 0.0, -100.0)
	await wait_physics_frames(6)
	return squads
## Where each unit was actually told to stand: its own slot in the group's formation, from the order it is carrying or
## the station its finished order left it at (K1's own record, not the anchor the player clicked).
func _slots(names: Array) -> Dictionary:
	var out := {}
	for unit_name: String in names:
		var order: Dictionary = _orders.current(unit_name)
		var goal: Variant = OrderFeed.point(order.get("goal")) if not order.is_empty() else null
		if goal == null:
			var station: Dictionary = _orders.station(unit_name)
			goal = OrderFeed.point(station.get("position")) if not station.is_empty() else null
		out[unit_name] = goal
	return out
func _positions(names: Array) -> Dictionary:
	var out := {}
	for unit_name: String in names:
		var tank := _match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		out[unit_name] = Vector3(tank.global_position.x, 0.0, tank.global_position.z) if tank != null else Vector3.INF
	return out
## Who a unit is nosed against, if anyone: the nearest other unit, and whether their hull boxes actually overlap.
##
## combat's mechanism for the yaw-constraint regression is that a crew trying to seat is nosed against a SQUADMATE, the
## plant refuses its arrival yaw because `test_move` counts that squadmate as a wall, and the brain re-tasks a unit that
## never arrives. Their `refusals_applied` / `yaw_vehicle_contact` counters are one half; positions are the other, and
## the two should name the SAME units. If they do not, the story is wrong however well the bisect fits it.
##
## SEPARATING AXIS, not centre distance against a length. My first version compared the gap to the two hull LENGTHS and
## printed `CONTACT` for five squads out of five -- 4.1 to 7.1 m gaps against 8.6 m hulls -- which is worthless, because
## **a label that is always true carries no information**, and it was always true because these crews are ABREAST, where
## the extent that matters is the 2.40 m width and not the 8.62 m length. So: project the offset onto the unit's own
## forward and right (its yaw IS known at this moment, so this is exact rather than a guess) and require BOTH axes to
## overlap, which is `ArmyLayout._is_clear`'s own rule. Five of five was the tell; a vacuous signal is the defect this
## whole round keeps producing.
func _nose_of(unit_name: String, settled: Dictionary) -> String:
	var near := ""
	var near_gap := INF
	for other: String in settled:
		if other == unit_name:
			continue
		var apart: float = (settled[unit_name] as Vector3).distance_to(settled[other] as Vector3)
		if apart < near_gap:
			near_gap = apart
			near = other
	if near == "":
		return ""
	var mine := _match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
	var theirs := _match.tanks.get_node_or_null(NodePath(near)) as Tank
	if mine == null or theirs == null:
		return "; nearest %s at %.1f m (a hull has been freed)" % [near, near_gap]
	var my_size: Array = Units.stat(mine.unit_id, "hull_size", [0.0, 0.0, 0.0])
	var their_size: Array = Units.stat(theirs.unit_id, "hull_size", [0.0, 0.0, 0.0])
	var forward := -mine.global_basis.z
	var right := Vector3(-forward.z, 0.0, forward.x)
	var offset: Vector3 = (settled[near] as Vector3) - (settled[unit_name] as Vector3)
	var across: float = absf(offset.dot(right)) - (float(my_size[0]) + float(their_size[0])) * 0.5
	var along: float = absf(offset.dot(forward)) - (float(my_size[2]) + float(their_size[2])) * 0.5
	# Clear when EITHER axis separates them, which is the pair's clearance (side by side needs width, nose to tail
	# needs length) -- the same separating-axis rule the layout uses to place them in the first place.
	var clearance := maxf(across, along)
	return "; nearest %s at %.1f m, hull gap %.2f m (across %.2f, along %.2f)%s" % [near, near_gap, clearance,
			across, along, " OVERLAPPING" if clearance < 0.0 else ""]
