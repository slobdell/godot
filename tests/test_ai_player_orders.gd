extends TestCase
## The lead, 2026-09-17: *"I start the game by selecting squad 1, having them go somewhere, select squad 2, move them,
## and I do that for all squads. And in just that simple action, the units do not re-arrange as intended."*
##
## His exact sequence, reproduced: three squads on the player's team, each given one move order in turn, then left
## alone. For every unit this reports where it was sent, where it got to, and — after it has been standing there a
## while — whether it stayed. That separates the three things it could be: never moved, moved then drifted back
## toward its spawn (the suspect: ai's "the player's units hold until ordered" post), or moved but never formed up.

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


func test_three_squads_ordered_one_after_another_go_and_stay() -> void:
	var squads := await _setup()
	_match.elimination = true
	var goals := {"Alpha": Vector3(-60, 0, 20), "Bravo": Vector3(0, 0, 20), "Charlie": Vector3(60, 0, 20)}
	var spawned := {}
	for squad_name: String in squads:
		spawned.merge(_positions(squads[squad_name]))
	# The lead's sequence: order a squad, watch it go, order the next.
	for squad_name: String in squads:
		var goal: Vector3 = goals[squad_name]
		var error: String = _orders.issue({"units": squads[squad_name], "verb": "move", "to": [goal.x, goal.z],
				"source": "player"}, Match.Team.GREEN)
		assert_eq(error, "", "squad %s accepts a move order" % squad_name)
		for unit_name: String in squads[squad_name]:
			var given: Dictionary = _orders.current(unit_name)
			_given[unit_name] = OrderFeed.point(given.get("goal")) if not given.is_empty() else null
		await wait_physics_frames(SimClock.TICK_RATE * MOVE_SECONDS)
	# Everyone has now had an order and time to carry it out: this is the mark drift is measured from (the last squad
	# ordered is still driving at the moment the last order goes in, and that journey is not drift).
	await wait_physics_frames(SimClock.TICK_RATE * MOVE_SECONDS)
	var arrived := {}
	for squad_name: String in squads:
		arrived.merge(_positions(squads[squad_name]))
	# Then nobody touches anything.
	await wait_physics_frames(SimClock.TICK_RATE * SETTLE_SECONDS)
	var settled := {}
	for squad_name: String in squads:
		settled.merge(_positions(squads[squad_name]))
	var worst_gap := 0.0
	var worst_drift := 0.0
	var toward_spawn := 0
	for squad_name: String in squads:
		for unit_name: String in squads[squad_name]:
			var goal: Vector3 = _given[unit_name]
			var gap: float = (settled[unit_name] as Vector3).distance_to(goal)
			var drift: float = (settled[unit_name] as Vector3).distance_to(arrived[unit_name])
			var homeward: bool = (settled[unit_name] as Vector3).distance_to(spawned[unit_name]) \
					< (arrived[unit_name] as Vector3).distance_to(spawned[unit_name]) - DRIFT_M
			toward_spawn += 1 if homeward else 0
			worst_gap = maxf(worst_gap, gap)
			worst_drift = maxf(worst_drift, drift)
			print("      %s sent to %v: %.0f m away when the last order went out, %.0f m away after %d s%s" % [
					unit_name, goal, (arrived[unit_name] as Vector3).distance_to(goal), gap, SETTLE_SECONDS,
					", drifting back toward its spawn" if homeward else ""])
	print("MEASURE player_orders worst gap to the spot it was sent %.0f m, worst drift after the orders stopped %.0f m, %d of %d units heading back toward their spawn" % [
			worst_gap, worst_drift, toward_spawn, spawned.size()])
	assert_eq(toward_spawn, 0, "no unit walks back toward its spawn once it has been ordered somewhere")
	assert_true(worst_gap < ARRIVED_M, "every unit is on the slot its squad's order gave it (worst %.0f m)" % worst_gap)
	assert_true(worst_drift < TankBrain.PLAYER_POST_LEASH,
			"and none of them wanders off the ground it was given (worst %.0f m)" % worst_drift)


## The same thing at the size and rhythm the lead plays at: five squads of six, each ordered a second after the last,
## which is as fast as a person can select and right-click.
func test_five_squads_ordered_in_quick_succession() -> void:
	var squads := await _setup(5, 6)
	var goals := {"Alpha": Vector3(-80, 0, 10), "Bravo": Vector3(-40, 0, 10), "Charlie": Vector3(0, 0, 10),
			"Delta": Vector3(40, 0, 10), "Echo": Vector3(80, 0, 10)}
	var spawned := {}
	for squad_name: String in squads:
		spawned.merge(_positions(squads[squad_name]))
	for squad_name: String in squads:
		var goal: Vector3 = goals[squad_name]
		assert_eq(_orders.issue({"units": squads[squad_name], "verb": "move", "to": [goal.x, goal.z],
				"source": "player"}, Match.Team.GREEN), "", "squad %s accepts a move order" % squad_name)
		await wait_physics_frames(SimClock.TICK_RATE * CLICK_GAP_SECONDS)
	await wait_physics_frames(SimClock.TICK_RATE * 40)
	var settled := {}
	for squad_name: String in squads:
		settled.merge(_positions(squads[squad_name]))
	var worst := {}
	var away := 0
	var without_a_slot := 0
	for squad_name: String in squads:
		var slots := _slots(squads[squad_name])
		var far := 0.0
		for unit_name: String in squads[squad_name]:
			var slot: Variant = slots[unit_name]
			if slot == null:
				without_a_slot += 1
				continue
			var gap: float = (settled[unit_name] as Vector3).distance_to(slot as Vector3)
			far = maxf(far, gap)
			# The leash a unit fighting at its post keeps to, with the longer lead an escape (cover, breaking contact) is
			# allowed: beyond that it has left the ground the player gave it.
			away += 1 if gap > TankBrain.PLAYER_POST_LEASH * TankBrain.ESCAPE_LEASH_FACTOR else 0
		worst[squad_name] = snappedf(far, 0.1)
	print("MEASURE player_orders_rapid worst gap to its OWN slot per squad %s; %d of %d units off their slot, %d with no slot at all" % [
			worst, away, spawned.size(), without_a_slot])
	assert_eq(without_a_slot, 0, "every ordered unit still knows where it belongs")
	assert_eq(away, 0, "every unit of every squad ends up on its own slot in its squad's formation")


## The same rhythm again, but with a real army loaded from a doctrine file the way skirmish loads one: its squads carry
## their own verbs, formations and directives, which is the layer between the player's K1 order and the brain.
func test_a_doctrine_army_re_arranges_when_each_squad_is_ordered() -> void:
	add_to_tree(ARENA.instantiate())
	_match = add_to_tree(MATCH.instantiate())
	_match.seed_spawns(3, 0.0)
	_match.elimination = true  # skirmish plays to elimination: a destroyed unit doesn't come back without its orders
	_match.set_meta("player_team", Match.Team.GREEN)
	_orders = Orders.new(_match)
	Orders.attach(_match, _orders)
	for side in 2:
		var loaded := Doctrine.load_file("res://doctrines/%s.json" % ["player_default", "anvil_hammer"][side])
		assert_true(not loaded.has("error"), "army loads: %s" % loaded.get("error", ""))
		assert_eq(_match.load_doctrine(side, loaded["doctrine"]), "", "army spawns")
	await wait_physics_frames(SimClock.TICK_RATE)
	var squads: Array[Squad] = _match.team_squads(Match.Team.GREEN)
	assert_true(squads.size() >= 2, "the player's army has squads to order (%d)" % squads.size())
	var goals := [Vector3(-70, 0, 30), Vector3(70, 0, 30), Vector3(0, 0, 50), Vector3(-40, 0, 60), Vector3(40, 0, 60)]
	var names := {}
	for i in squads.size():
		var roster: Array = []
		for unit_name in squads[i].roster:
			roster.append(String(unit_name))
		names[squads[i].squad_name] = roster
		var goal: Vector3 = goals[i % goals.size()]
		assert_eq(_orders.issue({"units": roster, "verb": "move", "to": [goal.x, goal.z], "source": "player"},
				Match.Team.GREEN), "", "squad %s accepts a move order" % squads[i].squad_name)
		# The slot each unit was actually given, read the moment the order goes in (a station is forgotten once the
		# order finishes, so asking later tells you nothing).
		for unit_name: String in roster:
			var given: Dictionary = _orders.current(unit_name)
			_given[unit_name] = OrderFeed.point(given.get("goal")) if not given.is_empty() else null
		await wait_physics_frames(SimClock.TICK_RATE * CLICK_GAP_SECONDS)
	# What happens to the player's order over the next 40 s: what the brain chose, and whether the order survived.
	var watched: Array = names[names.keys()[0]]
	var log := {}
	for tick in SimClock.TICK_RATE * 40:
		await wait_physics_frames(1)
		if tick % SimClock.TICK_RATE != 0:
			continue
		var unit_name: String = watched[0]
		var brain := _match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
		var order: Dictionary = _orders.current(unit_name)
		var key := "%s | order %s | %s" % [String(brain.choice.get("option", "")), order.get("verb", "(none)"),
				"goal " + str(OrderFeed.point(order.get("goal"))) if not order.is_empty() else "station"]
		log[key] = int(log.get(key, 0)) + 1
	print("      what %s did, seconds per state: %s" % [watched[0], log])
	var away := 0
	var dead := 0
	var worst := {}
	for squad_name: String in names:
		var settled := _positions(names[squad_name])
		var slots := _given
		var far := 0.0
		for unit_name: String in names[squad_name]:
			var tank := _match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank == null or not tank.is_alive():
				dead += 1  # a unit the enemy destroyed has no post to keep
				continue
			if slots[unit_name] == null:
				away += 1
				var lost := _match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
				print("        NO SLOT %s was never given one: current %s" % [unit_name, _orders.current(unit_name)])
				continue
			var gap: float = (settled[unit_name] as Vector3).distance_to(slots[unit_name] as Vector3)
			far = maxf(far, gap)
			var each := _match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
			print("        %s %.0f m from the slot it was sent to; choice %s; post %s; order now %s" % [unit_name, gap,
					each.choice.get("option", "?") if each != null else "(no brain)",
					each._player_post if each != null else "?", _orders.current(unit_name).get("verb", "(none)")])
			# The leash a unit fighting at its post keeps to, with the longer lead an escape (cover, breaking contact) is
			# allowed: beyond that it has left the ground the player gave it.
			away += 1 if gap > TankBrain.PLAYER_POST_LEASH * TankBrain.ESCAPE_LEASH_FACTOR else 0
		worst[squad_name] = snappedf(far, 0.1)
	print("MEASURE player_orders_doctrine_army worst gap to its own slot per squad %s; %d units off their slot, %d destroyed" % [worst, away, dead])
	assert_eq(away, 0, "a doctrine army's squads go where the player sent them and fight from there")


## The invariant (ruled 2026-09-17 after the lead's playtest): **a player's order outranks autonomy.** A unit ordered
## across a fight goes, and keeps going, however tempting the targets on the way. It may shoot while it drives and step
## around a wall of bullets, but it may not decide to stop and fight instead of arriving.
func test_a_unit_ordered_across_contact_arrives() -> void:
	add_to_tree(ARENA.instantiate())
	_match = add_to_tree(MATCH.instantiate())
	_match.seed_spawns(11, 0.0)
	_match.elimination = true
	_match.set_meta("player_team", Match.Team.GREEN)
	_orders = Orders.new(_match)
	Orders.attach(_match, _orders)
	var mover := _match.add_brain_tank(Match.Team.GREEN, "Alpha", "tank", [{}], "Green_A_1")
	mover.global_position = Vector3(-100, 0, 80)
	mover.rotation.y = PI
	mover.max_health = 100000  # the question is whether it arrives, not whether it survives
	mover.health = mover.max_health
	# Two enemies beside the route, close enough to shoot it the whole way.
	for i in 2:
		var gun := _match.add_brain_tank(Match.Team.RUST, "Guns", "tank", [{}], "Rust_G_%d" % (i + 1))
		gun.global_position = Vector3(-55.0, 0.0, 40.0 - i * 40.0)
		gun.max_health = 100000
		gun.health = gun.max_health
	await wait_physics_frames(SimClock.TICK_RATE)
	var goal := Vector3(-100, 0, -60)
	assert_eq(_orders.issue({"units": ["Green_A_1"], "verb": "move", "to": [goal.x, goal.z], "source": "player"},
			Match.Team.GREEN), "", "the order is accepted")
	var options := {}
	var arrived_after := -1.0
	for tick in SimClock.TICK_RATE * 40:
		await wait_physics_frames(1)
		var brain := _match.brains.get_node_or_null("Brain_Green_A_1") as TankBrain
		var option := String(brain.choice.get("option", ""))
		# What it chose WHILE carrying the player's order: once the order is finished it is free to fight from the
		# ground it was given (inside TankBrain.PLAYER_POST_LEASH of it), which the gap below holds it to.
		if not _orders.current("Green_A_1").is_empty():
			options[option] = int(options.get(option, 0)) + 1
		if arrived_after < 0.0 and Vector3(mover.global_position.x, 0.0, mover.global_position.z).distance_to(goal) <= 6.0:
			arrived_after = SimClock.seconds(tick)
	var gap := Vector3(mover.global_position.x, 0.0, mover.global_position.z).distance_to(goal)
	print("MEASURE ordered_across_contact arrived after %.1f s, %.0f m from the spot 40 s later; while it carried the order it spent its time on %s" % [
			arrived_after, gap, options])
	assert_true(arrived_after >= 0.0, "a unit ordered across a fight arrives (%.0f m short after 40 s)" % gap)
	for option: String in options:
		assert_true(["MOVE", "", "HOLD"].has(option),
				"and nothing else takes the wheel on the way: it spent %d ticks on %s" % [options[option], option])
	assert_true(gap <= TankBrain.PLAYER_POST_LEASH,
			"and it fights from the ground it was given rather than wandering off (%.0f m away)" % gap)
